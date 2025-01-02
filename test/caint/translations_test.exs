defmodule Caint.TranslationsTest do
  use ExUnit.Case

  alias Caint.Translations
  alias Caint.Translations.Translation
  alias Expo.Message.Plural
  alias Expo.Message.Singular

  describe "build_translations_from_po_files/2" do
    test "works" do
      gettext_dir = Application.get_env(:caint, :gettext_dir)
      locale = "ar"
      result = Translations.build_translations_from_po_files(gettext_dir, locale)

      assert [
               %Translation{
                 message: %Singular{msgid: ["Ambiguous time for timezone"]},
                 context: "datetime picker"
               },
               %Translation{
                 message: %Singular{msgid: ["Invalid date/time"]},
                 context: "datetime picker"
               },
               %Translation{
                 message: %Singular{msgid: ["Unable to upload file"]},
                 context: "file uploader"
               },
               %Translation{
                 message: %Singular{msgid: ["Help"]},
                 context: "imperative verbs"
               },
               %Translation{
                 message: %Singular{msgid: ["Help"]},
                 context: "nouns"
               },
               %Translation{
                 message: %Plural{msgid: ["should be %{count} byte(s)"]},
                 context: "errors"
               },
               %Translation{
                 message: %Plural{msgid: ["should be %{count} character(s)"]},
                 context: "errors"
               }
             ] = result

      assert Enum.all?(result, &(&1.domain == "caint\\ testing"))
      assert Enum.all?(result, &(&1.locale == "ar"))
    end
  end

  describe "put_translated_message_on_translated/2" do
    test "works for singular"
    test "works for plural"
    end
end
