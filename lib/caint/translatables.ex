defmodule Caint.Translatables do
  @moduledoc """
  "Translatables" are maps containing translations and inferred info.

  The extra info includes:
  - The text of the translation
  - The index of the plural form (if any)
  - An example number of the plural form (if any)
  """

  alias Caint.Plurals
  alias Caint.Translations
  alias Expo.Message.Plural
  alias Expo.Message.Singular
  alias Gettext.Interpolation.Default

  @type translatable :: %{
          translation: Translations.translation(),
          text: String.t(),
          plural_index: nil | non_neg_integer(),
          plural_number: nil | non_neg_integer()
        }

  @doc """
  Builds a map of translatables
  """
  @spec to_translatables(Translations.translation(), Plurals.plural_numbers_by_index()) :: [translatable()]
  def to_translatables(translation, plural_numbers_by_index) do
    case translation.message do
      %Singular{} -> to_translatables_for_singular(translation)
      %Plural{} -> to_translatables_for_plural(translation, plural_numbers_by_index)
    end
  end

  defp to_translatables_for_singular(translation) do
    text = Enum.join(translation.message.msgid, "\n")

    [
      %{
        translation: translation,
        text: text,
        plural_index: nil,
        plural_number: nil
      }
    ]
  end

  defp to_translatables_for_plural(translation, plural_numbers_by_index) do
    Enum.map(plural_numbers_by_index, fn {plural_index, plural_number} ->
      [msg] = if plural_number == 1, do: translation.message.msgid, else: translation.message.msgid_plural
      interpolatable = Default.to_interpolatable(msg)
      good_bindings = %{count: plural_number}
      {:ok, text} = Default.runtime_interpolate(interpolatable, good_bindings)

      %{
        translation: translation,
        text: text,
        plural_index: plural_index,
        plural_number: plural_number
      }
    end)
  end
end
