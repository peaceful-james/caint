defmodule Caint.CompletionTest do
  use ExUnit.Case

  alias Caint.Completion

  describe "percentage/2" do
    test "returns the percentage of the top number in relation to the bottom number" do
      gettext_dir = "test/support/priv/gettext"
      locale = "ar"
      # there are 5 single translations, 1 done
      # there are 2 plural translations, 1 done.
      # total_done / total = (1 + 1) / (5 + 2) = 2 / 7 =  0.2857
      assert Completion.percentage(gettext_dir, locale) == Decimal.new("28.57")
    end
  end
end
