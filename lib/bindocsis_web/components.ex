defmodule BindocsisWeb.Components do
  @moduledoc """
  Core UI components for the Bindocsis web interface.

  All components use the ddnet dark theme color scheme:
  - Background: gray-900
  - Cards/Surfaces: gray-800
  - Borders: gray-700
  - Text: gray-100 (primary), gray-400 (secondary)
  - Accent: blue-500/600
  """

  use Phoenix.Component

  # ============================================================================
  # Buttons
  # ============================================================================

  @doc """
  Renders a button.

  ## Examples

      <.button>Send</.button>
      <.button variant="secondary">Cancel</.button>
      <.button variant="danger">Delete</.button>
  """
  attr(:type, :string, default: "submit")
  attr(:variant, :string, default: "primary", values: ~w(primary secondary danger ghost))
  attr(:size, :string, default: "md", values: ~w(sm md lg))
  attr(:disabled, :boolean, default: false)
  attr(:class, :string, default: nil)
  attr(:rest, :global, include: ~w(form name value phx-click phx-disable-with))
  slot(:inner_block, required: true)

  def button(assigns) do
    base_classes =
      "inline-flex items-center justify-center font-semibold rounded-lg shadow-sm transition-all duration-200 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-offset-gray-900 disabled:opacity-50 disabled:cursor-not-allowed"

    size_classes =
      case assigns.size do
        "sm" -> "px-3 py-1.5 text-sm"
        "md" -> "px-4 py-2 text-sm"
        "lg" -> "px-6 py-3 text-base"
      end

    variant_classes =
      case assigns.variant do
        "primary" ->
          "bg-blue-600 text-white hover:bg-blue-500 focus:ring-blue-500"

        "secondary" ->
          "bg-gray-700 text-gray-100 border border-gray-600 hover:bg-gray-600 focus:ring-gray-500"

        "danger" ->
          "bg-red-600 text-white hover:bg-red-500 focus:ring-red-500"

        "ghost" ->
          "bg-transparent text-gray-300 hover:bg-gray-800 hover:text-gray-100 focus:ring-gray-500"
      end

    classes =
      [base_classes, size_classes, variant_classes, assigns.class]
      |> Enum.filter(& &1)
      |> Enum.join(" ")

    assigns = assign(assigns, :classes, classes)

    ~H"""
    <button type={@type} class={@classes} disabled={@disabled} {@rest}>
      <%= render_slot(@inner_block) %>
    </button>
    """
  end

  # ============================================================================
  # Cards
  # ============================================================================

  @doc """
  Renders a card container.

  ## Examples

      <.card>
        <:header>Title</:header>
        Content goes here
      </.card>
  """
  attr(:class, :string, default: nil)
  slot(:header)
  slot(:inner_block, required: true)
  slot(:footer)

  def card(assigns) do
    ~H"""
    <div class={["bg-gray-800 rounded-lg border border-gray-700 shadow-lg overflow-hidden", @class]}>
      <div :if={@header != []} class="px-6 py-4 border-b border-gray-700">
        <h3 class="text-lg font-semibold text-gray-100">
          <%= render_slot(@header) %>
        </h3>
      </div>
      <div class="p-6">
        <%= render_slot(@inner_block) %>
      </div>
      <div :if={@footer != []} class="px-6 py-4 border-t border-gray-700 bg-gray-800/50">
        <%= render_slot(@footer) %>
      </div>
    </div>
    """
  end

  # ============================================================================
  # Forms & Inputs
  # ============================================================================

  @doc """
  Renders an input field with label.

  ## Examples

      <.input field={@form[:email]} type="email" label="Email" />
      <.input field={@form[:name]} type="text" label="Name" placeholder="Enter name" />
  """
  attr(:id, :any, default: nil)
  attr(:name, :any)
  attr(:label, :string, default: nil)
  attr(:value, :any)

  attr(:type, :string,
    default: "text",
    values:
      ~w(text email password number tel url search textarea select hidden file date time datetime-local)
  )

  attr(:field, Phoenix.HTML.FormField, doc: "A form field struct from a form")
  attr(:errors, :list, default: [])
  attr(:placeholder, :string, default: nil)
  attr(:class, :string, default: nil)

  attr(:rest, :global,
    include:
      ~w(accept autocomplete disabled form max maxlength min minlength multiple pattern readonly required rows step)
  )

  slot(:inner_block)

  def input(%{field: %Phoenix.HTML.FormField{} = field} = assigns) do
    assigns
    |> assign(field: nil, id: assigns.id || field.id)
    |> assign(:errors, Enum.map(field.errors, &translate_error(&1)))
    |> assign_new(:name, fn -> field.name end)
    |> assign_new(:value, fn -> field.value end)
    |> input()
  end

  def input(%{type: "textarea"} = assigns) do
    ~H"""
    <div class={@class}>
      <label :if={@label} for={@id} class="block text-sm font-medium text-gray-300 mb-1.5">
        <%= @label %>
      </label>
      <textarea
        id={@id}
        name={@name}
        placeholder={@placeholder}
        class={[
          "block w-full px-3 py-2 bg-gray-800 border rounded-lg text-gray-100",
          "placeholder-gray-500 focus:ring-2 focus:ring-blue-500 focus:border-blue-500",
          "transition-colors duration-200 resize-y",
          @errors == [] && "border-gray-600",
          @errors != [] && "border-red-500"
        ]}
        {@rest}
      ><%= Phoenix.HTML.Form.normalize_value("textarea", @value) %></textarea>
      <.input_errors errors={@errors} />
    </div>
    """
  end

  def input(%{type: "select"} = assigns) do
    ~H"""
    <div class={@class}>
      <label :if={@label} for={@id} class="block text-sm font-medium text-gray-300 mb-1.5">
        <%= @label %>
      </label>
      <select
        id={@id}
        name={@name}
        class={[
          "block w-full px-3 py-2 bg-gray-800 border rounded-lg text-gray-100",
          "focus:ring-2 focus:ring-blue-500 focus:border-blue-500",
          "transition-colors duration-200",
          @errors == [] && "border-gray-600",
          @errors != [] && "border-red-500"
        ]}
        {@rest}
      >
        <%= render_slot(@inner_block) %>
      </select>
      <.input_errors errors={@errors} />
    </div>
    """
  end

  def input(%{type: "hidden"} = assigns) do
    ~H"""
    <input type="hidden" id={@id} name={@name} value={@value} {@rest} />
    """
  end

  def input(assigns) do
    ~H"""
    <div class={@class}>
      <label :if={@label} for={@id} class="block text-sm font-medium text-gray-300 mb-1.5">
        <%= @label %>
      </label>
      <input
        type={@type}
        id={@id}
        name={@name}
        value={Phoenix.HTML.Form.normalize_value(@type, @value)}
        placeholder={@placeholder}
        class={[
          "block w-full px-3 py-2 bg-gray-800 border rounded-lg text-gray-100",
          "placeholder-gray-500 focus:ring-2 focus:ring-blue-500 focus:border-blue-500",
          "transition-colors duration-200",
          @errors == [] && "border-gray-600",
          @errors != [] && "border-red-500"
        ]}
        {@rest}
      />
      <.input_errors errors={@errors} />
    </div>
    """
  end

  defp input_errors(assigns) do
    ~H"""
    <div :if={@errors != []} class="mt-1.5 space-y-1">
      <p :for={error <- @errors} class="text-sm text-red-400">
        <%= error %>
      </p>
    </div>
    """
  end

  defp translate_error({msg, opts}) do
    Enum.reduce(opts, msg, fn {key, value}, acc ->
      String.replace(acc, "%{#{key}}", fn _ -> to_string(value) end)
    end)
  end

  # ============================================================================
  # Tables
  # ============================================================================

  @doc """
  Renders a styled table.

  ## Examples

      <.table id="users" rows={@users}>
        <:col :let={user} label="Name"><%= user.name %></:col>
        <:col :let={user} label="Email"><%= user.email %></:col>
      </.table>
  """
  attr(:id, :string, required: true)
  attr(:rows, :list, required: true)
  attr(:row_id, :any, default: nil, doc: "Function to get row ID")
  attr(:row_click, :any, default: nil, doc: "Function to handle row click")
  attr(:class, :string, default: nil)

  slot :col, required: true do
    attr(:label, :string)
    attr(:class, :string)
  end

  slot(:action, doc: "Row actions slot")

  def table(assigns) do
    assigns =
      with %{rows: %Phoenix.LiveView.LiveStream{}} <- assigns do
        assign(assigns, row_id: assigns.row_id || fn {id, _item} -> id end)
      end

    ~H"""
    <div class={["bg-gray-800 rounded-lg border border-gray-700 overflow-hidden", @class]}>
      <table class="w-full">
        <thead class="bg-gray-700">
          <tr>
            <th :for={col <- @col} class="px-6 py-3 text-left text-xs font-medium text-gray-400 uppercase tracking-wider">
              <%= col[:label] %>
            </th>
            <th :if={@action != []} class="px-6 py-3 text-right text-xs font-medium text-gray-400 uppercase tracking-wider">
              Actions
            </th>
          </tr>
        </thead>
        <tbody class="divide-y divide-gray-700">
          <tr
            :for={row <- @rows}
            id={@row_id && @row_id.(row)}
            class={["hover:bg-gray-700/50 transition-colors", @row_click && "cursor-pointer"]}
          >
            <td
              :for={col <- @col}
              phx-click={@row_click && @row_click.(row)}
              class={["px-6 py-4 whitespace-nowrap text-sm text-gray-100", col[:class]]}
            >
              <%= render_slot(col, @row_id && @row_id.(row) |> elem(1) || row) %>
            </td>
            <td :if={@action != []} class="px-6 py-4 whitespace-nowrap text-right text-sm">
              <div class="flex items-center justify-end space-x-2">
                <%= for action <- @action do %>
                  <%= render_slot(action, @row_id && @row_id.(row) |> elem(1) || row) %>
                <% end %>
              </div>
            </td>
          </tr>
        </tbody>
      </table>
      <div :if={@rows == []} class="px-6 py-12 text-center text-gray-400">
        No data available
      </div>
    </div>
    """
  end

  # ============================================================================
  # Flash Messages
  # ============================================================================

  @doc """
  Renders a flash message.

  ## Examples

      <.flash kind={:info} message="Changes saved successfully" />
      <.flash kind={:error} message="Something went wrong" />
  """
  attr(:kind, :atom, required: true, values: [:info, :success, :error, :warning])
  attr(:message, :string, required: true)
  attr(:dismissible, :boolean, default: true)

  def flash(assigns) do
    colors =
      case assigns.kind do
        :info -> "bg-blue-900/50 text-blue-300 border-blue-700"
        :success -> "bg-green-900/50 text-green-300 border-green-700"
        :error -> "bg-red-900/50 text-red-300 border-red-700"
        :warning -> "bg-yellow-900/50 text-yellow-300 border-yellow-700"
      end

    icon =
      case assigns.kind do
        :info ->
          "M13 16h-1v-4h-1m1-4h.01M21 12a9 9 0 11-18 0 9 9 0 0118 0z"

        :success ->
          "M9 12l2 2 4-4m6 2a9 9 0 11-18 0 9 9 0 0118 0z"

        :error ->
          "M10 14l2-2m0 0l2-2m-2 2l-2-2m2 2l2 2m7-2a9 9 0 11-18 0 9 9 0 0118 0z"

        :warning ->
          "M12 9v2m0 4h.01m-6.938 4h13.856c1.54 0 2.502-1.667 1.732-3L13.732 4c-.77-1.333-2.694-1.333-3.464 0L3.34 16c-.77 1.333.192 3 1.732 3z"
      end

    assigns = assign(assigns, colors: colors, icon: icon)

    ~H"""
    <div class={["flex items-center p-4 rounded-lg border", @colors]} role="alert">
      <svg class="h-5 w-5 mr-3 flex-shrink-0" fill="none" viewBox="0 0 24 24" stroke="currentColor">
        <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d={@icon} />
      </svg>
      <span class="flex-1 text-sm font-medium"><%= @message %></span>
      <button :if={@dismissible} type="button" class="ml-3 -mr-1 p-1 rounded hover:bg-white/10" phx-click="lv:clear-flash">
        <svg class="h-4 w-4" fill="none" viewBox="0 0 24 24" stroke="currentColor">
          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12" />
        </svg>
      </button>
    </div>
    """
  end

  # ============================================================================
  # Badges
  # ============================================================================

  @doc """
  Renders a status badge.

  ## Examples

      <.badge>Default</.badge>
      <.badge variant="success">Active</.badge>
      <.badge variant="warning">Pending</.badge>
  """
  attr(:variant, :string, default: "default", values: ~w(default success warning error info))
  attr(:class, :string, default: nil)
  slot(:inner_block, required: true)

  def badge(assigns) do
    colors =
      case assigns.variant do
        "default" -> "bg-gray-700 text-gray-300"
        "success" -> "bg-green-900 text-green-300 border border-green-700"
        "warning" -> "bg-yellow-900 text-yellow-300 border border-yellow-700"
        "error" -> "bg-red-900 text-red-300 border border-red-700"
        "info" -> "bg-blue-900 text-blue-300 border border-blue-700"
      end

    assigns = assign(assigns, :colors, colors)

    ~H"""
    <span class={["inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium", @colors, @class]}>
      <%= render_slot(@inner_block) %>
    </span>
    """
  end

  # ============================================================================
  # Modal
  # ============================================================================

  @doc """
  Renders a modal dialog.

  ## Examples

      <.modal id="edit-modal" show={@show_modal} on_cancel={JS.push("close_modal")}>
        <:title>Edit Item</:title>
        Modal content here
      </.modal>
  """
  attr(:id, :string, required: true)
  attr(:show, :boolean, default: false)
  attr(:on_cancel, Phoenix.LiveView.JS, default: %Phoenix.LiveView.JS{})
  slot(:title)
  slot(:inner_block, required: true)
  slot(:footer)

  def modal(assigns) do
    ~H"""
    <div
      id={@id}
      phx-mounted={@show && show_modal(@id)}
      phx-remove={hide_modal(@id)}
      data-cancel={Phoenix.LiveView.JS.exec(@on_cancel, "phx-remove")}
      class="relative z-50 hidden"
    >
      <div id={"#{@id}-bg"} class="fixed inset-0 bg-black/60 transition-opacity" aria-hidden="true" />
      <div
        class="fixed inset-0 overflow-y-auto"
        aria-labelledby={"#{@id}-title"}
        aria-describedby={"#{@id}-description"}
        role="dialog"
        aria-modal="true"
        tabindex="0"
      >
        <div class="flex min-h-full items-center justify-center p-4">
          <div
            id={"#{@id}-container"}
            phx-window-keydown={Phoenix.LiveView.JS.exec("data-cancel", to: "##{@id}")}
            phx-key="escape"
            phx-click-away={Phoenix.LiveView.JS.exec("data-cancel", to: "##{@id}")}
            class="w-full max-w-2xl bg-gray-800 rounded-lg border border-gray-700 shadow-xl"
          >
            <div class="flex items-center justify-between px-6 py-4 border-b border-gray-700">
              <h3 :if={@title != []} id={"#{@id}-title"} class="text-lg font-semibold text-gray-100">
                <%= render_slot(@title) %>
              </h3>
              <button
                type="button"
                phx-click={Phoenix.LiveView.JS.exec("data-cancel", to: "##{@id}")}
                class="p-1 text-gray-400 hover:text-gray-300 rounded hover:bg-gray-700"
              >
                <svg class="h-5 w-5" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12" />
                </svg>
              </button>
            </div>
            <div id={"#{@id}-content"} class="p-6">
              <%= render_slot(@inner_block) %>
            </div>
            <div :if={@footer != []} class="px-6 py-4 border-t border-gray-700 bg-gray-800/50 flex items-center justify-end space-x-3">
              <%= render_slot(@footer) %>
            </div>
          </div>
        </div>
      </div>
    </div>
    """
  end

  defp show_modal(id) do
    %Phoenix.LiveView.JS{}
    |> Phoenix.LiveView.JS.show(to: "##{id}")
    |> Phoenix.LiveView.JS.show(
      to: "##{id}-bg",
      transition: {"transition-all ease-out duration-300", "opacity-0", "opacity-100"}
    )
    |> Phoenix.LiveView.JS.show(
      to: "##{id}-container",
      transition:
        {"transition-all ease-out duration-300", "opacity-0 scale-95", "opacity-100 scale-100"}
    )
    |> Phoenix.LiveView.JS.focus_first(to: "##{id}-content")
  end

  defp hide_modal(id) do
    %Phoenix.LiveView.JS{}
    |> Phoenix.LiveView.JS.hide(
      to: "##{id}-bg",
      transition: {"transition-all ease-in duration-200", "opacity-100", "opacity-0"}
    )
    |> Phoenix.LiveView.JS.hide(
      to: "##{id}-container",
      transition:
        {"transition-all ease-in duration-200", "opacity-100 scale-100", "opacity-0 scale-95"}
    )
    |> Phoenix.LiveView.JS.hide(to: "##{id}", transition: {"block", "block", "hidden"})
    |> Phoenix.LiveView.JS.pop_focus()
  end

  # ============================================================================
  # Breadcrumbs
  # ============================================================================

  @doc """
  Renders breadcrumb navigation.

  ## Examples

      <.breadcrumb>
        <:item href="/docsis">Home</:item>
        <:item href="/docsis/configs">Configs</:item>
        <:item>config.cm</:item>
      </.breadcrumb>
  """
  slot :item, required: true do
    attr(:href, :string)
  end

  def breadcrumb(assigns) do
    ~H"""
    <nav class="flex mb-4" aria-label="Breadcrumb">
      <ol class="flex items-center space-x-2">
        <%= for {item, idx} <- Enum.with_index(@item) do %>
          <li class="flex items-center">
            <svg :if={idx > 0} class="h-4 w-4 text-gray-500 mx-2" fill="none" viewBox="0 0 24 24" stroke="currentColor">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 5l7 7-7 7" />
            </svg>
            <%= if item[:href] do %>
              <.link navigate={item.href} class="text-sm text-gray-400 hover:text-gray-200 transition-colors">
                <%= render_slot(item) %>
              </.link>
            <% else %>
              <span class="text-sm text-gray-200 font-medium">
                <%= render_slot(item) %>
              </span>
            <% end %>
          </li>
        <% end %>
      </ol>
    </nav>
    """
  end

  # ============================================================================
  # Header
  # ============================================================================

  @doc """
  Renders a header with title.

  ## Examples

      <.header>Settings</.header>
      <.header>
        Account Settings
        <:subtitle>Manage your account settings</:subtitle>
      </.header>
  """
  attr(:class, :string, default: nil)
  slot(:inner_block, required: true)
  slot(:subtitle)
  slot(:actions)

  def header(assigns) do
    ~H"""
    <header class={[@class]}>
      <div>
        <h1 class="text-lg font-semibold leading-8 text-gray-100">
          <%= render_slot(@inner_block) %>
        </h1>
        <p :if={@subtitle != []} class="mt-2 text-sm leading-6 text-gray-400">
          <%= render_slot(@subtitle) %>
        </p>
      </div>
      <div :if={@actions != []} class="flex-none">
        <%= render_slot(@actions) %>
      </div>
    </header>
    """
  end

  # ============================================================================
  # Icons
  # ============================================================================

  @doc """
  Renders a heroicon.

  ## Examples

      <.icon name="hero-document" class="h-5 w-5" />
      <.icon name="hero-folder-solid" class="h-5 w-5 text-blue-500" />
  """
  attr(:name, :string, required: true)
  attr(:class, :string, default: "h-5 w-5")

  def icon(%{name: "hero-" <> icon_name} = assigns) do
    # Convert hero-pencil-square to heroicons:pencil-square (outline style)
    # Convert hero-pencil-solid to heroicons-solid:pencil
    {prefix, name} =
      if String.ends_with?(icon_name, "-solid") do
        {"heroicons-solid", String.replace_suffix(icon_name, "-solid", "")}
      else
        {"heroicons", icon_name}
      end

    assigns = assign(assigns, :iconify_name, "#{prefix}:#{name}")

    ~H"""
    <iconify-icon icon={@iconify_name} class={@class}></iconify-icon>
    """
  end

  def icon(assigns) do
    ~H"""
    <iconify-icon icon={"heroicons:#{@name}"} class={@class}></iconify-icon>
    """
  end

  # ============================================================================
  # Empty State
  # ============================================================================

  @doc """
  Renders an empty state placeholder.

  ## Examples

      <.empty_state>
        <:icon><.icon name="hero-document" class="h-12 w-12" /></:icon>
        <:title>No configs yet</:title>
        <:description>Upload a DOCSIS config file to get started.</:description>
        <:action>
          <.button>Upload Config</.button>
        </:action>
      </.empty_state>
  """
  slot(:icon)
  slot(:title)
  slot(:description)
  slot(:action)

  def empty_state(assigns) do
    ~H"""
    <div class="text-center py-12">
      <div :if={@icon != []} class="flex justify-center text-gray-500 mb-4">
        <%= render_slot(@icon) %>
      </div>
      <h3 :if={@title != []} class="text-lg font-medium text-gray-300 mb-2">
        <%= render_slot(@title) %>
      </h3>
      <p :if={@description != []} class="text-sm text-gray-500 mb-6 max-w-sm mx-auto">
        <%= render_slot(@description) %>
      </p>
      <div :if={@action != []}>
        <%= render_slot(@action) %>
      </div>
    </div>
    """
  end

  # ============================================================================
  # Loading States
  # ============================================================================

  @doc """
  Renders a loading spinner.

  ## Examples

      <.spinner />
      <.spinner size="lg" />
  """
  attr(:size, :string, default: "md", values: ~w(sm md lg))
  attr(:class, :string, default: nil)

  def spinner(assigns) do
    size_classes =
      case assigns.size do
        "sm" -> "h-4 w-4"
        "md" -> "h-6 w-6"
        "lg" -> "h-8 w-8"
      end

    assigns = assign(assigns, :size_classes, size_classes)

    ~H"""
    <svg class={["animate-spin text-blue-500", @size_classes, @class]} fill="none" viewBox="0 0 24 24">
      <circle class="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" stroke-width="4" />
      <path class="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4zm2 5.291A7.962 7.962 0 014 12H0c0 3.042 1.135 5.824 3 7.938l3-2.647z" />
    </svg>
    """
  end

  # ============================================================================
  # TLV-Specific Components
  # ============================================================================

  @doc """
  Renders a TLV type badge with appropriate coloring.

  ## Examples

      <.tlv_type_badge type={3} name="Net Access Control" />
  """
  attr(:type, :integer, required: true)
  attr(:name, :string, default: nil)

  def tlv_type_badge(assigns) do
    ~H"""
    <span class="inline-flex items-center space-x-1.5">
      <span class="inline-flex items-center justify-center min-w-[2rem] px-1.5 py-0.5 rounded bg-blue-900 text-blue-300 text-xs font-mono font-bold">
        <%= @type %>
      </span>
      <span :if={@name} class="text-sm text-gray-300"><%= @name %></span>
    </span>
    """
  end

  @doc """
  Renders a hex value with proper styling.

  ## Examples

      <.hex_value value={<<0x01, 0x02, 0x03>>} />
  """
  attr(:value, :any, required: true)
  attr(:max_bytes, :integer, default: 16)

  def hex_value(assigns) do
    bytes = :binary.bin_to_list(assigns.value)
    truncated = length(bytes) > assigns.max_bytes

    display_bytes =
      if truncated do
        Enum.take(bytes, assigns.max_bytes)
      else
        bytes
      end

    hex_string =
      display_bytes
      |> Enum.map(&(Integer.to_string(&1, 16) |> String.pad_leading(2, "0")))
      |> Enum.join(" ")

    assigns = assign(assigns, hex_string: hex_string, truncated: truncated, total: length(bytes))

    ~H"""
    <code class="font-mono text-sm text-cyan-400 bg-gray-900 px-2 py-1 rounded">
      <%= @hex_string %><span :if={@truncated} class="text-gray-500">... (<%= @total %> bytes)</span>
    </code>
    """
  end

  @doc """
  Renders a data value with appropriate formatting based on type.

  ## Examples

      <.data_value type={:ip} value="192.168.1.1" />
      <.data_value type={:mac} value="00:11:22:33:44:55" />
  """
  attr(:type, :atom, default: :string)
  attr(:value, :any, required: true)

  def data_value(assigns) do
    {color, formatted} =
      case assigns.type do
        t when t in [:ip, :ip_address] ->
          {"text-cyan-400", assigns.value}

        t when t in [:mac, :mac_address] ->
          {"text-amber-400", assigns.value}

        :hex ->
          {"text-purple-400", assigns.value}

        t when t in [:uint, :uchar, :ushort, :ulong] ->
          {"text-green-400", to_string(assigns.value)}

        _ ->
          {"text-gray-100", to_string(assigns.value)}
      end

    assigns = assign(assigns, color: color, formatted: formatted)

    ~H"""
    <span class={["font-mono text-sm", @color]}><%= @formatted %></span>
    """
  end

  # ============================================================================
  # File Upload Zone
  # ============================================================================

  @doc """
  Renders a file upload dropzone.

  ## Examples

      <.upload_zone upload={@uploads.config} />
  """
  attr(:upload, :any, required: true)
  attr(:class, :string, default: nil)

  def upload_zone(assigns) do
    ~H"""
    <div
      class={[
        "border-2 border-dashed border-gray-600 rounded-lg p-8 text-center",
        "hover:border-blue-500 hover:bg-gray-800/50 transition-all duration-200 cursor-pointer",
        @class
      ]}
      phx-drop-target={@upload.ref}
    >
      <.live_file_input upload={@upload} class="sr-only" />
      <svg class="mx-auto h-12 w-12 text-gray-500 mb-4" fill="none" viewBox="0 0 24 24" stroke="currentColor">
        <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M7 16a4 4 0 01-.88-7.903A5 5 0 1115.9 6L16 6a5 5 0 011 9.9M15 13l-3-3m0 0l-3 3m3-3v12" />
      </svg>
      <p class="text-gray-300 mb-2">
        <label for={@upload.ref} class="text-blue-400 hover:text-blue-300 cursor-pointer font-medium">
          Click to upload
        </label>
        or drag and drop
      </p>
      <p class="text-sm text-gray-500">
        DOCSIS config files (.cm, .bin, .json, .yaml, .yml) up to 1MB
      </p>
    </div>
    """
  end
end
