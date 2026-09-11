import Config

config :bindocsis, :scopes,
  user: [
    default: true,
    module: Bindocsis.Accounts.Scope,
    assign_key: :current_scope,
    access_path: [:user, :id],
    schema_key: :user_id,
    schema_type: :id,
    schema_table: :users,
    test_data_fixture: Bindocsis.AccountsFixtures,
    test_setup_helper: :register_and_log_in_user
  ]

# File extensions the upload widgets accept (LiveView's `accept:` option
# needs a MIME type for every extension). After changing this run
# `mix deps.clean mime --build`.
config :mime, :types, %{
  "application/octet-stream" => ["cm", "bin"],
  "application/yaml" => ["yaml", "yml"],
  "text/plain" => ["cfg", "conf", "txt"]
}

# Self-registration policy (see Bindocsis.Accounts.Registration). Production
# reads REGISTRATION_MODE / REGISTRATION_ALLOWLIST in config/runtime.exs.
config :bindocsis, :registration, mode: :open, allowlist: []

# Base configuration for all environments
config :bindocsis,
  verbose_mode: false,
  default_fixtures_path: "test/fixtures",
  version: "0.9.0",
  ecto_repos: [Bindocsis.Repo]

# Database configuration
config :bindocsis, Bindocsis.Repo,
  database: Path.expand("../bindocsis.db", __DIR__),
  pool_size: 5,
  stacktrace: true,
  show_sensitive_data_on_connection_error: true

# Configure Phoenix endpoint
config :bindocsis, BindocsisWeb.Endpoint,
  adapter: Bandit.PhoenixAdapter,
  render_errors: [
    formats: [html: BindocsisWeb.ErrorHTML],
    layout: false
  ],
  pubsub_server: Bindocsis.PubSub,
  live_view: [signing_salt: "bindocsis_lv_salt"]

# Configure esbuild (optional - we use CDN for Tailwind)
# config :esbuild, ...

# Add logger configuration
config :logger,
  level: :warning,
  format: "$time [$level] $message\n"

# Swoosh mailer configuration
config :bindocsis, Bindocsis.Mailer, adapter: Swoosh.Adapters.Local

# Swoosh API client for Resend
config :swoosh, :api_client, Swoosh.ApiClient.Finch

# Import environment specific config files
import_config "#{config_env()}.exs"
