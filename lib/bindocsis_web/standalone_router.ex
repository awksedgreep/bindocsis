defmodule BindocsisWeb.StandaloneRouter do
  @moduledoc """
  Router for standalone Bindocsis web server.

  This router is used when running `mix bindocsis.server` to provide
  a complete web interface without requiring an existing Phoenix app.
  """

  use Phoenix.Router
  import Phoenix.LiveView.Router

  pipeline :browser do
    plug(:accepts, ["html"])
    plug(:fetch_session)
    plug(:fetch_live_flash)
    plug(:put_root_layout, html: {BindocsisWeb.Layouts, :root})
    plug(:protect_from_forgery)
    plug(:put_secure_browser_headers)
    plug(:put_base_path)
  end

  pipeline :api do
    plug(:accepts, ["json"])
  end

  scope "/", BindocsisWeb do
    pipe_through(:browser)

    live_session :default,
      on_mount: [{__MODULE__, :assign_navigation_state}],
      layout: {BindocsisWeb.Layouts, :app} do
      live("/", DashboardLive, :index)
      live("/configs", ConfigListLive, :index)
      live("/configs/new", ConfigEditorLive, :new)
      live("/configs/:id", ConfigViewerLive, :show)
      live("/configs/:id/edit", ConfigEditorLive, :edit)
      live("/tlvs", TLVBrowserLive, :index)
      live("/tlvs/:tlv", TLVBrowserLive, :show)
    end
  end

  # API endpoints for programmatic access
  scope "/api", BindocsisWeb do
    pipe_through(:api)

    # Future: Add JSON API endpoints
  end

  @doc """
  LiveView on_mount hook that assigns navigation state.

  Sets:
  - `bindocsis_base_path` - The base URL path (empty for standalone)
  - `current_path` - The current URL path for navigation highlighting
  """
  def on_mount(:assign_navigation_state, _params, _session, socket) do
    socket =
      socket
      |> Phoenix.Component.assign(:bindocsis_base_path, "")
      |> Phoenix.Component.assign(:base_path, "")
      |> Phoenix.Component.assign_new(:current_path, fn ->
        case socket.assigns do
          %{__changed__: _} -> nil
          _ -> nil
        end
      end)
      |> attach_navigation_hook()

    {:cont, socket}
  end

  defp attach_navigation_hook(socket) do
    Phoenix.LiveView.attach_hook(socket, :track_path, :handle_params, fn
      _params, uri, socket ->
        path = URI.parse(uri).path || "/"
        {:cont, Phoenix.Component.assign(socket, :current_path, path)}
    end)
  end

  defp put_base_path(conn, _opts) do
    Plug.Conn.assign(conn, :bindocsis_base_path, "")
  end
end
