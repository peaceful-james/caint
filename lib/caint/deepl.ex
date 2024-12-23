defmodule Caint.Deepl do
  @moduledoc """
  --header 'Authorization: DeepL-Auth-Key [yourAuthKey]' \
  --header 'Content-Type: application/json' \
  """

  @domain "https://api-free.deepl.com/v2/"
  @batch_size 50

  defp api_key, do: Application.get_env(:caint, :deepl_api_key)
  defp auth_header, do: "DeepL-Auth-Key #{api_key()}"

  def language_code(gettext_locale) do
    gettext_locale
    |> to_string()
    |> String.replace("_", "-")
    |> String.upcase()
  end

  def translate(data) do
    @domain
    |> Path.join("translate")
    |> Req.post(auth: IO.inspect(auth_header(), label: "AUTH HEAD"), json: data)
  end

  def translate_all_untranslated(translations) do
    translations
    |> Enum.reject(&Caint.message_translated?(&1.message))
    |> Enum.group_by(& &1.message.msgctxt)
    |> Enum.flat_map(fn {_context, same_context_translations} ->
      same_context_translations
      |> Enum.chunk_every(@batch_size)
      |> Enum.map(fn list_of_same_context_translations ->
        {:ok, %{body: %{"translations" => deepl_results}}} =
          list_of_same_context_translations
          |> to_translate_data()
          |> translate()

        list_of_same_context_translations
        |> Enum.zip(deepl_results)
        |> Enum.map(fn {translation, %{"text" => translated_text}} ->
          Map.update!(translation, :message, fn message ->
            %{message | msgstr: [translated_text]}
          end)
        end)
      end)
    end)
  end

  defp to_translate_data(list_of_same_context_translations) do
    [%{locale: locale, message: message} | _] = list_of_same_context_translations

    text =
      Enum.map(list_of_same_context_translations, fn translation ->
        Enum.join(translation.message.msgid, "\n")
      end)

    context = Enum.join(message.msgctxt, "\n")

    %{
      text: text,
      source_lang: language_code("en"),
      target_lang: language_code(locale),
      context: context
    }
  end
end
