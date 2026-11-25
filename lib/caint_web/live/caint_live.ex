# credo:disable-for-this-file Credo.Check.Readability.Specs
defmodule CaintWeb.CaintLive do
  @moduledoc """
  The one and only page.

  - `:index` lists the locales in the gettext directory with their completion.
  - `:locale` lists the messages of one locale, untranslated ones first.

  Machine translation runs in the background (`start_async/3`) and reports progress,
  so the page stays responsive. Only one translation job runs at a time.
  """
  use CaintWeb, :live_view

  alias Caint.Completion
  alias Caint.Completion.CompletionBreakdown
  alias Caint.Deepl
  alias Caint.ExpoLogic
  alias Caint.GettextLocales
  alias Caint.Interpolatables
  alias Caint.Translations
  alias Caint.Translations.Translation

  @impl LiveView
  def mount(_params, _session, socket) do
    initial_gettext_dir = Application.get_env(:caint, :gettext_dir, "")

    socket
    |> assign(:job, nil)
    |> assign(:translation_count, 0)
    |> stream_configure(:translations, dom_id: &"translation-#{&1.id}")
    |> stream(:translations, [])
    |> assign_gettext_dir(initial_gettext_dir)
    |> assign_deepl_usage()
    |> then(&{:ok, &1})
  end

  @impl LiveView
  def handle_params(unsigned_params, _uri, socket) do
    socket
    |> assign(:locale, Map.get(unsigned_params, "locale"))
    |> load_translations()
    |> then(&{:noreply, &1})
  end

  @impl LiveView
  def render(assigns) do
    ~H"""
    <div id="caint-page" class="space-y-6">
      <div class="flex items-center justify-between gap-x-4 text-sm">
        <div id="deepl-usage">
          DeepL usage:
          <.async_result :let={percentage} assign={@deepl_usage}>
            <:loading>…</:loading>
            <:failed>unknown</:failed>
            {Decimal.to_string(percentage)}%
          </.async_result>
        </div>
        <.job_progress job={@job} />
      </div>
      <.simple_form
        :let={f}
        id="gettext-dir-form"
        for={@gettext_dir_form}
        phx-change="change-gettext-dir"
      >
        <.input field={f[:gettext_dir]} label="Gettext directory" phx-debounce={500} />
      </.simple_form>
      <.index_page
        :if={@live_action == :index}
        locales={@locales}
        completion_breakdowns={@completion_breakdowns}
        job={@job}
      />
      <.locale_page
        :if={@live_action == :locale}
        locale={@locale}
        translations={@streams.translations}
        translation_count={@translation_count}
        completion_breakdowns={@completion_breakdowns}
        job={@job}
      />
    </div>
    """
  end

  attr :job, :map, default: nil

  defp job_progress(assigns) do
    ~H"""
    <div :if={@job} id="job-progress" class="flex items-center gap-x-3" role="status">
      <.icon name="hero-arrow-path" class="h-4 w-4 animate-spin" />
      <span>{@job.label}</span>
      <progress class="w-40" value={@job.done} max={max(@job.total, 1)}></progress>
      <span class="tabular-nums">{@job.done}/{@job.total} batches</span>
    </div>
    """
  end

  attr :locales, :list, required: true
  attr :completion_breakdowns, :map, required: true
  attr :job, :map, default: nil

  def index_page(assigns) do
    ~H"""
    <div id="caint-index-page" class="space-y-4">
      <.button
        :if={Enum.any?(@locales)}
        id="translate-all-locales"
        type="button"
        phx-click="translate-all-locales"
        disabled={!!@job}
      >
        Translate all languages
      </.button>
      <.table :if={Enum.any?(@locales)} id="caint-index-table" rows={@locales}>
        <:col :let={locale} label="Gettext locale">
          <.link patch={~p"/#{locale}"}>
            {locale}
          </.link>
        </:col>
        <:col :let={locale} label="Completion %">
          <.completion locale={locale} breakdown={@completion_breakdowns[locale]} />
        </:col>
      </.table>
    </div>
    """
  end

  attr :locale, :string, required: true
  attr :completion_breakdowns, :map, required: true
  attr :translations, :any, required: true
  attr :translation_count, :integer, required: true
  attr :job, :map, default: nil

  defp locale_page(assigns) do
    ~H"""
    <div id="caint-locale-page" class="space-y-4">
      <.back patch={~p"/"}>
        Back
      </.back>
      <div class="flex items-center justify-start gap-x-6">
        <p>
          Locale:
        </p>
        <h1 class="p-2 border rounded-full font-bold">{@locale}</h1>
      </div>
      <div class="flex items-center justify-start gap-x-6">
        <p>
          Completion:
        </p>
        <.completion locale={@locale} breakdown={@completion_breakdowns[@locale]} />
      </div>
      <.button
        id="translate-all-untranslated"
        type="button"
        phx-click="translate-all-untranslated"
        phx-value-locale={@locale}
        disabled={!!@job}
      >
        Translate all "Missing"
      </.button>
      <p :if={@translation_count == 0} class="text-zinc-500">No messages for this locale.</p>
      <.table
        id="translations"
        rows={@translations}
        row_item={fn {_dom_id, translation} -> translation end}
      >
        <:col :let={translation} label="msgid">
          <.msgid translation={translation} />
        </:col>
        <:col :let={translation} label="msgstr">
          <div class="space-y-4">
            <.missing :if={!ExpoLogic.message_translated?(translation.message)} />
            <.single_translation_form translation={translation} />
          </div>
        </:col>
        <:col :let={translation} label="domain">
          {translation.domain}
        </:col>
        <:col :let={translation} label="context">
          {translation.context}
        </:col>
      </.table>
    </div>
    """
  end

  attr :locale, :string, required: true
  attr :breakdown, CompletionBreakdown, default: nil

  defp completion(assigns) do
    fully_complete? = !!assigns.breakdown && Decimal.eq?(assigns.breakdown.percentage, 100)
    assigns = assign(assigns, %{fully_complete?: fully_complete?})

    ~H"""
    <div :if={@breakdown} class="flex items-center justify-start gap-x-6 ">
      <div class="flex items-center justify-center gap-x-2">
        <div class="divide-y">
          <p class="tracking-wide">
            {@breakdown.translated_count || 0}
          </p>
          <p class="tracking-wide">
            {@breakdown.total_count || 0}
          </p>
        </div>
        <p>=</p>
        <p class={[if(@fully_complete?, do: "text-green-500", else: "text-red-500"), "tracking-wider"]}>
          {@breakdown.percentage |> to_string() |> Kernel.<>("%")}
        </p>
      </div>
      <.button phx-click="calc-percent" phx-value-locale={@locale}>
        Recalculate Completion
      </.button>
    </div>
    """
  end

  attr :translation, Translation, required: true

  defp msgid(assigns) do
    message = assigns.translation.message
    msgid_plural = if Map.has_key?(message, :msgid_plural), do: IO.iodata_to_binary(message.msgid_plural)
    assigns = assign(assigns, %{msgid: IO.iodata_to_binary(message.msgid), msgid_plural: msgid_plural})

    # Keep each <p> on one line: whitespace-pre-wrap would show any indentation inside it.
    ~H"""
    <p class={msgid_class()}>{@msgid}</p>
    <p :if={@msgid_plural} class={["mt-2", msgid_class()]}>{@msgid_plural}</p>
    """
  end

  defp msgid_class, do: "w-fit p-2 rounded-lg bg-cyan-100 text-balance whitespace-pre-wrap"

  defp missing(assigns) do
    ~H"""
    <p class="uppercase text-red-500">
      Missing
    </p>
    """
  end

  defp build_text_and_placeholder_by_plural_index(%Translation{} = translation) do
    case translation.message.msgstr do
      msgstr_list when is_list(msgstr_list) ->
        placeholder = IO.iodata_to_binary(translation.message.msgid)
        [{nil, %{text: IO.iodata_to_binary(msgstr_list), placeholder: placeholder}}]

      msgstr_map when is_map(msgstr_map) ->
        msgstr_map
        |> Enum.sort()
        |> Enum.map(fn {plural_index, msgstr_list} ->
          placeholder = plural_placeholder(translation, plural_index)
          {plural_index, %{text: IO.iodata_to_binary(msgstr_list), placeholder: placeholder}}
        end)
    end
  end

  defp plural_placeholder(translation, plural_index) do
    case Map.fetch(translation.plural_numbers_by_index, plural_index) do
      {:ok, plural_number} ->
        source = if plural_number == 1, do: translation.message.msgid, else: translation.message.msgid_plural
        numbered = Interpolatables.plural_numbered_string(translation, plural_number)
        "\"#{IO.iodata_to_binary(source)}\", as in \"#{numbered}\""

      :error ->
        "plural form #{plural_index}"
    end
  end

  attr :translation, Translation, required: true

  defp single_translation_form(assigns) do
    assigns = assign(assigns, :forms, build_text_and_placeholder_by_plural_index(assigns.translation))

    ~H"""
    <.form
      :let={f}
      :for={{plural_index, %{text: text, placeholder: placeholder}} <- @forms}
      class={["flex justify-start gap-x-4 items-center", "border rounded-lg p-2", "bg-gray-300"]}
      for={to_form(%{"new_text" => text}, id: "form-#{@translation.id}-#{plural_index}")}
      phx-submit="translate-single"
      phx-value-id={@translation.id}
      phx-value-plural_index={plural_index}
    >
      <div class="grow">
        <.input
          type="textarea"
          field={f[:new_text]}
          label={"Translation for " <> placeholder}
          placeholder={placeholder}
        />
      </div>
      <.button>Save</.button>
    </.form>
    """
  end

  @impl LiveView
  def handle_event("change-gettext-dir", %{"gettext_dir" => gettext_dir}, socket) do
    socket
    |> change_gettext_dir(gettext_dir)
    |> then(&{:noreply, &1})
  end

  @impl LiveView
  def handle_event("calc-percent", %{"locale" => locale}, socket) do
    {:noreply, refresh_completion_breakdowns(socket, [locale])}
  end

  @impl LiveView
  def handle_event("translate-all-untranslated", %{"locale" => locale}, socket) do
    {:noreply, start_translate_job(socket, [locale], "Translating #{locale}")}
  end

  @impl LiveView
  def handle_event("translate-all-locales", _params, socket) do
    {:noreply, start_translate_job(socket, socket.assigns.locales, "Translating all languages")}
  end

  @impl LiveView
  def handle_event("translate-single", params, socket) do
    socket
    |> translate_single(params)
    |> then(&{:noreply, &1})
  end

  @impl LiveView
  def handle_info({:translate_progress, %{done: done, total: total}}, socket) do
    case socket.assigns.job do
      nil -> {:noreply, socket}
      job -> {:noreply, assign(socket, :job, %{job | done: done, total: total})}
    end
  end

  @impl LiveView
  def handle_async(:translate, {:ok, result}, socket) do
    %{locales: job_locales} = socket.assigns.job

    socket
    |> assign(:job, nil)
    |> put_translate_result_flash(result)
    |> refresh_completion_breakdowns(job_locales)
    |> then(&if(&1.assigns.locale in job_locales, do: load_translations(&1), else: &1))
    |> assign_deepl_usage()
    |> then(&{:noreply, &1})
  end

  def handle_async(:translate, {:exit, reason}, socket) do
    socket
    |> assign(:job, nil)
    |> put_flash(:error, "Translating failed: #{Exception.format_exit(reason)}")
    |> then(&{:noreply, &1})
  end

  defp start_translate_job(socket, locales, label) do
    %{gettext_dir: gettext_dir, job: job} = socket.assigns

    if job || locales == [] do
      socket
    else
      live_view = self()
      on_progress = &send(live_view, {:translate_progress, &1})

      socket
      |> assign(:job, %{label: label, locales: locales, done: 0, total: 0})
      |> start_async(:translate, fn -> Caint.translate_missing(gettext_dir, locales, on_progress: on_progress) end)
    end
  end

  defp put_translate_result_flash(socket, %{translated_count: count, errors: [], skipped: skipped}) do
    put_flash(socket, :info, "Done translating :) #{count} message(s) translated." <> skipped_note(skipped))
  end

  defp put_translate_result_flash(socket, %{translated_count: count, errors: errors, skipped: skipped}) do
    failed_count = errors |> Enum.map(& &1.message_count) |> Enum.sum()

    reasons =
      errors
      |> Enum.map(&"#{&1.locale}: #{&1.reason}")
      |> Enum.uniq()
      |> Enum.join("; ")

    put_flash(
      socket,
      :error,
      "Translated #{count} message(s), but #{failed_count} could not be translated (#{reasons}). " <>
        "Run it again to retry the rest." <> skipped_note(skipped)
    )
  end

  defp skipped_note([]), do: ""

  defp skipped_note(skipped) do
    " Skipped " <> Enum.map_join(skipped, ", ", &"#{&1.locale} (#{&1.reason})") <> "."
  end

  defp assign_deepl_usage(socket) do
    assign_async(socket, :deepl_usage, fn ->
      case Deepl.usage_percent() do
        {:ok, percentage} -> {:ok, %{deepl_usage: percentage}}
        {:error, reason} -> {:error, reason}
      end
    end)
  end

  defp refresh_completion_breakdowns(socket, locales) do
    %{gettext_dir: gettext_dir} = socket.assigns

    breakdowns =
      locales
      |> Task.async_stream(&{&1, Completion.breakdown(gettext_dir, &1)}, timeout: :infinity)
      |> Map.new(fn {:ok, locale_and_breakdown} -> locale_and_breakdown end)

    update(socket, :completion_breakdowns, &Map.merge(&1, breakdowns))
  end

  defp assign_gettext_dir(socket, gettext_dir) do
    Application.put_env(:caint, :gettext_dir, gettext_dir)
    locales = if File.dir?(gettext_dir), do: GettextLocales.list(gettext_dir), else: []

    socket
    |> assign(:gettext_dir, gettext_dir)
    |> assign(:gettext_dir_form, to_form(%{"gettext_dir" => gettext_dir}))
    |> assign(:locales, locales)
    |> assign(:completion_breakdowns, %{})
    |> refresh_completion_breakdowns(locales)
  end

  defp load_translations(socket) do
    %{gettext_dir: gettext_dir, locale: locale} = socket.assigns

    translations =
      if locale && File.dir?(gettext_dir) do
        gettext_dir
        |> Translations.build_translations_from_po_files(locale)
        # Missing first. The sort is stable, so the PO file order is kept within each group.
        |> Enum.sort_by(&ExpoLogic.message_translated?(&1.message))
      else
        []
      end

    socket
    |> assign(:translation_count, length(translations))
    |> stream(:translations, translations, reset: true)
  end

  defp change_gettext_dir(socket, gettext_dir) do
    cond do
      !File.exists?(gettext_dir) ->
        put_flash(socket, :error, "No such directory #{gettext_dir}")

      !File.dir?(gettext_dir) ->
        put_flash(socket, :error, "#{gettext_dir} is not a directory")

      true ->
        socket
        |> assign_gettext_dir(gettext_dir)
        |> load_translations()
        |> put_flash(:info, "Gettext directory changed to #{gettext_dir}")
    end
  end

  defp translate_single(socket, %{"id" => id, "new_text" => new_text} = params) do
    %{locale: locale, gettext_dir: gettext_dir} = socket.assigns
    plural_index = parse_plural_index(params["plural_index"])

    # Always work from the PO file as it is now, not as it was when the page loaded.
    with {:ok, translation} <- Translations.fetch_translation(gettext_dir, locale, id),
         :ok <- Translations.translate_single(translation, gettext_dir, plural_index, new_text),
         {:ok, updated} <- Translations.fetch_translation(gettext_dir, locale, id) do
      socket
      |> stream_insert(:translations, updated)
      |> refresh_completion_breakdowns([locale])
      |> put_flash(:info, "Saved that translation 👍")
    else
      :error -> put_flash(socket, :error, "That message is no longer in the PO file. Reload the page?")
    end
  end

  defp parse_plural_index(plural_index_string) when is_binary(plural_index_string) do
    case Integer.parse(plural_index_string) do
      {plural_index, ""} -> plural_index
      _ -> nil
    end
  end

  defp parse_plural_index(_), do: nil
end
