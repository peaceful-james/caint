defmodule Caint.PercentageTest do
  use ExUnit.Case, async: true

  alias Caint.Percentage

  # def percentage(top, bottom) do
  # def anti_percentage(top, bottom) do
  #

  describe "percentage/2" do
    test "returns the percentage of the top number in relation to the bottom number" do
      assert Percentage.percentage(19, 20) == Decimal.new("95.00")
      assert Percentage.percentage(1, 2) == Decimal.new("50.00")
      assert Percentage.percentage(2, 2) == Decimal.new("100.00")
      assert Percentage.percentage(3, 2) == Decimal.new("150.00")
    end
  end

  describe "anti_percentage/2" do
    test "returns the percentage of the bottom number in relation to the bottom number minus the top number" do
      assert Percentage.anti_percentage(19, 20) == Decimal.new("5.00")
      assert Percentage.anti_percentage(20, 20) == Decimal.new("0.00")
      assert Percentage.anti_percentage(3, 2) == Decimal.new("-50.00")
    end
  end
end
