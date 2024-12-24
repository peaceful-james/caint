defmodule Caint do
  @moduledoc """
  Intended to replace Kanta, which seems to be abandoned

  Some terminology:
  - "po_path" is the full path to a PO file
  - "messages" refers to `Expo.Messages` which is their representation of a .po file
  """

  alias Caint.PoParsing

  def gettext_locales(gettext_dir) do
    gettext_dir
    |> PoParsing.po_paths_in_priv()
    |> Enum.map(&infer_gettext_locale_from_po_path/1)
    |> Enum.uniq()
  end

  def message_translated?(%Expo.Message.Singular{} = message) do
    message.msgstr != [""]
  end

  def message_translated?(%Expo.Message.Plural{} = message) do
    Enum.all?(message.msgstr, fn {_plural_index, plural_msgstr} ->
      plural_msgstr != [""]
    end)
  end

  def completion_percentage(gettext_dir, locale) do
    completion_details =
      gettext_dir
      |> PoParsing.po_paths_in_priv(locale)
      |> Enum.reduce(%{total_messages_count: 0, total_untranslated_count: 0}, fn po_path, completion_details ->
        messages = Expo.PO.parse_file!(po_path)
        total_messages_in_po_file = Enum.count(messages.messages)
        total_untranslated_in_po_file = Enum.count(messages.messages, &(!message_translated?(&1)))

        completion_details
        |> Map.update!(:total_messages_count, &(&1 + total_messages_in_po_file))
        |> Map.update!(:total_untranslated_count, &(&1 + total_untranslated_in_po_file))
      end)

    cond do
      completion_details.total_messages_count == 0 ->
        Decimal.new(100)

      completion_details.total_untranslated_count == completion_details.total_messages_count ->
        Decimal.new(0)

      true ->
        total_messages_count = Decimal.new(completion_details.total_messages_count)
        total_untranslated_count = Decimal.new(completion_details.total_untranslated_count)

        total_messages_count
        |> Decimal.sub(total_untranslated_count)
        |> Decimal.div(total_messages_count)
        |> Decimal.mult(100)
        |> Decimal.round(2, :down)
    end
  end

  def infer_language_from_messages(messages) do
    Expo.Messages.get_header(messages, "language")
  end

  def infer_gettext_locale_from_po_path(po_path) do
    [_file, "LC_MESSAGES", locale | _rest] = po_path |> Path.split() |> Enum.reverse()
    locale
  end

  def write_le_po_file(po_path, messages) do
    iodata = Expo.PO.compose(messages)
    File.write!(po_path, iodata)
  end
end
