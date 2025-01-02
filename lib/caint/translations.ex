defmodule Caint.Translations do
  @moduledoc """
  Enhanced type `translation` for Caint

  This map is both input and output for translations.
  """
  alias Caint.PoParsing
  alias Caint.Translatables.Translatable
  alias Caint.Translations.Translation
  alias Expo.Message.Plural
  alias Expo.Message.Singular

  @spec build_translations_from_po_files(PoParsing.gettext_dir(), Gettext.locale() | nil) :: [Translation.t()]
  def build_translations_from_po_files(gettext_dir, locale) do
    gettext_dir
    |> PoParsing.po_paths_in_priv(locale)
    |> Enum.flat_map(fn po_path ->
      domain = infer_domain_from_po_path(po_path)
      messages = Expo.PO.parse_file!(po_path).messages

      Enum.map(messages, fn message ->
        context = build_context(message)
        %Translation{message: message, domain: domain, context: context, locale: locale}
      end)
    end)
  end

  @spec put_translated_message_on_translated([Translatable.t()]) :: Translation.t()
  def put_translated_message_on_translated(translated) do
    case translated do
      [%Translatable{translation: %{message: %Singular{}}} = singular_translated] ->
        put_translated_message_on_translation_for_singular(singular_translated)

      [%Translatable{translation: %{message: %Plural{}}} | _] = plural_translateds ->
        put_translated_message_on_translation_for_plural(plural_translateds)
    end
  end

  def translate_single(msgid, msgctxt, locale, domain) do
  end

  defp build_context(message) do
    case message.msgctxt do
      [""] -> nil
      msgctxt -> Enum.join(msgctxt || [], "\n")
    end
  end

  defp infer_domain_from_po_path(po_path) do
    Path.basename(po_path, ".po")
  end

  defp put_translated_message_on_translation_for_singular(singular_translated) do
    msgstr = [singular_translated.translated_text]
    translated_message = Map.put(singular_translated.translation.message, :msgstr, msgstr)
    %{singular_translated.translation | message: translated_message}
  end

  defp put_translated_message_on_translation_for_plural(plural_translateds) do
    [
      %{translation: %{message: %Plural{} = message} = translation} =
        _first_translated
      | _
    ] = plural_translateds

    msgstr =
      Enum.reduce(plural_translateds, %{}, fn translated, msgstr ->
        re_interpolated = String.replace(translated.translated_text, "#{translated.plural_number}", "%{count}")
        Map.put(msgstr, translated.plural_index, [re_interpolated])
      end)

    translated_message = Map.put(message, :msgstr, msgstr)
    %{translation | message: translated_message}
  end
end
