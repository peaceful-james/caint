defmodule Caint.Completion.CompletionBreakdown do
  @moduledoc """
  A breakdown of the "completion" of a locale.
  """

  @type t :: %__MODULE__{
          percentage: Decimal.t(),
          total_count: non_neg_integer(),
          translated_count: non_neg_integer()
        }

  @enforce_keys [:percentage, :total_count, :translated_count]
  defstruct percentage: nil, total_count: nil, translated_count: nil
end
