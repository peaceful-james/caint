defmodule Caint.Percentage do
  @moduledoc """
  Calculate completion percentages for locales
  """

  @type input_number :: integer | binary() | Decimal.t()

  @doc """
  Effectively returns "% done"

  e.g. 19/20 = 95% done
  """
  @spec percentage(input_number, input_number) :: Decimal.t()
  def percentage(top, bottom) do
    top_dec = Decimal.new(top)
    bottom_dec = Decimal.new(bottom)
    perc(top_dec, bottom_dec)
  end

  @doc """
  Effectively returns "% left to do"

  e.g. 19/20 = 5% left to do
  """
  @spec anti_percentage(input_number, input_number) :: Decimal.t()
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
