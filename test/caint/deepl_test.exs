defmodule Caint.DeeplTest do
  use ExUnit.Case, async: true

  import Mox

  alias Caint.Deepl
  alias Caint.Deepl.MockApiImpl
  alias Caint.Fixtures
  alias Caint.Mocks.MockDeeplApiImpl
  alias Caint.Translations.Translation
  alias Expo.Message.Plural
  alias Expo.Message.Singular

  setup :verify_on_exit!

  describe "usage_percent/0" do
    test "returns the usage percentage" do
      expect(MockApiImpl, :usage, 1, &MockDeeplApiImpl.usage/0)
      assert Deepl.usage_percent() == {:ok, Decimal.new("50.00")}
    end

    test "returns error when unable to fetch" do
      expect(MockApiImpl, :usage, 1, fn -> {:error, %Req.TransportError{reason: :econnrefused}} end)
      assert {:error, "Failed to get DeepL usage: connection refused"} = Deepl.usage_percent()
    end

    test "returns error (rather than crashing) on an error status" do
      expect(MockApiImpl, :usage, 1, fn ->
        {:ok, Req.Response.new(status: 403, body: %{"message" => "Authentication failed"})}
      end)

      assert {:error, "Failed to get DeepL usage: DeepL rejected the API key (HTTP 403)"} = Deepl.usage_percent()
    end
  end

  describe "language_code/1" do
    test "works" do
      assert "PT-BR" == Deepl.language_code("pt")
      assert "ZH-HANT" == Deepl.language_code("zh_Hant")
    end
  end

  describe "target_languages/0" do
    test "returns the codes usable as targets, upper-cased" do
      expect(MockApiImpl, :target_languages, 1, &MockDeeplApiImpl.target_languages/0)
      assert {:ok, targets} = Deepl.target_languages()
      assert "EN-GB" in targets
      assert "ZH-HANT" in targets
      refute "EN" in targets
    end

    test "returns :error when DeepL cannot be asked" do
      expect(MockApiImpl, :target_languages, 1, fn -> {:ok, Req.Response.new(status: 403)} end)
      assert :error = Deepl.target_languages()
    end
  end

  describe "resolve_target/2" do
    setup do
      {:ok, supported: {:ok, MapSet.new(~w(AR DE EN-GB EN-US ES FR JA PT-BR PT-PT ZH-HANS ZH-HANT))}}
    end

    test "translates supported locales", %{supported: supported} do
      assert Deepl.resolve_target("ar", supported) == {:translate, "AR"}
      assert Deepl.resolve_target("pt", supported) == {:translate, "PT-BR"}
      assert Deepl.resolve_target("pt_PT", supported) == {:translate, "PT-PT"}
      assert Deepl.resolve_target("zh_Hant", supported) == {:translate, "ZH-HANT"}
    end

    test "falls back to the base language, then its first variant", %{supported: supported} do
      assert Deepl.resolve_target("fr_CA", supported) == {:translate, "FR"}
      assert Deepl.resolve_target("de_AT", supported) == {:translate, "DE"}
      assert Deepl.resolve_target("zh", supported) == {:translate, "ZH-HANS"}
    end

    test "skips the source language and its variants", %{supported: supported} do
      assert Deepl.resolve_target("en", supported) == {:skip, "same language as the source"}
      assert Deepl.resolve_target("en_IE", supported) == {:skip, "same language as the source"}
      assert Deepl.resolve_target("en_GB", supported) == {:skip, "same language as the source"}
    end

    test "skips languages DeepL does not support", %{supported: supported} do
      assert Deepl.resolve_target("ga", supported) == {:skip, "not supported by DeepL"}
    end

    test "uses the plain language code when the supported languages are unknown" do
      assert Deepl.resolve_target("ga", :error) == {:translate, "GA"}
      assert Deepl.resolve_target("fr_CA", :error) == {:translate, "FR-CA"}
      assert Deepl.resolve_target("en_IE", :error) == {:skip, "same language as the source"}
    end
  end

  describe "resolve_target/3" do
    test "overrides win" do
      supported = {:ok, MapSet.new(~w(FR EN-GB EN-US))}
      overrides = %{"ga" => "en-gb", "fr" => :skip, "en_US" => "EN-US"}

      assert Deepl.resolve_target("ga", supported, overrides) == {:translate, "EN-GB"}
      assert Deepl.resolve_target("fr", supported, overrides) == {:skip, "skipped in config"}
      assert Deepl.resolve_target("en_US", supported, overrides) == {:translate, "EN-US"}
    end
  end

  describe "translate_all_untranslated/2" do
    setup do
      stub(MockApiImpl, :batch_size, &MockDeeplApiImpl.batch_size/0)
      :ok
    end

    test "translates every Arabic plural form, restoring only the example number to %{count}" do
      domain = "home page"
      context = "labels"
      original_msgstr = Map.new(0..5, &{&1, [""]})

      translation = %Translation{
        message: %Plural{
          msgid: ["1 category"],
          msgstr: original_msgstr,
          msgctxt: [context],
          msgid_plural: ["%{count} categories, 1 of which is new"]
        },
        context: context,
        domain: domain,
        locale: "ar",
        plural_numbers_by_index: %{0 => 0, 1 => 1, 2 => 2, 3 => 3, 4 => 11, 5 => 100}
      }

      expect(MockApiImpl, :translate, 1, fn data ->
        assert data.target_lang == "AR"
        assert data.context == context
        assert data.tag_handling == "xml"
        assert "<caint_count>11</caint_count> categories, 1 of which is new" in data.text
        Fixtures.echo_translate(data)
      end)

      assert {[%Translation{message: message, domain: ^domain, locale: "ar"}], []} =
               Deepl.translate_all_untranslated([translation])

      assert message.msgstr == %{
               0 => ["[AR] %{count} categories, 1 of which is new"],
               1 => ["[AR] 1 category"],
               2 => ["[AR] %{count} categories, 1 of which is new"],
               3 => ["[AR] %{count} categories, 1 of which is new"],
               4 => ["[AR] %{count} categories, 1 of which is new"],
               5 => ["[AR] %{count} categories, 1 of which is new"]
             }
    end

    test "the canned mock response decodes too" do
      translation = %Translation{
        message: %Plural{msgid: ["1 category"], msgid_plural: ["%{count} categories"], msgstr: Map.new(0..5, &{&1, [""]})},
        context: nil,
        domain: "d",
        locale: "ar",
        plural_numbers_by_index: %{0 => 0, 1 => 1, 2 => 2, 3 => 3, 4 => 11, 5 => 100}
      }

      expect(MockApiImpl, :translate, 1, &MockDeeplApiImpl.translate/1)
      assert {[%Translation{message: %{msgstr: msgstr}}], []} = Deepl.translate_all_untranslated([translation])
      # "1 category" has no %{count}, so its number is left as DeepL wrote it.
      assert msgstr[1] == ["1 فئة 1"]
      assert msgstr[4] == ["%{count} فئة"]
    end

    test "keeps multiple interpolations intact" do
      translation = singular("Hello %{name}, you have %{count} messages", "fr")
      expect(MockApiImpl, :translate, 1, &Fixtures.echo_translate/1)

      assert {[%Translation{message: %Singular{msgstr: ["[FR] Hello %{name}, you have %{count} messages"]}}], []} =
               Deepl.translate_all_untranslated([translation])
    end

    test "only fills in missing plural forms" do
      translation = %Translation{
        message: %Plural{msgid: ["1 file"], msgid_plural: ["%{count} files"], msgstr: %{0 => ["1 fichier"], 1 => [""]}},
        context: nil,
        domain: "d",
        locale: "fr",
        plural_numbers_by_index: %{0 => 1, 1 => 2}
      }

      expect(MockApiImpl, :translate, 1, fn data ->
        assert data.text == ["<caint_count>2</caint_count> files"]
        Fixtures.echo_translate(data)
      end)

      assert {[%Translation{message: %{msgstr: %{0 => ["1 fichier"], 1 => ["[FR] %{count} files"]}}}], []} =
               Deepl.translate_all_untranslated([translation])
    end

    test "skips already-translated messages without calling DeepL" do
      translation = %{singular("Hi", "fr") | message: %Singular{msgid: ["Hi"], msgstr: ["Salut"]}}
      assert {[], []} = Deepl.translate_all_untranslated([translation])
    end

    test "uses the given target codes and a base source language" do
      expect(MockApiImpl, :translate, 1, fn data ->
        assert data.target_lang == "FR"
        assert data.source_lang == "EN"
        Fixtures.echo_translate(data)
      end)

      assert {[_], []} = Deepl.translate_all_untranslated([singular("a", "fr_CA")], target_langs: %{"fr_CA" => "FR"})
    end

    test "batches by locale and context, across locales" do
      translations = [singular("a", "fr"), singular("b", "de"), %{singular("c", "fr") | context: "other"}]
      expect(MockApiImpl, :translate, 3, &Fixtures.echo_translate/1)

      {translated, []} = Deepl.translate_all_untranslated(translations)

      assert translated |> Enum.map(&hd(&1.message.msgstr)) |> Enum.sort() == ["[DE] b", "[FR] a", "[FR] c"]
    end

    test "a failing batch is reported while the other batches still succeed" do
      translations = [singular("ok", "fr"), singular("quota", "de")]

      stub(MockApiImpl, :translate, fn
        %{target_lang: "DE"} -> {:ok, Req.Response.new(status: 456, body: %{"message" => "Quota exceeded"})}
        data -> Fixtures.echo_translate(data)
      end)

      assert {[%Translation{locale: "fr"}], [error]} = Deepl.translate_all_untranslated(translations)
      assert error == %{locale: "de", reason: "DeepL character quota exceeded (HTTP 456)", message_count: 1}
    end

    test "a crashing batch is reported rather than crashing the caller" do
      expect(MockApiImpl, :translate, 1, fn _ -> raise "boom" end)

      assert {[], [%{locale: "fr", reason: "boom", message_count: 1}]} =
               Deepl.translate_all_untranslated([singular("x", "fr")])
    end

    test "a response with the wrong number of translations is an error" do
      expect(MockApiImpl, :translate, 1, fn _ -> {:ok, Req.Response.new(status: 200, body: %{"translations" => []})} end)

      assert {[], [%{reason: "unexpected response from DeepL"}]} =
               Deepl.translate_all_untranslated([singular("x", "fr")])
    end

    test "plural messages without plural rules are reported and left alone" do
      translation = %Translation{
        message: %Plural{msgid: ["1 file"], msgid_plural: ["%{count} files"], msgstr: %{0 => [""], 1 => [""]}},
        context: nil,
        domain: "d",
        locale: "tlh",
        plural_numbers_by_index: %{}
      }

      assert {[], [%{locale: "tlh", message_count: 1, reason: "no plural rules known" <> _}]} =
               Deepl.translate_all_untranslated([translation])
    end

    test "reports progress per batch and respects max_concurrency" do
      test_pid = self()
      translations = for i <- 1..5, do: singular("m#{i}", "fr")
      stub(MockApiImpl, :batch_size, fn -> 2 end)

      counter = :counters.new(2, [])

      stub(MockApiImpl, :translate, fn data ->
        :counters.add(counter, 1, 1)
        :counters.put(counter, 2, max(:counters.get(counter, 2), :counters.get(counter, 1)))
        Process.sleep(20)
        :counters.sub(counter, 1, 1)
        Fixtures.echo_translate(data)
      end)

      {translated, []} =
        Deepl.translate_all_untranslated(translations,
          max_concurrency: 2,
          on_progress: &send(test_pid, {:progress, &1})
        )

      assert length(translated) == 5
      assert :counters.get(counter, 2) <= 2

      for done <- 0..3, do: assert_received({:progress, %{done: ^done, total: 3}})
    end
  end

  defp singular(msgid, locale) do
    %Translation{
      message: %Singular{msgid: [msgid], msgstr: [""]},
      context: nil,
      domain: "d",
      locale: locale
    }
  end
end
