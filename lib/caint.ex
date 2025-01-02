defmodule Caint do
  @moduledoc """
  Intended to replace Kanta, which seems to be abandoned

  Some terminology:
  - "po_path" is the full path to a PO file
  - "messages" refers to `Expo.Messages` which is their representation of a .po file
  """

  def write_le_po_file(po_path, messages) do
    iodata = Expo.PO.compose(messages)
    File.write!(po_path, iodata)
  end
end
