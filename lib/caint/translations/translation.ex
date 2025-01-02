defmodule Caint.Translations.Translation do
  @moduledoc """
  Enhanced type `translation` for Caint

  It exposes inferred locale, domain and context as root-level fields
  for easy grouping/displaying in web UI.

  Moreover, this struct is both input and output for translations.
  When translating, the `msgstr` field is added to the `message` field.
  """
  alias Expo.Message.Plural
  alias Expo.Message.Singular

  @typedoc """
  The context of a translation is a simple string.

  It is derived from the `msgctxt` field on an `Expo.Message.t()`
  For DeepL, the context is sent to help with translating correctly.
  """
  @type context :: String.t()

  @typedoc """
  The domain of a translation is a simple string.

  It is derived from the filename of the `.po` file that the translation was extracted from.
  e.g. `priv/gettext/en/LC_MESSAGES/home-page.po` would have a domain of `"home-page"`
  """
  @type domain :: String.t()

  @type t :: %__MODULE__{
          message: Singular.t() | Plural.t(),
          context: context(),
          domain: domain(),
          locale: Gettext.locale()
        }

  @enforce_keys [:message, :context, :domain, :locale]
  defstruct message: nil,
            context: "",
            domain: "",
            locale: ""
end
