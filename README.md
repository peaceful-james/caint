# Caint

Untested, inefficient, hacky translating of PO files for Elixir projects.

Inspired a lot by (but not as good as) `kanta`.

I used to use Kanta a lot but it relies on an outdated `gettext` PR that was recently rejected (years after being approved).

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
