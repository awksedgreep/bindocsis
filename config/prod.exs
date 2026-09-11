import Config

# For production, don't forget to configure the url host
# to something meaningful, Phoenix uses this information
# when generating URLs.

# Do not print debug messages in production
config :logger, level: :info

# Runtime production configuration, including reading
# of environment variables, is done on config/runtime.exs.

config :bindocsis,
  verbose_mode: false

# Configure Phoenix endpoint for production
# Note: We use CDN for Tailwind/Phoenix JS, no local static assets to cache
config :bindocsis, BindocsisWeb.Endpoint, check_origin: false
