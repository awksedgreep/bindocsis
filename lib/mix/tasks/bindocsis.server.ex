defmodule Mix.Tasks.Bindocsis.Server do
  @moduledoc """
  Starts the Bindocsis web interface as a standalone server.

  ## Usage

      mix bindocsis.server [options]

  ## Options

    * `--port` - Port to listen on (default: 4001, or PORT env var)
    * `--host` - Host to bind to (default: 127.0.0.1)
    * `--open` - Open browser automatically (default: false)

  ## Examples

      # Start on default port 4001
      mix bindocsis.server

      # Start on custom port
      mix bindocsis.server --port 8080

      # Start and open browser
      mix bindocsis.server --open

      # Bind to all interfaces
      mix bindocsis.server --host 0.0.0.0

  ## Environment Variables

    * `PORT` - Override default port
    * `HOST` - Override default host

  """

  use Mix.Task

  @shortdoc "Start the Bindocsis web interface"

  @requirements ["app.start"]

  @impl Mix.Task
  def run(args) do
    {opts, _, _} =
      OptionParser.parse(args,
        switches: [port: :integer, host: :string, open: :boolean],
        aliases: [p: :port, h: :host, o: :open]
      )

    # Get port from options, env var, or default
    port =
      opts[:port] ||
        (System.get_env("PORT") && String.to_integer(System.get_env("PORT"))) ||
        4001

    host = opts[:host] || System.get_env("HOST") || "127.0.0.1"
    open_browser = opts[:open] || false

    # Check for required dependencies
    unless Code.ensure_loaded?(Phoenix.LiveView) do
      Mix.raise("""
      Phoenix LiveView is required to run the Bindocsis web interface.

      Add the following to your mix.exs deps:

          {:phoenix_live_view, "~> 1.0"}
          {:phoenix_html, "~> 4.0"}

      Then run: mix deps.get
      """)
    end

    # Configure the endpoint
    Application.put_env(:bindocsis, BindocsisWeb.Endpoint,
      adapter: Bandit.PhoenixAdapter,
      http: [ip: parse_ip(host), port: port],
      server: true,
      live_view: [signing_salt: generate_salt()],
      secret_key_base: generate_secret(),
      render_errors: [formats: [html: BindocsisWeb.ErrorHTML], layout: false],
      pubsub_server: Bindocsis.PubSub,
      check_origin: false
    )

    # Start the endpoint and dependencies
    children = [
      {Phoenix.PubSub, name: Bindocsis.PubSub},
      BindocsisWeb.Supervisor,
      BindocsisWeb.Endpoint
    ]

    opts = [strategy: :one_for_one, name: Bindocsis.ServerSupervisor]

    Mix.shell().info("""

    ╔════════════════════════════════════════════════════════════════╗
    ║                                                                ║
    ║   🔧  Bindocsis Web Interface                                  ║
    ║                                                                ║
    ║   Running at: http://#{host}:#{port}                           #{String.duplicate(" ", max(0, 26 - String.length(host) - String.length(to_string(port))))}║
    ║                                                                ║
    ║   Features:                                                    ║
    ║   • Upload and parse DOCSIS config files                       ║
    ║   • View TLV hierarchy in tree, table, or hex view             ║
    ║   • Edit TLV values with type-aware inputs                     ║
    ║   • Export to binary, JSON, YAML formats                       ║
    ║   • Browse DOCSIS TLV specifications                           ║
    ║                                                                ║
    ║   Press Ctrl+C twice to stop                                   ║
    ║                                                                ║
    ╚════════════════════════════════════════════════════════════════╝

    """)

    {:ok, _} = Supervisor.start_link(children, opts)

    if open_browser do
      open_browser_url("http://#{host}:#{port}")
    end

    # Keep the task running
    Process.sleep(:infinity)
  end

  defp parse_ip(host) do
    case :inet.parse_address(String.to_charlist(host)) do
      {:ok, ip} -> ip
      {:error, _} -> {127, 0, 0, 1}
    end
  end

  defp generate_salt do
    :crypto.strong_rand_bytes(16) |> Base.encode64(padding: false) |> binary_part(0, 16)
  end

  defp generate_secret do
    :crypto.strong_rand_bytes(64) |> Base.encode64(padding: false)
  end

  defp open_browser_url(url) do
    case :os.type() do
      {:unix, :darwin} -> System.cmd("open", [url])
      {:unix, _} -> System.cmd("xdg-open", [url])
      {:win32, _} -> System.cmd("cmd", ["/c", "start", url])
      _ -> :ok
    end
  end
end
