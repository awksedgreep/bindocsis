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
# LiveView WebSocket origin check. `true` compares the Origin header's host
# against the endpoint's configured URL host (PHX_HOST in runtime.exs), which
# works behind Fly / any TLS-terminating proxy. Do NOT use `:conn` here: it
# also compares scheme and port of the *internal* connection (http/8080)
# against the browser's https/443 origin and rejects every socket. Never
# set this to `false` in prod: the session cookie would then authenticate
# cross-site socket connections. Override with the CHECK_ORIGIN env var
# (comma-separated origins) in config/runtime.exs for multiple hosts.
config :bindocsis, BindocsisWeb.Endpoint, check_origin: true
