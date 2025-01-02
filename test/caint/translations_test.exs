defmodule Caint.TranslationsTest do
  use ExUnit.Case

  alias Caint.Translatables.Translatable
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
                 context: nil
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

  describe "put_translated_message_on_translated/1" do
    test "works for singular" do
      translated_text = "translated text"

      singular_translatable = %Translatable{
        translation: %Translation{
          message: %Singular{msgid: ["msgid"], msgstr: [""]},
          context: "context",
          domain: "domain",
          locale: "en"
        },
        text: "text",
        translated_text: translated_text,
        plural_index: nil,
        plural_number: nil
      }

      result = Translations.put_translated_message_on_translated([singular_translatable])
      assert %Translation{message: %Singular{msgstr: [^translated_text]}} = result
    end

    test "works for plural" do
      translated_text_0 = "1 mot"
      translated_text_1 = "2 mots"
      expected_translated_msgstr = %{0 => ["%{count} mot"], 1 => ["%{count} mots"]}

      plural_translatable_0 = %Translatable{
        translation: %Translation{
          message: %Plural{msgid: ["%{count} thing"], msgid_plural: ["%{count} things"], msgstr: %{0 => [""], 1 => [""]}},
          context: "context",
          domain: "domain",
          locale: "fr"
        },
        text: "text",
        translated_text: translated_text_0,
        plural_index: 0,
        plural_number: 1
      }

      plural_translatable_1 = %Translatable{
        translation: %Translation{
          message: %Plural{msgid: ["%{count} thing"], msgid_plural: ["%{count} things"], msgstr: %{0 => [""], 1 => [""]}},
          context: "context",
          domain: "domain",
          locale: "fr"
        },
        text: "text",
        translated_text: translated_text_1,
        plural_index: 1,
        plural_number: 2
      }

      plural_translatables = [plural_translatable_0, plural_translatable_1]

      result = Translations.put_translated_message_on_translated(plural_translatables)
      assert %Translation{message: %Plural{msgstr: ^expected_translated_msgstr}} = result
    end
  end

  describe "translate_single/4" do
    test "works for singular" do
      gettext_dir = Application.get_env(:caint, :gettext_dir)
      locale = "ar"
      translations = Translations.build_translations_from_po_files(gettext_dir, locale)

      singular_translation =
        Enum.find(translations, fn
          %Translation{message: %Singular{}} -> true
          _ -> false
        end)

      plural_index = nil
      new_text = "Manually entered by user"
      result = Translations.translate_single(singular_translation, gettext_dir, locale, plural_index, new_text)
      assert result == [Translations]
      new_translations = Translations.build_translations_from_po_files(gettext_dir, locale)
      new_singular_translation = Enum.find(new_translations, &(&1.msgid == singular_translation.msgid))
      assert new_singular_translation.msgstr == [new_text]
    end

    test "works for plural"
  end
end
