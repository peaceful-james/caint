defmodule Caint.DeeplTest do
  use ExUnit.Case

  import Mox

  alias Caint.Deepl
  alias Caint.Deepl.MockApiImpl
  alias Caint.Mocks.MockDeeplApiImpl

  describe "usage_percent/0" do
    test "returns the usage percentage" do
      expect(MockApiImpl, :usage, 1, &MockDeeplApiImpl.usage/0)
      result = Deepl.usage_percent()
      assert result == {:ok, Decimal.new("50.00")}
    end
  end
end
