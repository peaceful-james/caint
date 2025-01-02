defmodule Caint.TranslatablesTest do
  use ExUnit.Case

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

      plural_numbers_by_index = %{}
      result = Translatables.to_translatables(translation, plural_numbers_by_index)

      assert [
               %Translatable{
                 text: "msgid",
                 translation: ^translation,
                 plural_index: nil,
                 plural_number: nil,
                 translated_text: nil
               }
             ] = result
    end

    test "works for plural translation" do
      translation =
        %Translation{
          message: %Plural{
            msgid: ["1 category"],
            msgstr: %{0 => [""], 1 => [""]},
            msgctxt: ["context"],
            msgid_plural: ["%{count} categories"]
          },
          context: "context",
          domain: "domain",
          locale: "en"
        }

      plural_numbers_by_index = %{0 => 1, 1 => 2}
      result = Translatables.to_translatables(translation, plural_numbers_by_index)

      assert [
               %Translatable{
                 text: "1 category",
                 translation: ^translation,
                 plural_index: 0,
                 plural_number: 1,
                 translated_text: nil
               },
               %Translatable{
                 text: "2 categories",
                 translation: ^translation,
                 plural_index: 1,
                 plural_number: 2,
                 translated_text: nil
               }
             ] = result
    end
  end
end
