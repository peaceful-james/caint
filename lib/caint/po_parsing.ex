defmodule Caint.PoParsing do
  @moduledoc """
  Reading and writing PO files
  """

  @type gettext_dir :: String.t()
  @po_wildcard "**/*.po"

  def po_paths_in_priv(gettext_dir, locale \\ nil) do
    gettext_dir
    |> then(&if locale, do: Path.join(&1, locale), else: &1)
    |> Path.join(@po_wildcard)
    |> Path.wildcard()
  end

  def delete_all_po_files do
    :caint
    |> Application.get_env(:gettext_dir)
    |> po_paths_in_priv()
    |> Enum.map(&File.rm!/1)
  end
end
