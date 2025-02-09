defmodule Caint.Completion do
  @moduledoc """
  Functions for inferring completion
  """

  alias Caint.Completion.CompletionBreakdown
  alias Caint.ExpoLogic
  alias Caint.Percentage
  alias Caint.PoParsing

  @spec breakdown(PoParsing.gettext_dir(), Gettext.locale()) :: CompletionBreakdown.t()
  def breakdown(gettext_dir, locale) do
    completion_breakdown =
      gettext_dir
      |> PoParsing.po_paths_in_priv(locale)
      |> Enum.reduce(
        %CompletionBreakdown{percentage: nil, total_count: 0, translated_count: 0},
        &breakdown_reducer/2
      )

    percentage =
      if completion_breakdown.total_count == 0 do
        Decimal.new("100.00")
      else
        Percentage.percentage(completion_breakdown.translated_count, completion_breakdown.total_count)
      end

    %{completion_breakdown | percentage: percentage}
  end

  defp breakdown_reducer(po_path, completion_breakdown) do
    messages = Expo.PO.parse_file!(po_path)
    total_messages_in_po_file = Enum.count(messages.messages)
    total_translated_in_po_file = Enum.count(messages.messages, &ExpoLogic.message_translated?/1)

    completion_breakdown
    |> Map.update!(:total_count, &(&1 + total_messages_in_po_file))
    |> Map.update!(:translated_count, &(&1 + total_translated_in_po_file))
  end
end
