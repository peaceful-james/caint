defmodule Caint.Deepl do
  @moduledoc """
  --header 'Authorization: DeepL-Auth-Key [yourAuthKey]' \
  --header 'Content-Type: application/json' \
  """

  alias Caint.Plurals

  @batch_size 50

  defp api_url, do: Application.get_env(:caint, :deepl_api_url)
  defp api_key, do: Application.get_env(:caint, :deepl_api_key)
  defp auth_header, do: "DeepL-Auth-Key #{api_key()}"


  @doc """
  Return the DeepL language code for a given gettext locale.

  https://developers.deepl.com/docs/resources/supported-languages

  Note that Portuguse in Brazil is simply "pt" in gettext, but DeepL requires "PT-BR".
  """
  def language_code(gettext_locale) do
    case gettext_locale |> to_string() |> String.replace("_", "-") do
      "pt" -> "PT-BR"
      x -> String.upcase(x)
    end
  end

  def translate(data) do
    api_url()
    |> Path.join("translate")
    |> Req.post(auth: auth_header(), json: data)
  end

  def translate_all_untranslated(translations, locale) do
    source_lang = language_code(Application.get_env(:caint, :source_locale))
    target_lang = language_code(locale)
    {:ok, forms_struct} = Expo.PluralForms.plural_form(locale)
    plural_numbers_by_index = Plurals.plural_numbers_by_index(forms_struct)
    {done, untranslated} = Enum.split_with(translations, &Caint.message_translated?(&1.message))

    untranslated
    |> Enum.flat_map(&to_translatables(&1, plural_numbers_by_index))
    |> Enum.group_by(& &1.translation.context)
    |> Enum.flat_map(fn {context, same_context_translatables} ->
      same_context_translatables
      |> Enum.chunk_every(@batch_size)
      |> Enum.flat_map(&translate_same_context_translatables_batch(&1, context, source_lang, target_lang))
    end)
    |> Enum.group_by(&{&1.translation.domain, &1.translation.message.msgid, &1.translation.message.msgctxt})
    |> Enum.map(fn {_messages_key, translated} ->
      case translated do
        [
          %{translation: %{message: %Expo.Message.Singular{} = message} = translation, translated_text: translated_text} =
              _single_translated
        ] ->
          msgstr = [translated_text]
          translated_message = Map.put(message, :msgstr, msgstr)
          _new_translation = Map.put(translation, :message, translated_message)

        # Map.put(single_translated, :translation, new_translation)     #

        [
          %{translation: %{message: %Expo.Message.Plural{} = message} = translation} =
            _first_translated
          | _
        ] = plural_translateds ->
          msgstr =
            Enum.reduce(plural_translateds, %{}, fn translated, msgstr ->
              re_interpolated = String.replace(translated.translated_text, "#{translated.plural_number}", "%{count}")
              Map.put(msgstr, translated.plural_index, [re_interpolated])
            end)

          translated_message = Map.put(message, :msgstr, msgstr)
          _new_translation = Map.put(translation, :message, translated_message)
          # Map.put(first_translated, :translation, new_translation)
      end
    end)
    |> Kernel.++(done)
  end

  @type translatable :: %{
          translation: Translations.translation(),
          text: String.t(),
          plural_index: nil | non_neg_integer(),
          plural_number: nil | non_neg_integer()
        }
  defp to_translatables(translation, plural_numbers_by_index) do
    case translation.message do
      %Expo.Message.Singular{} = message ->
        text = Enum.join(message.msgid, "\n")

        [
          %{
            translation: translation,
            text: text,
            plural_index: nil,
            plural_number: nil
          }
        ]

      %Expo.Message.Plural{} = message ->
        Enum.map(plural_numbers_by_index, fn {plural_index, plural_number} ->
          [msg] =
            if plural_number == 1 do
              message.msgid
            else
              message.msgid_plural
            end

          interpolatable = Gettext.Interpolation.Default.to_interpolatable(msg)
          good_bindings = %{count: plural_number}
          {:ok, text} = Gettext.Interpolation.Default.runtime_interpolate(interpolatable, good_bindings)

          %{
            translation: translation,
            text: text,
            plural_index: plural_index,
            plural_number: plural_number
          }
        end)
    end
  end

  defp translate_same_context_translatables_batch(same_context_translatables_batch, context, source_lang, target_lang) do
    {:ok, %{body: %{"translations" => deepl_results}}} =
      same_context_translatables_batch
      |> to_translate_data(context, source_lang, target_lang)
      |> translate()

    same_context_translatables_batch
    |> Enum.zip(deepl_results)
    |> Enum.map(fn {translatable, %{"text" => translated_text}} ->
      Map.put(translatable, :translated_text, replace_xml_tags_with_curly_brackets(translated_text))
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
