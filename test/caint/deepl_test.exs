defmodule Caint.DeeplTest do
  use ExUnit.Case, async: true

  import Mox

  alias Caint.Deepl
  alias Caint.Deepl.MockApiImpl
  alias Caint.Mocks.MockDeeplApiImpl
  alias Expo.Message.Plural

  describe "usage_percent/0" do
    test "returns the usage percentage" do
      expect(MockApiImpl, :usage, 1, &MockDeeplApiImpl.usage/0)
      result = Deepl.usage_percent()
      assert result == {:ok, Decimal.new("50.00")}
    end
  end

  describe "language_code/1" do
    test "works" do
      assert "PT-BR" == Deepl.language_code("pt")
      assert "ZH-HANT" == Deepl.language_code("zh_Hant")
    end
  end

  describe "translate_all_untranslated/2" do
    test "works" do
      source_locale = "en"
      context = "labels"
      domain = "home page"
      original_msgstr = %{0 => [""], 1 => [""], 2 => [""], 3 => [""], 4 => [""], 5 => [""]}

      translations = [
        %{
          message: %Plural{
            msgid: ["1 category"],
            msgstr: original_msgstr,
            msgctxt: [context],
            msgid_plural: ["%{count} categories"]
          },
          context: context,
          domain: domain,
          locale: source_locale
        }
      ]

      locale = "ar"

      expect(MockApiImpl, :batch_size, 1, &MockDeeplApiImpl.batch_size/0)
      expect(MockApiImpl, :translate, 1, &MockDeeplApiImpl.translate/1)

      result = Deepl.translate_all_untranslated(translations, locale)

      assert [
               %{
                 message: translated_message,
                 domain: ^domain,
                 context: ^context,
                 locale: ^source_locale
               }
             ] = result

      assert translated_message.msgstr != original_msgstr

      assert translated_message.msgstr == %{
               0 => ["%{count} التصنيفات"],
               1 => ["%{count} فئة %{count}"],
               2 => ["%{count} فئات"],
               3 => ["%{count} فئات"],
               4 => ["%{count} فئة"],
               5 => ["%{count} فئة"]
             }
    end
  end
end
