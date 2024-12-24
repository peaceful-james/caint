# Caint

## DeepL auto-translating of PO files

Inspired a lot by (but not as good as) `kanta`.

I used to use Kanta **a lot** but it relies on an outdated `gettext` PR that was recently rejected (years after being approved).
https://github.com/elixir-gettext/gettext/pull/305

So I made "Caint", just to keep the show on the road.

## Features

- Bulk-translate locale-scoped PO files in a single step
- See how "complete" a particular locale is.
- Easily find missing translations (they are at the top of a locale's page).
- Absolutely nothing else.

### What people are saying about `caint`: 

> "Untested, inefficient and hacky."

> "Totally unfit for public consumption."

> "How is this supposed to work?"

## Get started

Make a file `dev-secrets/.env.exs` with contents like this

```
System.put_env("DEEPL_API_KEY", "xxxxxxx")
System.put_env("DEEPL_API_URL", "https://api-free.deepl.com/v2/")
System.put_env("GETTEXT_DIR", "/home/my-project/priv/gettext")
System.put_env("SOURCE_LOCALE", "en")
```

## Do the thing

```
iex -S mix phx.server
```
