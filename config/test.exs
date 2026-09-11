import Config

# Only in tests, remove the complexity from the password hashing algorithm
config :bcrypt_elixir, :log_rounds, 1

config :logger, level: :error

config :bindocsis,
  verbose_mode: false,
  server: true

# Tests get their own SQLite file so they never touch the dev database.
config :bindocsis, Bindocsis.Repo,
  database: Path.expand("../bindocsis_test.db", __DIR__),
  pool: Ecto.Adapters.SQL.Sandbox,
  pool_size: 5,
  busy_timeout: 30_000
