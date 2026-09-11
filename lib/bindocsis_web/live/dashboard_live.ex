defmodule BindocsisWeb.DashboardLive do
  @moduledoc """
  Dashboard LiveView - landing page for the Bindocsis web interface.

  Features:
  - Quick file upload dropzone
  - Recent configs list
  - Quick stats
  - Navigation to other sections
  """

  use Phoenix.LiveView

  import BindocsisWeb.Components
  alias BindocsisWeb.ConfigStore
  alias BindocsisWeb.Uploads

  @impl true
  def mount(_params, _session, socket) do
    # Ensure ConfigStore is running
    BindocsisWeb.Supervisor.ensure_started()

    socket =
      socket
      |> assign(:page_title, "Dashboard")
      |> assign(:base_path, get_base_path(socket))
      |> assign(:recent_configs, ConfigStore.list_all() |> Enum.take(5))
      |> assign(:config_count, ConfigStore.count())
      |> allow_upload(:config,
        accept: Uploads.accepted_extensions(),
        max_entries: 5,
        max_file_size: Uploads.max_file_size()
      )

    {:ok, socket}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div>
      <div class="mb-8">
        <h1 class="text-2xl font-bold text-gray-100">DOCSIS Config Manager</h1>
        <p class="text-gray-400 mt-1">Upload, view, and edit DOCSIS configuration files</p>
      </div>

      <div class="grid grid-cols-1 lg:grid-cols-3 gap-6 mb-8">
        <.stat_card
          title="Configs Loaded"
          value={@config_count}
          icon="hero-document-text"
          color="blue"
        />
        <.stat_card
          title="TLV Types"
          value={tlv_spec_count()}
          icon="hero-cube"
          color="green"
        />
        <.stat_card
          title="Library Version"
          value={"v#{Application.spec(:bindocsis, :vsn)}"}
          icon="hero-code-bracket"
          color="purple"
        />
      </div>

      <div class="grid grid-cols-1 lg:grid-cols-2 gap-6">
        <.card>
          <:header>Upload Config File</:header>
          <form id="upload-form" phx-submit="upload" phx-change="validate">
            <.upload_zone upload={@uploads.config} />

            <div :if={@uploads.config.entries != []} class="mt-4 space-y-2">
              <div
                :for={entry <- @uploads.config.entries}
                class="flex items-center justify-between p-3 bg-gray-700 rounded-lg"
              >
                <div class="flex items-center space-x-3">
                  <.icon name="hero-document" class="h-5 w-5 text-gray-400" />
                  <span class="text-sm text-gray-200"><%= entry.client_name %></span>
                  <span class="text-xs text-gray-500"><%= format_bytes(entry.client_size) %></span>
                  <span
                    :for={err <- upload_errors(@uploads.config, entry)}
                    class="text-xs text-red-400"
                  >
                    <%= upload_error_message(err) %>
                  </span>
                </div>
                <div class="flex items-center space-x-3">
                  <div class="w-24 bg-gray-600 rounded-full h-2">
                    <div class="bg-blue-500 h-2 rounded-full" style={"width: #{entry.progress}%"} />
                  </div>
                  <button
                    type="button"
                    phx-click="cancel-upload"
                    phx-value-ref={entry.ref}
                    class="text-gray-400 hover:text-red-400"
                  >
                    <.icon name="hero-x-mark" class="h-4 w-4" />
                  </button>
                </div>
              </div>

              <div :for={err <- upload_errors(@uploads.config)} class="text-sm text-red-400">
                <%= upload_error_message(err) %>
              </div>
            </div>

            <div :if={@uploads.config.entries != []} class="mt-4">
              <.button type="submit" class="w-full">
                <.icon name="hero-arrow-up-tray" class="h-4 w-4 mr-2" />
                Upload <%= length(@uploads.config.entries) %> file(s)
              </.button>
            </div>
          </form>
        </.card>

        <.card>
          <:header>
            <div class="flex items-center justify-between">
              <span>Recent Configs</span>
              <.link
                :if={@config_count > 0}
                navigate={"#{@base_path}/configs"}
                class="text-sm text-blue-400 hover:text-blue-300"
              >
                View all →
              </.link>
            </div>
          </:header>
          <div :if={@recent_configs == []} class="text-center py-8">
            <.icon name="hero-inbox" class="h-12 w-12 text-gray-600 mx-auto mb-3" />
            <p class="text-gray-500">No configs uploaded yet</p>
            <p class="text-sm text-gray-600">Upload a .cm file to get started</p>
          </div>
          <ul :if={@recent_configs != []} class="divide-y divide-gray-700">
            <li :for={config <- @recent_configs} class="py-3 first:pt-0 last:pb-0">
              <.link
                navigate={"#{@base_path}/configs/#{config.id}"}
                class="flex items-center justify-between group"
              >
                <div class="flex items-center space-x-3">
                  <.icon name="hero-document-text" class="h-5 w-5 text-gray-500 group-hover:text-blue-400" />
                  <div>
                    <p class="text-sm font-medium text-gray-200 group-hover:text-blue-400">
                      <%= config.name %>
                    </p>
                    <p class="text-xs text-gray-500">
                      <%= format_bytes(byte_size(config.raw_bytes)) %> •
                      <%= length(config.parsed) %> TLVs •
                      <%= relative_time(config.updated_at) %>
                    </p>
                  </div>
                </div>
                <.badge :if={config.modified} variant="warning">Modified</.badge>
              </.link>
            </li>
          </ul>
        </.card>
      </div>

      <div class="mt-8 grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-4">
        <.quick_link
          href={"#{@base_path}/configs"}
          icon="hero-folder-open"
          title="All Configs"
          description="View and manage all uploaded config files"
        />
        <.quick_link
          href={"#{@base_path}/configs/new"}
          icon="hero-plus-circle"
          title="New Config"
          description="Create a new config from scratch"
        />
        <.quick_link
          href={"#{@base_path}/tlvs"}
          icon="hero-book-open"
          title="TLV Browser"
          description="Browse and search TLV specifications"
        />
      </div>
    </div>
    """
  end

  # ============================================================================
  # Event Handlers
  # ============================================================================

  @impl true
  def handle_event("validate", _params, socket) do
    {:noreply, socket}
  end

  @impl true
  def handle_event("upload", _params, socket) do
    owner = owner_id(socket)

    results =
      case Uploads.check_rate(owner) do
        :ok ->
          consume_uploaded_entries(socket, :config, fn %{path: path}, entry ->
            {:ok, Uploads.store_entry(path, entry, owner: owner)}
          end)

        {:error, msg} ->
          [{:error, msg}]
      end

    {oks, errors} = Enum.split_with(results, &match?({:ok, _}, &1))
    uploaded_ids = Enum.map(oks, fn {:ok, id} -> id end)
    error_text = errors |> Enum.map(fn {:error, msg} -> msg end) |> Enum.join("; ")

    socket =
      case uploaded_ids do
        [id] when errors == [] ->
          # Single file - navigate directly to it
          push_navigate(socket, to: "#{socket.assigns.base_path}/configs/#{id}")

        [_ | _] = ids ->
          socket
          |> put_flash(:info, "Uploaded #{length(ids)} config file(s)")
          |> then(fn s -> if errors == [], do: s, else: put_flash(s, :error, error_text) end)
          |> push_navigate(to: "#{socket.assigns.base_path}/configs")

        [] ->
          put_flash(socket, :error, "Failed to upload files: #{error_text}")
      end

    {:noreply, socket}
  end

  @impl true
  def handle_event("cancel-upload", %{"ref" => ref}, socket) do
    {:noreply, cancel_upload(socket, :config, ref)}
  end

  # ============================================================================
  # Components
  # ============================================================================

  defp stat_card(assigns) do
    bg_color =
      case assigns.color do
        "blue" -> "bg-blue-900/30 border-blue-800"
        "green" -> "bg-green-900/30 border-green-800"
        "purple" -> "bg-purple-900/30 border-purple-800"
        _ -> "bg-gray-800 border-gray-700"
      end

    icon_color =
      case assigns.color do
        "blue" -> "text-blue-400"
        "green" -> "text-green-400"
        "purple" -> "text-purple-400"
        _ -> "text-gray-400"
      end

    assigns = assign(assigns, bg_color: bg_color, icon_color: icon_color)

    ~H"""
    <div class={"rounded-lg border p-6 #{@bg_color}"}>
      <div class="flex items-center justify-between">
        <div>
          <p class="text-sm font-medium text-gray-400"><%= @title %></p>
          <p class="text-2xl font-bold text-gray-100 mt-1"><%= @value %></p>
        </div>
        <.icon name={@icon} class={"h-10 w-10 #{@icon_color}"} />
      </div>
    </div>
    """
  end

  defp quick_link(assigns) do
    ~H"""
    <.link
      navigate={@href}
      class="block p-4 bg-gray-800 border border-gray-700 rounded-lg hover:bg-gray-700 hover:border-gray-600 transition-all group"
    >
      <div class="flex items-center space-x-4">
        <div class="p-2 bg-gray-700 rounded-lg group-hover:bg-gray-600">
          <.icon name={@icon} class="h-6 w-6 text-blue-400" />
        </div>
        <div>
          <h3 class="font-medium text-gray-100 group-hover:text-blue-400"><%= @title %></h3>
          <p class="text-sm text-gray-500"><%= @description %></p>
        </div>
      </div>
    </.link>
    """
  end

  # ============================================================================
  # Helpers
  # ============================================================================

  defp get_base_path(socket) do
    # In standalone mode, bindocsis_base_path is "" (empty), so we default to "/"
    case socket.assigns[:bindocsis_base_path] do
      "" -> ""
      nil -> ""
      base -> base
    end
  end

  defp tlv_spec_count do
    # Return approximate count of supported TLV types
    # DOCSIS 3.1 supports roughly 85 base TLVs + vendor extensions
    85
  end

  defp format_bytes(bytes) when bytes < 1024, do: "#{bytes} B"
  defp format_bytes(bytes) when bytes < 1_048_576, do: "#{Float.round(bytes / 1024, 1)} KB"
  defp format_bytes(bytes), do: "#{Float.round(bytes / 1_048_576, 1)} MB"

  defp relative_time(datetime) do
    diff = DateTime.diff(DateTime.utc_now(), datetime, :second)

    cond do
      diff < 60 -> "just now"
      diff < 3600 -> "#{div(diff, 60)}m ago"
      diff < 86400 -> "#{div(diff, 3600)}h ago"
      true -> "#{div(diff, 86400)}d ago"
    end
  end

  defp upload_error_message(:too_many_files), do: "Too many files (max 5)"
  defp upload_error_message(err), do: String.capitalize(Uploads.error_message(err))

  defp owner_id(socket) do
    case socket.assigns[:current_scope] do
      %{user: %{id: id}} -> id
      _ -> nil
    end
  end
end
