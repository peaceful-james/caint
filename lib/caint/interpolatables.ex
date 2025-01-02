defmodule Caint.Interpolatables do
  @moduledoc false

  alias Caint.Translations.Translation
  alias Gettext.Interpolation.Default

  @spec plural_numbered_string(Translation.t(), non_neg_integer()) :: String.t()
  def plural_numbered_string(translation, plural_number) when is_integer(plural_number) do
    [msg] = if plural_number == 1, do: translation.message.msgid, else: translation.message.msgid_plural
    interpolatable = Default.to_interpolatable(msg)
    good_bindings = %{count: plural_number}

    case Default.runtime_interpolate(interpolatable, good_bindings) do
      {:ok, text} -> text
      {:missing_bindings, incomplete_string, _missing_bindings} -> incomplete_string
    end
  end
end
