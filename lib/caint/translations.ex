defmodule Caint.Translations do
  @moduledoc """
  The context for reading and writing translations in PO files.

  A `Caint.Translations.Translation` wraps an `Expo.Message` with its locale, domain,
  context and a stable id.

  Writes are always merged into the PO file as it is on disk *at the time of writing*:
  messages keep their original order, untouched messages are left as they are,
  and no message is ever removed.
  """
  alias Caint.Plurals
  alias Caint.PoParsing
  alias Caint.Translatables.Translatable
  alias Caint.Translations.Translation
  alias Expo.Message
  alias Expo.Message.Plural
  alias Expo.Message.Singular

  @typedoc """
  How a write treats `msgstr`s that already have text on disk.

  - `:overwrite` replaces them (manual edits).
  - `:fill_missing` only fills in empty ones, so text that appeared on disk while
    a machine translation was running is never clobbered.
  """
  @type write_mode :: :overwrite | :fill_missing

  @spec build_translations_from_po_files(PoParsing.gettext_dir(), Gettext.locale()) :: [Translation.t()]
  def build_translations_from_po_files(gettext_dir, locale) do
    gettext_dir
    |> PoParsing.po_paths_in_priv(locale)
    |> Task.async_stream(&build_translations_from_po_file(&1, locale), timeout: :infinity)
    |> Enum.flat_map(fn {:ok, translations} -> translations end)
  end

  @doc """
  Re-reads a single translation from disk by its id.
  """
  @spec fetch_translation(PoParsing.gettext_dir(), Gettext.locale(), Translation.id()) ::
          {:ok, Translation.t()} | :error
  def fetch_translation(gettext_dir, locale, id) do
    gettext_dir
    |> build_translations_from_po_files(locale)
    |> Enum.find(&(&1.id == id))
    |> case do
      nil -> :error
      translation -> {:ok, translation}
    end
  end

  @spec put_translated_message_on_translated([Translatable.t()]) :: Translation.t()
  def put_translated_message_on_translated(translated) do
    case translated do
      [%Translatable{translation: %{message: %Singular{}}} = singular_translated] ->
        put_translated_message_on_translation_for_singular(singular_translated)

      [%Translatable{translation: %{message: %Plural{}}} | _] = plural_translateds ->
        put_translated_message_on_translation_for_plural(plural_translateds)
    end
  end

  @doc """
  Saves a manually entered translation for one message (or one plural form of it).
  """
  @spec translate_single(Translation.t(), PoParsing.gettext_dir(), non_neg_integer() | nil, String.t()) :: :ok
  def translate_single(%Translation{} = translation, gettext_dir, plural_index, new_text) do
    msgstr =
      case translation.message do
        %Singular{} -> [new_text]
        %Plural{msgstr: msgstr} -> Map.put(msgstr || %{}, plural_index, [new_text])
      end

    new_translation = put_in(translation.message.msgstr, msgstr)
    write_translations([new_translation], gettext_dir, :overwrite)
  end

  @doc """
  Writes the `msgstr` of each translation into its PO file.

  See `t:write_mode/0`.
  """
  @spec write_translations([Translation.t()], PoParsing.gettext_dir(), write_mode()) :: :ok
  def write_translations(translations, gettext_dir, mode \\ :fill_missing) do
    translations
    |> Enum.group_by(&{&1.locale, &1.domain})
    |> Enum.each(fn {{locale, domain}, same_file_translations} ->
      po_path = po_path(gettext_dir, locale, domain)
      new_by_key = Map.new(same_file_translations, &{Message.key(&1.message), &1.message})
      original = Expo.PO.parse_file!(po_path)

      messages = Enum.map(original.messages, &merge_message(&1, new_by_key, mode))

      File.write!(po_path, Expo.PO.compose(%{original | messages: messages}))
    end)
  end

  @spec po_path(PoParsing.gettext_dir(), Gettext.locale(), Translation.domain()) :: Path.t()
  def po_path(gettext_dir, locale, domain) do
    Path.join([gettext_dir, locale, "LC_MESSAGES", domain <> ".po"])
  end

  defp build_translations_from_po_file(po_path, locale) do
    domain = infer_domain_from_po_path(po_path)
    po = Expo.PO.parse_file!(po_path)
    plural_numbers_by_index = Plurals.for_messages(po, locale)

    Enum.map(po.messages, fn message ->
      %Translation{
        id: build_id(domain, message),
        message: message,
        domain: domain,
        context: build_context(message),
        locale: locale,
        plural_numbers_by_index: plural_numbers_by_index
      }
    end)
  end

  defp build_id(domain, message) do
    :sha256
    |> :crypto.hash(:erlang.term_to_binary({domain, Message.key(message)}))
    |> binary_part(0, 12)
    |> Base.url_encode64(padding: false)
  end

  defp merge_message(on_disk, new_by_key, mode) do
    case Map.fetch(new_by_key, Message.key(on_disk)) do
      {:ok, new_message} -> merge_msgstr(on_disk, new_message, mode)
      :error -> on_disk
    end
  end

  defp merge_msgstr(%Singular{} = on_disk, %Singular{msgstr: new_msgstr}, mode) do
    if mode == :overwrite or empty_msgstr?(on_disk.msgstr) do
      %{on_disk | msgstr: new_msgstr}
    else
      on_disk
    end
  end

  defp merge_msgstr(%Plural{} = on_disk, %Plural{msgstr: new_msgstr}, mode) do
    merged =
      Enum.reduce(new_msgstr, on_disk.msgstr, fn {plural_index, new_text}, acc ->
        if mode == :overwrite or empty_msgstr?(Map.get(acc, plural_index)) do
          Map.put(acc, plural_index, new_text)
        else
          acc
        end
      end)

    %{on_disk | msgstr: merged}
  end

  # The message changed kind (singular <-> plural) on disk since it was read. Leave it alone.
  defp merge_msgstr(on_disk, _new_message, _mode), do: on_disk

  defp empty_msgstr?(nil), do: true
  defp empty_msgstr?(msgstr), do: IO.iodata_to_binary(msgstr) == ""

  defp build_context(message) do
    # PO strings split over several lines are concatenated, not joined with newlines.
    case IO.iodata_to_binary(message.msgctxt || []) do
      "" -> nil
      context -> context
    end
  end

  defp infer_domain_from_po_path(po_path) do
    Path.basename(po_path, ".po")
  end

  defp put_translated_message_on_translation_for_singular(singular_translated) do
    msgstr = [singular_translated.translated_text]
    translated_message = Map.put(singular_translated.translation.message, :msgstr, msgstr)
    %{singular_translated.translation | message: translated_message}
  end

  defp put_translated_message_on_translation_for_plural(plural_translateds) do
    [%{translation: %{message: %Plural{} = message} = translation} | _] = plural_translateds

    msgstr =
      Enum.reduce(plural_translateds, message.msgstr || %{}, fn translated, msgstr ->
        if translated.translated_text do
          Map.put(msgstr, translated.plural_index, [translated.translated_text])
        else
          msgstr
        end
      end)

    %{translation | message: %{message | msgstr: msgstr}}
  end
end
