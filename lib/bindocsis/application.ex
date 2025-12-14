defmodule Bindocsis.Application do
  @moduledoc """
  The Bindocsis Application.

  Starts the web server in server mode, otherwise runs as a library.
  """

  use Application

  @impl true
  def start(_type, _args) do
    children =
      if server_mode?() do
        # Start the web server
        [
          {BindocsisWeb.Supervisor, []}
        ]
      else
        # Library mode - no children needed
        []
      end

    opts = [strategy: :one_for_one, name: Bindocsis.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Check if we should start in server mode
  defp server_mode? do
    # Server mode if PHX_SERVER env var is set or if config says so
    System.get_env("PHX_SERVER") == "true" ||
      Application.get_env(:bindocsis, :server, false)
  end
end
