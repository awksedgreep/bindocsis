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
      |> assign(:selected_tlv, params["tlv"] && String.to_integer(params["tlv"]))

    {:ok, socket}
  end

  @impl true
  def handle_params(%{"tlv" => tlv_str}, _uri, socket) do
    tlv_type = String.to_integer(tlv_str)
    {:noreply, assign(socket, :selected_tlv, tlv_type)}
  end

  @impl true
  def handle_params(_params, _uri, socket) do
    {:noreply, assign(socket, :selected_tlv, nil)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div>
      <.breadcrumb>
        <:item href={@base_path}>Dashboard</:item>
        <:item :if={!@selected_tlv}>TLV Browser</:item>
        <:item :if={@selected_tlv} href={"#{@base_path}/tlvs"}>TLV Browser</:item>
        <:item :if={@selected_tlv}>TLV <%= @selected_tlv %></:item>
      </.breadcrumb>

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
              <.category_filter category={@category} value="core" label="Core (1-30)" />
              <.category_filter category={@category} value="security" label="Security" />
              <.category_filter category={@category} value="service_flow" label="Service Flows" />
              <.category_filter category={@category} value="classification" label="Classification" />
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

  defp filter_by_category(specs, "core") do
    Enum.filter(specs, fn s -> s.type >= 1 and s.type <= 30 end)
  end

  defp filter_by_category(specs, "security") do
    Enum.filter(specs, fn s -> s.type in [17, 31, 32, 33, 34, 35, 36, 37, 38, 39, 40, 41, 42] end)
  end

  defp filter_by_category(specs, "service_flow") do
    Enum.filter(specs, fn s -> s.type in [22, 23, 24, 25, 26, 27] end)
  end

  defp filter_by_category(specs, "classification") do
    Enum.filter(specs, fn s -> s.type in [28, 29] end)
  end

  defp filter_by_category(specs, "vendor") do
    Enum.filter(specs, fn s -> s.type == 43 or (s.type >= 200 and s.type <= 254) end)
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
  # TLV Specifications Data
  # ============================================================================

  defp get_all_tlv_specs do
    [
      %{
        type: 1,
        name: "Downstream Frequency",
        description: "Center frequency of the downstream channel in Hz",
        data_type: :uint,
        min_length: 4,
        max_length: 4,
        introduced_version: "1.0",
        has_sub_tlvs: false,
        sub_tlvs: [],
        constraints: %{min: 88_000_000, max: 860_000_000}
      },
      %{
        type: 2,
        name: "Upstream Channel ID",
        description: "Identifier for the upstream channel",
        data_type: :uint,
        min_length: 1,
        max_length: 1,
        introduced_version: "1.0",
        has_sub_tlvs: false,
        sub_tlvs: [],
        constraints: %{min: 0, max: 255}
      },
      %{
        type: 3,
        name: "Network Access",
        description: "Enable or disable network access for the CM",
        data_type: :boolean,
        min_length: 1,
        max_length: 1,
        introduced_version: "1.0",
        has_sub_tlvs: false,
        sub_tlvs: [],
        constraints: nil
      },
      %{
        type: 4,
        name: "Class of Service",
        description: "Defines a class of service for upstream transmission",
        data_type: :aggregate,
        min_length: nil,
        max_length: nil,
        introduced_version: "1.0",
        has_sub_tlvs: true,
        sub_tlvs: [
          %{type: 1, name: "Class ID", data_type: :uint, min_length: 1, max_length: 1},
          %{type: 2, name: "Max Downstream Rate", data_type: :uint, min_length: 4, max_length: 4},
          %{type: 3, name: "Max Upstream Rate", data_type: :uint, min_length: 4, max_length: 4},
          %{type: 4, name: "Upstream Priority", data_type: :uint, min_length: 1, max_length: 1},
          %{
            type: 5,
            name: "Guaranteed Upstream Rate",
            data_type: :uint,
            min_length: 4,
            max_length: 4
          },
          %{type: 6, name: "Max Upstream Burst", data_type: :uint, min_length: 2, max_length: 2},
          %{type: 7, name: "Privacy Enable", data_type: :boolean, min_length: 1, max_length: 1}
        ],
        constraints: nil
      },
      %{
        type: 5,
        name: "CM MIC",
        description: "CM Message Integrity Check",
        data_type: :hex,
        min_length: 16,
        max_length: 16,
        introduced_version: "1.0",
        has_sub_tlvs: false,
        sub_tlvs: [],
        constraints: nil
      },
      %{
        type: 6,
        name: "CMTS MIC",
        description: "CMTS Message Integrity Check",
        data_type: :hex,
        min_length: 16,
        max_length: 16,
        introduced_version: "1.0",
        has_sub_tlvs: false,
        sub_tlvs: [],
        constraints: nil
      },
      %{
        type: 7,
        name: "Software Upgrade Filename",
        description: "Filename of software image to download",
        data_type: :string,
        min_length: 1,
        max_length: 64,
        introduced_version: "1.0",
        has_sub_tlvs: false,
        sub_tlvs: [],
        constraints: nil
      },
      %{
        type: 8,
        name: "SNMP Write-Access",
        description: "Control SNMP write access",
        data_type: :aggregate,
        min_length: nil,
        max_length: nil,
        introduced_version: "1.0",
        has_sub_tlvs: true,
        sub_tlvs: [
          %{type: 1, name: "Control", data_type: :uint, min_length: 1, max_length: 1},
          %{type: 2, name: "OID", data_type: :oid, min_length: 1, max_length: 128}
        ],
        constraints: nil
      },
      %{
        type: 9,
        name: "SNMP MIB Object",
        description: "Set an SNMP MIB object value",
        data_type: :aggregate,
        min_length: nil,
        max_length: nil,
        introduced_version: "1.0",
        has_sub_tlvs: false,
        sub_tlvs: [],
        constraints: nil
      },
      %{
        type: 10,
        name: "Software Upgrade TFTP Server",
        description: "TFTP server IP for software upgrades",
        data_type: :ip,
        min_length: 4,
        max_length: 4,
        introduced_version: "1.0",
        has_sub_tlvs: false,
        sub_tlvs: [],
        constraints: nil
      },
      %{
        type: 11,
        name: "SNMP V3 Notification Receiver",
        description: "SNMPv3 trap/inform destination configuration",
        data_type: :aggregate,
        min_length: nil,
        max_length: nil,
        introduced_version: "1.1",
        has_sub_tlvs: true,
        sub_tlvs: [
          %{type: 1, name: "IP Address", data_type: :ip, min_length: 4, max_length: 4},
          %{type: 2, name: "UDP Port", data_type: :uint, min_length: 2, max_length: 2},
          %{type: 3, name: "Trap Type", data_type: :uint, min_length: 2, max_length: 2},
          %{type: 4, name: "Timeout", data_type: :uint, min_length: 2, max_length: 2},
          %{type: 5, name: "Retries", data_type: :uint, min_length: 2, max_length: 2},
          %{type: 6, name: "Security Name", data_type: :string, min_length: 1, max_length: 16}
        ],
        constraints: nil
      },
      %{
        type: 17,
        name: "Baseline Privacy Configuration",
        description: "BPI+ configuration parameters",
        data_type: :aggregate,
        min_length: nil,
        max_length: nil,
        introduced_version: "1.0",
        has_sub_tlvs: true,
        sub_tlvs: [
          %{
            type: 1,
            name: "Authorize Wait Timeout",
            data_type: :uint,
            min_length: 4,
            max_length: 4
          },
          %{
            type: 2,
            name: "Reauthorize Wait Timeout",
            data_type: :uint,
            min_length: 4,
            max_length: 4
          },
          %{
            type: 3,
            name: "Authorization Grace Time",
            data_type: :uint,
            min_length: 4,
            max_length: 4
          },
          %{
            type: 4,
            name: "Operational Wait Timeout",
            data_type: :uint,
            min_length: 4,
            max_length: 4
          },
          %{type: 5, name: "Rekey Wait Timeout", data_type: :uint, min_length: 4, max_length: 4},
          %{type: 6, name: "TEK Grace Time", data_type: :uint, min_length: 4, max_length: 4},
          %{
            type: 7,
            name: "Authorize Reject Wait Timeout",
            data_type: :uint,
            min_length: 4,
            max_length: 4
          }
        ],
        constraints: nil
      },
      %{
        type: 18,
        name: "Maximum Number of CPE",
        description: "Maximum number of CPE devices allowed",
        data_type: :uint,
        min_length: 1,
        max_length: 1,
        introduced_version: "1.0",
        has_sub_tlvs: false,
        sub_tlvs: [],
        constraints: %{min: 1, max: 254}
      },
      %{
        type: 19,
        name: "TFTP Server Timestamp",
        description: "Timestamp for TFTP provisioning",
        data_type: :uint,
        min_length: 4,
        max_length: 4,
        introduced_version: "1.0",
        has_sub_tlvs: false,
        sub_tlvs: [],
        constraints: nil
      },
      %{
        type: 20,
        name: "TFTP Modem Address",
        description: "TFTP server provisioned modem IP address",
        data_type: :ip,
        min_length: 4,
        max_length: 4,
        introduced_version: "1.0",
        has_sub_tlvs: false,
        sub_tlvs: [],
        constraints: nil
      },
      %{
        type: 24,
        name: "Upstream Service Flow",
        description: "Defines upstream service flow parameters",
        data_type: :aggregate,
        min_length: nil,
        max_length: nil,
        introduced_version: "1.1",
        has_sub_tlvs: true,
        sub_tlvs: [
          %{
            type: 1,
            name: "Service Flow Reference",
            data_type: :uint,
            min_length: 2,
            max_length: 2
          },
          %{type: 2, name: "Service Flow ID", data_type: :uint, min_length: 4, max_length: 4},
          %{type: 3, name: "Service Identifier", data_type: :uint, min_length: 2, max_length: 2},
          %{
            type: 4,
            name: "Service Class Name",
            data_type: :string,
            min_length: 2,
            max_length: 16
          },
          %{
            type: 6,
            name: "QoS Parameter Set Type",
            data_type: :uint,
            min_length: 1,
            max_length: 1
          },
          %{type: 7, name: "Traffic Priority", data_type: :uint, min_length: 1, max_length: 1},
          %{type: 8, name: "Max Sustained Rate", data_type: :uint, min_length: 4, max_length: 4},
          %{type: 9, name: "Max Traffic Burst", data_type: :uint, min_length: 4, max_length: 4},
          %{type: 10, name: "Min Reserved Rate", data_type: :uint, min_length: 4, max_length: 4},
          %{type: 11, name: "Min Packet Size", data_type: :uint, min_length: 2, max_length: 2},
          %{type: 12, name: "Active QoS Timeout", data_type: :uint, min_length: 2, max_length: 2},
          %{
            type: 13,
            name: "Admitted QoS Timeout",
            data_type: :uint,
            min_length: 2,
            max_length: 2
          }
        ],
        constraints: nil
      },
      %{
        type: 25,
        name: "Downstream Service Flow",
        description: "Defines downstream service flow parameters",
        data_type: :aggregate,
        min_length: nil,
        max_length: nil,
        introduced_version: "1.1",
        has_sub_tlvs: true,
        sub_tlvs: [
          %{
            type: 1,
            name: "Service Flow Reference",
            data_type: :uint,
            min_length: 2,
            max_length: 2
          },
          %{type: 2, name: "Service Flow ID", data_type: :uint, min_length: 4, max_length: 4},
          %{type: 3, name: "Service Identifier", data_type: :uint, min_length: 2, max_length: 2},
          %{
            type: 4,
            name: "Service Class Name",
            data_type: :string,
            min_length: 2,
            max_length: 16
          },
          %{
            type: 6,
            name: "QoS Parameter Set Type",
            data_type: :uint,
            min_length: 1,
            max_length: 1
          },
          %{type: 7, name: "Traffic Priority", data_type: :uint, min_length: 1, max_length: 1},
          %{type: 8, name: "Max Sustained Rate", data_type: :uint, min_length: 4, max_length: 4},
          %{type: 9, name: "Max Traffic Burst", data_type: :uint, min_length: 4, max_length: 4},
          %{type: 10, name: "Min Reserved Rate", data_type: :uint, min_length: 4, max_length: 4},
          %{type: 11, name: "Min Packet Size", data_type: :uint, min_length: 2, max_length: 2},
          %{type: 12, name: "Active QoS Timeout", data_type: :uint, min_length: 2, max_length: 2},
          %{
            type: 13,
            name: "Admitted QoS Timeout",
            data_type: :uint,
            min_length: 2,
            max_length: 2
          }
        ],
        constraints: nil
      },
      %{
        type: 28,
        name: "Upstream Packet Classification",
        description: "Upstream packet classification rules",
        data_type: :aggregate,
        min_length: nil,
        max_length: nil,
        introduced_version: "1.1",
        has_sub_tlvs: true,
        sub_tlvs: [
          %{
            type: 1,
            name: "Classifier Reference",
            data_type: :uint,
            min_length: 1,
            max_length: 1
          },
          %{type: 2, name: "Classifier ID", data_type: :uint, min_length: 2, max_length: 2},
          %{
            type: 3,
            name: "Service Flow Reference",
            data_type: :uint,
            min_length: 2,
            max_length: 2
          },
          %{type: 4, name: "Service Flow ID", data_type: :uint, min_length: 4, max_length: 4},
          %{type: 5, name: "Rule Priority", data_type: :uint, min_length: 1, max_length: 1},
          %{type: 6, name: "Activation State", data_type: :boolean, min_length: 1, max_length: 1}
        ],
        constraints: nil
      },
      %{
        type: 29,
        name: "Downstream Packet Classification",
        description: "Downstream packet classification rules",
        data_type: :aggregate,
        min_length: nil,
        max_length: nil,
        introduced_version: "1.1",
        has_sub_tlvs: true,
        sub_tlvs: [
          %{
            type: 1,
            name: "Classifier Reference",
            data_type: :uint,
            min_length: 1,
            max_length: 1
          },
          %{type: 2, name: "Classifier ID", data_type: :uint, min_length: 2, max_length: 2},
          %{
            type: 3,
            name: "Service Flow Reference",
            data_type: :uint,
            min_length: 2,
            max_length: 2
          },
          %{type: 4, name: "Service Flow ID", data_type: :uint, min_length: 4, max_length: 4},
          %{type: 5, name: "Rule Priority", data_type: :uint, min_length: 1, max_length: 1},
          %{type: 6, name: "Activation State", data_type: :boolean, min_length: 1, max_length: 1}
        ],
        constraints: nil
      },
      %{
        type: 43,
        name: "Vendor Specific",
        description: "Vendor-specific configuration extensions",
        data_type: :aggregate,
        min_length: nil,
        max_length: nil,
        introduced_version: "1.0",
        has_sub_tlvs: true,
        sub_tlvs: [
          %{type: 8, name: "Vendor ID", data_type: :hex, min_length: 3, max_length: 3}
        ],
        constraints: nil
      }
    ]
  end
end
