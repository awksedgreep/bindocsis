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
#
# LiveView WebSocket origin check. `:conn` compares the Origin header
# against the request host, which is correct behind Fly / a reverse proxy
# that forwards the public Host. Never set this to `false` in prod: the
# session cookie would then authenticate cross-site socket connections.
# Override with the CHECK_ORIGIN env var (comma-separated origins) in
# config/runtime.exs when the proxy rewrites Host.
config :bindocsis, BindocsisWeb.Endpoint, check_origin: :conn
