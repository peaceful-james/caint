defmodule Caint.Deepl.Markup do
  @moduledoc """
  Converts gettext text to and from the XML markup sent to DeepL (`tag_handling: "xml"`).

  - Interpolations such as `%{name}` become `<gettext_variable>name</gettext_variable>`.
    That tag is in DeepL's `ignore_tags`, so its content is never translated.
  - For plural forms, `%{count}` becomes `<caint_count>11</caint_count>`, i.e. the example number
    for that plural form wrapped in a tag that is *not* ignored. DeepL sees the number and can
    pick the right grammatical form, and we can find exactly that number again afterwards.
  - `&`, `<` and `>` in the text are escaped, so they are not mistaken for markup.
  """

  @variable_tag "gettext_variable"
  @count_tag "caint_count"

  @spec ignore_tags() :: [String.t()]
  def ignore_tags, do: [@variable_tag]

  @doc """
  Encodes gettext source text for DeepL.

      iex> Caint.Deepl.Markup.encode("Hi %{name}, you have %{count} new & unread", 11)
      "Hi <gettext_variable>name</gettext_variable>, you have <caint_count>11</caint_count> new &amp; unread"
  """
  @spec encode(String.t(), non_neg_integer() | nil) :: String.t()
  def encode(text, plural_number \\ nil) do
    text
    |> escape()
    |> encode_count(plural_number)
    |> then(&Regex.replace(~r/%{([^}]+)}/, &1, "<#{@variable_tag}>\\1</#{@variable_tag}>"))
  end

  @doc """
  Decodes text returned by DeepL back into gettext text.

  If DeepL dropped the `<caint_count>` tag, the first standalone occurrence of
  `plural_number` is turned back into `%{count}`. Other numbers are left alone.

      iex> Caint.Deepl.Markup.decode("<caint_count>1</caint_count> von 10 &amp; <gettext_variable>name</gettext_variable>")
      "%{count} von 10 & %{name}"
  """
  @spec decode(String.t(), non_neg_integer() | nil) :: String.t()
  def decode(text, plural_number \\ nil) do
    text
    |> then(&Regex.replace(~r/<#{@count_tag}>[^<]*<\/#{@count_tag}>/, &1, "%{count}"))
    |> then(&Regex.replace(~r/<#{@variable_tag}>([^<]*)<\/#{@variable_tag}>/, &1, "%{\\1}"))
    |> restore_untagged_count(plural_number)
    |> unescape()
  end

  defp encode_count(text, nil), do: text
  defp encode_count(text, n), do: String.replace(text, "%{count}", "<#{@count_tag}>#{n}</#{@count_tag}>")

  defp restore_untagged_count(text, nil), do: text

  defp restore_untagged_count(text, plural_number) do
    if String.contains?(text, "%{count}") do
      text
    else
      Regex.replace(~r/(?<!\d)#{plural_number}(?!\d)/, text, "%{count}", global: false)
    end
  end

  defp escape(text) do
    text
    |> String.replace("&", "&amp;")
    |> String.replace("<", "&lt;")
    |> String.replace(">", "&gt;")
  end

  defp unescape(text) do
    text
    |> String.replace("&lt;", "<")
    |> String.replace("&gt;", ">")
    |> String.replace("&quot;", "\"")
    |> String.replace("&apos;", "'")
    |> String.replace("&amp;", "&")
  end
end
