defmodule BindocsisWeb.Router do
  use BindocsisWeb, :router

  import BindocsisWeb.UserAuth

  pipeline :browser do
    plug(:accepts, ["html"])
    plug(:fetch_session)
    plug(:fetch_live_flash)
    plug(:put_root_layout, html: {BindocsisWeb.Layouts, :root})
    plug(:protect_from_forgery)
    plug(:put_secure_browser_headers)
    plug(:fetch_current_scope_for_user)
  end

  pipeline :auth_required do
    plug(:require_authenticated_user)
  end

  @moduledoc """
  Router helpers for embedding Bindocsis LiveView UI in your Phoenix application.

  ## Usage

  In your router.ex:

      import BindocsisWeb.Router

      scope "/" do
        pipe_through :browser
        bindocsis_live "/docsis"
      end

  ## Options

  All standard Phoenix LiveView options are supported, including:

  - `:on_mount` - List of on_mount hooks for authentication
  - `:layout` - Custom layout tuple `{Module, :template}`

  ## Example with Authentication

      scope "/" do
        pipe_through [:browser, :require_authenticated_user]
        bindocsis_live "/docsis", on_mount: [{MyAppWeb.Auth, :ensure_admin}]
      end

  ## Tailwind Configuration

  Add to your `tailwind.config.js` content array:

      content: [
        // ... your existing paths
        "../deps/bindocsis/**/*.*ex",
      ]

  This ensures Tailwind includes the classes used by Bindocsis components.
  """

  @doc """
  Generates routes for the Bindocsis web interface.

  ## Routes Generated

  | Path | LiveView | Action | Description |
  |------|----------|--------|-------------|
  | `/` | DashboardLive | :index | Landing page with upload |
  | `/configs` | ConfigListLive | :index | List all configs |
  | `/configs/new` | ConfigEditorLive | :new | Create new config |
  | `/configs/:id` | ConfigViewerLive | :show | View config (read-only) |
  | `/configs/:id/edit` | ConfigEditorLive | :edit | Edit config |
  | `/tlvs` | TLVBrowserLive | :index | Browse TLV specs |
  | `/tlvs/:tlv` | TLVBrowserLive | :show | View TLV details |

  ## Examples

      # Basic usage
      bindocsis_live "/docsis"

      # With custom layout
      bindocsis_live "/docsis", layout: {MyAppWeb.Layouts, :admin}

      # With authentication hook
      bindocsis_live "/docsis", on_mount: [{MyApp.Auth, :require_admin}]
  """
  defmacro bindocsis_live(path, opts \\ []) do
    quote bind_quoted: [path: path, opts: opts] do
      import Phoenix.LiveView.Router, only: [live: 3, live: 4]

      scope path, alias: false, as: :bindocsis do
        live("/", BindocsisWeb.DashboardLive, :index, opts)
        live("/configs", BindocsisWeb.ConfigListLive, :index, opts)
        live("/configs/new", BindocsisWeb.ConfigEditorLive, :new, opts)
        live("/configs/:id", BindocsisWeb.ConfigViewerLive, :show, opts)
        live("/configs/:id/edit", BindocsisWeb.ConfigEditorLive, :edit, opts)
        live("/tlvs", BindocsisWeb.TLVBrowserLive, :index, opts)
        live("/tlvs/:tlv", BindocsisWeb.TLVBrowserLive, :show, opts)
      end
    end
  end

  @doc """
  Returns the base path for Bindocsis routes.

  Useful for building links within your application:

      <.link navigate={BindocsisWeb.Router.docsis_path(@socket, "/configs")}>
        View Configs
      </.link>
  """
  def docsis_path(socket_or_conn, path \\ "/") do
    # This will be set by the host application's router
    base =
      case socket_or_conn do
        %Phoenix.LiveView.Socket{} = socket ->
          socket.assigns[:bindocsis_base_path] || "/docsis"

        %Plug.Conn{} = conn ->
          conn.assigns[:bindocsis_base_path] || "/docsis"

        _ ->
          "/docsis"
      end

    Path.join(base, path)
  end

  ## Authentication routes

  scope "/", BindocsisWeb do
    pipe_through([:browser, :auth_required])

    live_session :require_authenticated_user,
      on_mount: [{BindocsisWeb.UserAuth, :require_authenticated}] do
      live("/users/settings", UserLive.Settings, :edit)
      live("/users/settings/confirm-email/:token", UserLive.Settings, :confirm_email)
    end

    post("/users/update-password", UserSessionController, :update_password)
  end

  scope "/", BindocsisWeb do
    pipe_through([:browser])

    live_session :current_user,
      on_mount: [{BindocsisWeb.UserAuth, :mount_current_scope}] do
      live("/users/register", UserLive.Registration, :new)
      live("/users/log-in", UserLive.Login, :new)
      live("/users/log-in/:token", UserLive.Confirmation, :new)
    end

    post("/users/log-in", UserSessionController, :create)
    delete("/users/log-out", UserSessionController, :delete)
  end

  # Main application routes (require authentication)
  scope "/", alias: false do
    pipe_through([:browser, :auth_required])

    live_session :main,
      on_mount: [{BindocsisWeb.UserAuth, :require_authenticated}],
      root_layout: {BindocsisWeb.Layouts, :root} do
      live("/", BindocsisWeb.DashboardLive, :index)
      live("/configs", BindocsisWeb.ConfigListLive, :index)
      live("/configs/new", BindocsisWeb.ConfigEditorLive, :new)
      live("/configs/:id", BindocsisWeb.ConfigViewerLive, :show)
      live("/configs/:id/edit", BindocsisWeb.ConfigEditorLive, :edit)
      live("/tlvs", BindocsisWeb.TLVBrowserLive, :index)
      live("/tlvs/:tlv", BindocsisWeb.TLVBrowserLive, :show)
    end
  end
end
