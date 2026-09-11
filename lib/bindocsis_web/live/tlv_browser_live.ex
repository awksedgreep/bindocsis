defmodule BindocsisWeb.TLVBrowserLive do
  @moduledoc """
  TLV Browser LiveView - browse and search TLV specifications.

  Features:
  - Searchable list of all TLV types
  - Filter by category (CM, MTA, etc.)
  - Detailed view of each TLV
  - Sub-TLV hierarchy display
  """

  use Phoenix.LiveView

  import BindocsisWeb.Components

  @impl true
  def mount(params, _session, socket) do
    socket =
      socket
      |> assign(:page_title, "TLV Browser")
      |> assign(:base_path, get_base_path(socket))
      |> assign(:search, "")
      |> assign(:category, "all")
      |> assign(:tlv_specs, get_all_tlv_specs())
      |> assign(:selected_tlv, parse_selected_tlv(params["tlv"]))

    {:ok, socket}
  end

  @impl true
  def handle_params(%{"tlv" => tlv_str}, _uri, socket) do
    case parse_selected_tlv(tlv_str) do
      nil ->
        {:noreply,
         socket
         |> assign(:selected_tlv, nil)
         |> put_flash(:error, "Unknown TLV type: #{String.slice(tlv_str, 0, 32)}")}

      tlv_type ->
        {:noreply, assign(socket, :selected_tlv, tlv_type)}
    end
  end

  @impl true
  def handle_params(_params, _uri, socket) do
    {:noreply, assign(socket, :selected_tlv, nil)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div>
      <div class="flex items-center justify-between mb-6">
        <div>
          <h1 class="text-2xl font-bold text-gray-100">TLV Browser</h1>
          <p class="text-gray-400 mt-1">
            Browse DOCSIS TLV specifications
          </p>
        </div>
      </div>

      <div class="grid grid-cols-1 lg:grid-cols-3 gap-6">
        <div class={[@selected_tlv && "lg:col-span-1", !@selected_tlv && "lg:col-span-3"]}>
          <.card>
            <:header>
              <div class="flex items-center justify-between flex-wrap gap-2">
                <span><%= length(filter_specs(@tlv_specs, @search, @category)) %> TLV Types</span>
                <.input
                  type="search"
                  name="search"
                  value={@search}
                  placeholder="Search..."
                  phx-change="search"
                  phx-debounce="300"
                  class="!w-48 !py-1"
                />
              </div>
            </:header>

            <div class="mb-4 flex flex-wrap gap-2 -mt-2">
              <.category_filter category={@category} value="all" label="All" />
              <.category_filter category={@category} value="core" label="Core (1-21)" />
              <.category_filter category={@category} value="service_flow" label="Service Flows" />
              <.category_filter category={@category} value="classification" label="Classification" />
              <.category_filter category={@category} value="security" label="Security" />
              <.category_filter category={@category} value="docsis31" label="DOCSIS 3.1+" />
              <.category_filter category={@category} value="vendor" label="Vendor" />
            </div>

            <div class="-mx-6 -mb-6 max-h-[600px] overflow-y-auto">
              <div class="divide-y divide-gray-700">
                <.tlv_list_item
                  :for={spec <- filter_specs(@tlv_specs, @search, @category)}
                  spec={spec}
                  selected={@selected_tlv == spec.type}
                  base_path={@base_path}
                />
              </div>
              <div :if={filter_specs(@tlv_specs, @search, @category) == []} class="text-center py-12 text-gray-500">
                No TLVs match your search
              </div>
            </div>
          </.card>
        </div>

        <div :if={@selected_tlv} class="lg:col-span-2">
          <.tlv_detail_view
            spec={find_spec(@tlv_specs, @selected_tlv)}
            base_path={@base_path}
          />
        </div>
      </div>
    </div>
    """
  end

  # ============================================================================
  # Components
  # ============================================================================

  attr(:category, :string, required: true)
  attr(:value, :string, required: true)
  attr(:label, :string, required: true)

  defp category_filter(assigns) do
    assigns = assign(assigns, :active, assigns.category == assigns.value)

    ~H"""
    <button
      phx-click="set-category"
      phx-value-category={@value}
      class={[
        "px-3 py-1 text-xs font-medium rounded-full transition-colors",
        @active && "bg-blue-600 text-white",
        !@active && "bg-gray-700 text-gray-300 hover:bg-gray-600"
      ]}
    >
      <%= @label %>
    </button>
    """
  end

  defp tlv_list_item(assigns) do
    ~H"""
    <.link
      navigate={"#{@base_path}/tlvs/#{@spec.type}"}
      class={[
        "block px-6 py-3 hover:bg-gray-700/50 transition-colors",
        @selected && "bg-blue-900/30 border-l-2 border-blue-500"
      ]}
    >
      <div class="flex items-center justify-between">
        <div class="flex items-center space-x-3">
          <span class="inline-flex items-center justify-center min-w-[2.5rem] px-2 py-1 rounded bg-blue-900 text-blue-300 text-sm font-mono font-bold">
            <%= @spec.type %>
          </span>
          <span class="text-sm text-gray-200"><%= @spec.name %></span>
        </div>
        <div class="flex items-center space-x-2">
          <.badge :if={@spec.has_sub_tlvs} variant="info">Sub-TLVs</.badge>
        </div>
      </div>
    </.link>
    """
  end

  defp tlv_detail_view(%{spec: nil} = assigns) do
    ~H"""
    <.card>
      <:header>TLV Details</:header>
      <p class="text-gray-400">TLV specification not found</p>
    </.card>
    """
  end

  defp tlv_detail_view(assigns) do
    ~H"""
    <div class="space-y-6">
      <.card>
        <:header>
          <div class="flex items-center space-x-3">
            <span class="inline-flex items-center justify-center min-w-[3rem] px-2 py-1 rounded bg-blue-900 text-blue-300 text-lg font-mono font-bold">
              <%= @spec.type %>
            </span>
            <span class="text-xl font-semibold text-gray-100"><%= @spec.name %></span>
          </div>
        </:header>

        <div class="space-y-6">
          <div>
            <label class="block text-xs font-medium text-gray-500 uppercase mb-1">Description</label>
            <p class="text-gray-300"><%= @spec.description %></p>
          </div>

          <div class="grid grid-cols-2 md:grid-cols-4 gap-4">
            <div>
              <label class="block text-xs font-medium text-gray-500 uppercase mb-1">Data Type</label>
              <p class="text-gray-200 font-mono"><%= @spec.data_type %></p>
            </div>
            <div>
              <label class="block text-xs font-medium text-gray-500 uppercase mb-1">Length</label>
              <p class="text-gray-200">
                <%= format_length(@spec.min_length, @spec.max_length) %>
              </p>
            </div>
            <div>
              <label class="block text-xs font-medium text-gray-500 uppercase mb-1">Introduced</label>
              <p class="text-gray-200">DOCSIS <%= @spec.introduced_version %></p>
            </div>
            <div>
              <label class="block text-xs font-medium text-gray-500 uppercase mb-1">Has Sub-TLVs</label>
              <p class="text-gray-200"><%= if @spec.has_sub_tlvs, do: "Yes", else: "No" %></p>
            </div>
          </div>

          <div :if={@spec.constraints}>
            <label class="block text-xs font-medium text-gray-500 uppercase mb-1">Constraints</label>
            <div class="bg-gray-900 rounded p-3 text-sm font-mono text-gray-300">
              <%= inspect(@spec.constraints, pretty: true) %>
            </div>
          </div>
        </div>
      </.card>

      <.card :if={@spec.has_sub_tlvs && @spec.sub_tlvs != []}>
        <:header>Sub-TLVs</:header>
        <div class="-mx-6 -my-6">
          <table class="w-full">
            <thead class="bg-gray-700">
              <tr>
                <th class="px-6 py-3 text-left text-xs font-medium text-gray-400 uppercase">Type</th>
                <th class="px-6 py-3 text-left text-xs font-medium text-gray-400 uppercase">Name</th>
                <th class="px-6 py-3 text-left text-xs font-medium text-gray-400 uppercase">Data Type</th>
                <th class="px-6 py-3 text-left text-xs font-medium text-gray-400 uppercase">Length</th>
              </tr>
            </thead>
            <tbody class="divide-y divide-gray-700">
              <tr :for={sub <- @spec.sub_tlvs} class="hover:bg-gray-700/50">
                <td class="px-6 py-3">
                  <span class="font-mono text-blue-400"><%= sub.type %></span>
                </td>
                <td class="px-6 py-3 text-sm text-gray-200"><%= sub.name %></td>
                <td class="px-6 py-3 text-sm font-mono text-gray-400"><%= sub.data_type %></td>
                <td class="px-6 py-3 text-sm text-gray-400">
                  <%= format_length(sub[:min_length], sub[:max_length]) %>
                </td>
              </tr>
            </tbody>
          </table>
        </div>
      </.card>

      <.card>
        <:header>Usage Example</:header>
        <div class="bg-gray-900 rounded p-4">
          <pre class="text-sm font-mono text-gray-300 overflow-x-auto"><%= generate_example(@spec) %></pre>
        </div>
      </.card>
    </div>
    """
  end

  # ============================================================================
  # Event Handlers
  # ============================================================================

  @impl true
  def handle_event("search", %{"search" => search}, socket) do
    {:noreply, assign(socket, :search, search)}
  end

  @impl true
  def handle_event("set-category", %{"category" => category}, socket) do
    {:noreply, assign(socket, :category, category)}
  end

  # ============================================================================
  # Helper Functions
  # ============================================================================

  defp get_base_path(socket) do
    case socket.assigns[:bindocsis_base_path] do
      "" -> ""
      nil -> ""
      base -> base
    end
  end

  defp filter_specs(specs, search, category) do
    specs
    |> filter_by_category(category)
    |> filter_by_search(search)
  end

  defp filter_by_category(specs, "all"), do: specs

  # Core TLVs: 1-21 (basic configuration per CANN-I22)
  defp filter_by_category(specs, "core") do
    Enum.filter(specs, fn s -> s.type >= 1 and s.type <= 21 end)
  end

  # Security TLVs: BPI+ (17), SNMPv3 (34, 38), Subscriber Mgmt (35-37)
  defp filter_by_category(specs, "security") do
    Enum.filter(specs, fn s -> s.type in [17, 30, 31, 34, 35, 36, 37, 38] end)
  end

  # Service Flow TLVs: US/DS flows (24, 25), Aggregate flows (70, 71), Symmetric (82)
  defp filter_by_category(specs, "service_flow") do
    Enum.filter(specs, fn s -> s.type in [24, 25, 70, 71, 82] end)
  end

  # Classification TLVs: Packet Classification (22, 23), PHS (26), Drop Classification (60)
  defp filter_by_category(specs, "classification") do
    Enum.filter(specs, fn s -> s.type in [22, 23, 26, 60] end)
  end

  # Vendor TLVs: Vendor Specific (43) and vendor range (200-254)
  defp filter_by_category(specs, "vendor") do
    Enum.filter(specs, fn s -> s.type == 43 or (s.type >= 200 and s.type <= 254) end)
  end

  # DOCSIS 3.1+ TLVs: OFDM/OFDMA profiles, energy management, etc.
  defp filter_by_category(specs, "docsis31") do
    Enum.filter(specs, fn s -> s.type in [62, 63, 66, 67, 72, 73, 74, 77, 79, 80, 81] end)
  end

  defp filter_by_search(specs, ""), do: specs

  defp filter_by_search(specs, search) do
    search_lower = String.downcase(search)

    Enum.filter(specs, fn spec ->
      String.contains?(String.downcase(spec.name), search_lower) or
        String.contains?(to_string(spec.type), search_lower)
    end)
  end

  defp find_spec(specs, type) do
    Enum.find(specs, fn s -> s.type == type end)
  end

  defp format_length(nil, nil), do: "Variable"
  defp format_length(min, nil), do: "#{min}+ bytes"
  defp format_length(nil, max), do: "≤#{max} bytes"
  defp format_length(min, max) when min == max, do: "#{min} bytes"
  defp format_length(min, max), do: "#{min}-#{max} bytes"

  defp generate_example(spec) do
    """
    # #{spec.name} (TLV #{spec.type})
    # #{spec.description}

    %{
      type: #{spec.type},
      name: "#{spec.name}",
      value: #{example_value(spec)}
    }
    """
  end

  defp example_value(%{data_type: :uint}), do: "1"
  defp example_value(%{data_type: :boolean}), do: "<<1>>"
  defp example_value(%{data_type: :ip}), do: "<<192, 168, 1, 1>>"
  defp example_value(%{data_type: :mac}), do: "<<0x00, 0x11, 0x22, 0x33, 0x44, 0x55>>"
  defp example_value(%{data_type: :string}), do: "\"example\""
  defp example_value(_), do: "<<...>>"

  # ============================================================================
  # Dynamic TLV Specifications from DocsisSpecs and SubTlvSpecs
  # ============================================================================

  # URL segment -> TLV type; anything that is not 0-255 selects nothing
  defp parse_selected_tlv(nil), do: nil

  defp parse_selected_tlv(str) do
    case BindocsisWeb.Params.tlv_type(str) do
      {:ok, type} -> type
      :error -> nil
    end
  end

  defp get_all_tlv_specs do
    # Use version "4.0" to get ALL known TLVs including DOCSIS 4.0
    all_tlvs = Bindocsis.DocsisSpecs.get_spec("4.0")

    all_tlvs
    |> Enum.map(fn {type, info} ->
      has_sub_tlvs = Map.get(info, :subtlv_support, false)
      sub_tlvs = if has_sub_tlvs, do: get_sub_tlv_specs(type), else: []

      %{
        type: type,
        name: info.name,
        description: Map.get(info, :description, ""),
        data_type: Map.get(info, :value_type, :binary),
        min_length: get_min_length(info),
        max_length: get_max_length(info),
        introduced_version: Map.get(info, :introduced_version, "1.0"),
        has_sub_tlvs: has_sub_tlvs,
        sub_tlvs: sub_tlvs,
        constraints: nil
      }
    end)
    |> Enum.sort_by(& &1.type)
  end

  defp get_sub_tlv_specs(parent_type) do
    case Bindocsis.SubTlvSpecs.get_subtlv_specs(parent_type) do
      {:ok, sub_specs} when is_map(sub_specs) ->
        sub_specs
        |> Enum.map(fn {sub_type, sub_info} ->
          %{
            type: sub_type,
            name: Map.get(sub_info, :name, "Unknown"),
            data_type: Map.get(sub_info, :value_type, :binary),
            min_length: nil,
            max_length: Map.get(sub_info, :max_length, nil)
          }
        end)
        |> Enum.sort_by(& &1.type)

      _ ->
        []
    end
  end

  defp get_min_length(%{max_length: max}) when is_integer(max), do: nil
  defp get_min_length(_), do: nil

  defp get_max_length(%{max_length: :unlimited}), do: nil
  defp get_max_length(%{max_length: max}) when is_integer(max), do: max
  defp get_max_length(_), do: nil
end
