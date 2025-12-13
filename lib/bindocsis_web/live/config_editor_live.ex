defmodule BindocsisWeb.ConfigEditorLive do
  @moduledoc """
  Config Editor LiveView - full editing capabilities for DOCSIS configs.

  Features:
  - Add new TLVs from spec
  - Edit existing TLV values
  - Delete TLVs
  - Reorder TLVs
  - Type-appropriate input fields
  - Real-time validation
  - Preview encoded bytes
  - Save/export changes
  """

  use Phoenix.LiveView

  import BindocsisWeb.Components
  alias Phoenix.LiveView.JS
  alias BindocsisWeb.ConfigStore

  @impl true
  def mount(params, _session, socket) do
    BindocsisWeb.Supervisor.ensure_started()

    socket =
      socket
      |> assign(:base_path, get_base_path(socket))
      |> assign(:action, determine_action(params))
      |> assign(:expanded, MapSet.new())
      |> assign(:selected_tlv_path, nil)
      |> assign(:edit_modal, nil)
      |> assign(:add_modal, nil)
      |> assign(:delete_confirm, nil)
      |> assign(:search, "")
      |> assign(:dirty, false)
      |> assign(:editing_path, nil)
      |> assign(:editing_value, nil)

    socket = load_config(socket, params)

    {:ok, socket}
  end

  defp determine_action(%{"id" => _}), do: :edit
  defp determine_action(_), do: :new

  defp load_config(socket, %{"id" => id}) do
    case ConfigStore.get(id) do
      {:ok, config} ->
        # Use enriched TLVs for editing (has formatted_value, value_type, etc.)
        tlvs = config.enriched || config.parsed

        socket
        |> assign(:page_title, "Edit: #{config.name}")
        |> assign(:config_id, id)
        |> assign(:config_name, config.name)
        |> assign(:tlvs, tlvs)
        |> assign(:original_tlvs, tlvs)

      {:error, :not_found} ->
        socket
        |> put_flash(:error, "Config not found")
        |> push_navigate(to: get_base_path(socket) <> "/configs")
    end
  end

  defp load_config(socket, _params) do
    socket
    |> assign(:page_title, "New Config")
    |> assign(:config_id, nil)
    |> assign(:config_name, "untitled.cm")
    |> assign(:tlvs, [])
    |> assign(:original_tlvs, [])
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div>
      <.breadcrumb>
        <:item href={@base_path}>Dashboard</:item>
        <:item href={"#{@base_path}/configs"}>Configs</:item>
        <:item><%= if @action == :new, do: "New Config", else: @config_name %></:item>
      </.breadcrumb>

      <div class="flex items-center justify-between mb-6">
        <div>
          <h1 class="text-2xl font-bold text-gray-100">
            <%= if @action == :new, do: "Create New Config", else: "Edit Config" %>
          </h1>
          <p class="text-gray-400 mt-1">
            <%= length(@tlvs) %> TLVs
            <span :if={@dirty} class="text-yellow-400">• Unsaved changes</span>
          </p>
        </div>
        <div class="flex items-center space-x-3">
          <.button variant="ghost" phx-click="discard" disabled={!@dirty}>
            Discard Changes
          </.button>
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
                <.icon name="hero-document-text" class="h-4 w-4 inline mr-2 text-gray-400" />
                Config (.txt)
              </button>
              <button
                phx-click="download"
                phx-value-format="hex"
                class="block w-full text-left px-4 py-2 text-sm text-gray-200 hover:bg-gray-700 rounded-b-lg"
              >
                <.icon name="hero-code-bracket-square" class="h-4 w-4 inline mr-2 text-gray-400" />
                Hex Dump
              </button>
            </div>
          </div>
          <.button phx-click="save" disabled={!@dirty}>
            <.icon name="hero-check" class="h-4 w-4 mr-2" />
            Save
          </.button>
        </div>
      </div>

      <div class="grid grid-cols-1 lg:grid-cols-4 gap-6">
        <div class="lg:col-span-3">
          <.card>
            <:header>
              <div class="flex items-center justify-between">
                <span>TLV Configuration</span>
                <div class="flex items-center space-x-2">
                  <.input
                    type="search"
                    name="search"
                    value={@search}
                    placeholder="Search..."
                    phx-change="search"
                    phx-debounce="300"
                    class="!w-48 !py-1"
                  />
                  <.button size="sm" phx-click="show-add-modal">
                    <.icon name="hero-plus" class="h-4 w-4 mr-1" />
                    Add TLV
                  </.button>
                </div>
              </div>
            </:header>

            <div class="-mx-6 -my-6">
              <%= if @tlvs == [] do %>
                <.empty_state>
                  <:icon><.icon name="hero-document-plus" class="h-12 w-12" /></:icon>
                  <:title>No TLVs yet</:title>
                  <:description>Start from a template or add TLVs manually.</:description>
                  <:action>
                    <div class="flex flex-col items-center space-y-4">
                      <div :if={@action == :new} class="space-y-3">
                        <div class="text-xs text-gray-500 text-center">Basic Templates</div>
                        <div class="flex flex-wrap justify-center gap-2">
                          <.button variant="secondary" size="sm" phx-click="load-template" phx-value-template="residential">
                            <.icon name="hero-home" class="h-4 w-4 mr-1" />
                            Residential
                          </.button>
                          <.button variant="secondary" size="sm" phx-click="load-template" phx-value-template="business">
                            <.icon name="hero-building-office" class="h-4 w-4 mr-1" />
                            Business
                          </.button>
                          <.button variant="secondary" size="sm" phx-click="load-template" phx-value-template="minimal">
                            <.icon name="hero-beaker" class="h-4 w-4 mr-1" />
                            Minimal
                          </.button>
                        </div>
                        <div class="text-xs text-gray-500 text-center mt-2">Speed Tiers</div>
                        <div class="flex flex-wrap justify-center gap-2">
                          <.button variant="secondary" size="sm" phx-click="load-template" phx-value-template="docsis30">
                            <.icon name="hero-signal" class="h-4 w-4 mr-1" />
                            100M/30M
                          </.button>
                          <.button variant="secondary" size="sm" phx-click="load-template" phx-value-template="gigabit">
                            <.icon name="hero-rocket-launch" class="h-4 w-4 mr-1" />
                            Gigabit
                          </.button>
                          <.button variant="secondary" size="sm" phx-click="load-template" phx-value-template="docsis31">
                            <.icon name="hero-bolt" class="h-4 w-4 mr-1" />
                            1G/100M
                          </.button>
                        </div>
                      </div>
                      <span :if={@action == :new} class="text-gray-500 text-sm">or</span>
                      <.button phx-click="show-add-modal">
                        <.icon name="hero-plus" class="h-4 w-4 mr-2" />
                        Add TLV Manually
                      </.button>
                    </div>
                  </:action>
                </.empty_state>
              <% else %>
                <div class="divide-y divide-gray-700">
                  <.editable_tlv_row
                    :for={{tlv, idx} <- filter_tlvs(@tlvs, @search) |> Enum.with_index()}
                    tlv={tlv}
                    index={idx}
                    path={to_string(idx)}
                    selected={@selected_tlv_path == to_string(idx)}
                    expanded={MapSet.member?(@expanded, to_string(idx))}
                    editing_path={@editing_path}
                    editing_value={@editing_value}
                    expanded_set={@expanded}
                  />
                </div>
              <% end %>
            </div>
          </.card>
        </div>

        <div class="lg:col-span-1 space-y-6">
          <.card>
            <:header>Config Info</:header>
            <div class="space-y-4">
              <.input
                type="text"
                name="config_name"
                label="Filename"
                value={@config_name}
                phx-change="update-name"
                phx-debounce="500"
              />
              <div>
                <label class="block text-sm font-medium text-gray-300 mb-1">TLV Count</label>
                <p class="text-2xl font-bold text-gray-100"><%= length(@tlvs) %></p>
              </div>
              <div>
                <label class="block text-sm font-medium text-gray-300 mb-1">Status</label>
                <.badge :if={@dirty} variant="warning">Modified</.badge>
                <.badge :if={!@dirty} variant="success">Saved</.badge>
              </div>
            </div>
          </.card>

          <.card>
            <:header>Quick Actions</:header>
            <div class="space-y-2">
              <.button variant="secondary" class="w-full justify-start" phx-click="show-add-modal">
                <.icon name="hero-plus" class="h-4 w-4 mr-2" />
                Add TLV
              </.button>
              <.button variant="secondary" class="w-full justify-start" phx-click="expand-all">
                <.icon name="hero-arrows-pointing-out" class="h-4 w-4 mr-2" />
                Expand All
              </.button>
              <.button variant="secondary" class="w-full justify-start" phx-click="collapse-all">
                <.icon name="hero-arrows-pointing-in" class="h-4 w-4 mr-2" />
                Collapse All
              </.button>
            </div>
          </.card>

          <.card :if={@action == :new && @tlvs == []}>
            <:header>Start from Template</:header>
            <div class="space-y-2">
              <p class="text-xs text-gray-500 mb-2">Basic</p>
              <.template_button template="residential" name="Residential" description="Standard home cable modem" />
              <.template_button template="business" name="Business" description="Enhanced business config" />
              <.template_button template="minimal" name="Minimal" description="Basic testing config" />

              <p class="text-xs text-gray-500 mt-4 mb-2">DOCSIS Version</p>
              <.template_button template="docsis30" name="DOCSIS 3.0" description="100M/30M bonded service flows" />
              <.template_button template="docsis31" name="DOCSIS 3.1" description="1G/100M gigabit service flows" />

              <p class="text-xs text-gray-500 mt-4 mb-2">Features</p>
              <.template_button template="gigabit" name="Gigabit" description="1G downstream, 35M upstream" />
              <.template_button template="ipv6" name="IPv6" description="100M/10M service flows" />
            </div>
          </.card>

          <.card>
            <:header>Common TLVs</:header>
            <div class="space-y-1">
              <.quick_add_button type={3} name="Net Access" />
              <.quick_add_button type={4} name="Class of Service" />
              <.quick_add_button type={17} name="Baseline Privacy" />
              <.quick_add_button type={18} name="Max CPE" />
              <.quick_add_button type={24} name="Upstream Service Flow" />
              <.quick_add_button type={25} name="Downstream Service Flow" />
            </div>
          </.card>
        </div>
      </div>

      <!-- Edit TLV Modal -->
      <.modal
        :if={@edit_modal}
        id="edit-modal"
        show={true}
        on_cancel={JS.push("close-edit-modal")}
      >
        <:title>Edit TLV <%= @edit_modal.type %></:title>
        <.edit_tlv_form tlv={@edit_modal} />
        <:footer>
          <.button variant="ghost" phx-click="close-edit-modal">Cancel</.button>
          <.button phx-click="save-tlv-edit">Save Changes</.button>
        </:footer>
      </.modal>

      <!-- Add TLV Modal -->
      <.modal
        :if={@add_modal}
        id="add-modal"
        show={true}
        on_cancel={JS.push("close-add-modal")}
      >
        <:title>
          <%= if @add_modal[:insert_after] do %>
            Insert TLV after position <%= @add_modal[:insert_after] %>
          <% else %>
            Add New TLV
          <% end %>
        </:title>
        <.add_tlv_form available_types={get_available_tlv_types()} selected={@add_modal} />
        <:footer>
          <.button variant="ghost" phx-click="close-add-modal">Cancel</.button>
          <.button phx-click="add-tlv" disabled={!@add_modal[:type]}>
            <%= if @add_modal[:insert_after], do: "Insert TLV", else: "Add TLV" %>
          </.button>
        </:footer>
      </.modal>

      <!-- Delete Confirmation Modal -->
      <.modal
        :if={@delete_confirm}
        id="delete-modal"
        show={true}
        on_cancel={JS.push("cancel-delete")}
      >
        <:title>Delete TLV</:title>
        <p class="text-gray-300">
          Are you sure you want to delete TLV <strong class="text-gray-100"><%= @delete_confirm.type %></strong>
          (<%= get_tlv_name(@delete_confirm) %>)?
        </p>
        <:footer>
          <.button variant="ghost" phx-click="cancel-delete">Cancel</.button>
          <.button variant="danger" phx-click="confirm-delete">Delete</.button>
        </:footer>
      </.modal>
    </div>
    """
  end

  # ============================================================================
  # Editable TLV Row Component
  # ============================================================================

  defp editable_tlv_row(assigns) do
    has_children = has_sub_tlvs?(assigns.tlv)
    is_editing = assigns.editing_path == assigns.path
    is_snmp = is_snmp_object?(assigns.tlv)
    is_editable = !has_children && !is_snmp

    assigns =
      assigns
      |> assign(:has_children, has_children)
      |> assign(:is_editing, is_editing)
      |> assign(:is_editable, is_editable)
      |> assign(:is_snmp, is_snmp)

    ~H"""
    <div class={[
      "px-6 py-3 hover:bg-gray-700/30 transition-colors",
      @selected && "bg-blue-900/20 border-l-2 border-blue-500",
      @is_editing && "bg-blue-900/30 ring-1 ring-blue-500"
    ]}>
      <div class="flex items-center justify-between">
        <div class="flex items-center space-x-3 flex-1 min-w-0">
          <button
            :if={@has_children}
            phx-click="toggle-expand"
            phx-value-path={@path}
            class="p-1 hover:bg-gray-600 rounded"
          >
            <.icon
              name={if @expanded, do: "hero-chevron-down", else: "hero-chevron-right"}
              class="h-4 w-4 text-gray-400"
            />
          </button>
          <span :if={!@has_children} class="w-6"></span>

          <.tlv_type_badge type={get_tlv_type(@tlv)} name={get_tlv_name(@tlv)} />

          <!-- Inline editing form -->
          <%= if @is_editing do %>
            <form phx-submit="save-inline-edit" phx-change="update-inline-edit" class="flex-1 flex items-center space-x-2">
              <.inline_edit_input tlv={@tlv} value={@editing_value} />
              <button type="submit" class="p-1 text-green-400 hover:text-green-300 hover:bg-gray-700 rounded" title="Save">
                <.icon name="hero-check" class="h-4 w-4" />
              </button>
              <button type="button" phx-click="cancel-inline-edit" class="p-1 text-gray-400 hover:text-gray-300 hover:bg-gray-700 rounded" title="Cancel">
                <.icon name="hero-x-mark" class="h-4 w-4" />
              </button>
            </form>
          <% else %>
            <!-- SNMP TLVs don't show inline value (card shown below) -->
            <%= if @is_snmp do %>
              <span class="text-sm text-gray-500 italic">SNMP Object (see below)</span>
            <% else %>
              <!-- Clickable value display -->
              <span
                class={[
                  "text-sm font-mono truncate",
                  @is_editable && "text-gray-200 cursor-pointer hover:text-blue-400 hover:bg-gray-700/50 px-2 py-1 rounded",
                  !@is_editable && "text-gray-400"
                ]}
                phx-click={@is_editable && "start-inline-edit"}
                phx-value-path={@path}
                title={@is_editable && "Click to edit"}
              >
                <%= format_tlv_value(@tlv) %>
              </span>
            <% end %>
          <% end %>
        </div>

        <div :if={!@is_editing} class="flex items-center space-x-1 ml-4">
          <button
            phx-click="edit-tlv"
            phx-value-path={@path}
            class="p-1.5 text-gray-400 hover:text-blue-400 hover:bg-gray-700 rounded"
            title="Edit (advanced)"
          >
            <.icon name="hero-pencil-square" class="h-4 w-4" />
          </button>
          <button
            phx-click="insert-tlv-after"
            phx-value-path={@path}
            class="p-1.5 text-gray-400 hover:text-cyan-400 hover:bg-gray-700 rounded"
            title="Insert new TLV after"
          >
            <.icon name="hero-plus-circle" class="h-4 w-4" />
          </button>
          <button
            phx-click="duplicate-tlv"
            phx-value-path={@path}
            class="p-1.5 text-gray-400 hover:text-green-400 hover:bg-gray-700 rounded"
            title="Duplicate"
          >
            <.icon name="hero-document-duplicate" class="h-4 w-4" />
          </button>
          <button
            phx-click="move-tlv-up"
            phx-value-path={@path}
            class="p-1.5 text-gray-400 hover:text-gray-200 hover:bg-gray-700 rounded"
            title="Move Up"
            disabled={@index == 0}
          >
            <.icon name="hero-arrow-up" class="h-4 w-4" />
          </button>
          <button
            phx-click="move-tlv-down"
            phx-value-path={@path}
            class="p-1.5 text-gray-400 hover:text-gray-200 hover:bg-gray-700 rounded"
            title="Move Down"
          >
            <.icon name="hero-arrow-down" class="h-4 w-4" />
          </button>
          <button
            phx-click="delete-tlv"
            phx-value-path={@path}
            class="p-1.5 text-gray-400 hover:text-red-400 hover:bg-gray-700 rounded"
            title="Delete"
          >
            <.icon name="hero-trash" class="h-4 w-4" />
          </button>
        </div>
      </div>

      <!-- SNMP Object Card -->
      <div :if={@is_snmp} class="mt-2 ml-8">
        <.snmp_display_card tlv={@tlv} path={@path} />
      </div>

      <!-- Sub-TLVs -->
      <div :if={@has_children && @expanded} class="mt-2 ml-8 border-l border-gray-700 pl-4 space-y-2">
        <.editable_tlv_row
          :for={{sub_tlv, sub_idx} <- Enum.with_index(get_sub_tlvs(@tlv))}
          tlv={sub_tlv}
          index={sub_idx}
          path={"#{@path}.#{sub_idx}"}
          selected={false}
          expanded={MapSet.member?(@expanded_set, "#{@path}.#{sub_idx}")}
          editing_path={@editing_path}
          editing_value={@editing_value}
          expanded_set={@expanded_set}
        />
      </div>
    </div>
    """
  end

  defp is_snmp_object?(%{type: 48, value_type: :asn1_der, formatted_value: fv})
       when is_map(fv) and is_map_key(fv, :oid),
       do: true

  defp is_snmp_object?(%{type: 48, value_type: :asn1_der, formatted_value: fv})
       when is_map(fv) and is_map_key(fv, "oid"),
       do: true

  defp is_snmp_object?(_), do: false

  # SNMP display card for editor (read-only view, click edit button for form)
  defp snmp_display_card(assigns) do
    formatted = Map.get(assigns.tlv, :formatted_value) || Map.get(assigns.tlv, "formatted_value") || %{}

    oid = Map.get(formatted, :oid) || Map.get(formatted, "oid") || ""
    oid_name = Map.get(formatted, :oid_name) || Map.get(formatted, "oid_name")
    snmp_type = Map.get(formatted, :type) || Map.get(formatted, "type") || ""
    snmp_value = Map.get(formatted, :value) || Map.get(formatted, "value") || ""

    assigns =
      assigns
      |> assign(:oid, oid)
      |> assign(:oid_name, oid_name)
      |> assign(:snmp_type, snmp_type)
      |> assign(:snmp_value, snmp_value)

    ~H"""
    <div class="bg-gray-800 rounded-lg border border-gray-700 p-3 text-sm">
      <div class="grid grid-cols-[auto_1fr] gap-x-4 gap-y-1">
        <span class="text-gray-500">OID:</span>
        <span class="font-mono text-blue-400 text-xs"><%= @oid %></span>

        <span :if={@oid_name} class="text-gray-500">Name:</span>
        <span :if={@oid_name} class="text-cyan-400"><%= @oid_name %></span>

        <span class="text-gray-500">Type:</span>
        <span class="text-gray-400"><%= @snmp_type %></span>

        <span class="text-gray-500">Value:</span>
        <span class="font-mono text-green-400"><%= @snmp_value %></span>
      </div>
      <div class="mt-2 text-xs text-gray-500">
        Click the <.icon name="hero-pencil-square" class="h-3 w-3 inline" /> edit button to modify
      </div>
    </div>
    """
  end

  defp inline_edit_input(assigns) do
    data_type = get_data_type(assigns.tlv)
    assigns = assign(assigns, :data_type, data_type)

    ~H"""
    <%= case @data_type do %>
      <% :boolean -> %>
        <select name="value" class="flex-1 bg-gray-900 border border-gray-600 rounded px-2 py-1 text-sm text-gray-100 focus:ring-blue-500 focus:border-blue-500">
          <option value="1" selected={@value == "1"}>Enabled (1)</option>
          <option value="0" selected={@value == "0"}>Disabled (0)</option>
        </select>
      <% :ip -> %>
        <input
          type="text"
          name="value"
          value={@value}
          placeholder="192.168.1.1"
          class="flex-1 bg-gray-900 border border-gray-600 rounded px-2 py-1 text-sm font-mono text-gray-100 focus:ring-blue-500 focus:border-blue-500"
          autofocus
        />
      <% :mac -> %>
        <input
          type="text"
          name="value"
          value={@value}
          placeholder="00:11:22:33:44:55"
          class="flex-1 bg-gray-900 border border-gray-600 rounded px-2 py-1 text-sm font-mono text-gray-100 focus:ring-blue-500 focus:border-blue-500"
          autofocus
        />
      <% :uint -> %>
        <input
          type="number"
          name="value"
          value={@value}
          min="0"
          class="flex-1 bg-gray-900 border border-gray-600 rounded px-2 py-1 text-sm font-mono text-gray-100 focus:ring-blue-500 focus:border-blue-500"
          autofocus
        />
      <% _ -> %>
        <input
          type="text"
          name="value"
          value={@value}
          class="flex-1 bg-gray-900 border border-gray-600 rounded px-2 py-1 text-sm font-mono text-gray-100 focus:ring-blue-500 focus:border-blue-500"
          autofocus
        />
    <% end %>
    """
  end

  # ============================================================================
  # Edit TLV Form Component
  # ============================================================================

  defp edit_tlv_form(assigns) do
    ~H"""
    <form phx-change="update-edit-form" class="space-y-4">
      <div class="grid grid-cols-2 gap-4">
        <div>
          <label class="block text-sm font-medium text-gray-300 mb-1">Type</label>
          <p class="text-lg font-bold text-gray-100"><%= @tlv.type %></p>
        </div>
        <div>
          <label class="block text-sm font-medium text-gray-300 mb-1">Name</label>
          <p class="text-gray-200"><%= get_tlv_name(@tlv) %></p>
        </div>
      </div>

      <.tlv_value_input tlv={@tlv} />

      <div :if={@tlv[:preview_bytes]} class="mt-4">
        <label class="block text-sm font-medium text-gray-300 mb-1">Preview (encoded bytes)</label>
        <code class="block bg-gray-900 p-2 rounded text-sm font-mono text-cyan-400">
          <%= @tlv[:preview_bytes] %>
        </code>
      </div>
    </form>
    """
  end

  # ============================================================================
  # TLV Value Input Component
  # ============================================================================

  defp tlv_value_input(assigns) do
    data_type = get_data_type(assigns.tlv)
    assigns = assign(assigns, :data_type, data_type)

    ~H"""
    <%= case @data_type do %>
      <% :uint -> %>
        <.input
          type="number"
          name="value"
          label="Value (unsigned integer)"
          value={get_edit_value(@tlv)}
          min="0"
        />
      <% :boolean -> %>
        <div>
          <label class="block text-sm font-medium text-gray-300 mb-1">Value</label>
          <select name="value" class="w-full bg-gray-800 border border-gray-600 rounded-lg px-3 py-2 text-gray-100">
            <option value="1" selected={get_edit_value(@tlv) == "1"}>Enabled (1)</option>
            <option value="0" selected={get_edit_value(@tlv) == "0"}>Disabled (0)</option>
          </select>
        </div>
      <% :ip -> %>
        <.input
          type="text"
          name="value"
          label="IP Address"
          value={get_edit_value(@tlv)}
          placeholder="192.168.1.1"
          pattern="^(?:[0-9]{1,3}\.){3}[0-9]{1,3}$"
        />
      <% :mac -> %>
        <.input
          type="text"
          name="value"
          label="MAC Address"
          value={get_edit_value(@tlv)}
          placeholder="00:11:22:33:44:55"
        />
      <% :string -> %>
        <.input
          type="text"
          name="value"
          label="String Value"
          value={get_edit_value(@tlv)}
        />
      <% :hex -> %>
        <.input
          type="text"
          name="value"
          label="Hex Value"
          value={get_edit_value(@tlv)}
          placeholder="0a1b2c3d"
        />
      <% :snmp -> %>
        <.snmp_edit_form tlv={@tlv} />
      <% _ -> %>
        <.input
          type="textarea"
          name="value"
          label="Value"
          value={get_edit_value(@tlv)}
          rows={3}
        />
    <% end %>
    """
  end

  # ============================================================================
  # SNMP Edit Form Component
  # ============================================================================

  defp snmp_edit_form(assigns) do
    formatted = Map.get(assigns.tlv, :formatted_value) || Map.get(assigns.tlv, "formatted_value") || %{}

    oid = Map.get(formatted, :oid) || Map.get(formatted, "oid") || ""
    oid_name = Map.get(formatted, :oid_name) || Map.get(formatted, "oid_name")
    snmp_type = Map.get(formatted, :type) || Map.get(formatted, "type") || "STRING"
    snmp_value = Map.get(formatted, :value) || Map.get(formatted, "value") || ""

    assigns =
      assigns
      |> assign(:oid, oid)
      |> assign(:oid_name, oid_name)
      |> assign(:snmp_type, snmp_type)
      |> assign(:snmp_value, snmp_value)

    ~H"""
    <div class="space-y-4 bg-gray-800 rounded-lg border border-gray-700 p-4">
      <h4 class="text-sm font-medium text-gray-300 flex items-center">
        <.icon name="hero-server" class="h-4 w-4 mr-2 text-blue-400" />
        SNMP MIB Object
      </h4>

      <.input
        type="text"
        name="snmp_oid"
        label="OID"
        value={@oid}
        placeholder="1.3.6.1.2.1.1.5.0"
        class="font-mono"
      />

      <div :if={@oid_name} class="text-sm text-gray-400">
        <span class="text-gray-500">Known as:</span> <%= @oid_name %>
      </div>

      <div>
        <label class="block text-sm font-medium text-gray-300 mb-1">Type</label>
        <select
          name="snmp_type"
          class="w-full bg-gray-900 border border-gray-600 rounded-lg px-3 py-2 text-gray-100"
        >
          <option value="STRING" selected={@snmp_type in ["STRING", "OCTET STRING"]}>STRING (text)</option>
          <option value="INTEGER" selected={@snmp_type == "INTEGER"}>INTEGER</option>
          <option value="IpAddress" selected={@snmp_type == "IpAddress"}>IpAddress</option>
          <option value="Counter32" selected={@snmp_type == "Counter32"}>Counter32</option>
          <option value="Gauge32" selected={@snmp_type == "Gauge32"}>Gauge32</option>
          <option value="TimeTicks" selected={@snmp_type == "TimeTicks"}>TimeTicks</option>
          <option value="OCTET STRING" selected={@snmp_type == "OCTET STRING" and not String.printable?(@snmp_value)}>OCTET STRING (hex)</option>
        </select>
      </div>

      <.input
        type="text"
        name="snmp_value"
        label="Value"
        value={@snmp_value}
        placeholder="Enter value..."
        class="font-mono"
      />
    </div>
    """
  end

  # ============================================================================
  # Add TLV Form Component
  # ============================================================================

  defp add_tlv_form(assigns) do
    ~H"""
    <form phx-change="update-add-form" class="space-y-4">
      <div>
        <label class="block text-sm font-medium text-gray-300 mb-1">TLV Type</label>
        <select
          name="type"
          class="w-full bg-gray-800 border border-gray-600 rounded-lg px-3 py-2 text-gray-100"
        >
          <option value="">Select a TLV type...</option>
          <%= for {type, name} <- @available_types do %>
            <option value={type} selected={@selected[:type] == type}>
              <%= type %> - <%= name %>
            </option>
          <% end %>
        </select>
      </div>

      <div :if={@selected[:type]}>
        <.input
          type="text"
          name="value"
          label="Value"
          value={@selected[:value] || ""}
          placeholder="Enter value..."
        />
      </div>
    </form>
    """
  end

  # ============================================================================
  # Quick Add Button Component
  # ============================================================================

  defp quick_add_button(assigns) do
    ~H"""
    <button
      phx-click="quick-add-tlv"
      phx-value-type={@type}
      class="w-full text-left px-3 py-2 text-sm text-gray-300 hover:bg-gray-700 hover:text-gray-100 rounded transition-colors"
    >
      <span class="font-mono text-blue-400 mr-2"><%= @type %></span>
      <%= @name %>
    </button>
    """
  end

  # ============================================================================
  # Template Button Component
  # ============================================================================

  defp template_button(assigns) do
    ~H"""
    <button
      phx-click="load-template"
      phx-value-template={@template}
      class="w-full text-left px-3 py-3 bg-gray-700/50 hover:bg-gray-700 rounded-lg transition-colors group"
    >
      <div class="flex items-center justify-between">
        <span class="font-medium text-gray-100 group-hover:text-blue-400"><%= @name %></span>
        <.icon name="hero-arrow-right" class="h-4 w-4 text-gray-500 group-hover:text-blue-400" />
      </div>
      <p class="text-xs text-gray-500 mt-1"><%= @description %></p>
    </button>
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
  def handle_event("update-name", %{"config_name" => name}, socket) do
    {:noreply, socket |> assign(:config_name, name) |> assign(:dirty, true)}
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
  def handle_event("expand-all", _params, socket) do
    paths = collect_all_expandable_paths(socket.assigns.tlvs, "")
    {:noreply, assign(socket, :expanded, MapSet.new(paths))}
  end

  @impl true
  def handle_event("collapse-all", _params, socket) do
    {:noreply, assign(socket, :expanded, MapSet.new())}
  end

  @impl true
  def handle_event("edit-tlv", %{"path" => path}, socket) do
    tlv = get_tlv_at_path(socket.assigns.tlvs, path)

    if tlv do
      edit_modal = Map.merge(tlv, %{path: path, type: get_tlv_type(tlv)})
      {:noreply, assign(socket, :edit_modal, edit_modal)}
    else
      {:noreply, put_flash(socket, :error, "TLV not found at path #{path}")}
    end
  end

  @impl true
  def handle_event("update-edit-form", params, socket) do
    edit_modal = socket.assigns.edit_modal

    edit_modal =
      cond do
        # SNMP form fields
        Map.has_key?(params, "snmp_oid") or Map.has_key?(params, "snmp_type") or
            Map.has_key?(params, "snmp_value") ->
          edit_modal
          |> maybe_put(:snmp_oid, params["snmp_oid"])
          |> maybe_put(:snmp_type, params["snmp_type"])
          |> maybe_put(:snmp_value, params["snmp_value"])
          |> Map.put(:edit_type, :snmp)

        # Regular value field
        Map.has_key?(params, "value") ->
          Map.put(edit_modal, :edit_value, params["value"])

        true ->
          edit_modal
      end

    {:noreply, assign(socket, :edit_modal, edit_modal)}
  end

  @impl true
  def handle_event("save-tlv-edit", _params, socket) do
    edit_modal = socket.assigns.edit_modal
    path = edit_modal.path
    current_tlv = get_tlv_at_path(socket.assigns.tlvs, path)

    # Handle SNMP edits specially
    updated_tlv =
      if edit_modal[:edit_type] == :snmp do
        update_snmp_tlv(current_tlv, edit_modal)
      else
        # Regular update
        new_value = edit_modal[:edit_value] || get_edit_value(edit_modal)
        update_tlv_value(current_tlv, new_value)
      end

    # Update the TLV at the given path (handles nested paths)
    tlvs = update_tlv_at_path(socket.assigns.tlvs, path, updated_tlv)

    socket =
      socket
      |> assign(:tlvs, tlvs)
      |> assign(:edit_modal, nil)
      |> assign(:dirty, true)

    {:noreply, socket}
  end

  @impl true
  def handle_event("close-edit-modal", _params, socket) do
    {:noreply, assign(socket, :edit_modal, nil)}
  end

  # ============================================================================
  # Inline Editing Event Handlers
  # ============================================================================

  @impl true
  def handle_event("start-inline-edit", %{"path" => path}, socket) do
    tlv = get_tlv_at_path(socket.assigns.tlvs, path)

    if tlv do
      current_value = get_edit_value(tlv)

      socket =
        socket
        |> assign(:editing_path, path)
        |> assign(:editing_value, current_value)

      {:noreply, socket}
    else
      {:noreply, socket}
    end
  end

  @impl true
  def handle_event("update-inline-edit", %{"value" => value}, socket) do
    {:noreply, assign(socket, :editing_value, value)}
  end

  @impl true
  def handle_event("save-inline-edit", _params, socket) do
    path = socket.assigns.editing_path
    new_value = socket.assigns.editing_value

    if path && new_value do
      current_tlv = get_tlv_at_path(socket.assigns.tlvs, path)
      updated_tlv = update_tlv_value(current_tlv, new_value)
      tlvs = update_tlv_at_path(socket.assigns.tlvs, path, updated_tlv)

      socket =
        socket
        |> assign(:tlvs, tlvs)
        |> assign(:editing_path, nil)
        |> assign(:editing_value, nil)
        |> assign(:dirty, true)

      {:noreply, socket}
    else
      {:noreply, assign(socket, editing_path: nil, editing_value: nil)}
    end
  end

  @impl true
  def handle_event("cancel-inline-edit", _params, socket) do
    {:noreply, assign(socket, editing_path: nil, editing_value: nil)}
  end

  @impl true
  def handle_event("show-add-modal", _params, socket) do
    {:noreply, assign(socket, :add_modal, %{})}
  end

  @impl true
  def handle_event("insert-tlv-after", %{"path" => path}, socket) do
    # Open add modal with insert position
    {:noreply, assign(socket, :add_modal, %{insert_after: path})}
  end

  @impl true
  def handle_event("update-add-form", params, socket) do
    add_modal =
      socket.assigns.add_modal
      |> Map.put(:type, params["type"] && String.to_integer(params["type"]))
      |> Map.put(:value, params["value"])

    {:noreply, assign(socket, :add_modal, add_modal)}
  end

  @impl true
  def handle_event("add-tlv", _params, socket) do
    add_modal = socket.assigns.add_modal

    if add_modal[:type] do
      new_tlv = create_tlv(add_modal[:type], add_modal[:value] || "")

      tlvs =
        if insert_after = add_modal[:insert_after] do
          # Insert after specified position
          idx = String.to_integer(insert_after)
          List.insert_at(socket.assigns.tlvs, idx + 1, new_tlv)
        else
          # Append to end
          socket.assigns.tlvs ++ [new_tlv]
        end

      socket =
        socket
        |> assign(:tlvs, tlvs)
        |> assign(:add_modal, nil)
        |> assign(:dirty, true)

      {:noreply, socket}
    else
      {:noreply, socket}
    end
  end

  @impl true
  def handle_event("quick-add-tlv", %{"type" => type_str}, socket) do
    type = String.to_integer(type_str)
    new_tlv = create_tlv(type, default_value_for_type(type))
    tlvs = socket.assigns.tlvs ++ [new_tlv]

    socket =
      socket
      |> assign(:tlvs, tlvs)
      |> assign(:dirty, true)

    {:noreply, socket}
  end

  @impl true
  def handle_event("load-template", %{"template" => template_name}, socket) do
    template_atom = String.to_existing_atom(template_name)

    case load_template_tlvs(template_atom) do
      {:ok, tlvs} ->
        socket =
          socket
          |> assign(:tlvs, tlvs)
          |> assign(:dirty, true)
          |> assign(:config_name, "#{template_name}_config.cm")
          |> put_flash(:info, "Loaded #{template_name} template with #{length(tlvs)} TLVs")

        {:noreply, socket}

      {:error, reason} ->
        {:noreply, put_flash(socket, :error, "Failed to load template: #{reason}")}
    end
  rescue
    ArgumentError ->
      {:noreply, put_flash(socket, :error, "Unknown template: #{template_name}")}
  end

  @impl true
  def handle_event("close-add-modal", _params, socket) do
    {:noreply, assign(socket, :add_modal, nil)}
  end

  @impl true
  def handle_event("duplicate-tlv", %{"path" => path}, socket) do
    idx = String.to_integer(path)
    tlv = Enum.at(socket.assigns.tlvs, idx)
    tlvs = List.insert_at(socket.assigns.tlvs, idx + 1, tlv)

    socket =
      socket
      |> assign(:tlvs, tlvs)
      |> assign(:dirty, true)

    {:noreply, socket}
  end

  @impl true
  def handle_event("move-tlv-up", %{"path" => path}, socket) do
    idx = String.to_integer(path)

    if idx > 0 do
      tlvs = swap_at(socket.assigns.tlvs, idx, idx - 1)
      {:noreply, socket |> assign(:tlvs, tlvs) |> assign(:dirty, true)}
    else
      {:noreply, socket}
    end
  end

  @impl true
  def handle_event("move-tlv-down", %{"path" => path}, socket) do
    idx = String.to_integer(path)

    if idx < length(socket.assigns.tlvs) - 1 do
      tlvs = swap_at(socket.assigns.tlvs, idx, idx + 1)
      {:noreply, socket |> assign(:tlvs, tlvs) |> assign(:dirty, true)}
    else
      {:noreply, socket}
    end
  end

  @impl true
  def handle_event("delete-tlv", %{"path" => path}, socket) do
    idx = String.to_integer(path)
    tlv = Enum.at(socket.assigns.tlvs, idx)
    {:noreply, assign(socket, :delete_confirm, Map.put(tlv, :path, path))}
  end

  @impl true
  def handle_event("cancel-delete", _params, socket) do
    {:noreply, assign(socket, :delete_confirm, nil)}
  end

  @impl true
  def handle_event("confirm-delete", _params, socket) do
    idx = String.to_integer(socket.assigns.delete_confirm.path)
    tlvs = List.delete_at(socket.assigns.tlvs, idx)

    socket =
      socket
      |> assign(:tlvs, tlvs)
      |> assign(:delete_confirm, nil)
      |> assign(:dirty, true)

    {:noreply, socket}
  end

  @impl true
  def handle_event("save", _params, socket) do
    case save_config(socket) do
      {:ok, id} ->
        socket =
          socket
          |> assign(:config_id, id)
          |> assign(:dirty, false)
          |> assign(:original_tlvs, socket.assigns.tlvs)
          |> put_flash(:info, "Config saved successfully")

        {:noreply, socket}

      {:error, reason} ->
        {:noreply, put_flash(socket, :error, "Failed to save: #{reason}")}
    end
  end

  @impl true
  def handle_event("discard", _params, socket) do
    socket =
      socket
      |> assign(:tlvs, socket.assigns.original_tlvs)
      |> assign(:dirty, false)

    {:noreply, socket}
  end

  @impl true
  def handle_event("download", %{"format" => format}, socket) do
    {content, filename, _content_type} = prepare_download(socket, format)

    socket =
      push_event(socket, "download", %{
        content: Base.encode64(content),
        filename: filename,
        binary: true
      })

    {:noreply, socket}
  end

  # ============================================================================
  # Private Functions
  # ============================================================================

  # Recursively collect all paths that have sub-TLVs
  defp collect_all_expandable_paths(tlvs, prefix) when is_list(tlvs) do
    tlvs
    |> Enum.with_index()
    |> Enum.flat_map(fn {tlv, idx} ->
      path = if prefix == "", do: to_string(idx), else: "#{prefix}.#{idx}"

      if has_sub_tlvs?(tlv) do
        sub_paths = collect_all_expandable_paths(get_sub_tlvs(tlv), path)
        [path | sub_paths]
      else
        []
      end
    end)
  end

  defp collect_all_expandable_paths(_, _), do: []

  defp maybe_put(map, _key, nil), do: map
  defp maybe_put(map, key, value), do: Map.put(map, key, value)

  defp update_snmp_tlv(tlv, edit_modal) do
    # Get SNMP fields from edit_modal, falling back to current values
    current_formatted = Map.get(tlv, :formatted_value) || %{}

    oid =
      edit_modal[:snmp_oid] || Map.get(current_formatted, :oid) ||
        Map.get(current_formatted, "oid") || ""

    type =
      edit_modal[:snmp_type] || Map.get(current_formatted, :type) ||
        Map.get(current_formatted, "type") || "STRING"

    value =
      edit_modal[:snmp_value] || Map.get(current_formatted, :value) ||
        Map.get(current_formatted, "value") || ""

    # Parse value based on type
    parsed_value =
      case type do
        "INTEGER" -> String.to_integer(value)
        "Counter32" -> String.to_integer(value)
        "Gauge32" -> String.to_integer(value)
        "TimeTicks" -> String.to_integer(value)
        _ -> value
      end

    # Create the SNMP object map for ValueParser
    snmp_data = %{oid: oid, type: type, value: parsed_value}

    # Encode the SNMP value using ValueParser
    case Bindocsis.ValueParser.parse_value(:asn1_der, snmp_data, []) do
      {:ok, encoded_binary} ->
        # Update the TLV with new encoded value and formatted_value
        tlv
        |> Map.put(:value, encoded_binary)
        |> Map.put(:formatted_value, %{oid: oid, type: type, value: value})
        |> Map.put(:length, byte_size(encoded_binary))

      {:error, _reason} ->
        # Keep original on error
        tlv
    end
  end

  defp toggle_dropdown(id) do
    Phoenix.LiveView.JS.toggle(to: "##{id}")
  end

  defp prepare_download(socket, "binary") do
    # Unenrich TLVs before binary generation
    unenriched_tlvs = Bindocsis.TlvEnricher.unenrich_tlvs(socket.assigns.tlvs)

    case Bindocsis.generate(unenriched_tlvs, format: :binary) do
      {:ok, binary} ->
        {binary, socket.assigns.config_name, "application/octet-stream"}

      {:error, _} ->
        {"", socket.assigns.config_name, "application/octet-stream"}
    end
  end

  defp prepare_download(socket, "json") do
    # Try to enrich the TLVs for better JSON output
    enriched = enrich_tlvs(socket.assigns.tlvs)

    content =
      case Bindocsis.generate(enriched, format: :json) do
        {:ok, json} -> json
        {:error, _} -> Jason.encode!(enriched, pretty: true)
      end

    filename = String.replace(socket.assigns.config_name, ~r/\.(cm|bin)$/, ".json")
    {content, filename, "application/json"}
  end

  defp prepare_download(socket, "yaml") do
    enriched = enrich_tlvs(socket.assigns.tlvs)

    content =
      case Bindocsis.generate(enriched, format: :yaml) do
        {:ok, yaml} -> yaml
        {:error, _} -> "# Error generating YAML\n"
      end

    filename = String.replace(socket.assigns.config_name, ~r/\.(cm|bin)$/, ".yaml")
    {content, filename, "text/yaml"}
  end

  defp prepare_download(socket, "config") do
    enriched = enrich_tlvs(socket.assigns.tlvs)

    content =
      case Bindocsis.generate(enriched, format: :config) do
        {:ok, config} -> config
        {:error, _} -> "# Error generating config\n"
      end

    filename = String.replace(socket.assigns.config_name, ~r/\.(cm|bin)$/, ".txt")
    {content, filename, "text/plain"}
  end

  defp prepare_download(socket, "hex") do
    # Generate binary first, then format as hex dump
    unenriched_tlvs = Bindocsis.TlvEnricher.unenrich_tlvs(socket.assigns.tlvs)

    content =
      case Bindocsis.generate(unenriched_tlvs, format: :binary) do
        {:ok, binary} -> format_hex_dump(binary)
        {:error, _} -> "# Error generating hex dump\n"
      end

    filename = String.replace(socket.assigns.config_name, ~r/\.(cm|bin)$/, "_hex.txt")
    {content, filename, "text/plain"}
  end

  defp format_hex_dump(binary) do
    binary
    |> :binary.bin_to_list()
    |> Enum.chunk_every(16)
    |> Enum.with_index()
    |> Enum.map(fn {chunk, idx} ->
      offset = String.pad_leading(Integer.to_string(idx * 16, 16), 8, "0")
      hex_part = chunk |> Enum.map(&String.pad_leading(Integer.to_string(&1, 16), 2, "0")) |> Enum.join(" ")
      ascii_part = chunk |> Enum.map(fn b -> if b >= 32 and b < 127, do: <<b>>, else: "." end) |> Enum.join("")
      "#{offset}  #{String.pad_trailing(hex_part, 48)}  |#{ascii_part}|"
    end)
    |> Enum.join("\n")
  end

  defp enrich_tlvs(tlvs) do
    # If TLVs already have names, they're enriched; otherwise try to enrich
    case Enum.any?(tlvs, &Map.has_key?(&1, :name)) do
      true ->
        tlvs

      false ->
        case Bindocsis.generate(tlvs, format: :binary) do
          {:ok, binary} ->
            case Bindocsis.parse(binary, format: :binary, enhanced: true) do
              {:ok, enriched} -> enriched
              _ -> tlvs
            end

          _ ->
            tlvs
        end
    end
  end

  defp get_base_path(socket) do
    case socket.assigns[:bindocsis_base_path] do
      "" -> ""
      nil -> ""
      base -> base
    end
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

  defp swap_at(list, idx1, idx2) do
    elem1 = Enum.at(list, idx1)
    elem2 = Enum.at(list, idx2)

    list
    |> List.replace_at(idx1, elem2)
    |> List.replace_at(idx2, elem1)
  end

  defp save_config(socket) do
    tlvs = socket.assigns.tlvs
    name = socket.assigns.config_name

    # Generate binary from TLVs
    case generate_binary(tlvs) do
      {:ok, binary} ->
        if socket.assigns.config_id do
          # Update existing
          ConfigStore.update(socket.assigns.config_id, %{
            name: name,
            parsed: tlvs,
            enriched: tlvs,
            raw_bytes: binary,
            modified: false
          })

          {:ok, socket.assigns.config_id}
        else
          # Create new
          ConfigStore.store(binary, name: name)
        end

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp generate_binary(tlvs) do
    # Unenrich TLVs before binary generation (converts formatted_value back to binary)
    unenriched_tlvs = Bindocsis.TlvEnricher.unenrich_tlvs(tlvs)

    # Use Bindocsis to generate binary from TLVs
    case Bindocsis.generate(unenriched_tlvs, format: :binary) do
      {:ok, binary} -> {:ok, binary}
      error -> error
    end
  rescue
    e -> {:error, Exception.message(e)}
  end

  # Load template TLVs from HumanConfig and convert to enriched format
  defp load_template_tlvs(template_name) do
    case Bindocsis.HumanConfig.generate_template(template_name) do
      {:ok, yaml_content} ->
        # Parse the YAML back to get TLVs
        case Bindocsis.HumanConfig.from_yaml(yaml_content) do
          {:ok, tlvs} ->
            # Enrich the TLVs for display in the editor
            enriched = Bindocsis.TlvEnricher.enrich_tlvs(tlvs)
            {:ok, enriched}

          {:error, reason} ->
            {:error, reason}
        end

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp create_tlv(type, value) do
    %{
      type: type,
      name: get_name_for_type(type),
      value: encode_value(type, value),
      length: byte_size(encode_value(type, value))
    }
  end

  defp update_tlv_value(tlv, new_value) do
    type = get_tlv_type(tlv)
    value_type = Map.get(tlv, :value_type) || Map.get(tlv, "value_type")
    encoded = encode_value_for_type(value_type, type, new_value)

    tlv
    |> Map.put(:value, encoded)
    |> Map.put(:formatted_value, new_value)
    |> Map.put(:length, byte_size(encoded))
  end

  defp encode_value_for_type(:uint, _type, value), do: encode_uint(value)
  defp encode_value_for_type(:uint8, _type, value), do: encode_uint(value, 1)
  defp encode_value_for_type(:uint16, _type, value), do: encode_uint(value, 2)
  defp encode_value_for_type(:uint32, _type, value), do: encode_uint(value, 4)
  defp encode_value_for_type(:boolean, _type, value), do: encode_boolean(value)
  defp encode_value_for_type(:ip, _type, value), do: encode_ip(value)
  defp encode_value_for_type(:ipv4, _type, value), do: encode_ip(value)
  defp encode_value_for_type(:mac, _type, value), do: encode_mac(value)
  defp encode_value_for_type(:mac_address, _type, value), do: encode_mac(value)
  defp encode_value_for_type(:hex, _type, value), do: decode_hex(value)
  defp encode_value_for_type(:hex_string, _type, value), do: decode_hex(value)
  defp encode_value_for_type(:string, _type, value), do: value
  defp encode_value_for_type(:string_zero, _type, value), do: value <> <<0>>
  defp encode_value_for_type(:frequency, _type, value), do: encode_uint(value, 4)
  defp encode_value_for_type(nil, type, value), do: encode_value(type, value)
  defp encode_value_for_type(_, type, value), do: encode_value(type, value)

  defp encode_uint(value, bytes \\ 4) do
    num = parse_int(value)
    <<num::unsigned-big-size(bytes * 8)>>
  end

  defp encode_boolean("1"), do: <<1>>
  defp encode_boolean("0"), do: <<0>>
  defp encode_boolean(true), do: <<1>>
  defp encode_boolean(false), do: <<0>>
  defp encode_boolean(val), do: <<parse_int(val)::8>>

  defp encode_ip(value) when is_binary(value) do
    case :inet.parse_address(String.to_charlist(value)) do
      {:ok, {a, b, c, d}} ->
        <<a, b, c, d>>

      {:ok, {a, b, c, d, e, f, g, h}} ->
        <<a::16, b::16, c::16, d::16, e::16, f::16, g::16, h::16>>

      _ ->
        value
    end
  end

  defp encode_mac(value) when is_binary(value) do
    value
    |> String.replace(~r/[:\-\.]/, "")
    |> Base.decode16!(case: :mixed)
  rescue
    _ -> value
  end

  defp decode_hex(value) when is_binary(value) do
    value
    |> String.replace(~r/[\s:\-]/, "")
    |> Base.decode16!(case: :mixed)
  rescue
    _ -> value
  end

  defp parse_int(val) when is_integer(val), do: val

  defp parse_int(val) when is_binary(val) do
    case Integer.parse(val) do
      {n, _} -> n
      :error -> 0
    end
  end

  defp parse_int(_), do: 0

  # Basic encode for new TLVs (type-based inference)
  defp encode_value(type, value) do
    case type do
      # Boolean types
      3 -> encode_boolean(value)
      # Unsigned integers
      # Downstream Frequency
      1 -> encode_uint(value, 4)
      # Upstream Channel ID
      2 -> encode_uint(value, 1)
      # Max CPE
      18 -> encode_uint(value, 1)
      # Default to string
      _ when is_binary(value) -> value
      _ -> to_string(value)
    end
  end

  defp get_name_for_type(type) do
    names = %{
      1 => "Downstream Frequency",
      2 => "Upstream Channel ID",
      3 => "Network Access",
      4 => "Class of Service",
      5 => "CM MIC",
      6 => "CMTS MIC",
      7 => "Software Upgrade Filename",
      8 => "SNMP Write-Access",
      9 => "SNMP MIB Object",
      10 => "Software Upgrade TFTP Server",
      11 => "SNMP V3 Notification Receiver",
      17 => "Baseline Privacy Configuration",
      18 => "Maximum Number of CPE",
      24 => "Upstream Service Flow",
      25 => "Downstream Service Flow",
      43 => "Vendor Specific"
    }

    Map.get(names, type, "TLV #{type}")
  end

  defp default_value_for_type(type) do
    case type do
      # Network Access enabled
      3 -> "1"
      # Max CPE
      18 -> "4"
      _ -> ""
    end
  end

  defp get_available_tlv_types do
    [
      {1, "Downstream Frequency"},
      {2, "Upstream Channel ID"},
      {3, "Network Access"},
      {4, "Class of Service"},
      {7, "Software Upgrade Filename"},
      {8, "SNMP Write-Access"},
      {9, "SNMP MIB Object"},
      {10, "Software Upgrade TFTP Server"},
      {17, "Baseline Privacy Configuration"},
      {18, "Maximum Number of CPE"},
      {19, "TFTP Server Timestamp"},
      {20, "TFTP Server Provisioned Modem Address"},
      {24, "Upstream Service Flow"},
      {25, "Downstream Service Flow"},
      {28, "Upstream Packet Classification"},
      {29, "Downstream Packet Classification"},
      {43, "Vendor Specific"}
    ]
  end

  # TLV accessor functions
  defp get_tlv_type(%{type: type}), do: type
  defp get_tlv_type(%{"type" => type}), do: type
  defp get_tlv_type(_), do: 0

  defp get_tlv_name(%{name: name}), do: name
  defp get_tlv_name(%{"name" => name}), do: name
  defp get_tlv_name(tlv), do: "TLV #{get_tlv_type(tlv)}"

  # Priority: formatted_value (from enrichment) > raw_value > value (binary)
  defp format_tlv_value(%{formatted_value: val}) when not is_nil(val),
    do: format_enriched_value(val)

  defp format_tlv_value(%{"formatted_value" => val}) when not is_nil(val),
    do: format_enriched_value(val)

  defp format_tlv_value(%{raw_value: val}) when not is_nil(val), do: to_string(val)
  defp format_tlv_value(%{"raw_value" => val}) when not is_nil(val), do: to_string(val)

  defp format_tlv_value(%{value: val}) when is_binary(val) and byte_size(val) <= 8 do
    Base.encode16(val, case: :lower)
  end

  defp format_tlv_value(%{value: val}) when is_binary(val) do
    Base.encode16(binary_part(val, 0, 8), case: :lower) <> "..."
  end

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

  # For edit forms - get the editable value
  defp get_edit_value(%{edit_value: val}) when not is_nil(val), do: val
  defp get_edit_value(%{formatted_value: val}) when not is_nil(val), do: format_edit_value(val)

  defp get_edit_value(%{"formatted_value" => val}) when not is_nil(val),
    do: format_edit_value(val)

  defp get_edit_value(%{raw_value: val}) when not is_nil(val), do: to_string(val)
  defp get_edit_value(%{"raw_value" => val}) when not is_nil(val), do: to_string(val)
  defp get_edit_value(%{value: val}) when is_binary(val), do: Base.encode16(val, case: :lower)
  defp get_edit_value(%{value: val}), do: to_string(val)
  defp get_edit_value(_), do: ""

  defp format_edit_value(val) when is_binary(val), do: val
  defp format_edit_value(val) when is_map(val), do: Jason.encode!(val)
  defp format_edit_value(val), do: to_string(val)

  # SNMP Object Value - type 48 with asn1_der and formatted_value containing oid
  defp get_data_type(%{type: 48, value_type: :asn1_der, formatted_value: fv})
       when is_map(fv) and is_map_key(fv, :oid),
       do: :snmp

  defp get_data_type(%{"type" => 48, "value_type" => "asn1_der", "formatted_value" => fv})
       when is_map(fv) and is_map_key(fv, "oid"),
       do: :snmp

  defp get_data_type(%{value_type: vt}), do: map_value_type(vt)
  defp get_data_type(%{"value_type" => vt}), do: map_value_type(vt)
  defp get_data_type(%{data_type: dt}), do: dt
  defp get_data_type(%{"data_type" => dt}), do: dt
  defp get_data_type(%{type: type}), do: infer_data_type(type)
  defp get_data_type(_), do: :string

  # Map library value_type to editor data_type
  defp map_value_type(nil), do: :string
  defp map_value_type(:uint), do: :uint
  defp map_value_type(:uint8), do: :uint
  defp map_value_type(:uint16), do: :uint
  defp map_value_type(:uint32), do: :uint
  defp map_value_type(:boolean), do: :boolean
  defp map_value_type(:ip), do: :ip
  defp map_value_type(:ipv4), do: :ip
  defp map_value_type(:ipv6), do: :ip
  defp map_value_type(:mac), do: :mac
  defp map_value_type(:mac_address), do: :mac
  defp map_value_type(:string), do: :string
  defp map_value_type(:string_zero), do: :string
  defp map_value_type(:hex), do: :hex
  defp map_value_type(:hex_string), do: :hex
  defp map_value_type(:frequency), do: :uint
  defp map_value_type(_), do: :string

  defp infer_data_type(type) do
    case type do
      # Network Access
      3 -> :boolean
      # Max CPE
      18 -> :uint
      _ -> :string
    end
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

  # ============================================================================
  # Path-based TLV Navigation
  # ============================================================================

  # Get a TLV at a given path (e.g., "0" for top-level, "0.1" for sub-TLV)
  defp get_tlv_at_path(tlvs, path) when is_binary(path) do
    indices = path |> String.split(".") |> Enum.map(&String.to_integer/1)
    do_get_tlv_at_path(tlvs, indices)
  end

  defp do_get_tlv_at_path(tlvs, [idx]) when is_list(tlvs) and idx < length(tlvs) do
    Enum.at(tlvs, idx)
  end

  defp do_get_tlv_at_path(tlvs, [idx | rest]) when is_list(tlvs) and idx < length(tlvs) do
    tlv = Enum.at(tlvs, idx)
    sub_tlvs = get_sub_tlvs(tlv)
    do_get_tlv_at_path(sub_tlvs, rest)
  end

  defp do_get_tlv_at_path(_tlvs, _indices), do: nil

  # Update a TLV at a given path
  defp update_tlv_at_path(tlvs, path, updated_tlv) when is_binary(path) do
    indices = path |> String.split(".") |> Enum.map(&String.to_integer/1)
    do_update_tlv_at_path(tlvs, indices, updated_tlv)
  end

  defp do_update_tlv_at_path(tlvs, [idx], updated_tlv) when is_list(tlvs) do
    List.replace_at(tlvs, idx, updated_tlv)
  end

  defp do_update_tlv_at_path(tlvs, [idx | rest], updated_tlv) when is_list(tlvs) do
    tlv = Enum.at(tlvs, idx)
    sub_tlvs = get_sub_tlvs(tlv)
    updated_sub_tlvs = do_update_tlv_at_path(sub_tlvs, rest, updated_tlv)

    # Update the parent TLV with the new sub-TLVs
    updated_parent = put_sub_tlvs(tlv, updated_sub_tlvs)
    List.replace_at(tlvs, idx, updated_parent)
  end

  defp do_update_tlv_at_path(tlvs, _indices, _updated_tlv), do: tlvs

  # Set sub-TLVs on a parent TLV (preserve the original key used)
  defp put_sub_tlvs(%{subtlvs: _} = tlv, sub_tlvs), do: Map.put(tlv, :subtlvs, sub_tlvs)
  defp put_sub_tlvs(%{"subtlvs" => _} = tlv, sub_tlvs), do: Map.put(tlv, "subtlvs", sub_tlvs)
  defp put_sub_tlvs(%{sub_tlvs: _} = tlv, sub_tlvs), do: Map.put(tlv, :sub_tlvs, sub_tlvs)
  defp put_sub_tlvs(%{"sub_tlvs" => _} = tlv, sub_tlvs), do: Map.put(tlv, "sub_tlvs", sub_tlvs)
  defp put_sub_tlvs(%{children: _} = tlv, sub_tlvs), do: Map.put(tlv, :children, sub_tlvs)
  defp put_sub_tlvs(tlv, sub_tlvs), do: Map.put(tlv, :subtlvs, sub_tlvs)
end
