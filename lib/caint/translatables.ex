defmodule Caint.Translatables do
  @moduledoc false

  alias Caint.Translations
  alias Gettext.Interpolation.Default

  @type plural_numbers_by_index :: %{non_neg_integer() => non_neg_integer()}

  @type translatable :: %{
          translation: Translations.translation(),
          text: String.t(),
          plural_index: nil | non_neg_integer(),
          plural_number: nil | non_neg_integer()
        }

  @spec to_translatables(Translations.translation(), plural_numbers_by_index) :: [translatable()]
  def to_translatables(translation, plural_numbers_by_index) do
    case translation.message do
      %Expo.Message.Singular{} = message ->
        text = Enum.join(message.msgid, "\n")

        [
          %{
            translation: translation,
            text: text,
            plural_index: nil,
            plural_number: nil
          }
        ]

      %Expo.Message.Plural{} ->
        to_translatables_for_plural(translation, plural_numbers_by_index)
    end
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
