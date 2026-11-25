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

  @typedoc """
  A stable identifier for a message within a locale.

  Derived from the domain, `msgctxt` and `msgid`, so it survives re-reading the PO file
  and is safe to use as a DOM id and as a form value.
  """
  @type id :: String.t()

  @type t :: %__MODULE__{
          id: id() | nil,
          message: Singular.t() | Plural.t(),
          context: context() | nil,
          domain: domain(),
          locale: Gettext.locale(),
          plural_numbers_by_index: Caint.Plurals.plural_numbers_by_index()
        }

  @enforce_keys [:message, :context, :domain, :locale]
  defstruct id: nil,
            message: nil,
            context: "",
            domain: "",
            locale: "",
            plural_numbers_by_index: %{}
end
