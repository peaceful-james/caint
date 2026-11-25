defmodule Caint.Fixtures do
  @moduledoc """
  Test helpers for working on throwaway copies of gettext directories.
  """

  @fixture_gettext_dir "test/support/priv/gettext"

  @doc """
  Copies the fixture gettext directory into `tmp_dir` and returns the copy's path.
  """
  @spec copy_gettext_dir!(Path.t()) :: Path.t()
  def copy_gettext_dir!(tmp_dir) do
    dest = Path.join(tmp_dir, "gettext")
    File.cp_r!(@fixture_gettext_dir, dest)
    dest
  end

  @doc """
  Writes a PO file for `locale` / `domain` under `gettext_dir` and returns its path.
  """
  @spec write_po!(Path.t(), String.t(), String.t(), iodata()) :: Path.t()
  def write_po!(gettext_dir, locale, domain, contents) do
    path = Path.join([gettext_dir, locale, "LC_MESSAGES", domain <> ".po"])
    File.mkdir_p!(Path.dirname(path))
    File.write!(path, contents)
    path
  end

  @doc """
  A DeepL `translate` stand-in that "translates" each text by prefixing it with the target language,
  echoing the markup back the way DeepL does.
  """
  @spec echo_translate(map()) :: {:ok, Req.Response.t()}
  def echo_translate(%{text: texts, target_lang: target_lang}) do
    translations = Enum.map(texts, &%{"detected_source_language" => "EN", "text" => "[#{target_lang}] " <> &1})
    {:ok, Req.Response.new(status: 200, body: %{"translations" => translations})}
  end
end
