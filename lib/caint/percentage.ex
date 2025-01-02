defmodule Caint.Percentage do
  @moduledoc """
  Calculate completion percentages for locales
  """

  @type input_number :: integer | binary() | Decimal.t()

  @doc """
  Effectively returns "% done"

  e.g. 19/20 = 95% done
  """
  @spec percentage(input_number, input_number, Decimal.rounding()) :: Decimal.t()
  def percentage(top, bottom, rounding \\ :down) do
    top_dec = Decimal.new(top)
    bottom_dec = Decimal.new(bottom)
    perc(top_dec, bottom_dec, rounding)
  end

  defp perc(top_dec, bottom_dec, rounding) do
    top_dec
    |> Decimal.mult(100)
    |> Decimal.div(bottom_dec)
    |> Decimal.round(2, rounding)
  end
end
