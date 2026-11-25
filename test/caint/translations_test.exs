defmodule Caint.TranslationsTest do
  use ExUnit.Case, async: true

  alias Caint.Fixtures
  alias Caint.Translatables.Translatable
  alias Caint.Translations
  alias Caint.Translations.Translation
  alias Expo.Message.Plural
  alias Expo.Message.Singular

  @moduletag :tmp_dir

  setup %{tmp_dir: tmp_dir} do
    {:ok, gettext_dir: Fixtures.copy_gettext_dir!(tmp_dir)}
  end

  describe "build_translations_from_po_files/2" do
    test "works", %{gettext_dir: gettext_dir} do
      result = Translations.build_translations_from_po_files(gettext_dir, "ar")

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

      assert Enum.all?(result, &(&1.domain == "caint testing"))
      assert Enum.all?(result, &(&1.locale == "ar"))
      assert Enum.all?(result, &(&1.plural_numbers_by_index == %{0 => 0, 1 => 1, 2 => 2, 3 => 3, 4 => 11, 5 => 100}))
    end

    test "gives every message a distinct, stable id", %{gettext_dir: gettext_dir} do
      ids = gettext_dir |> Translations.build_translations_from_po_files("ar") |> Enum.map(& &1.id)
      assert ids == Enum.uniq(ids)
      assert ids == gettext_dir |> Translations.build_translations_from_po_files("ar") |> Enum.map(& &1.id)
      assert Enum.all?(ids, &(&1 =~ ~r/^[A-Za-z0-9_-]+$/))
    end

    test "uses the PO file's Plural-Forms header", %{gettext_dir: gettext_dir} do
      Fixtures.write_po!(gettext_dir, "tlh", "default", """
      msgid ""
      msgstr ""
      "Plural-Forms: nplurals=2; plural=(n != 1);\\n"

      msgid "1 file"
      msgid_plural "%{count} files"
      msgstr[0] ""
      msgstr[1] ""
      """)

      assert [%Translation{plural_numbers_by_index: %{0 => 1, 1 => 2}}] =
               Translations.build_translations_from_po_files(gettext_dir, "tlh")
    end

    test "concatenates multi-line msgctxt", %{gettext_dir: gettext_dir} do
      Fixtures.write_po!(gettext_dir, "fr", "default", """
      msgctxt ""
      "long "
      "context"
      msgid "Hi"
      msgstr ""
      """)

      assert [%Translation{context: "long context"}] = Translations.build_translations_from_po_files(gettext_dir, "fr")
    end
  end

  describe "fetch_translation/3" do
    test "finds a translation by id, or :error", %{gettext_dir: gettext_dir} do
      [_, second | _] = Translations.build_translations_from_po_files(gettext_dir, "ar")
      assert {:ok, ^second} = Translations.fetch_translation(gettext_dir, "ar", second.id)
      assert :error = Translations.fetch_translation(gettext_dir, "ar", "nope")
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

    test "works for plural, leaving forms without a translation as they were" do
      translation = %Translation{
        message: %Plural{msgid: ["%{count} thing"], msgid_plural: ["%{count} things"], msgstr: %{0 => ["a"], 1 => [""]}},
        context: "context",
        domain: "domain",
        locale: "fr"
      }

      translatables = [
        %Translatable{translation: translation, text: "", translated_text: nil, plural_index: 0, plural_number: 1},
        %Translatable{
          translation: translation,
          text: "",
          translated_text: "%{count} mots",
          plural_index: 1,
          plural_number: 2
        }
      ]

      result = Translations.put_translated_message_on_translated(translatables)
      assert %Translation{message: %Plural{msgstr: %{0 => ["a"], 1 => ["%{count} mots"]}}} = result
    end
  end

  describe "translate_single/4" do
    test "works for singular, keeping the message order", %{gettext_dir: gettext_dir} do
      translations = Translations.build_translations_from_po_files(gettext_dir, "ar")
      singular_translation = Enum.at(translations, 2)

      assert :ok = Translations.translate_single(singular_translation, gettext_dir, nil, "Manually entered by user")

      new_translations = Translations.build_translations_from_po_files(gettext_dir, "ar")
      assert Enum.map(new_translations, & &1.id) == Enum.map(translations, & &1.id)
      assert Enum.at(new_translations, 2).message.msgstr == ["Manually entered by user"]
    end

    test "overwrites an existing translation", %{gettext_dir: gettext_dir} do
      {:ok, translated} =
        gettext_dir
        |> Translations.build_translations_from_po_files("ar")
        |> Enum.find(&(&1.message.msgid == ["Invalid date/time"]))
        |> then(&{:ok, &1})

      :ok = Translations.translate_single(translated, gettext_dir, nil, "new")
      assert {:ok, %{message: %{msgstr: ["new"]}}} = Translations.fetch_translation(gettext_dir, "ar", translated.id)
    end

    test "works for plural", %{gettext_dir: gettext_dir} do
      plural_translation =
        gettext_dir
        |> Translations.build_translations_from_po_files("ar")
        |> Enum.find(&match?(%Translation{message: %Plural{}}, &1))

      assert :ok = Translations.translate_single(plural_translation, gettext_dir, 0, "Manually entered by user")

      {:ok, new_plural_translation} = Translations.fetch_translation(gettext_dir, "ar", plural_translation.id)

      assert new_plural_translation.message.msgstr == %{
               0 => ["Manually entered by user"],
               1 => [""],
               2 => [""],
               3 => [""],
               4 => [""],
               5 => [""]
             }
    end

    test "works for multi-line msgids", %{gettext_dir: gettext_dir} do
      Fixtures.write_po!(gettext_dir, "fr", "default", """
      msgid ""
      "Hello "
      "world"
      msgstr ""
      """)

      [translation] = Translations.build_translations_from_po_files(gettext_dir, "fr")
      :ok = Translations.translate_single(translation, gettext_dir, nil, "Bonjour le monde")

      assert {:ok, %{message: %{msgstr: ["Bonjour le monde"]}}} =
               Translations.fetch_translation(gettext_dir, "fr", translation.id)
    end
  end

  describe "write_translations/3" do
    test "keeps message order, untouched messages and headers", %{gettext_dir: gettext_dir} do
      po_path = Translations.po_path(gettext_dir, "ar", "caint testing")
      original = Expo.PO.parse_file!(po_path)
      translations = Translations.build_translations_from_po_files(gettext_dir, "ar")

      # Only write the last message: everything else must be left as it was.
      last = List.last(translations)
      :ok = Translations.write_translations([put_in(last.message.msgstr[0], ["changed"])], gettext_dir, :overwrite)

      updated = Expo.PO.parse_file!(po_path)
      assert updated.headers == original.headers
      assert length(updated.messages) == length(original.messages)
      assert Enum.drop(updated.messages, -1) == Enum.drop(original.messages, -1)
      assert List.last(updated.messages).msgstr[0] == ["changed"]
    end

    test ":fill_missing does not overwrite text that is on disk", %{gettext_dir: gettext_dir} do
      translations = Translations.build_translations_from_po_files(gettext_dir, "ar")
      [missing, translated] = Enum.slice(translations, 0..1)

      # A manual edit lands on disk after `missing` was read.
      :ok = Translations.translate_single(missing, gettext_dir, nil, "manual")

      machine = [put_in(missing.message.msgstr, ["machine"]), put_in(translated.message.msgstr, ["machine"])]
      :ok = Translations.write_translations(machine, gettext_dir, :fill_missing)

      assert {:ok, %{message: %{msgstr: ["manual"]}}} = Translations.fetch_translation(gettext_dir, "ar", missing.id)

      assert {:ok, %{message: %{msgstr: ["تاريخ/وقت غير صالح"]}}} =
               Translations.fetch_translation(gettext_dir, "ar", translated.id)
    end

    test ":fill_missing fills only the empty plural forms", %{gettext_dir: gettext_dir} do
      plural =
        gettext_dir
        |> Translations.build_translations_from_po_files("ar")
        |> Enum.find(&match?(%Plural{}, &1.message))

      :ok = Translations.translate_single(plural, gettext_dir, 0, "manual")
      machine = put_in(plural.message.msgstr, Map.new(0..5, &{&1, ["machine"]}))
      :ok = Translations.write_translations([machine], gettext_dir, :fill_missing)

      {:ok, %{message: %{msgstr: msgstr}}} = Translations.fetch_translation(gettext_dir, "ar", plural.id)
      assert msgstr == Map.put(Map.new(1..5, &{&1, ["machine"]}), 0, ["manual"])
    end
  end
end
