defmodule Bindocsis.ProdConfigTest do
  use ExUnit.Case, async: true

  @moduledoc """
  Guards production endpoint settings that would silently weaken security
  (issue #10). Reads config/prod.exs the same way Mix does.
  """

  test "prod endpoint never disables the LiveView origin check" do
    config = Config.Reader.read!("config/prod.exs", env: :prod)
    endpoint = get_in(config, [:bindocsis, BindocsisWeb.Endpoint])

    assert Keyword.has_key?(endpoint, :check_origin)
    refute endpoint[:check_origin] == false

    # :conn compares scheme and port of the internal (http/8080) connection
    # against the browser's https origin and rejects every socket behind a
    # TLS-terminating proxy such as Fly; only `true` or an explicit list is
    # deployable.
    refute endpoint[:check_origin] == :conn
    assert endpoint[:check_origin] == true or is_list(endpoint[:check_origin])
  end
end
