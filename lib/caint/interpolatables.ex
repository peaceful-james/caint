defmodule Caint.Interpolatables do
  @moduledoc false

  alias Gettext.Interpolation.Default

  def hyu(translation, plural_number) do
    [msg] = if plural_number == 1, do: translation.message.msgid, else: translation.message.msgid_plural
    interpolatable = Default.to_interpolatable(msg)
    good_bindings = %{count: plural_number}
    {:ok, text} = Default.runtime_interpolate(interpolatable, good_bindings)
    text
  end
end
