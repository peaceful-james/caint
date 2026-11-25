defmodule Caint.PluralsTest do
  use ExUnit.Case, async: true

  alias Caint.Plurals
  alias Expo.PluralForms

  describe "for_locale/1" do
    test "finds an example number for every Arabic plural index" do
      assert Plurals.for_locale("ar") == %{0 => 0, 1 => 1, 2 => 2, 3 => 3, 4 => 11, 5 => 100}
    end

    test "prefers natural examples over zero" do
      assert Plurals.for_locale("en") == %{0 => 1, 1 => 2}
      assert Plurals.for_locale("de") == %{0 => 1, 1 => 2}
    end

    test "only uses 1 for a plural form that 1 has to itself" do
      # French uses form 0 for both 0 and 1, so "1" (i.e. the singular msgid) would be wrong for 0.
      assert Plurals.for_locale("fr") == %{0 => 0, 1 => 2}
      # Japanese has one form for every number.
      assert Plurals.for_locale("ja") == %{0 => 2}
    end

    test "returns empty map for unknown locales" do
      assert Plurals.for_locale("sdfdsfef") == %{}
    end
  end

  describe "for_messages/2" do
    test "uses the PO file's Plural-Forms header over the locale table" do
      messages = %Expo.Messages{
        headers: ["Language: tlh\n", "Plural-Forms: nplurals=3; plural=(n==1 ? 0 : n==2 ? 1 : 2);\n"],
        messages: []
      }

      assert Plurals.for_messages(messages, "tlh") == %{0 => 1, 1 => 2, 2 => 3}
    end

    test "falls back to the locale table without a header" do
      assert Plurals.for_messages(%Expo.Messages{headers: [], messages: []}, "ar") == Plurals.for_locale("ar")
    end

    test "falls back to the locale table when the header is invalid" do
      messages = %Expo.Messages{headers: ["Plural-Forms: garbage\n"], messages: []}
      assert Plurals.for_messages(messages, "en") == %{0 => 1, 1 => 2}
    end
  end

  describe "for_plural_forms/1" do
    test "is cached" do
      {:ok, plural_forms} = PluralForms.parse("nplurals=2; plural=(n%7 != 1);")
      result = Plurals.for_plural_forms(plural_forms)
      # Form 0 holds 1, 8, 15, ... so it is not singular-only and gets 8 as its example.
      assert result == %{0 => 8, 1 => 2}
      assert :persistent_term.get({Plurals, PluralForms.to_string(plural_forms)}) == result
    end

    test "gives up gracefully on unreachable indices" do
      {:ok, plural_forms} = PluralForms.parse("nplurals=3; plural=(n==1 ? 0 : 1);")
      assert Plurals.for_plural_forms(plural_forms) == %{0 => 1, 1 => 2}
    end
  end
end
