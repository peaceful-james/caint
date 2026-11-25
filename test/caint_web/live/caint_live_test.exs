defmodule CaintWeb.CaintLiveTest do
  # Not async: the LiveView reads (and writes) the gettext dir from the application env.
  use CaintWeb.ConnCase, async: false

  import Mox
  import Phoenix.LiveViewTest

  alias Caint.Deepl.MockApiImpl
  alias Caint.Fixtures
  alias Caint.Mocks.MockDeeplApiImpl
  alias Caint.Translations

  @moduletag :tmp_dir

  setup :set_mox_global
  setup :verify_on_exit!

  setup %{tmp_dir: tmp_dir} do
    gettext_dir = Fixtures.copy_gettext_dir!(tmp_dir)
    File.cp_r!(Path.join(gettext_dir, "ar"), Path.join(gettext_dir, "fr"))

    previous = Application.get_env(:caint, :gettext_dir)
    Application.put_env(:caint, :gettext_dir, gettext_dir)
    on_exit(fn -> Application.put_env(:caint, :gettext_dir, previous) end)

    stub(MockApiImpl, :usage, &MockDeeplApiImpl.usage/0)
    stub(MockApiImpl, :batch_size, fn -> 50 end)
    {:ok, gettext_dir: gettext_dir}
  end

  describe "index" do
    test "lists locales with completion and DeepL usage", %{conn: conn} do
      {:ok, view, html} = live(conn, ~p"/")
      assert html =~ "Translate all languages"
      assert has_element?(view, "#caint-index-table a", "ar")
      assert has_element?(view, "#caint-index-table a", "fr")
      assert render_async(view) =~ "DeepL usage:\n"
      assert render(view) =~ "50.00%"
    end

    test "still renders when DeepL usage fails", %{conn: conn} do
      stub(MockApiImpl, :usage, fn -> {:ok, Req.Response.new(status: 403)} end)
      {:ok, view, _html} = live(conn, ~p"/")
      assert render_async(view) =~ "unknown"
    end

    test "translate all languages translates every locale", %{conn: conn, gettext_dir: gettext_dir} do
      stub(MockApiImpl, :translate, &Fixtures.echo_translate/1)
      {:ok, view, _html} = live(conn, ~p"/")

      view |> element("#translate-all-locales") |> render_click()
      html = render_async(view)

      assert html =~ "10 message(s) translated"
      assert Caint.Completion.breakdown(gettext_dir, "ar").percentage == Decimal.new("100.00")
      assert Caint.Completion.breakdown(gettext_dir, "fr").percentage == Decimal.new("100.00")
      assert html =~ "100.00%"
      refute has_element?(view, "#job-progress")
    end

    test "shows progress while translating and disables the buttons", %{conn: conn} do
      test_pid = self()

      stub(MockApiImpl, :translate, fn data ->
        send(test_pid, {:translating, self()})

        receive do
          :continue -> Fixtures.echo_translate(data)
        end
      end)

      {:ok, view, _html} = live(conn, ~p"/")
      view |> element("#translate-all-locales") |> render_click()

      assert_receive {:translating, worker}
      assert has_element?(view, "#job-progress", "Translating all languages")
      assert has_element?(view, "#translate-all-locales[disabled]")

      send(worker, :continue)

      # Unblock the remaining batches.
      for _ <- 1..10 do
        receive do
          {:translating, worker} -> send(worker, :continue)
        after
          50 -> :ok
        end
      end

      render_async(view)
      refute has_element?(view, "#job-progress")
    end

    test "reports partial failures", %{conn: conn} do
      stub(MockApiImpl, :translate, fn
        %{target_lang: "FR"} -> {:ok, Req.Response.new(status: 456)}
        data -> Fixtures.echo_translate(data)
      end)

      {:ok, view, _html} = live(conn, ~p"/")
      view |> element("#translate-all-locales") |> render_click()
      html = render_async(view)

      assert html =~ "Translated 5 message(s), but 5 could not be translated"
      assert html =~ "fr: DeepL character quota exceeded (HTTP 456)"
    end

    test "changing to a missing gettext dir shows an error", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/")

      assert view
             |> form("form[phx-change=change-gettext-dir]", %{gettext_dir: "/no/such/dir"})
             |> render_change() =~ "No such directory /no/such/dir"
    end
  end

  describe "locale page" do
    test "lists messages, missing ones first", %{conn: conn} do
      {:ok, view, html} = live(conn, ~p"/ar")
      assert html =~ "Translate all &quot;Missing&quot;"

      rows = view |> render() |> LazyHTML.from_fragment() |> LazyHTML.query("#translations tr")
      assert Enum.count(rows) == 7
      assert view |> render() |> String.split("Invalid date/time") |> hd() =~ "Ambiguous time for timezone"
    end

    test "saving a single translation updates the row and completion", %{conn: conn, gettext_dir: gettext_dir} do
      {:ok, view, _html} = live(conn, ~p"/ar")

      translation =
        gettext_dir
        |> Translations.build_translations_from_po_files("ar")
        |> Enum.find(&(&1.message.msgid == ["Ambiguous time for timezone"]))

      assert has_element?(view, "#translation-#{translation.id}", "Missing")

      view
      |> form("#form-#{translation.id}-", %{new_text: "منطقة زمنية غامضة"})
      |> render_submit()

      assert render(view) =~ "Saved that translation"
      refute has_element?(view, "#translation-#{translation.id}", "Missing")
      assert has_element?(view, "#translation-#{translation.id} textarea", "منطقة زمنية غامضة")

      assert {:ok, %{message: %{msgstr: ["منطقة زمنية غامضة"]}}} =
               Translations.fetch_translation(gettext_dir, "ar", translation.id)
    end

    test "translate all missing keeps manual edits made after the page loaded", %{conn: conn, gettext_dir: gettext_dir} do
      stub(MockApiImpl, :translate, &Fixtures.echo_translate/1)
      {:ok, view, _html} = live(conn, ~p"/ar")

      [first | _] = Translations.build_translations_from_po_files(gettext_dir, "ar")
      view |> form("#form-#{first.id}-", %{new_text: "manual"}) |> render_submit()

      view |> element("#translate-all-untranslated") |> render_click()
      assert render_async(view) =~ "4 message(s) translated"

      assert {:ok, %{message: %{msgstr: ["manual"]}}} = Translations.fetch_translation(gettext_dir, "ar", first.id)
      assert Caint.Completion.breakdown(gettext_dir, "fr").percentage != Decimal.new("100.00")
      refute has_element?(view, "#translations", "Missing")
    end

    test "saving a plural form", %{conn: conn, gettext_dir: gettext_dir} do
      {:ok, view, _html} = live(conn, ~p"/ar")

      plural =
        gettext_dir
        |> Translations.build_translations_from_po_files("ar")
        |> Enum.find(&(&1.message.msgid == ["should be %{count} byte(s)"]))

      view |> form("#form-#{plural.id}-3", %{new_text: "plural three"}) |> render_submit()

      assert {:ok, %{message: %{msgstr: %{3 => ["plural three"], 0 => [""]}}}} =
               Translations.fetch_translation(gettext_dir, "ar", plural.id)
    end
  end
end
