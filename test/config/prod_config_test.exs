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
  end
end
