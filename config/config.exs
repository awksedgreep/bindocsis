import Config

# Base configuration for all environments
config :bindocsis,
  verbose_mode: false,
  default_fixtures_path: "test/fixtures",
  version: "0.9.0"

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

# Import environment specific config files
import_config "#{config_env()}.exs"
