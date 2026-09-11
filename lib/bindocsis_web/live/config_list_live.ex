defmodule BindocsisWeb.ConfigListLive do
  @moduledoc """
  Config List LiveView - displays all uploaded config files.

  Features:
  - List all configs with sorting
  - Upload new configs
  - Delete configs
  - Quick actions (view, edit, download)
  """

  use Phoenix.LiveView

  import BindocsisWeb.Components
  alias Phoenix.LiveView.JS
  alias BindocsisWeb.ConfigStore
  alias BindocsisWeb.Uploads

  @impl true
  def mount(_params, _session, socket) do
    # Ensure ConfigStore is running
    BindocsisWeb.Supervisor.ensure_started()

    socket =
      socket
      |> assign(:page_title, "Configs")
      |> assign(:base_path, get_base_path(socket))
      |> assign(:configs, ConfigStore.list_all())
      |> assign(:sort_by, :updated_at)
      |> assign(:sort_order, :desc)
      |> assign(:search, "")
      |> assign(:delete_confirm, nil)
      |> allow_upload(:config,
        accept: Uploads.accepted_extensions(),
        max_entries: 10,
        max_file_size: Uploads.max_file_size()
      )

    {:ok, socket}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div>
      <div class="flex items-center justify-between mb-6">
        <div>
          <h1 class="text-2xl font-bold text-gray-100">Config Files</h1>
          <p class="text-gray-400 mt-1"><%= length(@configs) %> files</p>
        </div>
        <div class="flex items-center space-x-3">
          <.link navigate={"#{@base_path}/configs/new"}>
            <.button>
              <.icon name="hero-plus" class="h-4 w-4 mr-2" />
              New Config
            </.button>
          </.link>
        </div>
      </div>

      <div class="grid grid-cols-1 lg:grid-cols-3 gap-6">
        <div class="lg:col-span-2">
          <.card>
            <:header>
              <div class="flex items-center justify-between">
                <span>All Configs</span>
                <div class="flex items-center space-x-2">
                  <.input
                    type="search"
                    name="search"
                    value={@search}
                    placeholder="Search..."
                    phx-change="search"
                    phx-debounce="300"
                    class="!w-48 !py-1.5 !text-sm"
                  />
                </div>
              </div>
            </:header>

            <div :if={filtered_configs(@configs, @search) == []} class="text-center py-12">
              <.icon name="hero-folder-open" class="h-12 w-12 text-gray-600 mx-auto mb-3" />
              <p class="text-gray-500">
                <%= if @search != "", do: "No configs match your search", else: "No configs uploaded yet" %>
              </p>
            </div>

            <div :if={filtered_configs(@configs, @search) != []} class="divide-y divide-gray-700 -mx-6 -mb-6">
              <div
                :for={config <- filtered_configs(@configs, @search)}
                class="px-6 py-4 hover:bg-gray-700/50 transition-colors"
              >
                <div class="flex items-center justify-between">
                  <.link navigate={"#{@base_path}/configs/#{config.id}"} class="flex-1 min-w-0 group">
                    <div class="flex items-center space-x-3">
                      <.icon name="hero-document-text" class="h-8 w-8 text-gray-500 flex-shrink-0 group-hover:text-blue-400" />
                      <div class="min-w-0">
                        <p class="text-sm font-medium text-gray-200 truncate group-hover:text-blue-400">
                          <%= config.name %>
                        </p>
                        <p class="text-xs text-gray-500">
                          <%= format_bytes(byte_size(config.raw_bytes)) %> •
                          <%= length(config.parsed) %> TLVs •
                          Updated <%= relative_time(config.updated_at) %>
                        </p>
                      </div>
                    </div>
                  </.link>

                  <div class="flex items-center space-x-2 ml-4">
                    <.badge :if={config.modified} variant="warning">Modified</.badge>

                    <.link navigate={"#{@base_path}/configs/#{config.id}"} title="View">
                      <.button variant="ghost" size="sm">
                        <.icon name="hero-eye" class="h-4 w-4" />
                      </.button>
                    </.link>

                    <.link navigate={"#{@base_path}/configs/#{config.id}/edit"} title="Edit">
                      <.button variant="ghost" size="sm">
                        <.icon name="hero-pencil" class="h-4 w-4" />
                      </.button>
                    </.link>

                    <.button
                      variant="ghost"
                      size="sm"
                      phx-click="download"
                      phx-value-id={config.id}
                      phx-value-format="binary"
                      title="Download"
                    >
                      <.icon name="hero-arrow-down-tray" class="h-4 w-4" />
                    </.button>

                    <.button
                      variant="ghost"
                      size="sm"
                      phx-click="confirm-delete"
                      phx-value-id={config.id}
                      title="Delete"
                      class="!text-red-400 hover:!text-red-300"
                    >
                      <.icon name="hero-trash" class="h-4 w-4" />
                    </.button>
                  </div>
                </div>
              </div>
            </div>
          </.card>
        </div>

        <div>
          <.card>
            <:header>Quick Upload</:header>
            <form id="upload-form" phx-submit="upload" phx-change="validate">
              <.upload_zone upload={@uploads.config} />

              <div :if={@uploads.config.entries != []} class="mt-4 space-y-2">
                <div
                  :for={entry <- @uploads.config.entries}
                  class="flex items-center justify-between p-2 bg-gray-700 rounded text-sm"
                >
                  <span class="text-gray-200 truncate flex-1"><%= entry.client_name %></span>
                  <span
                    :for={err <- upload_errors(@uploads.config, entry)}
                    class="text-xs text-red-400 ml-2"
                  >
                    <%= upload_error_message(err) %>
                  </span>
                  <button
                    type="button"
                    phx-click="cancel-upload"
                    phx-value-ref={entry.ref}
                    class="text-gray-400 hover:text-red-400 ml-2"
                  >
                    <.icon name="hero-x-mark" class="h-4 w-4" />
                  </button>
                </div>
              </div>

              <div :for={err <- upload_errors(@uploads.config)} class="mt-2 text-sm text-red-400">
                <%= upload_error_message(err) %>
              </div>

              <div :if={@uploads.config.entries != []} class="mt-4">
                <.button type="submit" class="w-full">
                  Upload <%= length(@uploads.config.entries) %> file(s)
                </.button>
              </div>
            </form>
          </.card>

          <.card class="mt-6">
            <:header>Actions</:header>
            <div class="space-y-2">
              <.link navigate={"#{@base_path}/configs/new"} class="block">
                <.button variant="secondary" class="w-full justify-start">
                  <.icon name="hero-plus" class="h-4 w-4 mr-2" />
                  Create New Config
                </.button>
              </.link>
              <.link navigate={"#{@base_path}/tlvs"} class="block">
                <.button variant="secondary" class="w-full justify-start">
                  <.icon name="hero-book-open" class="h-4 w-4 mr-2" />
                  Browse TLV Specs
                </.button>
              </.link>
            </div>
          </.card>
        </div>
      </div>

      <.modal
        :if={@delete_confirm}
        id="delete-modal"
        show={true}
        on_cancel={JS.push("cancel-delete")}
      >
        <:title>Delete Config</:title>
        <p class="text-gray-300">
          Are you sure you want to delete <strong class="text-gray-100"><%= @delete_confirm.name %></strong>?
        </p>
        <p class="text-sm text-gray-500 mt-2">This action cannot be undone.</p>
        <:footer>
          <.button variant="ghost" phx-click="cancel-delete">Cancel</.button>
          <.button variant="danger" phx-click="delete" phx-value-id={@delete_confirm.id}>
            Delete
          </.button>
        </:footer>
      </.modal>
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
  def handle_event("search", %{"search" => search}, socket) do
    {:noreply, assign(socket, :search, search)}
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

    socket =
      socket
      |> assign(:configs, ConfigStore.list_all())
      |> then(fn s ->
        if oks == [], do: s, else: put_flash(s, :info, "Uploaded #{length(oks)} file(s)")
      end)
      |> then(fn s ->
        if errors == [] do
          s
        else
          put_flash(s, :error, errors |> Enum.map(fn {:error, m} -> m end) |> Enum.join("; "))
        end
      end)

    {:noreply, socket}
  end

  @impl true
  def handle_event("cancel-upload", %{"ref" => ref}, socket) do
    {:noreply, cancel_upload(socket, :config, ref)}
  end

  defp upload_error_message(:too_many_files), do: "Too many files (max 10)"
  defp upload_error_message(err), do: String.capitalize(Uploads.error_message(err))

  defp owner_id(socket) do
    case socket.assigns[:current_scope] do
      %{user: %{id: id}} -> id
      _ -> nil
    end
  end

  @impl true
  def handle_event("confirm-delete", %{"id" => id}, socket) do
    case ConfigStore.get(id) do
      {:ok, config} ->
        {:noreply, assign(socket, :delete_confirm, config)}

      _ ->
        {:noreply, socket}
    end
  end

  @impl true
  def handle_event("cancel-delete", _params, socket) do
    {:noreply, assign(socket, :delete_confirm, nil)}
  end

  @impl true
  def handle_event("delete", %{"id" => id}, socket) do
    ConfigStore.delete(id)

    socket =
      socket
      |> assign(:configs, ConfigStore.list_all())
      |> assign(:delete_confirm, nil)
      |> put_flash(:info, "Config deleted")

    {:noreply, socket}
  end

  @impl true
  def handle_event("download", %{"id" => id, "format" => format}, socket) do
    case ConfigStore.get(id) do
      {:ok, config} ->
        {content, filename, _content_type} = prepare_download(config, format)

        socket =
          socket
          |> push_event("download", %{
            content: Base.encode64(content),
            filename: filename,
            binary: true
          })

        {:noreply, socket}

      _ ->
        {:noreply, put_flash(socket, :error, "Config not found")}
    end
  end

  # ============================================================================
  # Helpers
  # ============================================================================

  defp get_base_path(socket) do
    case socket.assigns[:bindocsis_base_path] do
      "" -> ""
      nil -> ""
      base -> base
    end
  end

  defp filtered_configs(configs, ""), do: configs

  defp filtered_configs(configs, search) do
    search_lower = String.downcase(search)

    Enum.filter(configs, fn config ->
      String.contains?(String.downcase(config.name), search_lower)
    end)
  end

  defp prepare_download(config, "binary") do
    {config.raw_bytes, config.name, "application/octet-stream"}
  end

  defp prepare_download(config, "json") do
    json = Jason.encode!(config.enriched, pretty: true)
    filename = String.replace(config.name, ~r/\.(cm|bin)$/, ".json")
    {json, filename, "application/json"}
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
end
