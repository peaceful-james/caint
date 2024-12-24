defmodule Caint.Translations do
  @moduledoc """
  Enhanced type `translation` for Caint
  """
  alias Caint.PoParsing

  @type translation :: %{
          message: Expo.Message.t(),
          context: String.t(),
          domain: String.t(),
          locale: String.t()
        }

  def translations(gettext_dir, locale) do
    gettext_dir
    |> PoParsing.po_paths_in_priv(locale)
    |> Enum.flat_map(fn po_path ->
      domain = infer_domain_from_po_path(po_path)
      messages = Expo.PO.parse_file!(po_path).messages

      Enum.map(messages, fn message ->
        context = build_context(message)
        %{message: message, domain: domain, context: context, locale: locale}
      end)
    end)
  end

  defp build_context(message) do
    case message.msgctxt do
      [""] -> nil
      msgctxt -> Enum.join(msgctxt || [], "\n")
    end
  end

  defp infer_domain_from_po_path(po_path) do
    Path.basename(po_path, ".po")
  end
end
