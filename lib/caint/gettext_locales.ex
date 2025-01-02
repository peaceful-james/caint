defmodule Caint.GettextLocales do
  @moduledoc """
  Functions for inferring Gettext locales
  """
  alias Caint.PoParsing

  @spec list(PoParsing.gettext_dir()) :: [Gettext.locale()]
  def list(gettext_dir) do
    gettext_dir
    |> PoParsing.po_paths_in_priv()
    |> Enum.map(&infer_gettext_locale_from_po_path/1)
    |> Enum.uniq()
  end

  defp infer_gettext_locale_from_po_path(po_path) do
    [_file, "LC_MESSAGES", locale | _rest] = po_path |> Path.split() |> Enum.reverse()
    locale
  end
end
