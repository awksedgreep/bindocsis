Code.require_file("support/fixtures/accounts_fixtures.ex", __DIR__)
Code.require_file("support/data_case.ex", __DIR__)
Code.require_file("support/conn_case.ex", __DIR__)

ExUnit.start(exclude: [:comprehensive_fixtures, :cli, :performance])
Ecto.Adapters.SQL.Sandbox.mode(Bindocsis.Repo, :manual)
