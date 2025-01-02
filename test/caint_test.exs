defmodule CaintTest do
  use ExUnit.Case

  describe "env/0" do
    test "returns an atom" do
      assert Caint.env() == :test
    end
  end
end
