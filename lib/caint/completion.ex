defmodule Caint.Completion do
  @moduledoc """
  Functions for inferring completion
  """

  alias Caint.ExpoLogic
  alias Caint.Percentage
  alias Caint.PoParsing

  @spec percentage(PoParsing.gettext_dir(), Gettext.locale()) :: Decimal.t()
  def percentage(gettext_dir, locale) do
    completion_details =
      gettext_dir
      |> PoParsing.po_paths_in_priv(locale)
      |> Enum.reduce(%{total_messages_count: 0, total_untranslated_count: 0}, fn po_path, completion_details ->
        messages = Expo.PO.parse_file!(po_path)
        total_messages_in_po_file = Enum.count(messages.messages)
        total_untranslated_in_po_file = Enum.count(messages.messages, &(!ExpoLogic.message_translated?(&1)))

        completion_details
        |> Map.update!(:total_messages_count, &(&1 + total_messages_in_po_file))
        |> Map.update!(:total_untranslated_count, &(&1 + total_untranslated_in_po_file))
      end)

    cond do
      completion_details.total_messages_count == 0 ->
        Decimal.new(100)

      completion_details.total_untranslated_count == completion_details.total_messages_count ->
        Decimal.new(0)

      true ->
        Percentage.anti_percentage(completion_details.total_untranslated_count, completion_details.total_messages_count)
    end
  end
end
