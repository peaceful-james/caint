defmodule Caint.Percentage do
  @moduledoc """
  Calculate completion percentages for locales
  """

  def percentage(top, bottom) do
    top_dec = Decimal.new(top)
    bottom_dec = Decimal.new(bottom)
    perc(top_dec, bottom_dec)
  end

  def anti_percentage(top, bottom) do
    top_dec = Decimal.new(top)
    bottom_dec = Decimal.new(bottom)

    bottom_dec
    |> Decimal.sub(top_dec)
    |> perc(bottom_dec)
  end

  defp perc(top_dec, bottom_dec) do
    top_dec
    |> Decimal.mult(100)
    |> Decimal.div(bottom_dec)
    |> Decimal.round(2, :down)
  end
end
