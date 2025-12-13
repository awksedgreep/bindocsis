defmodule BindocsisWeb.ConfigViewerLive do
  @moduledoc """
  Config Viewer LiveView - displays a parsed DOCSIS config file.

  Features:
  - Tree view of TLV hierarchy
  - Table view with sorting/filtering
  - Hex view with TLV boundaries
  - TLV detail sidebar
  - Export options (JSON, YAML, binary)
  """

  use Phoenix.LiveView

  import BindocsisWeb.Components
  alias Phoenix.LiveView.JS
  alias BindocsisWeb.ConfigStore

  @impl true
  def mount(%{"id" => id}, _session, socket) do
    BindocsisWeb.Supervisor.ensure_started()

    case ConfigStore.get(id) do
      {:ok, config} ->
        socket =
          socket
          |> assign(:page_title, config.name)
          |> assign(:base_path, get_base_path(socket))
          |> assign(:config, config)
          |> assign(:view_mode, :tree)
          |> assign(:selected_tlv, nil)
          |> assign(:expanded, MapSet.new())
          |> assign(:search, "")
          |> assign(:show_hex, false)

        {:ok, socket}

      {:error, :not_found} ->
        socket =
          socket
          |> put_flash(:error, "Config not found")
          |> push_navigate(to: get_base_path(socket) <> "/configs")

        {:ok, socket}
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div>
      <.breadcrumb>
        <:item href={@base_path}>Dashboard</:item>
        <:item href={"#{@base_path}/configs"}>Configs</:item>
        <:item><%= @config.name %></:item>
      </.breadcrumb>

      <div class="flex items-center justify-between mb-6">
        <div>
          <h1 class="text-2xl font-bold text-gray-100"><%= @config.name %></h1>
          <p class="text-gray-400 mt-1">
            <%= format_bytes(byte_size(@config.raw_bytes)) %> •
            <%= length(@config.parsed) %> TLVs
            <span :if={@config.modified} class="text-yellow-400">• Modified</span>
          </p>
        </div>
        <div class="flex items-center space-x-3">
          <.link navigate={"#{@base_path}/configs/#{@config.id}/edit"}>
            <.button>
              <.icon name="hero-pencil" class="h-4 w-4 mr-2" />
              Edit
            </.button>
          </.link>
          <div class="relative" id="export-menu">
            <.button variant="secondary" phx-click={toggle_dropdown("export-dropdown")}>
              <.icon name="hero-arrow-down-tray" class="h-4 w-4 mr-2" />
              Export
              <.icon name="hero-chevron-down" class="h-4 w-4 ml-2" />
            </.button>
            <div
              id="export-dropdown"
              class="hidden absolute right-0 mt-2 w-48 bg-gray-800 border border-gray-700 rounded-lg shadow-xl z-10"
            >
              <button
                phx-click="download"
                phx-value-format="binary"
                class="block w-full text-left px-4 py-2 text-sm text-gray-200 hover:bg-gray-700 rounded-t-lg"
              >
                <.icon name="hero-document" class="h-4 w-4 inline mr-2 text-gray-400" />
                Binary (.cm)
              </button>
              <button
                phx-click="download"
                phx-value-format="json"
                class="block w-full text-left px-4 py-2 text-sm text-gray-200 hover:bg-gray-700"
              >
                <.icon name="hero-code-bracket" class="h-4 w-4 inline mr-2 text-gray-400" />
                JSON
              </button>
              <button
                phx-click="download"
                phx-value-format="yaml"
                class="block w-full text-left px-4 py-2 text-sm text-gray-200 hover:bg-gray-700"
              >
                <.icon name="hero-document-text" class="h-4 w-4 inline mr-2 text-gray-400" />
                YAML
              </button>
              <button
                phx-click="download"
                phx-value-format="config"
                class="block w-full text-left px-4 py-2 text-sm text-gray-200 hover:bg-gray-700"
              >
                <.icon name="hero-cog-6-tooth" class="h-4 w-4 inline mr-2 text-gray-400" />
                Config (.txt)
              </button>
              <hr class="border-gray-700 my-1" />
              <button
                phx-click="download"
                phx-value-format="hex"
                class="block w-full text-left px-4 py-2 text-sm text-gray-200 hover:bg-gray-700 rounded-b-lg"
              >
                <.icon name="hero-command-line" class="h-4 w-4 inline mr-2 text-gray-400" />
                Hex Dump
              </button>
            </div>
          </div>
        </div>
      </div>

      <div class="flex items-center space-x-4 mb-6">
        <div class="flex rounded-lg bg-gray-800 p-1">
          <button
            phx-click="set-view"
            phx-value-mode="tree"
            class={[
              "px-3 py-1.5 text-sm font-medium rounded-md transition-colors",
              @view_mode == :tree && "bg-gray-700 text-gray-100",
              @view_mode != :tree && "text-gray-400 hover:text-gray-200"
            ]}
          >
            <.icon name="hero-queue-list" class="h-4 w-4 inline mr-1" />
            Tree
          </button>
          <button
            phx-click="set-view"
            phx-value-mode="table"
            class={[
              "px-3 py-1.5 text-sm font-medium rounded-md transition-colors",
              @view_mode == :table && "bg-gray-700 text-gray-100",
              @view_mode != :table && "text-gray-400 hover:text-gray-200"
            ]}
          >
            <.icon name="hero-table-cells" class="h-4 w-4 inline mr-1" />
            Table
          </button>
          <button
            phx-click="set-view"
            phx-value-mode="hex"
            class={[
              "px-3 py-1.5 text-sm font-medium rounded-md transition-colors",
              @view_mode == :hex && "bg-gray-700 text-gray-100",
              @view_mode != :hex && "text-gray-400 hover:text-gray-200"
            ]}
          >
            <.icon name="hero-code-bracket" class="h-4 w-4 inline mr-1" />
            Hex
          </button>
        </div>

        <.input
          type="search"
          name="search"
          value={@search}
          placeholder="Search TLVs..."
          phx-change="search"
          phx-debounce="300"
          class="!w-64"
        />
      </div>

      <div class="grid grid-cols-1 lg:grid-cols-3 gap-6">
        <div class={[@selected_tlv && "lg:col-span-2", !@selected_tlv && "lg:col-span-3"]}>
          <.card>
            <:header>
              <div class="flex items-center justify-between">
                <span>Configuration</span>
                <span class="text-sm text-gray-500">
                  <%= length(filter_tlvs(@config.parsed, @search)) %> TLVs
                </span>
              </div>
            </:header>

            <%= case @view_mode do %>
              <% :tree -> %>
                <.tree_view
                  tlvs={filter_tlvs(@config.parsed, @search)}
                  expanded={@expanded}
                  selected={@selected_tlv}
                />
              <% :table -> %>
                <.table_view
                  tlvs={flatten_tlvs(filter_tlvs(@config.parsed, @search))}
                  selected={@selected_tlv}
                />
              <% :hex -> %>
                <.hex_view bytes={@config.raw_bytes} />
            <% end %>
          </.card>
        </div>

        <div :if={@selected_tlv} class="lg:col-span-1">
          <.tlv_detail_panel tlv={@selected_tlv} base_path={@base_path} config_id={@config.id} />
        </div>
      </div>
    </div>
    """
  end

  # ============================================================================
  # Tree View Component
  # ============================================================================

  defp tree_view(assigns) do
    ~H"""
    <div class="space-y-1 -mx-6 -my-6">
      <%= if @tlvs == [] do %>
        <div class="text-center py-12 text-gray-500">
          No TLVs found
        </div>
      <% else %>
        <div class="divide-y divide-gray-700">
          <.tlv_tree_node
            :for={{tlv, idx} <- Enum.with_index(@tlvs)}
            tlv={tlv}
            path={[idx]}
            expanded={@expanded}
            selected={@selected}
            depth={0}
          />
        </div>
      <% end %>
    </div>
    """
  end

  defp tlv_tree_node(assigns) do
    has_children = has_sub_tlvs?(assigns.tlv)
    path_key = Enum.join(assigns.path, ".")
    is_expanded = MapSet.member?(assigns.expanded, path_key)
    is_selected = assigns.selected && assigns.selected[:_path] == path_key

    assigns =
      assigns
      |> assign(:has_children, has_children)
      |> assign(:path_key, path_key)
      |> assign(:is_expanded, is_expanded)
      |> assign(:is_selected, is_selected)

    ~H"""
    <div>
      <div
        class={[
          "flex items-center px-6 py-2 hover:bg-gray-700/50 cursor-pointer transition-colors",
          @is_selected && "bg-blue-900/30 border-l-2 border-blue-500"
        ]}
        style={"padding-left: #{@depth * 20 + 24}px"}
        phx-click="select-tlv"
        phx-value-path={@path_key}
      >
        <button
          :if={@has_children}
          phx-click="toggle-expand"
          phx-value-path={@path_key}
          class="mr-2 p-0.5 hover:bg-gray-600 rounded"
        >
          <.icon
            name={if @is_expanded, do: "hero-chevron-down", else: "hero-chevron-right"}
            class="h-4 w-4 text-gray-400"
          />
        </button>
        <span :if={!@has_children} class="w-5 mr-2"></span>

        <.tlv_type_badge type={get_tlv_type(@tlv)} name={get_tlv_name(@tlv)} />

        <%= if is_snmp_object_value?(@tlv) do %>
          <div class="ml-4 flex-1"></div>
        <% else %>
          <span class="ml-auto text-sm text-gray-400 font-mono">
            <%= format_tlv_value(@tlv) %>
          </span>
        <% end %>
      </div>

      <!-- SNMP Object Value expanded display -->
      <div :if={is_snmp_object_value?(@tlv)} class="ml-12 mr-6 mb-2 mt-1">
        <.snmp_value_card value={get_snmp_formatted_value(@tlv)} />
      </div>

      <div :if={@has_children && @is_expanded}>
        <.tlv_tree_node
          :for={{sub_tlv, idx} <- Enum.with_index(get_sub_tlvs(@tlv))}
          tlv={sub_tlv}
          path={@path ++ [idx]}
          expanded={@expanded}
          selected={@selected}
          depth={@depth + 1}
        />
      </div>
    </div>
    """
  end

  # ============================================================================
  # SNMP Value Card Component
  # ============================================================================

  defp snmp_value_card(assigns) do
    value = assigns.value
    oid = Map.get(value, :oid) || Map.get(value, "oid") || ""
    oid_name = Map.get(value, :oid_name) || Map.get(value, "oid_name")
    snmp_type = Map.get(value, :type) || Map.get(value, "type") || ""
    snmp_value = Map.get(value, :value) || Map.get(value, "value") || ""

    assigns =
      assigns
      |> assign(:oid, oid)
      |> assign(:oid_name, oid_name)
      |> assign(:snmp_type, snmp_type)
      |> assign(:snmp_value, snmp_value)

    ~H"""
    <div class="bg-gray-800 rounded-lg border border-gray-700 p-3 text-sm">
      <div class="grid grid-cols-[auto_1fr] gap-x-3 gap-y-1">
        <span class="text-gray-500">OID:</span>
        <span class="font-mono text-blue-400"><%= @oid %></span>

        <span :if={@oid_name} class="text-gray-500">Name:</span>
        <span :if={@oid_name} class="text-cyan-400"><%= @oid_name %></span>

        <span class="text-gray-500">Type:</span>
        <span class="text-gray-400"><%= @snmp_type %></span>

        <span class="text-gray-500">Value:</span>
        <span class="font-mono text-green-400"><%= @snmp_value %></span>
      </div>
    </div>
    """
  end

  # ============================================================================
  # Table View Component
  # ============================================================================

  defp table_view(assigns) do
    ~H"""
    <div class="-mx-6 -my-6">
      <table class="w-full">
        <thead class="bg-gray-700">
          <tr>
            <th class="px-6 py-3 text-left text-xs font-medium text-gray-400 uppercase">Type</th>
            <th class="px-6 py-3 text-left text-xs font-medium text-gray-400 uppercase">Name</th>
            <th class="px-6 py-3 text-left text-xs font-medium text-gray-400 uppercase">Value</th>
            <th class="px-6 py-3 text-left text-xs font-medium text-gray-400 uppercase">Length</th>
          </tr>
        </thead>
        <tbody class="divide-y divide-gray-700">
          <tr
            :for={tlv <- @tlvs}
            class={[
              "hover:bg-gray-700/50 cursor-pointer transition-colors",
              @selected && @selected[:_path] == tlv[:_path] && "bg-blue-900/30"
            ]}
            phx-click="select-tlv"
            phx-value-path={tlv[:_path]}
          >
            <td class="px-6 py-3">
              <.tlv_type_badge type={get_tlv_type(tlv)} />
            </td>
            <td class="px-6 py-3 text-sm text-gray-200">
              <%= get_tlv_name(tlv) %>
            </td>
            <td class="px-6 py-3 text-sm font-mono text-gray-300">
              <%= format_tlv_value(tlv) |> String.slice(0..50) %>
            </td>
            <td class="px-6 py-3 text-sm text-gray-400">
              <%= get_tlv_length(tlv) %> bytes
            </td>
          </tr>
        </tbody>
      </table>
      <div :if={@tlvs == []} class="text-center py-12 text-gray-500">
        No TLVs found
      </div>
    </div>
    """
  end

  # ============================================================================
  # Hex View Component
  # ============================================================================

  defp hex_view(assigns) do
    bytes = :binary.bin_to_list(assigns.bytes)

    chunks =
      bytes
      |> Enum.with_index()
      |> Enum.chunk_every(16)

    assigns = assign(assigns, :chunks, chunks)

    ~H"""
    <div class="-mx-6 -my-6 overflow-x-auto">
      <div class="font-mono text-sm p-4 bg-gray-900">
        <div class="text-gray-500 mb-2 text-xs">
          Offset    00 01 02 03 04 05 06 07  08 09 0A 0B 0C 0D 0E 0F   ASCII
        </div>
        <div :for={chunk <- @chunks} class="flex hover:bg-gray-800">
          <span class="text-gray-500 w-20">
            <%= chunk |> List.first() |> elem(1) |> Integer.to_string(16) |> String.pad_leading(6, "0") %>
          </span>
          <span class="text-cyan-400 flex-1">
            <%= for {{byte, _idx}, pos} <- Enum.with_index(chunk) do %>
              <%= Integer.to_string(byte, 16) |> String.pad_leading(2, "0") %><%= if pos == 7, do: "  ", else: " " %>
            <% end %>
            <%= String.duplicate("   ", 16 - length(chunk)) %>
          </span>
          <span class="text-gray-400 ml-4">
            <%= chunk |> Enum.map(fn {byte, _} -> if byte >= 32 and byte < 127, do: <<byte>>, else: "." end) |> Enum.join() %>
          </span>
        </div>
      </div>
    </div>
    """
  end

  # ============================================================================
  # TLV Detail Panel Component
  # ============================================================================

  defp tlv_detail_panel(assigns) do
    ~H"""
    <.card>
      <:header>
        <div class="flex items-center justify-between">
          <span>TLV Details</span>
          <button phx-click="close-detail" class="text-gray-400 hover:text-gray-200">
            <.icon name="hero-x-mark" class="h-5 w-5" />
          </button>
        </div>
      </:header>

      <div class="space-y-4">
        <div>
          <label class="block text-xs font-medium text-gray-500 uppercase mb-1">Type</label>
          <.tlv_type_badge type={get_tlv_type(@tlv)} name={get_tlv_name(@tlv)} />
        </div>

        <div>
          <label class="block text-xs font-medium text-gray-500 uppercase mb-1">Description</label>
          <p class="text-sm text-gray-300"><%= get_tlv_description(@tlv) %></p>
        </div>

        <div>
          <label class="block text-xs font-medium text-gray-500 uppercase mb-1">Value</label>
          <div class="bg-gray-900 rounded p-3 font-mono text-sm text-gray-200 break-all">
            <%= format_tlv_value_full(@tlv) %>
          </div>
        </div>

        <div :if={get_tlv_raw_bytes(@tlv)}>
          <label class="block text-xs font-medium text-gray-500 uppercase mb-1">Raw Bytes</label>
          <.hex_value value={get_tlv_raw_bytes(@tlv)} max_bytes={32} />
        </div>

        <div class="pt-4 border-t border-gray-700">
          <.link navigate={"#{@base_path}/configs/#{@config_id}/edit?tlv=#{get_tlv_type(@tlv)}"}>
            <.button variant="secondary" class="w-full">
              <.icon name="hero-pencil" class="h-4 w-4 mr-2" />
              Edit this TLV
            </.button>
          </.link>
        </div>
      </div>
    </.card>
    """
  end

  # ============================================================================
  # Event Handlers
  # ============================================================================

  @impl true
  def handle_event("set-view", %{"mode" => mode}, socket) do
    {:noreply, assign(socket, :view_mode, String.to_atom(mode))}
  end

  @impl true
  def handle_event("search", %{"search" => search}, socket) do
    {:noreply, assign(socket, :search, search)}
  end

  @impl true
  def handle_event("toggle-expand", %{"path" => path}, socket) do
    expanded = socket.assigns.expanded

    expanded =
      if MapSet.member?(expanded, path) do
        MapSet.delete(expanded, path)
      else
        MapSet.put(expanded, path)
      end

    {:noreply, assign(socket, :expanded, expanded)}
  end

  @impl true
  def handle_event("select-tlv", %{"path" => path}, socket) do
    tlv = find_tlv_by_path(socket.assigns.config.parsed, path)
    tlv = if tlv, do: Map.put(tlv, :_path, path), else: nil
    {:noreply, assign(socket, :selected_tlv, tlv)}
  end

  @impl true
  def handle_event("close-detail", _params, socket) do
    {:noreply, assign(socket, :selected_tlv, nil)}
  end

  @impl true
  def handle_event("download", %{"format" => format}, socket) do
    config = socket.assigns.config
    {content, filename, _content_type} = prepare_download(config, format)

    socket =
      push_event(socket, "download", %{
        content: Base.encode64(content),
        filename: filename,
        binary: true
      })

    {:noreply, socket}
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

  defp toggle_dropdown(id) do
    JS.toggle(to: "##{id}")
  end

  defp filter_tlvs(tlvs, ""), do: tlvs

  defp filter_tlvs(tlvs, search) do
    search_lower = String.downcase(search)

    Enum.filter(tlvs, fn tlv ->
      name = get_tlv_name(tlv) |> String.downcase()
      type = get_tlv_type(tlv) |> to_string()
      String.contains?(name, search_lower) or String.contains?(type, search_lower)
    end)
  end

  defp flatten_tlvs(tlvs, path \\ [], acc \\ [])
  defp flatten_tlvs([], _path, acc), do: Enum.reverse(acc)

  defp flatten_tlvs([tlv | rest], path, acc) do
    current_path = path ++ [length(acc)]
    tlv_with_path = Map.put(tlv, :_path, Enum.join(current_path, "."))

    sub_acc =
      if has_sub_tlvs?(tlv) do
        flatten_tlvs(get_sub_tlvs(tlv), current_path, [])
      else
        []
      end

    flatten_tlvs(rest, path, sub_acc ++ [tlv_with_path | acc])
  end

  defp find_tlv_by_path(tlvs, path) do
    indices = path |> String.split(".") |> Enum.map(&String.to_integer/1)
    do_find_tlv_by_path(tlvs, indices)
  end

  defp do_find_tlv_by_path(_tlvs, []), do: nil
  defp do_find_tlv_by_path(tlvs, [idx]) when idx < length(tlvs), do: Enum.at(tlvs, idx)

  defp do_find_tlv_by_path(tlvs, [idx | rest]) when idx < length(tlvs) do
    tlv = Enum.at(tlvs, idx)

    if has_sub_tlvs?(tlv) do
      do_find_tlv_by_path(get_sub_tlvs(tlv), rest)
    else
      tlv
    end
  end

  defp do_find_tlv_by_path(_tlvs, _indices), do: nil

  # TLV accessor functions - handles various TLV struct formats
  defp get_tlv_type(%{type: type}), do: type
  defp get_tlv_type(%{"type" => type}), do: type
  defp get_tlv_type(_), do: 0

  defp get_tlv_name(%{name: name}), do: name
  defp get_tlv_name(%{"name" => name}), do: name
  defp get_tlv_name(tlv), do: "TLV #{get_tlv_type(tlv)}"

  defp get_tlv_description(%{description: desc}), do: desc
  defp get_tlv_description(%{"description" => desc}), do: desc
  defp get_tlv_description(_), do: "No description available"

  defp get_tlv_length(%{length: len}), do: len
  defp get_tlv_length(%{"length" => len}), do: len
  defp get_tlv_length(%{value: val}) when is_binary(val), do: byte_size(val)
  defp get_tlv_length(_), do: 0

  defp get_tlv_raw_bytes(%{value: val}) when is_binary(val), do: val
  defp get_tlv_raw_bytes(%{"value" => val}) when is_binary(val), do: val
  defp get_tlv_raw_bytes(_), do: nil

  # Check if this is an SNMP Object Value subtlv (type 48 with asn1_der formatted as map)
  defp is_snmp_object_value?(%{type: 48, value_type: :asn1_der, formatted_value: fv})
       when is_map(fv) and is_map_key(fv, :oid),
       do: true

  defp is_snmp_object_value?(%{"type" => 48, "value_type" => "asn1_der", "formatted_value" => fv})
       when is_map(fv) and is_map_key(fv, "oid"),
       do: true

  defp is_snmp_object_value?(_), do: false

  # Get the SNMP formatted value map
  defp get_snmp_formatted_value(%{formatted_value: fv}) when is_map(fv), do: fv
  defp get_snmp_formatted_value(%{"formatted_value" => fv}) when is_map(fv), do: fv
  defp get_snmp_formatted_value(_), do: %{}

  # Priority: formatted_value (from enrichment) > raw_value > value (binary)
  defp format_tlv_value(%{formatted_value: val}) when not is_nil(val),
    do: format_enriched_value(val)

  defp format_tlv_value(%{"formatted_value" => val}) when not is_nil(val),
    do: format_enriched_value(val)

  defp format_tlv_value(%{raw_value: val}) when not is_nil(val), do: to_string(val)
  defp format_tlv_value(%{"raw_value" => val}) when not is_nil(val), do: to_string(val)
  defp format_tlv_value(%{value: val}) when is_binary(val), do: format_binary_value(val)
  defp format_tlv_value(%{"value" => val}) when is_binary(val), do: format_binary_value(val)
  defp format_tlv_value(%{value: val}), do: inspect(val)
  defp format_tlv_value(_), do: "-"

  defp format_enriched_value(val) when is_binary(val), do: val

  # SNMP MIB object maps - format human-friendly
  # Always show OID, add name if known
  defp format_enriched_value(%{oid: oid, value: value} = map) do
    oid_name = Map.get(map, :oid_name)

    case oid_name do
      nil -> "#{value} [#{oid}]"
      name -> "#{value} [#{oid}] (#{name})"
    end
  end

  # String key version
  defp format_enriched_value(%{"oid" => oid, "value" => value} = map) do
    oid_name = Map.get(map, "oid_name")

    case oid_name do
      nil -> "#{value} [#{oid}]"
      name -> "#{value} [#{oid}] (#{name})"
    end
  end

  # Vendor TLV maps
  defp format_enriched_value(%{"oui" => oui, "data" => data} = map) do
    vendor = Map.get(map, "vendor_name")

    case vendor do
      nil -> "OUI #{oui}: #{data}"
      name -> "#{name} (#{oui}): #{data}"
    end
  end

  defp format_enriched_value(%{oui: oui, data: data} = map) do
    vendor = Map.get(map, :vendor_name)

    case vendor do
      nil -> "OUI #{oui}: #{data}"
      name -> "#{name} (#{oui}): #{data}"
    end
  end

  # Generic map fallback
  defp format_enriched_value(val) when is_map(val), do: inspect(val, pretty: false, limit: 50)
  defp format_enriched_value(val), do: to_string(val)

  defp format_tlv_value_full(tlv) do
    case tlv do
      %{formatted_value: val} when not is_nil(val) -> format_enriched_value(val)
      %{"formatted_value" => val} when not is_nil(val) -> format_enriched_value(val)
      %{raw_value: val} when not is_nil(val) -> to_string(val)
      %{"raw_value" => val} when not is_nil(val) -> to_string(val)
      %{value: val} when is_binary(val) -> Base.encode16(val, case: :lower)
      %{"value" => val} when is_binary(val) -> Base.encode16(val, case: :lower)
      %{value: val} -> inspect(val)
      _ -> "-"
    end
  end

  defp format_binary_value(val) when byte_size(val) <= 8 do
    Base.encode16(val, case: :lower)
  end

  defp format_binary_value(val) do
    Base.encode16(binary_part(val, 0, 8), case: :lower) <> "..."
  end

  defp has_sub_tlvs?(%{subtlvs: subs}) when is_list(subs) and length(subs) > 0, do: true
  defp has_sub_tlvs?(%{"subtlvs" => subs}) when is_list(subs) and length(subs) > 0, do: true
  defp has_sub_tlvs?(%{sub_tlvs: subs}) when is_list(subs) and length(subs) > 0, do: true
  defp has_sub_tlvs?(%{"sub_tlvs" => subs}) when is_list(subs) and length(subs) > 0, do: true

  defp has_sub_tlvs?(%{children: children}) when is_list(children) and length(children) > 0,
    do: true

  defp has_sub_tlvs?(_), do: false

  defp get_sub_tlvs(%{subtlvs: subs}) when is_list(subs), do: subs
  defp get_sub_tlvs(%{"subtlvs" => subs}) when is_list(subs), do: subs
  defp get_sub_tlvs(%{sub_tlvs: subs}) when is_list(subs), do: subs
  defp get_sub_tlvs(%{"sub_tlvs" => subs}) when is_list(subs), do: subs
  defp get_sub_tlvs(%{children: children}) when is_list(children), do: children
  defp get_sub_tlvs(_), do: []

  defp format_bytes(bytes) when bytes < 1024, do: "#{bytes} B"
  defp format_bytes(bytes) when bytes < 1_048_576, do: "#{Float.round(bytes / 1024, 1)} KB"
  defp format_bytes(bytes), do: "#{Float.round(bytes / 1_048_576, 1)} MB"

  defp prepare_download(config, "binary") do
    # Use the library to regenerate binary from parsed TLVs if modified
    content =
      if config.modified do
        # Unenrich TLVs before binary generation
        unenriched_tlvs = Bindocsis.TlvEnricher.unenrich_tlvs(config.parsed)

        case Bindocsis.generate(unenriched_tlvs, format: :binary) do
          {:ok, binary} -> binary
          {:error, _} -> config.raw_bytes
        end
      else
        config.raw_bytes
      end

    {content, config.name, "application/octet-stream"}
  end

  defp prepare_download(config, "json") do
    # Use library's JSON generator for proper output
    content =
      case Bindocsis.generate(config.enriched, format: :json) do
        {:ok, json} -> json
        {:error, _} -> Jason.encode!(config.enriched, pretty: true)
      end

    filename = String.replace(config.name, ~r/\.(cm|bin)$/, ".json")
    {content, filename, "application/json"}
  end

  defp prepare_download(config, "yaml") do
    # Use library's YAML generator
    content =
      case Bindocsis.generate(config.enriched, format: :yaml) do
        {:ok, yaml} -> yaml
        {:error, _} -> fallback_to_yaml(config.enriched)
      end

    filename = String.replace(config.name, ~r/\.(cm|bin)$/, ".yaml")
    {content, filename, "text/yaml"}
  end

  defp prepare_download(config, "config") do
    # Human-readable DOCSIS config format
    content =
      case Bindocsis.generate(config.enriched, format: :config) do
        {:ok, cfg} -> cfg
        {:error, _} -> "# Error generating config format\n"
      end

    filename = String.replace(config.name, ~r/\.(cm|bin)$/, ".txt")
    {content, filename, "text/plain"}
  end

  defp prepare_download(config, "hex") do
    # Hex dump format
    content = format_hex_dump(config.raw_bytes)
    filename = String.replace(config.name, ~r/\.(cm|bin)$/, "_hex.txt")
    {content, filename, "text/plain"}
  end

  defp fallback_to_yaml(data) when is_list(data) do
    data
    |> Enum.map(&tlv_to_yaml/1)
    |> Enum.join("\n")
  end

  defp tlv_to_yaml(tlv) do
    """
    - type: #{get_tlv_type(tlv)}
      name: "#{get_tlv_name(tlv)}"
      value: "#{format_tlv_value(tlv)}"
    """
  end

  defp format_hex_dump(binary) do
    binary
    |> :binary.bin_to_list()
    |> Enum.chunk_every(16)
    |> Enum.with_index()
    |> Enum.map(fn {bytes, idx} ->
      offset = String.pad_leading(Integer.to_string(idx * 16, 16), 8, "0")

      hex =
        bytes
        |> Enum.map(&String.pad_leading(Integer.to_string(&1, 16), 2, "0"))
        |> Enum.join(" ")

      ascii = bytes |> Enum.map(&printable_char/1) |> Enum.join("")
      "#{offset}  #{String.pad_trailing(hex, 47)}  |#{ascii}|"
    end)
    |> Enum.join("\n")
  end

  defp printable_char(byte) when byte >= 32 and byte <= 126, do: <<byte>>
  defp printable_char(_), do: "."
end
