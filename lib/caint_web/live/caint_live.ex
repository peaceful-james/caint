# credo:disable-for-this-file Credo.Check.Readability.Specs
defmodule CaintWeb.CaintLive do
  @moduledoc false
  use CaintWeb, :live_view

  alias Caint.Completion
  alias Caint.Deepl
  alias Caint.ExpoLogic
  alias Caint.GettextLocales
  alias Caint.Interpolatables
  alias Caint.Plurals
  alias Caint.Translations
  alias Caint.Translations.Translation

  @impl LiveView
  def mount(_params, _session, socket) do
    initial_gettext_dir = Application.get_env(:caint, :gettext_dir, "")

    socket
    |> assign_gettext_dir(initial_gettext_dir)
    |> assign_deepl_usage_percent()
    |> then(&{:ok, &1})
  end

  defp assign_deepl_usage_percent(socket) do
    case Deepl.usage_percent() do
      {:ok, percentage} ->
        assign(socket, :deepl_usage_percent, percentage)

      {:error, _} ->
        socket
        |> assign(:deepl_usage_percent, nil)
        |> put_flash(:error, "Failed to get DeepL usage")
    end
  end

  @impl LiveView
  def handle_params(unsigned_params, _uri, socket) do
    locale = Map.get(unsigned_params, "locale")
    plural_numbers_by_index = if locale, do: Plurals.build_plural_numbers_by_index_for_locale(locale), else: %{}

    socket
    |> assign(%{locale: locale, plural_numbers_by_index: plural_numbers_by_index})
    |> assign_translations()
    |> then(&{:noreply, &1})
  end

  @impl LiveView
  def render(assigns) do
    ~H"""
    <div id="caint-index-page">
      <div>
        DeepL usage: {@deepl_usage_percent |> to_string() |> Kernel.<>("%")}
      </div>
      <.simple_form :let={f} for={@gettext_dir_form} phx-change="change-gettext-dir">
        <.input field={f[:gettext_dir]} label="Gettext directory" phx-debounce={500} />
      </.simple_form>
      <.index_page
        :if={@live_action == :index}
        locales={@locales}
        completion_percentages={@completion_percentages}
      />
      <.locale_page
        :if={@live_action == :locale}
        locale={@locale}
        translations={@translations}
        plural_numbers_by_index={@plural_numbers_by_index}
      />
    </div>
    """
  end

  attr :locales, :list, required: true
  attr :completion_percentages, :map, required: true

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

  attr :locale, :string, required: true
  attr :translations, :list, required: true
  attr :plural_numbers_by_index, :map, required: true

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
      <.table
        id="users"
        rows={Enum.sort_by(@translations, &ExpoLogic.message_translated?(&1.message))}
      >
        <:col :let={translation} label="msgid">
          <.msgid translation={translation} />
        </:col>
        <:col :let={translation} label="msgstr">
          <div class="space-y-4">
            <.missing
              :if={!ExpoLogic.message_translated?(translation.message)}
              translation={translation}
            />
            <.single_translation_form
              translation={translation}
              locale={@locale}
              plural_numbers_by_index={@plural_numbers_by_index}
            />
          </div>
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

  attr :translation, Translation, required: true

  defp msgid(assigns) do
    %{translation: translation} = assigns
    msgid_str = Enum.join(translation.message.msgid, "\n")

    msgid_plural_str =
      if Map.has_key?(translation.message, :msgid_plural) do
        Enum.join(translation.message.msgid_plural, "\n")
      end

    assigns = %{msgid_str: msgid_str, msgid_plural_str: msgid_plural_str}

    ~H"""
    <p class="w-fit p-2 rounded-lg bg-cyan-100 text-balance">
      {@msgid_str}
    </p>
    <p :if={@msgid_plural_str} class="w-fit mt-2 p-2 rounded-lg bg-cyan-100 text-balance">
      {@msgid_plural_str}
    </p>
    """
  end

  defp missing(assigns) do
    ~H"""
    <p class="uppercase text-red-500">
      Missing
    </p>
    """
  end

  defp infer_msg_txt_field(plural_number) do
    if plural_number == 1, do: :msgid, else: :msgid_plural
  end

  defp build_text_and_placeholder_by_plural_index(translation, plural_numbers_by_index) do
    case translation.message.msgstr do
      msgstr_list when is_list(msgstr_list) ->
        placeholder = Enum.join(translation.message.msgid, "\n")
        %{nil => %{text: msgstr_list, placeholder: placeholder}}

      msgstr_map when is_map(msgstr_map) ->
        Enum.reduce(msgstr_map, %{}, fn {plural_index, msgstr_list}, msgstr_map ->
          plural_number = Map.get(plural_numbers_by_index, plural_index, 0)
          msg_text_field = infer_msg_txt_field(plural_number)
          interpolated = translation.message |> Map.get(msg_text_field) |> Enum.join("\n")
          numbered = Interpolatables.plural_numbered_string(translation, plural_number)
          placeholder = "\"#{interpolated}\", as in \"#{numbered}\""
          Map.put(msgstr_map, plural_index, %{text: msgstr_list, placeholder: placeholder})
        end)
    end
  end

  attr :translation, Translation, required: true
  attr :locale, :string, required: true
  attr :plural_numbers_by_index, :map, required: true

  defp single_translation_form(assigns) do
    text_and_placeholder_by_plural_index =
      build_text_and_placeholder_by_plural_index(assigns.translation, assigns.plural_numbers_by_index)

    assigns = assign(assigns, %{text_and_placeholder_by_plural_index: text_and_placeholder_by_plural_index})

    ~H"""
    <.form
      :let={f}
      :for={
        {plural_index, %{text: text, placeholder: placeholder}} <-
          @text_and_placeholder_by_plural_index
      }
      class={["flex justify-start gap-x-4 items-center", "border rounded-lg p-2", "bg-gray-300"]}
      for={to_form(%{"new_text" => text})}
      phx-submit="translate-single"
      phx-value-locale={@locale}
      phx-value-msgid={@translation.message.msgid}
      phx-value-msgctxt={@translation.message.msgctxt}
      phx-value-plural_index={plural_index}
    >
      <div class="grow">
        <.input
          type="textarea"
          field={f[:new_text]}
          label={"Translation for " <> placeholder}
          phx-debounce={100}
          placeholder={placeholder}
        />
      </div>
      <.button>Save</.button>
    </.form>
    """
  end

  attr :translation, Translation, required: true

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
    percentage = Completion.percentage(gettext_dir, locale)

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

  @impl LiveView
  def handle_event("translate-single", params, socket) do
    socket
    |> translate_single(params)
    |> then(&{:noreply, &1})
  end

  defp calculate_all_completion_percentages(socket) do
    %{locales: locales, gettext_dir: gettext_dir} = socket.assigns

    completion_percentages =
      if gettext_dir do
        Enum.reduce(locales, %{}, fn locale, completion_percentages ->
          percentage = Completion.percentage(gettext_dir, locale)
          Map.put(completion_percentages, locale, percentage)
        end)
      else
        %{}
      end

    assign(socket, :completion_percentages, completion_percentages)
  end

  defp init_locales(socket) do
    %{gettext_dir: gettext_dir} = socket.assigns
    locales = if gettext_dir, do: GettextLocales.list(gettext_dir), else: []

    socket
    |> assign(%{locale: nil, plural_numbers_by_index: %{}})
    |> assign(:locales, locales)
    |> assign(:completion_percentages, %{})
  end

  defp assign_gettext_dir(socket, gettext_dir) do
    Application.put_env(:caint, :gettext_dir, gettext_dir)

    socket
    |> assign(:gettext_dir, gettext_dir)
    |> assign(:gettext_dir_form, to_form(%{"gettext_dir" => gettext_dir}))
    |> init_locales()
    |> calculate_all_completion_percentages()
  end

  defp assign_translations(socket) do
    %{gettext_dir: gettext_dir, locale: locale} = socket.assigns

    translations =
      if gettext_dir && locale, do: Translations.build_translations_from_po_files(gettext_dir, locale), else: []

    assign(socket, :translations, translations)
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
        |> put_flash(:info, "Gettext directory changed to #{gettext_dir}")
    end
  end

  defp translate_single(socket, params) do
    %{"locale" => locale, "new_text" => new_text} = params
    %{locale: ^locale, translations: translations, gettext_dir: gettext_dir} = socket.assigns
    matching_fields = Translations.translation_matching_fields()

    msgid =
      case Map.get(params, "msgid") do
        msgid_string when is_binary(msgid_string) -> [msgid_string]
        nil -> nil
      end

    msgctxt =
      case Map.get(params, "msgctxt") do
        msgctxt_string when is_binary(msgctxt_string) -> [msgctxt_string]
        nil -> nil
      end

    search_match = %{msgid: msgid, msgctxt: msgctxt}
    translation = Enum.find(translations, &(Map.take(&1.message, matching_fields) == search_match))

    plural_index =
      with plural_index_string when is_binary(plural_index_string) <- Map.get(params, "plural_index"),
           {plural_index, ""} <- Integer.parse(plural_index_string) do
        plural_index
      else
        _ -> nil
      end

    :ok = Translations.translate_single(translation, gettext_dir, locale, plural_index, new_text)
    put_flash(socket, :info, "Saved that translation 👍")
  end

  defp translate_all_untranslated(socket, params) do
    %{"locale" => locale} = params
    %{locale: ^locale, translations: translations, gettext_dir: gettext_dir} = socket.assigns

    new_translations = Deepl.translate_all_untranslated(translations, locale)
    write_new_translations(new_translations, gettext_dir, locale)

    socket
    |> put_flash(:info, "Done translating :)")
    |> assign(:translations, new_translations)
  end

  defp write_new_translations(new_translations, gettext_dir, locale) do
    new_translations
    |> Enum.group_by(& &1.domain)
    |> Enum.each(fn {domain, same_domain_translations} ->
      po_path = Path.join([gettext_dir, locale, "LC_MESSAGES", domain <> ".po"])

      unless File.exists?(po_path) do
        raise "NO SUCH PATH #{po_path}"
      end

      original = Expo.PO.parse_file!(po_path)
      messages = Enum.map(same_domain_translations, & &1.message)
      new = %{original | messages: messages}
      iodata = Expo.PO.compose(new)
      File.write!(po_path, iodata)
    end)
  end
end
