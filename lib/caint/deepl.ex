defmodule Caint.Deepl do
  @moduledoc """
  DeepL integration high-level functions
  """

  alias Caint.Deepl.Api
  alias Caint.Deepl.Markup
  alias Caint.ExpoLogic
  alias Caint.Percentage
  alias Caint.Translatables
  alias Caint.Translations
  alias Caint.Translations.Translation
  alias Expo.Message
  alias Expo.Message.Plural

  require Logger

  @typedoc "A batch of messages that could not be translated, and why."
  @type error :: %{locale: Gettext.locale(), reason: String.t(), message_count: pos_integer()}

  @typedoc "Progress of a translation run, in DeepL requests (batches)."
  @type progress :: %{done: non_neg_integer(), total: non_neg_integer()}

  @spec usage_percent() :: {:ok, Decimal.t()} | {:error, String.t()}
  def usage_percent do
    case Api.usage() do
      {:ok, %{status: 200, body: %{"character_count" => character_count, "character_limit" => character_limit}}} ->
        {:ok, Percentage.percentage(character_count, character_limit)}

      other ->
        {:error, "Failed to get DeepL usage: " <> describe_error(other)}
    end
  end

  @doc """
  Return the DeepL language code for a given gettext locale.

  https://developers.deepl.com/docs/resources/supported-languages

  Note that Portuguse in Brazil is simply "pt" in gettext, but DeepL requires "PT-BR".
  """
  @spec language_code(Gettext.locale()) :: String.t()
  def language_code(gettext_locale) do
    case gettext_locale |> to_string() |> String.replace("_", "-") do
      "pt" -> "PT-BR"
      x -> String.upcase(x)
    end
  end

  @typedoc "What to do with a locale: translate it into a DeepL target code, or skip it (and why)."
  @type target :: {:translate, String.t()} | {:skip, String.t()}

  @doc """
  The DeepL codes usable as translation targets (upper-cased, e.g. `"DE"`, `"EN-GB"`, `"PT-BR"`),
  or `:error` if DeepL could not be asked.
  """
  @spec target_languages() :: {:ok, MapSet.t(String.t())} | :error
  def target_languages do
    case Api.target_languages() do
      {:ok, %{status: 200, body: languages}} when is_list(languages) ->
        {:ok,
         for(%{"lang" => lang, "usable_as_target" => true} <- languages, into: MapSet.new(), do: String.upcase(lang))}

      other ->
        Logger.warning("Could not get DeepL target languages, translating every locale: #{describe_error(other)}")
        :error
    end
  end

  @doc """
  Decide whether, and into which DeepL target language, to translate a gettext locale.

  In order:

    1. An override wins. They default to
       `config :caint, deepl_locale_overrides: %{"en_IE" => :skip, "nb" => "NB"}`.
    2. Locales in the same language as the source locale (e.g. `en`, `en_IE` from `en`) are skipped:
       they need no translation, and Gettext falls back to the msgid anyway.
    3. If DeepL's target languages are known, use the locale's code if supported, else its base
       language (`fr_CA` -> `FR`), else the first regional variant of it (`zh` -> `ZH-HANS`),
       else skip the locale as unsupported.
    4. If they are not known, translate using `language_code/1` and let DeepL decide.
  """
  @spec resolve_target(Gettext.locale(), {:ok, MapSet.t(String.t())} | :error, %{
          optional(String.t()) => :skip | String.t()
        }) :: target()
  def resolve_target(locale, supported_targets, overrides \\ configured_overrides()) do
    locale = to_string(locale)
    code = language_code(locale)
    override = Map.get(overrides, locale)

    cond do
      override == :skip -> {:skip, "skipped in config"}
      is_binary(override) -> {:translate, String.upcase(override)}
      base_language(code) == base_language(language_code(source_locale())) -> {:skip, "same language as the source"}
      supported_targets == :error -> {:translate, code}
      true -> resolve_supported_target(code, elem(supported_targets, 1))
    end
  end

  defp resolve_supported_target(code, supported) do
    base = base_language(code)
    variant = supported |> Enum.sort() |> Enum.find(&String.starts_with?(&1, base <> "-"))

    cond do
      code in supported -> {:translate, code}
      base in supported -> {:translate, base}
      variant -> {:translate, variant}
      true -> {:skip, "not supported by DeepL"}
    end
  end

  defp configured_overrides, do: Application.get_env(:caint, :deepl_locale_overrides, %{})
  defp source_locale, do: Application.get_env(:caint, :source_locale)
  defp base_language(code), do: code |> String.split("-") |> hd()

  @doc """
  Machine-translate every untranslated message (or untranslated plural form) in `translations`.

  `translations` may span several locales. Messages are sent in batches (one batch per locale,
  context and `Api.batch_size/0` messages), several batches at a time. Throttling and other
  transient failures are retried by the API layer; a batch that still fails is reported in
  the returned errors and its messages are left untranslated, while the other batches still succeed.

  Returns only the translations that changed.

  ## Options

    * `:max_concurrency` - how many DeepL requests to have in flight at once.
      Defaults to the `:deepl_max_concurrency` app env, or `3`.
    * `:on_progress` - a 1-arity function called with a `t:progress/0` map after each batch.
    * `:target_langs` - a map of locale to DeepL target code (see `resolve_target/2`).
      Locales not in it use `language_code/1`.
  """
  @spec translate_all_untranslated([Translation.t()], keyword()) :: {[Translation.t()], [error()]}
  def translate_all_untranslated(translations, opts \\ []) do
    on_progress = Keyword.get(opts, :on_progress, fn _ -> :ok end)
    max_concurrency = Keyword.get(opts, :max_concurrency, Application.get_env(:caint, :deepl_max_concurrency, 3))
    target_langs = Keyword.get(opts, :target_langs, %{})
    # DeepL source languages have no regional variants (e.g. "EN", not "EN-GB").
    source_lang = base_language(language_code(source_locale()))

    untranslated = Enum.reject(translations, &ExpoLogic.message_translated?(&1.message))

    # Without plural rules we cannot pick example numbers, so those messages are left as they are.
    {no_plural_rules, translatable} =
      Enum.split_with(untranslated, &(match?(%Plural{}, &1.message) and &1.plural_numbers_by_index == %{}))

    batches =
      translatable
      |> Enum.flat_map(&Translatables.to_translatables(&1, only_missing: true))
      |> Enum.group_by(&{&1.translation.locale, &1.translation.context})
      |> Enum.flat_map(fn {{locale, context}, translatables} ->
        translatables
        |> Enum.chunk_every(Api.batch_size())
        |> Enum.map(&%{locale: locale, context: context, translatables: &1})
      end)

    total = length(batches)
    on_progress.(%{done: 0, total: total})

    {translated, errors} =
      batches
      |> Task.async_stream(&translate_batch(&1, source_lang, target_langs),
        max_concurrency: max(max_concurrency, 1),
        ordered: false,
        timeout: :infinity
      )
      |> Stream.with_index(1)
      |> Enum.reduce({[], []}, fn {{:ok, result}, done}, {translated, errors} ->
        on_progress.(%{done: done, total: total})

        case result do
          {:ok, translatables} -> {translatables ++ translated, errors}
          {:error, error} -> {translated, [error | errors]}
        end
      end)

    new_translations =
      translated
      |> Enum.group_by(&{&1.translation.locale, &1.translation.domain, Message.key(&1.translation.message)})
      |> Enum.map(fn {_id, same_message} ->
        same_message
        |> Enum.sort_by(& &1.plural_index)
        |> Translations.put_translated_message_on_translated()
      end)

    {new_translations, no_plural_rules_errors(no_plural_rules) ++ Enum.reverse(errors)}
  end

  defp no_plural_rules_errors(translations) do
    translations
    |> Enum.frequencies_by(& &1.locale)
    |> Enum.map(fn {locale, count} ->
      %{
        locale: locale,
        reason: "no plural rules known for #{inspect(locale)} (add a Plural-Forms header to its PO files)",
        message_count: count
      }
    end)
  end

  defp translate_batch(%{locale: locale, context: context, translatables: translatables}, source_lang, target_langs) do
    data = %{
      text: Enum.map(translatables, &Markup.encode(&1.text, &1.plural_number)),
      source_lang: source_lang,
      target_lang: Map.get_lazy(target_langs, locale, fn -> language_code(locale) end),
      context: context,
      tag_handling: "xml",
      ignore_tags: Markup.ignore_tags()
    }

    case Api.translate(data) do
      {:ok, %{status: 200, body: %{"translations" => results}}} when length(results) == length(translatables) ->
        {:ok, Enum.zip_with(translatables, results, &put_translated_text/2)}

      other ->
        reason = describe_error(other)
        Logger.warning("DeepL failed to translate #{message_count(translatables)} #{locale} message(s): #{reason}")
        {:error, %{locale: locale, reason: reason, message_count: message_count(translatables)}}
    end
  rescue
    # Never let one odd batch take down the whole run.
    exception ->
      reason = Exception.message(exception)
      Logger.error("DeepL batch crashed: #{reason}")
      {:error, %{locale: locale, reason: reason, message_count: message_count(translatables)}}
  end

  # A plural message contributes one translatable per plural form; count it once.
  defp message_count(translatables) do
    translatables
    |> Enum.uniq_by(&{&1.translation.domain, Message.key(&1.translation.message)})
    |> length()
  end

  defp put_translated_text(translatable, %{"text" => text}) do
    # Only look for a bare example number if the source actually had a `%{count}` to restore.
    plural_number = if String.contains?(translatable.text, "%{count}"), do: translatable.plural_number
    %{translatable | translated_text: Markup.decode(text, plural_number)}
  end

  defp describe_error({:ok, %{status: 403}}), do: "DeepL rejected the API key (HTTP 403)"
  defp describe_error({:ok, %{status: 456}}), do: "DeepL character quota exceeded (HTTP 456)"
  defp describe_error({:ok, %{status: 429}}), do: "still throttled by DeepL after retrying (HTTP 429)"

  defp describe_error({:ok, %{status: 200}}), do: "unexpected response from DeepL"

  defp describe_error({:ok, %{status: status, body: %{"message" => message}}}), do: "HTTP #{status}: #{message}"
  defp describe_error({:ok, %{status: status}}), do: "HTTP #{status}"
  defp describe_error({:error, exception}) when is_exception(exception), do: Exception.message(exception)
  defp describe_error({:error, reason}), do: inspect(reason)
end
