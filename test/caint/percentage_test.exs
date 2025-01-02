defmodule Caint.PercentageTest do
  use ExUnit.Case, async: true

  alias Caint.Percentage

  describe "percentage/2" do
    test "returns the percentage of the top number in relation to the bottom number" do
      assert Percentage.percentage(19, 20) == Decimal.new("95.00")
      assert Percentage.percentage(1, 2) == Decimal.new("50.00")
      assert Percentage.percentage(2, 2) == Decimal.new("100.00")
      assert Percentage.percentage(3, 2) == Decimal.new("150.00")
    end
  end
end
