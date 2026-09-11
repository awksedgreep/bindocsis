defmodule BindocsisWeb.Endpoint do
  @moduledoc """
  Minimal Phoenix Endpoint for standalone Bindocsis web server.

  This endpoint is used when running `mix bindocsis.server` to provide
  a standalone web interface without requiring an existing Phoenix app.

  ## Usage

      mix bindocsis.server --port 4001

  ## Configuration

  The endpoint can be configured in config/config.exs:

      config :bindocsis, BindocsisWeb.Endpoint,
        http: [port: 4001],
        live_view: [signing_salt: "your_salt"]

  Or via environment variables:

      PORT=4001 mix bindocsis.server
  """

  use Phoenix.Endpoint, otp_app: :bindocsis

  # Live reloading is disabled in standalone mode by default
  # Enable in dev config if needed

  @session_options [
    store: :cookie,
    key: "_bindocsis_key",
    signing_salt: "bindocsis_salt",
    same_site: "Lax"
  ]

  socket("/live", Phoenix.LiveView.Socket,
    websocket: [connect_info: [:peer_data, :x_headers, session: @session_options]]
  )

  # Serve static assets from priv/static
  plug(Plug.Static,
    at: "/",
    from: :bindocsis,
    gzip: false,
    only: BindocsisWeb.static_paths()
  )

  # Code reloading can be explicitly enabled
  if code_reloading? do
    socket("/phoenix/live_reload/socket", Phoenix.LiveReloader.Socket)
    plug(Phoenix.LiveReloader)
    plug(Phoenix.CodeReloader)
  end

  plug(Plug.RequestId)
  plug(Plug.Telemetry, event_prefix: [:phoenix, :endpoint])

  plug(Plug.Parsers,
    parsers: [:urlencoded, :multipart, :json],
    pass: ["*/*"],
    json_decoder: Phoenix.json_library()
  )

  plug(Plug.MethodOverride)
  plug(Plug.Head)
  plug(Plug.Session, @session_options)

  plug(BindocsisWeb.StandaloneRouter)

  @doc """
  Returns the static asset paths for Plug.Static configuration.
  """
  def static_paths, do: ~w(assets fonts images favicon.ico robots.txt)
end
