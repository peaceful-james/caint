defmodule Caint.ExpoLogic do
  @moduledoc """
  Functions that I am bewildered to not find in Expo
  """
  alias Expo.Message
  alias Expo.Message.Plural
  alias Expo.Message.Singular

  @spec message_translated?(Message.t()) :: boolean()
  def message_translated?(%Singular{} = message) do
    message.msgstr != [""]
  end

  def message_translated?(%Plural{} = message) do
    Enum.all?(message.msgstr, fn {_plural_index, plural_msgstr} ->
      plural_msgstr != [""]
    end)
  end
end
