defmodule CaintTest do
  use ExUnit.Case, async: true

  import Mox

  alias Caint.Deepl.MockApiImpl
  alias Caint.Fixtures
  alias Caint.Translations

  setup :verify_on_exit!

  describe "env/0" do
    test "returns an atom" do
      assert Caint.env() == :test
    end
  end

  describe "translate_missing/3" do
    @describetag :tmp_dir

    setup %{tmp_dir: tmp_dir} do
      gettext_dir = Fixtures.copy_gettext_dir!(tmp_dir)
      File.cp_r!(Path.join(gettext_dir, "ar"), Path.join(gettext_dir, "fr"))
      stub(MockApiImpl, :batch_size, fn -> 50 end)
      {:ok, gettext_dir: gettext_dir}
    end

    test "translates all locales and writes them in place", %{gettext_dir: gettext_dir} do
      stub(MockApiImpl, :translate, &Fixtures.echo_translate/1)
      before = Translations.build_translations_from_po_files(gettext_dir, "ar")

      assert %{translated_count: 10, errors: []} = Caint.translate_missing(gettext_dir, ["ar", "fr"])

      for locale <- ["ar", "fr"] do
        after_ = Translations.build_translations_from_po_files(gettext_dir, locale)
        assert Enum.map(after_, & &1.id) == Enum.map(before, & &1.id)
        assert Enum.all?(after_, &Caint.ExpoLogic.message_translated?(&1.message))
      end

      {:ok, untouched} =
        Translations.fetch_translation(
          gettext_dir,
          "ar",
          Enum.find(before, &(&1.message.msgid == ["Invalid date/time"])).id
        )

      assert untouched.message.msgstr == ["تاريخ/وقت غير صالح"]
    end

    test "writes what succeeded when some batches fail", %{gettext_dir: gettext_dir} do
      stub(MockApiImpl, :translate, fn
        %{target_lang: "FR"} -> {:ok, Req.Response.new(status: 429)}
        data -> Fixtures.echo_translate(data)
      end)

      assert %{translated_count: 5, errors: errors} = Caint.translate_missing(gettext_dir, ["ar", "fr"])
      assert Enum.all?(errors, &(&1.locale == "fr"))
      assert Caint.Completion.breakdown(gettext_dir, "ar").percentage == Decimal.new("100.00")
      refute Caint.Completion.breakdown(gettext_dir, "fr").percentage == Decimal.new("100.00")
    end
  end
end
