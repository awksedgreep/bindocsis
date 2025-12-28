defmodule BindocsisWeb.StandaloneRouter do
  @moduledoc """
  Router for standalone Bindocsis web server.

  This router is used when running `mix bindocsis.server` to provide
  a complete web interface without requiring an existing Phoenix app.
  """

  use Phoenix.Router
  import Phoenix.LiveView.Router
  import BindocsisWeb.UserAuth

  pipeline :browser do
    plug(:accepts, ["html"])
    plug(:fetch_session)
    plug(:fetch_live_flash)
    plug(:put_root_layout, html: {BindocsisWeb.Layouts, :root})
    plug(:protect_from_forgery)
    plug(:put_secure_browser_headers)
    plug(:fetch_current_scope_for_user)
    plug(:put_base_path)
  end

  pipeline :api do
    plug(:accepts, ["json"])
  end

  pipeline :auth_required do
    plug(:require_authenticated_user)
  end

  # Authentication routes (no auth required)
  scope "/", BindocsisWeb do
    pipe_through(:browser)

    live_session :auth,
      on_mount: [{BindocsisWeb.UserAuth, :mount_current_scope}] do
      live("/users/register", UserLive.Registration, :new)
      live("/users/log-in", UserLive.Login, :new)
      live("/users/log-in/:token", UserLive.Confirmation, :new)
    end

    post("/users/log-in", UserSessionController, :create)
    delete("/users/log-out", UserSessionController, :delete)
  end

  # User settings (auth required)
  scope "/", BindocsisWeb do
    pipe_through([:browser, :auth_required])

    live_session :user_settings,
      on_mount: [{BindocsisWeb.UserAuth, :require_authenticated}] do
      live("/users/settings", UserLive.Settings, :edit)
      live("/users/settings/confirm-email/:token", UserLive.Settings, :confirm_email)
    end

    post("/users/update-password", UserSessionController, :update_password)
  end

  # Main app routes (auth required)
  scope "/", BindocsisWeb do
    pipe_through([:browser, :auth_required])

    live_session :default,
      on_mount: [
        {BindocsisWeb.UserAuth, :require_authenticated},
        {__MODULE__, :assign_navigation_state}
      ],
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
