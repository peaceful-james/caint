defmodule CaintWeb.CaintLive do
  @moduledoc false
  use CaintWeb, :live_view

  alias Caint.Deepl

  @initial_gettext_dir "../my_app/priv/gettext"
  @impl LiveView
  def mount(_params, _session, socket) do
    socket
    |> assign_gettext_dir(@initial_gettext_dir)
    |> then(&{:ok, &1})
  end

  @impl LiveView
  def handle_params(unsigned_params, _uri, socket) do
    locale = Map.get(unsigned_params, "locale")

    socket
    |> assign(%{locale: locale})
    |> assign_translations()
    |> then(&{:noreply, &1})
  end

  @impl LiveView
  def render(assigns) do
    ~H"""
    <div id="caint-index-page">
      <.simple_form :let={f} for={@gettext_dir_form} phx-change="change-gettext-dir">
        <.input field={f[:gettext_dir]} label="Gettext directory" phx-debounce={500} />
      </.simple_form>
      <.index_page
        :if={@live_action == :index}
        locales={@locales}
        completion_percentages={@completion_percentages}
      />
      <.locale_page :if={@live_action == :locale} locale={@locale} translations={@translations} />
    </div>
    """
  end

  def index_page(assigns) do
    ~H"""
    <div id="caint-index-page">
      <.table :if={Enum.any?(@locales)} id="caint-index-table" rows={@locales}>
        <:col :let={locale} label="Gettext locale">
          <.link patch={~p"/#{locale}"}>
            {locale}
          </.link>
        </:col>
        <:col :let={locale} label="Completion %">
          <.completion locale={locale} percentage={@completion_percentages[locale]} />
        </:col>
      </.table>
    </div>
    """
  end

  defp locale_page(assigns) do
    ~H"""
    <div id="caint-locale-page">
      <.back patch={~p"/"}>
        Back
      </.back>
      <h1>Locale: {@locale}</h1>
      <.button type="button" phx-click="translate-all-untranslated" phx-value-locale={@locale}>
        Translate all "Missing"
      </.button>
      <.table id="users" rows={Enum.sort_by(@translations, &Caint.message_translated?(&1.message))}>
        <:col :let={translation} label="msgid">
          <.msgid translation={translation} />
        </:col>
        <:col :let={translation} label="msgstr">
          <.msgstr translation={translation} />
        </:col>
        <:col :let={translation} label="domain">
          {translation.domain}
        </:col>
        <:col :let={translation} label="context">
          <.msgctxt translation={translation} />
        </:col>
      </.table>
    </div>
    """
  end

  attr :locale, :string, required: true
  attr :percentage, :any, required: true

  defp completion(assigns) do
    ~H"""
    <div class="flex justify-between items-center gap-x-2">
      <p
        :if={@percentage}
        class={[
          if(Decimal.eq?(@percentage, 100), do: "text-green-500", else: "text-red-500")
        ]}
      >
        {@percentage |> to_string() |> Kernel.<>("%")}
      </p>
      <.button phx-click="calc-percent" phx-value-locale={@locale}>
        Recalculate
      </.button>
    </div>
    """
  end

  attr :translation, :map, required: true

  defp msgid(assigns) do
    %{translation: translation} = assigns
    [msgid_str] = translation.message.msgid
    assigns = %{msgid_str: msgid_str}

    ~H"""
    <p>
      {@msgid_str}
    </p>
    """
  end

  attr :translation, :map, required: true

  defp msgstr(assigns) do
    %{translation: translation} = assigns

    msgstr_strs =
      case translation.message.msgstr do
        [""] -> [:missing]
        [msgstr_str] -> [msgstr_str]
        msgstr_map when is_map(msgstr_map) -> Enum.map(msgstr_map, fn {k, v} -> "#{k}: #{v}" end)
      end

    assigns = %{msgstr_strs: msgstr_strs}

    ~H"""
    <p
      :for={msgstr_str <- @msgstr_strs}
      class={[if(msgstr_str == :missing, do: "uppercase text-red-500")]}
    >
      {msgstr_str}
    </p>
    """
  end

  attr :translation, :map, required: true

  defp msgctxt(assigns) do
    ~H"""
    <p>
      {@translation.message.msgctxt}
    </p>
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
    %{gettext_dir: gettext_dir} = socket.assigns
    percentage = Caint.completion_percentage(gettext_dir, locale)

    socket
    |> update(:completion_percentages, &Map.put(&1, locale, percentage))
    |> then(&{:noreply, &1})
  end

  @impl LiveView
  def handle_event("translate-all-untranslated", params, socket) do
    socket
    |> translate_all_untranslated(params)
    |> then(&{:noreply, &1})
  end

  defp calculate_all_completion_percentages(socket) do
    %{locales: locales, gettext_dir: gettext_dir} = socket.assigns

    completion_percentages =
      if gettext_dir do
        Enum.reduce(locales, %{}, fn locale, completion_percentages ->
          percentage = Caint.completion_percentage(gettext_dir, locale)
          Map.put(completion_percentages, locale, percentage)
        end)
      else
        %{}
      end

    assign(socket, :completion_percentages, completion_percentages)
  end

  defp init_locales(socket) do
    %{gettext_dir: gettext_dir} = socket.assigns
    locales = if gettext_dir, do: Caint.gettext_locales(gettext_dir), else: []

    socket
    |> assign(:locale, nil)
    |> assign(:locales, locales)
    |> assign(:completion_percentages, %{})
  end

  defp assign_gettext_dir(socket, gettext_dir) do
    socket
    |> assign(:gettext_dir, gettext_dir)
    |> assign(:gettext_dir_form, to_form(%{"gettext_dir" => gettext_dir}))
    |> init_locales()
    |> calculate_all_completion_percentages()
  end

  defp assign_translations(socket) do
    %{gettext_dir: gettext_dir, locale: locale} = socket.assigns
    translations = if gettext_dir && locale, do: Caint.translations(gettext_dir, locale), else: []
    assign(socket, :translations, translations)
  end

  defp change_gettext_dir(socket, gettext_dir) do
    cond do
      !File.exists?(gettext_dir) ->
        put_flash(socket, :error, "No such directory #{gettext_dir}")

      !File.dir?(gettext_dir) ->
        put_flash(socket, :error, "#{gettext_dir} is not a directory")

      true ->
        assign_gettext_dir(socket, gettext_dir)
    end
  end

  defp translate_all_untranslated(socket, params) do
    %{"locale" => locale} = params
    %{locale: ^locale, translations: translations, gettext_dir: gettext_dir} = socket.assigns

    new_translations = Deepl.translate_all_untranslated(translations)

    new_translations
    |> Enum.group_by(& &1.domain)
    |> Enum.map(fn {domain, same_domain_translations} ->
      po_path = Path.join([gettext_dir, locale, "LC_MESSAGES", domain <> ".po"])

      unless File.exists?(po_path) do
        raise "NO SUCH PATH #{po_path}"
      end

      original = Expo.PO.parse_file!(po_path)
      messages = Enum.map(same_domain_translations, & &1.message)
      new = %{original | messages: messages}
      Caint.write_le_po_file(po_path, new)
    end)

    socket
    |> assign(:translations, new_translations)
    |> put_flash(:info, "Done translating :)")
  end
end
