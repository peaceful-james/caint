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

  @type skipped :: %{locale: Gettext.locale(), reason: String.t()}
  @type translate_result :: %{
          translated_count: non_neg_integer(),
          errors: [Deepl.error()],
          skipped: [skipped()]
        }

  @doc """
  Machine-translate everything missing in the given locales, and write it to the PO files.

  Locales that DeepL cannot translate into, or that need no translation (the source language
  and its variants), are skipped up front; see `Caint.Deepl.resolve_target/2`.

  The PO files are read fresh from disk (so nothing saved since a page was loaded is lost)
  and the results are merged back in without overwriting anything that has been translated
  in the meantime. Whatever DeepL did translate is written even if some batches failed.

  Accepts the same options as `Caint.Deepl.translate_all_untranslated/2`.
  """
  @spec translate_missing(PoParsing.gettext_dir(), [Gettext.locale()], keyword()) :: translate_result()
  def translate_missing(gettext_dir, locales, opts \\ []) do
    supported_targets = Deepl.target_languages()
    targets = Map.new(locales, &{&1, Deepl.resolve_target(&1, supported_targets)})
    target_langs = for {locale, {:translate, code}} <- targets, into: %{}, do: {locale, code}
    skipped = for {locale, {:skip, reason}} <- targets, do: %{locale: locale, reason: reason}

    {translated, errors} =
      target_langs
      |> Map.keys()
      |> Enum.flat_map(&Translations.build_translations_from_po_files(gettext_dir, &1))
      |> Deepl.translate_all_untranslated(Keyword.put(opts, :target_langs, target_langs))

    :ok = Translations.write_translations(translated, gettext_dir, :fill_missing)
    %{translated_count: length(translated), errors: errors, skipped: Enum.sort_by(skipped, & &1.locale)}
  end
end
