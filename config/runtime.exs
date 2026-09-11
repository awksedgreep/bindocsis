import Config

# config/runtime.exs is executed for all environments, including
# during releases. It is executed after compilation and before the
# system starts, so it is typically used to load production configuration
# and secrets from environment variables or elsewhere.

if config_env() == :prod do
  # The secret key base is used to sign/encrypt cookies and other secrets.
  # A default value is used in config/dev.exs and config/test.exs but you
  # want to use a different value for prod and you most likely don't want
  # to check this value into version control, so we use an environment
  # variable instead.
  secret_key_base =
    System.get_env("SECRET_KEY_BASE") ||
      raise """
      environment variable SECRET_KEY_BASE is missing.
      You can generate one by calling: mix phx.gen.secret
      """

  host = System.get_env("PHX_HOST") || "localhost"
  port = String.to_integer(System.get_env("PORT") || "4555")

  config :bindocsis, BindocsisWeb.Endpoint,
    url: [host: host, port: 443, scheme: "https"],
    http: [
      ip: {0, 0, 0, 0, 0, 0, 0, 0},
      port: port
    ],
    secret_key_base: secret_key_base,
    server: true

  # Enable server mode
  config :bindocsis, server: true

  # ## SSL Support
  #
  # To get SSL working, you will need to add the `https` key
  # to your endpoint configuration:
  #
  #     config :bindocsis, BindocsisWeb.Endpoint,
  #       https: [
  #         ...,
  #         port: 443,
  #         cipher_suite: :strong,
  #         keyfile: System.get_env("SSL_KEY_PATH"),
  #         certfile: System.get_env("SSL_CERT_PATH")
  #       ]
  #
  # The `cipher_suite` is set to `:strong` to support only the
  # latest and most secure SSL ciphers. This means old browsers
  # and clients may not be supported.

  # ## DNS Clustering
  #
  # If you're deploying to Kubernetes or other environments that support
  # DNS-based cluster discovery:
  #
  # config :dns_cluster,
  #   query: System.get_env("DNS_CLUSTER_QUERY")

  # Configure logging for production
  config :logger, level: :info

  # Database configuration for production
  # Use /app/data for persistent volume storage on Fly.io
  database_path =
    System.get_env("DATABASE_PATH") || "/app/data/bindocsis.db"

  config :bindocsis, Bindocsis.Repo,
    database: database_path,
    pool_size: String.to_integer(System.get_env("POOL_SIZE") || "5")

  # Configure Resend for email in production
  config :bindocsis, Bindocsis.Mailer,
    adapter: Swoosh.Adapters.Resend,
    api_key: System.get_env("RESEND_API_KEY")
end

# Development/test configuration
if config_env() in [:dev, :test] do
  # For development, we use a hardcoded secret
  endpoint_server =
    if config_env() == :test, do: true, else: System.get_env("PHX_SERVER") == "true"

  config :bindocsis, BindocsisWeb.Endpoint,
    http: [ip: {127, 0, 0, 1}, port: 4555],
    secret_key_base: "dev-secret-key-base-that-is-at-least-64-bytes-long-for-security!",
    server: endpoint_server

  if config_env() == :dev and System.get_env("PHX_SERVER") do
    config :bindocsis, server: System.get_env("PHX_SERVER") == "true"
  end
end
