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
  """
  @spec translate_all_untranslated([Translation.t()], keyword()) :: {[Translation.t()], [error()]}
  def translate_all_untranslated(translations, opts \\ []) do
    on_progress = Keyword.get(opts, :on_progress, fn _ -> :ok end)
    max_concurrency = Keyword.get(opts, :max_concurrency, Application.get_env(:caint, :deepl_max_concurrency, 3))
    source_lang = language_code(Application.get_env(:caint, :source_locale))

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
      |> Task.async_stream(&translate_batch(&1, source_lang),
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

  defp translate_batch(%{locale: locale, context: context, translatables: translatables}, source_lang) do
    data = %{
      text: Enum.map(translatables, &Markup.encode(&1.text, &1.plural_number)),
      source_lang: source_lang,
      target_lang: language_code(locale),
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
