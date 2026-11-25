defmodule Caint.Plurals do
  @moduledoc """
  Find an "example" number for each plural index of a set of plural forms.

  e.g. for English (`nplurals=2; plural=(n != 1)`) we get `%{0 => 1, 1 => 0}`:
  the number `1` is an example of plural index `0` and `0` is an example of plural index `1`.

  These example numbers are sent to DeepL in place of `%{count}` so it can choose the correct
  grammatical form for each plural index.

  Results are cached in `:persistent_term`, keyed by the plural forms expression,
  because they never change and are needed for every plural message.
  """
  alias Expo.Messages
  alias Expo.PluralForms

  @type plural_numbers_by_index :: %{non_neg_integer() => non_neg_integer()}

  # Every real-world plural forms expression finds all its indices well below this.
  # It only guards against expressions where some index is unreachable.
  @max_number_to_try 1_000

  @doc """
  Plural numbers for a parsed PO file.

  The file's own `Plural-Forms` header takes precedence, since that is what Gettext will use at runtime.
  If the header is missing or invalid, fall back to Expo's table of known locales.
  Returns an empty map when neither is available.
  """
  @spec for_messages(Messages.t(), Gettext.locale()) :: plural_numbers_by_index()
  def for_messages(%Messages{} = messages, locale) do
    with [plural_forms_header | _] <- Messages.get_header(messages, "Plural-Forms"),
         {:ok, plural_forms} <- PluralForms.parse(plural_forms_header) do
      for_plural_forms(plural_forms)
    else
      _ -> for_locale(locale)
    end
  end

  @doc """
  Plural numbers for a locale, according to Expo's table of known locales.
  Returns an empty map for unknown locales.
  """
  @spec for_locale(Gettext.locale()) :: plural_numbers_by_index()
  def for_locale(locale) do
    case PluralForms.plural_form(locale) do
      {:ok, plural_forms} -> for_plural_forms(plural_forms)
      :error -> %{}
    end
  end

  @doc """
  Plural numbers for a plural forms struct. Cached.
  """
  @spec for_plural_forms(PluralForms.t()) :: plural_numbers_by_index()
  def for_plural_forms(%PluralForms{} = plural_forms) do
    cache_key = {__MODULE__, PluralForms.to_string(plural_forms)}

    case :persistent_term.get(cache_key, nil) do
      nil ->
        result = compute(plural_forms)
        :persistent_term.put(cache_key, result)
        result

      cached ->
        cached
    end
  end

  # The example for an index is `1` only if `1` is the *only* number in that index, because
  # `Caint.Translatables` translates the singular msgid (which may not contain `%{count}`) for `1`.
  # e.g. Japanese has one form for all numbers, and French uses form 0 for both 0 and 1,
  # so those must be translated from msgid_plural with a different example number.
  #
  # Otherwise the smallest number is used, with zero tried last, so that e.g. English gets
  # `2 files` rather than `0 files`, while languages with a dedicated zero form (Arabic) still get `0`.
  defp compute(%PluralForms{} = plural_forms) do
    numbers_by_index =
      1..@max_number_to_try
      |> Enum.concat([0])
      |> Enum.group_by(&PluralForms.index(plural_forms, &1))

    Map.new(numbers_by_index, fn
      {index, [1]} -> {index, 1}
      {index, numbers} -> {index, Enum.find(numbers, &(&1 != 1))}
    end)
  end
end
