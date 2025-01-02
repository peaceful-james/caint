# Caint

Auto-translating of PO files for the lazy dev

## Features

- Bulk-translate locale-scoped PO files using [DeepL](https://developers.deepl.com/docs/api-reference/translate) 

![Screenshot 2024-12-24 191018](https://github.com/user-attachments/assets/12ea5a7a-0ae3-4a8a-8ec8-a1e65eee3902)

- See how "complete" a particular locale is.

![Screenshot 2024-12-24 191046](https://github.com/user-attachments/assets/bfae84fe-18cc-45dc-917e-8a49c0f4de37)

- Easily find missing translations (they are at the top of a locale's page).

![Screenshot 2024-12-24 191108](https://github.com/user-attachments/assets/36007341-b814-4645-9dec-08506aadde20)

- Absolutely nothing else.

## What people are saying about Caint: 

> "Untested, inefficient and hacky."

> "Totally unfit for public consumption."

> "How is this supposed to work?"

## First-time setup

Make a file `config/dev_secrets.exs` with contents like this

```elixir
import Config

config :caint,
  deepl_api_key: "xxxxxxx",
  deepl_api_url: "https://api-free.deepl.com/v2/",
  gettext_dir: "/home/my-project/priv/gettext",
  source_locale: "en"
```

## Run it locally

```
iex -S mix phx.server
```
