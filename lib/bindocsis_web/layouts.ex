defmodule BindocsisWeb.Layouts do
  @moduledoc """
  Layout components for the Bindocsis web interface.

  Provides dark-themed layouts matching the ddnet color scheme:
  - Background: gray-900
  - Cards/Surfaces: gray-800
  - Borders: gray-700
  - Text: gray-100 (primary), gray-400 (secondary)
  - Accent: blue-500/600
  """

  use Phoenix.Component

  import BindocsisWeb.Components

  @doc """
  Root layout that wraps the entire page.

  Includes HTML doctype, head with meta tags, and body wrapper.
  """
  def root(assigns) do
    ~H"""
    <!DOCTYPE html>
    <html lang="en" class="h-full bg-gray-900">
      <head>
        <meta charset="utf-8" />
        <meta name="viewport" content="width=device-width, initial-scale=1" />
        <meta name="csrf-token" content={Phoenix.Controller.get_csrf_token()} />
        <title><%= assigns[:page_title] || "Bindocsis" %></title>

        <!-- Tailwind CSS Play CDN - compiles on the fly -->
        <script src="https://cdn.tailwindcss.com"></script>
        <script>
          tailwind.config = {
            darkMode: 'class',
            theme: {
              extend: {
                colors: {
                  gray: {
                    900: '#111827',
                    800: '#1f2937',
                    700: '#374151',
                    600: '#4b5563',
                    500: '#6b7280',
                    400: '#9ca3af',
                    300: '#d1d5db',
                    200: '#e5e7eb',
                    100: '#f3f4f6',
                  }
                }
              }
            }
          }
        </script>

        <!-- Heroicons via CSS - using icon font approach -->
        <link rel="stylesheet" href="https://cdn.jsdelivr.net/npm/@iconify/iconify@latest/dist/iconify.min.css" />
        <script src="https://cdn.jsdelivr.net/npm/iconify-icon@2.1.0/dist/iconify-icon.min.js"></script>

        <!-- Phoenix LiveView JS from CDN - must match server version 1.1.19 -->
        <script src="https://unpkg.com/phoenix@1.7.14/priv/static/phoenix.min.js"></script>
        <script src="https://unpkg.com/phoenix_live_view@1.1.19/priv/static/phoenix_live_view.min.js"></script>

        <script>
          // Initialize LiveView after page loads
          window.addEventListener("load", () => {
            let csrfToken = document.querySelector("meta[name='csrf-token']").getAttribute("content");
            let liveSocket = new LiveView.LiveSocket("/live", Phoenix.Socket, {
              params: { _csrf_token: csrfToken },
              uploaders: {}
            });
            liveSocket.connect();
            window.liveSocket = liveSocket;
          });
        </script>

        <style>
          /* Additional styles for dark mode */
          html { background-color: #111827; }
          body { background-color: #111827; color: #f3f4f6; }

          /* Form element styling */
          input, select, textarea {
            background-color: #1f2937;
            border-color: #4b5563;
            color: #f3f4f6;
          }
          input:focus, select:focus, textarea:focus {
            border-color: #3b82f6;
            outline: none;
            box-shadow: 0 0 0 2px rgba(59, 130, 246, 0.5);
          }

          /* Scrollbar styling */
          ::-webkit-scrollbar { width: 8px; height: 8px; }
          ::-webkit-scrollbar-track { background: #1f2937; }
          ::-webkit-scrollbar-thumb { background: #4b5563; border-radius: 4px; }
          ::-webkit-scrollbar-thumb:hover { background: #6b7280; }
        </style>

        <script>
          // Download handler for file exports
          window.addEventListener("phx:download", (e) => {
            const { content, filename, binary } = e.detail;
            const decoded = binary ? atob(content) : content;
            let blob;
            if (binary) {
              const bytes = new Uint8Array(decoded.length);
              for (let i = 0; i < decoded.length; i++) {
                bytes[i] = decoded.charCodeAt(i);
              }
              blob = new Blob([bytes], { type: "application/octet-stream" });
            } else {
              blob = new Blob([decoded], { type: "text/plain" });
            }
            const url = URL.createObjectURL(blob);
            const a = document.createElement("a");
            a.href = url;
            a.download = filename;
            document.body.appendChild(a);
            a.click();
            document.body.removeChild(a);
            URL.revokeObjectURL(url);
          });
        </script>
      </head>
      <body class="h-full bg-gray-900 text-gray-100 antialiased" id="bindocsis-app">
        <%= @inner_content %>
      </body>
    </html>
    """
  end

  @doc """
  Application layout with navigation header.

  Provides consistent navigation across all Bindocsis pages.
  Can be used as a layout (with @inner_content) or as a component (with inner_block slot).
  """
  slot(:inner_block)
  attr(:flash, :map, default: %{})
  attr(:current_scope, :any, default: nil)
  attr(:base_path, :string, default: "")
  attr(:current_path, :string, default: nil)

  def app(assigns) do
    # Get base_path from assigns, defaulting to empty for standalone mode
    assigns =
      assigns
      |> assign_new(:base_path, fn ->
        assigns[:bindocsis_base_path] || ""
      end)
      |> assign_new(:current_path, fn -> nil end)

    ~H"""
    <div class="min-h-full flex flex-col">
      <.navbar base_path={@base_path} current_path={@current_path} current_scope={assigns[:current_scope]} />

      <main class="py-6 flex-1">
        <div class="mx-auto max-w-7xl px-4 sm:px-6 lg:px-8">
          <.flash_group flash={assigns[:flash] || %{}} />
          <%= if assigns[:inner_content] do %>
            <%= @inner_content %>
          <% else %>
            <%= render_slot(@inner_block) %>
          <% end %>
        </div>
      </main>

      <.footer />
    </div>
    """
  end

  @doc """
  Navigation bar component.
  """
  attr(:base_path, :string, default: "")
  attr(:current_path, :string, default: nil)
  attr(:current_scope, :any, default: nil)

  def navbar(assigns) do
    # Normalize base_path - empty string means root "/"
    base = if assigns.base_path == "", do: "/", else: assigns.base_path
    assigns = assign(assigns, :normalized_base, base)

    ~H"""
    <nav class="bg-gray-800 border-b border-gray-700">
      <div class="mx-auto max-w-7xl px-4 sm:px-6 lg:px-8">
        <div class="flex h-16 items-center justify-between">
          <div class="flex items-center">
            <div class="flex-shrink-0">
              <.link navigate={@normalized_base} class="flex items-center space-x-2">
                <.docsis_logo />
                <span class="text-xl font-bold text-gray-100">Bindocsis</span>
              </.link>
            </div>
            <div class="ml-10 flex items-baseline space-x-4">
              <.nav_link href={@normalized_base} current={is_dashboard_active?(@current_path, @base_path)}>
                Dashboard
              </.nav_link>
              <.nav_link href={build_path(@base_path, "/configs")} current={is_section_active?(@current_path, @base_path, "/configs")}>
                Configs
              </.nav_link>
              <.nav_link href={build_path(@base_path, "/tlvs")} current={is_section_active?(@current_path, @base_path, "/tlvs")}>
                TLV Browser
              </.nav_link>
            </div>
          </div>
          <div class="flex items-center space-x-4">
            <%= if assigns[:current_scope] do %>
              <span class="text-sm text-gray-300"><%= @current_scope.user.email %></span>
              <.link href="/users/settings" class="text-sm text-gray-400 hover:text-gray-200">Settings</.link>
              <.link href="/users/log-out" method="delete" class="text-sm text-gray-400 hover:text-gray-200">Log out</.link>
            <% else %>
              <.link href="/users/register" class="text-sm text-gray-400 hover:text-gray-200">Register</.link>
              <.link href="/users/log-in" class="text-sm text-gray-400 hover:text-gray-200">Log in</.link>
            <% end %>
            <span class="text-sm text-gray-500">v<%= Application.spec(:bindocsis, :vsn) %></span>
          </div>
        </div>
      </div>
    </nav>
    """
  end

  # Build a path with optional base_path prefix
  defp build_path("", path), do: path
  defp build_path(base, path), do: "#{base}#{path}"

  # Check if dashboard is active (root path)
  defp is_dashboard_active?(nil, _base), do: false
  defp is_dashboard_active?(current, ""), do: current == "/"
  defp is_dashboard_active?(current, base), do: current == base

  # Check if a section is active
  defp is_section_active?(nil, _base, _section), do: false
  defp is_section_active?(current, "", section), do: String.starts_with?(current, section)

  defp is_section_active?(current, base, section),
    do: String.starts_with?(current, "#{base}#{section}")

  @doc """
  Navigation link component with active state styling.
  """
  attr(:href, :string, required: true)
  attr(:current, :boolean, default: false)
  slot(:inner_block, required: true)

  def nav_link(assigns) do
    base_classes = "px-3 py-2 text-sm font-medium rounded-md transition-colors duration-150"

    active_classes =
      if assigns.current do
        "bg-gray-900 text-gray-100"
      else
        "text-gray-300 hover:bg-gray-700 hover:text-gray-100"
      end

    assigns = assign(assigns, :classes, "#{base_classes} #{active_classes}")

    ~H"""
    <.link navigate={@href} class={@classes}>
      <%= render_slot(@inner_block) %>
    </.link>
    """
  end

  @doc """
  Simple DOCSIS-themed logo (cable/signal icon).
  """
  def docsis_logo(assigns) do
    ~H"""
    <svg class="h-8 w-8 text-blue-500" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2">
      <path stroke-linecap="round" stroke-linejoin="round" d="M9 3v2m6-2v2M9 19v2m6-2v2M5 9H3m2 6H3m18-6h-2m2 6h-2M7 19h10a2 2 0 002-2V7a2 2 0 00-2-2H7a2 2 0 00-2 2v10a2 2 0 002 2zM9 9h6v6H9V9z" />
    </svg>
    """
  end

  @doc """
  Footer component.
  """
  def footer(assigns) do
    ~H"""
    <footer class="bg-gray-800 border-t border-gray-700 mt-auto">
      <div class="mx-auto max-w-7xl px-4 py-4 sm:px-6 lg:px-8">
        <div class="flex items-center justify-between">
          <p class="text-sm text-gray-400">
            Bindocsis &mdash; DOCSIS Configuration Manager
          </p>
          <div class="flex items-center space-x-4">
            <a
              href="https://github.com/awksedgreep/bindocsis"
              target="_blank"
              rel="noopener"
              class="text-gray-400 hover:text-gray-300 transition-colors"
            >
              <span class="sr-only">GitHub</span>
              <svg class="h-5 w-5" fill="currentColor" viewBox="0 0 24 24">
                <path fill-rule="evenodd" d="M12 2C6.477 2 2 6.484 2 12.017c0 4.425 2.865 8.18 6.839 9.504.5.092.682-.217.682-.483 0-.237-.008-.868-.013-1.703-2.782.605-3.369-1.343-3.369-1.343-.454-1.158-1.11-1.466-1.11-1.466-.908-.62.069-.608.069-.608 1.003.07 1.531 1.032 1.531 1.032.892 1.53 2.341 1.088 2.91.832.092-.647.35-1.088.636-1.338-2.22-.253-4.555-1.113-4.555-4.951 0-1.093.39-1.988 1.029-2.688-.103-.253-.446-1.272.098-2.65 0 0 .84-.27 2.75 1.026A9.564 9.564 0 0112 6.844c.85.004 1.705.115 2.504.337 1.909-1.296 2.747-1.027 2.747-1.027.546 1.379.202 2.398.1 2.651.64.7 1.028 1.595 1.028 2.688 0 3.848-2.339 4.695-4.566 4.943.359.309.678.92.678 1.855 0 1.338-.012 2.419-.012 2.747 0 .268.18.58.688.482A10.019 10.019 0 0022 12.017C22 6.484 17.522 2 12 2z" clip-rule="evenodd" />
              </svg>
            </a>
            <a
              href="https://hexdocs.pm/bindocsis"
              target="_blank"
              rel="noopener"
              class="text-gray-400 hover:text-gray-300 transition-colors text-sm"
            >
              Docs
            </a>
          </div>
        </div>
      </div>
    </footer>
    """
  end

  @doc """
  Flash message group component.
  """
  attr(:flash, :map, default: %{})

  def flash_group(assigns) do
    ~H"""
    <div class="space-y-2 mb-6">
      <.flash :if={@flash["info"]} kind={:info} message={@flash["info"]} />
      <.flash :if={@flash["error"]} kind={:error} message={@flash["error"]} />
      <.flash :if={@flash["success"]} kind={:success} message={@flash["success"]} />
    </div>
    """
  end
end
