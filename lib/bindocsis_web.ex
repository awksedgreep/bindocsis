defmodule BindocsisWeb do
  @moduledoc """
  The entrypoint for defining the web interface.

  This module provides the `static_paths/0` function used by the endpoint
  and any other web-related configuration.
  """

  @doc """
  Returns the static paths that should be served by the endpoint.
  """
  def static_paths, do: ~w(assets fonts images favicon.ico robots.txt)
end
