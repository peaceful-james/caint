defmodule Caint.Deepl.MarkupTest do
  use ExUnit.Case, async: true

  alias Caint.Deepl.Markup

  doctest Markup

  describe "encode/2" do
    test "tags each interpolation separately (non-greedy)" do
      assert Markup.encode("Hello %{name}, you have %{count} messages") ==
               "Hello <gettext_variable>name</gettext_variable>, you have " <>
                 "<gettext_variable>count</gettext_variable> messages"
    end

    test "replaces %{count} with the tagged plural number" do
      assert Markup.encode("%{count} of %{total} files", 11) ==
               "<caint_count>11</caint_count> of <gettext_variable>total</gettext_variable> files"
    end

    test "escapes XML special characters" do
      assert Markup.encode("Terms & <Conditions>") == "Terms &amp; &lt;Conditions&gt;"
    end
  end

  describe "decode/2" do
    test "restores each interpolation separately (non-greedy)" do
      assert Markup.decode(
               "Bonjour <gettext_variable>name</gettext_variable>, vous avez <gettext_variable>n</gettext_variable>"
             ) == "Bonjour %{name}, vous avez %{n}"
    end

    test "only the tagged number becomes %{count}" do
      assert Markup.decode("<caint_count>1</caint_count> von 10 Dateien, 1 übrig", 1) ==
               "%{count} von 10 Dateien, 1 übrig"
    end

    test "falls back to the first standalone number if DeepL dropped the tag" do
      assert Markup.decode("1 von 10 Dateien, 1 übrig", 1) == "%{count} von 10 Dateien, 1 übrig"
      assert Markup.decode("10 von 1 Dateien", 1) == "10 von %{count} Dateien"
    end

    test "leaves numbers alone without a plural number" do
      assert Markup.decode("1 von 10") == "1 von 10"
    end

    test "unescapes XML entities" do
      assert Markup.decode("Conditions &amp; &lt;termes&gt; &quot;x&quot; &apos;y&apos;") ==
               ~s(Conditions & <termes> "x" 'y')
    end

    test "round-trips" do
      text = "Hi %{name} & co, %{count} <new> items"
      assert text |> Markup.encode(3) |> Markup.decode(3) == text
    end
  end
end
