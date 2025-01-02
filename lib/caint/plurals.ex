defmodule Caint.Plurals do
  @moduledoc """
  Inefficient, hacky way of getting "example" plural numbers for each plural index
  """
  alias Expo.PluralForms

  @type plural_numbers_by_index :: %{non_neg_integer() => non_neg_integer()}

  @spec build_plural_numbers_by_index_for_locale(Gettext.locale()) :: plural_numbers_by_index()
  def build_plural_numbers_by_index_for_locale(locale) do
    {:ok, forms_struct} = PluralForms.plural_form(locale)
    plural_numbers_by_index(forms_struct)
  end

  defp plural_numbers_by_index(plural_form) do
    required_length = plural_form.nplurals
    acc = %{}
    number_to_try = 0
    required_index = 0
    build_plural_numbers_by_index_recursive(plural_form, number_to_try, required_index, acc, required_length)
  end

  defp build_plural_numbers_by_index_recursive(plural_form, number_to_try, required_index, acc, required_length) do
    index = Expo.PluralForms.index(plural_form, number_to_try)

    if index == required_index do
      new_acc = Map.put(acc, index, number_to_try)

      if required_index + 1 == required_length do
        new_acc
      else
        build_plural_numbers_by_index_recursive(
          plural_form,
          number_to_try + 1,
          required_index + 1,
          new_acc,
          required_length
        )
      end
    else
      build_plural_numbers_by_index_recursive(plural_form, number_to_try + 1, required_index, acc, required_length)
    end
  end
end
