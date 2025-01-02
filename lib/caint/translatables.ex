defmodule Caint.Translatables do
  @moduledoc """
  Functions for building `Caint.Translatables.Translatable.t()` structs.
  """

  alias Caint.Interpolatables
  alias Caint.Plurals
  alias Caint.Translatables.Translatable
  alias Caint.Translations.Translation
  alias Expo.Message.Plural
  alias Expo.Message.Singular

  @doc """
  Builds a list of `Caint.Translatables.Translatable.t()` structs.
  """
  @spec to_translatables(Translation.t(), Plurals.plural_numbers_by_index()) :: [Translatable.t()]
  def to_translatables(translation, plural_numbers_by_index) do
    case translation.message do
      %Singular{} -> to_translatables_for_singular(translation)
      %Plural{} -> to_translatables_for_plural(translation, plural_numbers_by_index)
    end
  end

  defp to_translatables_for_singular(translation) do
    text = Enum.join(translation.message.msgid, "\n")

    [
      %Translatable{
        translation: translation,
        text: text,
        translated_text: nil,
        plural_index: nil,
        plural_number: nil
      }
    ]
  end

  defp to_translatables_for_plural(translation, plural_numbers_by_index) do
    Enum.map(plural_numbers_by_index, fn {plural_index, plural_number} ->
      text = Interpolatables.plural_numbered_string(translation, plural_number)

      %Translatable{
        translation: translation,
        text: text,
        translated_text: nil,
        plural_index: plural_index,
        plural_number: plural_number
      }
    end)
  end
end
