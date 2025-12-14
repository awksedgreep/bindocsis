import Config

config :logger, level: :debug

config :bindocsis,
  verbose_mode: true

# Development endpoint configuration
config :bindocsis, BindocsisWeb.Endpoint,
  http: [ip: {127, 0, 0, 1}, port: 4555],
  secret_key_base: "dev-only-secret-key-base-must-be-at-least-64-bytes-long-for-cookie-signing",
  debug_errors: true,
  code_reloader: false,
  check_origin: false,
  watchers: []

# Enable server mode when PHX_SERVER is set
config :bindocsis, server: System.get_env("PHX_SERVER") == "true"
