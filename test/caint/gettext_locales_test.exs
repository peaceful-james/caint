defmodule Caint.GettextLocalesTest do
  use ExUnit.Case

  describe "list/1" do
    test "returns a list of locales" do
      gettext_dir = Application.get_env(:caint, :gettext_dir)
      assert Caint.GettextLocales.list(gettext_dir) == ["ar"]
    end
  end
end
