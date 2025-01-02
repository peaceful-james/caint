defmodule Caint.Translatables.Translatable do
  @moduledoc """
  "Translatables" are maps containing translations and inferred info.

  The extra info includes:
  - The text of the translation, with interpolation still present.
  - The index of the plural form (if any)
  - An example number of the plural form (if any)

  Since the `Translation` struct is a bit too low-level for sending to an API.

  For example, we don't want to translate `"%{count} categories"` as is.

  Instead, we want to translate `"1 category"` and `"2 categories"` separately.
  In fact, for some languages we might need to also translate
  `"5 categories"` and `"100 categories"` differently.

  In Arabic, for example, there are 6 plural forms.

  The role of the `plural_number` field is to give an example number to the API.
  That way, the API can infer the correct plural form to use.

  We must take care to convert the plural number back to `%{count}` in the string
  after translating!
  """

  alias Caint.Translations.Translation

  @type t :: %{
          translation: Translation.t(),
          text: String.t(),
          plural_index: nil | non_neg_integer(),
          plural_number: nil | non_neg_integer()
        }

  @enforce_keys [:translation, :text, :plural_index, :plural_number]
  defstruct translation: nil,
            text: "",
            plural_index: nil,
            plural_number: nil
end
