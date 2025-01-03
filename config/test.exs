import Config

# We don't run a server during test. If one is required,
# you can enable the server option below.
config :caint, CaintWeb.Endpoint,
  http: [ip: {127, 0, 0, 1}, port: 4002],
  secret_key_base: "LixyjLbFax9qkA3t37RV9MUWZHSZzYwVvcOaKpwvv/t97szo0Dm9gclzyit+sglk",
  server: false

# Print only warnings and errors during test
config :logger, level: :warning

# Initialize plugs at runtime for faster test compilation
config :phoenix, :plug_init_mode, :runtime

# Enable helpful, but potentially expensive runtime checks
config :phoenix_live_view,
  enable_expensive_runtime_checks: true

config :caint,
  deepl_api_key: "xxxxxxx",
  deepl_api_url: "https://api-free.deepl.com/v2/",
  gettext_dir: "test/support/priv/gettext",
  source_locale: "en"
