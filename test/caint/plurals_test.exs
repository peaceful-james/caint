defmodule Caint.PluralsTest do
  use ExUnit.Case

  alias Caint.Plurals

  describe "build_plural_numbers_by_index_for_locale/1" do
    test "works" do
      assert Plurals.build_plural_numbers_by_index_for_locale("ar") == %{
               0 => 0,
               1 => 1,
               2 => 2,
               3 => 3,
               4 => 11,
               5 => 100
             }
    end

    test "returns empty map when errors" do
      assert Plurals.build_plural_numbers_by_index_for_locale("sdfdsfef") == %{}
    end
  end
end
