defmodule Caint.Translatables do
  @moduledoc """
  Functions for building `Caint.Translatables.Translatable.t()` structs.
  """

  alias Caint.Translatables.Translatable
  alias Caint.Translations.Translation
  alias Expo.Message.Plural
  alias Expo.Message.Singular

  @doc """
  Builds a list of `Caint.Translatables.Translatable.t()` structs.

  A singular message gives one translatable. A plural message gives one per plural index,
  each carrying an example `plural_number` for that index (see `Caint.Plurals`).
  The `text` is the source text with `%{count}` still present.

  ## Options

    * `:only_missing` - for plural messages, skip plural indices that already have a translation.
      Defaults to `false`.
  """
  @spec to_translatables(Translation.t(), keyword()) :: [Translatable.t()]
  def to_translatables(translation, opts \\ []) do
    case translation.message do
      %Singular{} -> to_translatables_for_singular(translation)
      %Plural{} -> to_translatables_for_plural(translation, Keyword.get(opts, :only_missing, false))
    end
  end

  defp to_translatables_for_singular(translation) do
    [
      %Translatable{
        translation: translation,
        text: Enum.join(translation.message.msgid),
        translated_text: nil,
        plural_index: nil,
        plural_number: nil
      }
    ]
  end

  defp to_translatables_for_plural(translation, only_missing?) do
    msgstr = translation.message.msgstr || %{}

    translation.plural_numbers_by_index
    |> Enum.sort()
    |> Enum.reject(fn {plural_index, _} -> only_missing? and translated?(Map.get(msgstr, plural_index)) end)
    |> Enum.map(fn {plural_index, plural_number} ->
      source = if plural_number == 1, do: translation.message.msgid, else: translation.message.msgid_plural

      %Translatable{
        translation: translation,
        text: Enum.join(source),
        translated_text: nil,
        plural_index: plural_index,
        plural_number: plural_number
      }
    end)
  end

  defp translated?(nil), do: false
  defp translated?(msgstr), do: IO.iodata_to_binary(msgstr) != ""
end
