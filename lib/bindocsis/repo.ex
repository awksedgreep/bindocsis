defmodule Bindocsis.Repo do
  use Ecto.Repo,
    otp_app: :bindocsis,
    adapter: Ecto.Adapters.SQLite3
end
