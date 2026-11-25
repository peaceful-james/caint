defmodule Caint.TranslatablesTest do
  use ExUnit.Case, async: true

  alias Caint.Translatables
  alias Caint.Translatables.Translatable
  alias Caint.Translations.Translation
  alias Expo.Message.Plural
  alias Expo.Message.Singular

  describe "to_translatables/2" do
    test "works for singular translation" do
      translation = %Translation{
        message: %Singular{msgid: ["msgid"], msgstr: [""]},
        context: "context",
        domain: "domain",
        locale: "en"
      }

      assert [
               %Translatable{
                 text: "msgid",
                 translation: ^translation,
                 plural_index: nil,
                 plural_number: nil,
                 translated_text: nil
               }
             ] = Translatables.to_translatables(translation)
    end

    test "concatenates multi-line msgids without adding newlines" do
      translation = %Translation{
        message: %Singular{msgid: ["", "Hello ", "world"], msgstr: [""]},
        context: nil,
        domain: "domain",
        locale: "en"
      }

      assert [%Translatable{text: "Hello world"}] = Translatables.to_translatables(translation)
    end

    test "works for plural translation, keeping %{count} in the text" do
      translation = plural_translation(%{0 => [""], 1 => [""]})

      assert [
               %Translatable{
                 text: "1 category",
                 translation: ^translation,
                 plural_index: 0,
                 plural_number: 1,
                 translated_text: nil
               },
               %Translatable{
                 text: "%{count} categories",
                 translation: ^translation,
                 plural_index: 1,
                 plural_number: 2,
                 translated_text: nil
               }
             ] = Translatables.to_translatables(translation)
    end

    test "only_missing skips plural forms that are already translated" do
      translation = plural_translation(%{0 => ["1 catégorie"], 1 => [""]})

      assert [%Translatable{plural_index: 1}] = Translatables.to_translatables(translation, only_missing: true)
      assert [_, _] = Translatables.to_translatables(translation)
    end
  end

  defp plural_translation(msgstr) do
    %Translation{
      message: %Plural{
        msgid: ["1 category"],
        msgstr: msgstr,
        msgctxt: ["context"],
        msgid_plural: ["%{count} categories"]
      },
      context: "context",
      domain: "domain",
      locale: "fr",
      plural_numbers_by_index: %{0 => 1, 1 => 2}
    }
  end
end
