defmodule Caint do
  @moduledoc """
  Translate PO files
  """

  alias Caint.Deepl
  alias Caint.PoParsing
  alias Caint.Translations

  @env Application.compile_env(:caint, :env)
  @spec env() :: :dev | :test | :prod
  def env, do: Application.get_env(:caint, :env) || @env

  @type translate_result :: %{translated_count: non_neg_integer(), errors: [Deepl.error()]}

  @doc """
  Machine-translate everything missing in the given locales, and write it to the PO files.

  The PO files are read fresh from disk (so nothing saved since a page was loaded is lost)
  and the results are merged back in without overwriting anything that has been translated
  in the meantime. Whatever DeepL did translate is written even if some batches failed.

  Accepts the same options as `Caint.Deepl.translate_all_untranslated/2`.
  """
  @spec translate_missing(PoParsing.gettext_dir(), [Gettext.locale()], keyword()) :: translate_result()
  def translate_missing(gettext_dir, locales, opts \\ []) do
    {translated, errors} =
      locales
      |> Enum.flat_map(&Translations.build_translations_from_po_files(gettext_dir, &1))
      |> Deepl.translate_all_untranslated(opts)

    :ok = Translations.write_translations(translated, gettext_dir, :fill_missing)
    %{translated_count: length(translated), errors: errors}
  end
end
