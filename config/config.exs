import Config

# Base configuration for all environments
config :bindocsis,
  verbose_mode: false,
  default_fixtures_path: "test/fixtures",
  version: "0.1.0"

# Add logger configuration
config :logger,
  level: :warning,
  format: "$time [$level] $message\n"

# Import environment specific config files
import_config "#{config_env()}.exs"
