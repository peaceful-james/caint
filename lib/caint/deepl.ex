defmodule Caint.Deepl do
  @moduledoc """
  DeepL integration high-level functions
  """

  alias Caint.Deepl.Api
  alias Caint.ExpoLogic
  alias Caint.Percentage
  alias Caint.Plurals
  alias Caint.Translatables
  alias Caint.Translations
  alias Caint.Translations.Translation

  @spec usage_percent() :: {:ok, Decimal.t()} | {:error, String.t()}
  def usage_percent do
    case Api.usage() do
      {:ok, %{body: %{"character_count" => character_count, "character_limit" => character_limit}}} ->
        {:ok, Percentage.percentage(character_count, character_limit)}

      {:error, _} ->
        {:error, "Failed to get usage"}
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

  @spec translate_all_untranslated([Translation.t()], Gettext.locale()) :: [Translation.t()]
  def translate_all_untranslated(translations, locale) do
    plural_numbers_by_index = Plurals.build_plural_numbers_by_index_for_locale(locale)
    {done, untranslated} = Enum.split_with(translations, &ExpoLogic.message_translated?(&1.message))

    translatables_by_context =
      untranslated
      |> Enum.flat_map(&Translatables.to_translatables(&1, plural_numbers_by_index))
      |> Enum.group_by(& &1.translation.context)

    source_lang = language_code(Application.get_env(:caint, :source_locale))
    target_lang = language_code(locale)

    translatables_by_context
    |> Enum.flat_map(fn {context, same_context_translatables} ->
      same_context_translatables
      |> Enum.chunk_every(Api.batch_size())
      |> Enum.flat_map(&translate_same_context_translatables_batch(&1, context, source_lang, target_lang))
    end)
    |> Enum.group_by(&{&1.translation.domain, &1.translation.message.msgid, &1.translation.message.msgctxt})
    |> Enum.map(fn {_messages_key, translated} ->
      Translations.put_translated_message_on_translated(translated)
    end)
    |> Kernel.++(done)
  end

  defp translate_same_context_translatables_batch(same_context_translatables_batch, context, source_lang, target_lang) do
    {:ok, %{body: %{"translations" => deepl_results}}} =
      same_context_translatables_batch
      |> to_translate_data(context, source_lang, target_lang)
      |> Api.translate()

    same_context_translatables_batch
    |> Enum.zip(deepl_results)
    |> Enum.map(fn {translatable, %{"text" => xml_tagged_translated_text}} ->
      translated_text = replace_xml_tags_with_curly_brackets(xml_tagged_translated_text)
      %{translatable | translated_text: translated_text}
    end)
  end

  defp to_translate_data(same_context_translatables_batch, context, source_lang, target_lang) do
    text = Enum.map(same_context_translatables_batch, &replace_curly_brackets_with_xml_tags(&1.text))

    %{
      text: text,
      source_lang: source_lang,
      target_lang: target_lang,
      context: context,
      tag_handling: "xml",
      ignore_tags: ["gettext_variable"]
    }
  end

  defp replace_curly_brackets_with_xml_tags(text) do
    Regex.replace(~r/%{(.*)}/, text, fn _, x -> "<gettext_variable>#{x}</gettext_variable>" end)
  end

  defp replace_xml_tags_with_curly_brackets(text) do
    Regex.replace(~r/<gettext_variable>(.*)<\/gettext_variable>/, text, fn _, x -> "%{#{x}}" end)
  end
end
