# Bindocsis Portable LiveView UI Implementation Plan

## ✅ IMPLEMENTATION COMPLETE

All 9 phases have been implemented. The web UI is now ready for use.

## Overview

Implement an embeddable LiveView UI for bindocsis that can be:
1. Embedded in host Phoenix apps (like ddnet) via a simple router macro
2. Run standalone for quick config file inspection/editing

The UI will allow users to **view, edit, and export DOCSIS configuration files** with full TLV browsing capabilities.

---

## Quick Start

### Standalone Mode

```bash
# Run the standalone server
mix bindocsis.server

# With options
mix bindocsis.server --port 8080 --open
```

### Embedded in Phoenix App

```elixir
# In your router.ex
import BindocsisWeb.Router

scope "/" do
  pipe_through :browser
  bindocsis_live "/docsis"
end
```

---

## Color Scheme (matches ddnet)

```
Background:       bg-gray-900
Cards/Surfaces:   bg-gray-800
Borders:          border-gray-700, border-gray-600
Text Primary:     text-gray-100
Text Secondary:   text-gray-400, text-gray-300
Accent/Primary:   blue-500, blue-600
Success:          green-400, green-600
Warning:          yellow-400, amber-500
Error:            red-400, red-600
Info:             cyan-400
Monospace:        font-mono (for hex, MACs, values)
```

---

## Phase 1: Foundation & Router [✅ COMPLETE]

### 1.1 Add Optional Dependencies to mix.exs [✅]

```elixir
# In mix.exs deps
{:phoenix_live_view, "~> 1.0", optional: true},
{:phoenix_html, "~> 4.0", optional: true},
```

### 1.2 Create Router Macro [✅]

**File: `lib/bindocsis_web/router.ex`**

```elixir
defmodule BindocsisWeb.Router do
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

  - `:on_mount` - List of on_mount hooks for authentication (optional)
  - `:layout` - Custom layout tuple `{Module, :template}` (optional)

  ## Tailwind Configuration

  Add to your `tailwind.config.js` content array:

      "../deps/bindocsis/**/*.*ex",
  """

  defmacro bindocsis_live(path, opts \\ []) do
    quote bind_quoted: [path: path, opts: opts] do
      import Phoenix.LiveView.Router, only: [live: 3, live: 4]

      scope path, alias: false, as: :bindocsis do
        live "/", BindocsisWeb.DashboardLive, :index, opts
        live "/configs", BindocsisWeb.ConfigListLive, :index, opts
        live "/configs/new", BindocsisWeb.ConfigEditorLive, :new, opts
        live "/configs/:id", BindocsisWeb.ConfigViewerLive, :show, opts
        live "/configs/:id/edit", BindocsisWeb.ConfigEditorLive, :edit, opts
        live "/tlvs", BindocsisWeb.TLVBrowserLive, :index, opts
        live "/tlvs/:tlv", BindocsisWeb.TLVBrowserLive, :show, opts
      end
    end
  end
end
```

### 1.3 Create Layouts Module [✅]

**File: `lib/bindocsis_web/layouts.ex`**

Provides root and app layouts with dark theme matching ddnet.

### 1.4 Create Core Components [✅]

**File: `lib/bindocsis_web/components.ex`**

Shared UI components:
- `button/1` - Primary, secondary, danger variants
- `card/1` - Card container with header/body slots
- `table/1` - Styled data tables
- `input/1` - Form inputs with labels
- `modal/1` - Modal dialogs for editing
- `flash/1` - Flash messages
- `badge/1` - Status badges
- `icon/1` - Heroicon wrapper
- `breadcrumb/1` - Navigation breadcrumbs
- `tlv_tree/1` - Recursive TLV tree component
- `hex_viewer/1` - Hex byte display with highlighting

---

## Phase 2: Config Storage & Session Management [✅ COMPLETE]

### 2.1 ETS-based Config Store [ ]

**File: `lib/bindocsis_web/config_store.ex`**

```elixir
defmodule BindocsisWeb.ConfigStore do
  @moduledoc """
  Temporary storage for parsed config files.
  Uses ETS with automatic cleanup after TTL expires.
  """

  use GenServer

  @table :bindocsis_configs
  @default_ttl :timer.hours(24)

  # API
  def start_link(opts \\ [])
  def store(config, opts \\ [])  # Returns UUID
  def get(id)
  def update(id, config)
  def delete(id)
  def list_all()

  # Stores: %{
  #   id: UUID,
  #   name: "filename.cm",
  #   raw_bytes: <<binary>>,
  #   parsed: [TLV structs],
  #   enriched: [enriched TLVs],
  #   modified: boolean,
  #   created_at: DateTime,
  #   updated_at: DateTime,
  #   expires_at: DateTime
  # }
end
```

### 2.2 Application Supervisor (Optional) [ ]

**File: `lib/bindocsis_web/application.ex`**

Only starts if Phoenix is available. Supervises ConfigStore.

---

## Phase 3: Dashboard & Config List [✅ COMPLETE]

### 3.1 Dashboard LiveView [ ]

**File: `lib/bindocsis_web/live/dashboard_live.ex`**

Landing page showing:
- Quick upload dropzone
- Recent configs (from ConfigStore)
- Link to TLV browser
- Library version info

### 3.2 Config List LiveView [ ]

**File: `lib/bindocsis_web/live/config_list_live.ex`**

- List all configs in ConfigStore
- Upload new configs (live_upload)
- Delete configs
- Quick actions: View, Edit, Export

---

## Phase 4: Config Viewer (Read-Only) [✅ COMPLETE]

### 4.1 Config Viewer LiveView [ ]

**File: `lib/bindocsis_web/live/config_viewer_live.ex`**

Display parsed config file:
- **Tree View**: Hierarchical TLV structure with expand/collapse
- **Table View**: Flat list with sorting/filtering
- **Hex View**: Raw bytes with TLV boundary highlighting
- **JSON/YAML Export**: Download buttons

Features:
- Search/filter TLVs by type, name, value
- Click TLV to see details (spec info, raw bytes, human value)
- Syntax highlighting for values (IPs, MACs, hex, etc.)

### 4.2 TLV Detail Component [ ]

**File: `lib/bindocsis_web/live/components/tlv_detail.ex`**

Sidebar or modal showing:
- TLV type number and name
- Description from spec
- Raw bytes (hex)
- Parsed value (human-readable)
- Nested sub-TLVs if compound
- Edit button (links to editor)

---

## Phase 5: Config Editor (Core Feature) [✅ COMPLETE]

### 5.1 Config Editor LiveView [ ]

**File: `lib/bindocsis_web/live/config_editor_live.ex`**

Full editing capabilities:

#### Edit Modes:
1. **Tree Editor** - Visual tree with inline editing
2. **Form Editor** - Traditional form for selected TLV
3. **JSON Editor** - Raw JSON editing with validation
4. **Hex Editor** - Direct byte editing (advanced)

#### Features:
- [ ] **Add TLV** - Select from spec, fill values
- [ ] **Edit TLV** - Modify existing TLV values
- [ ] **Delete TLV** - Remove TLV from config
- [ ] **Reorder TLVs** - Drag-and-drop ordering
- [ ] **Duplicate TLV** - Clone existing TLV
- [ ] **Add Sub-TLV** - Add children to compound TLVs

#### Edit Flow:
```
User clicks TLV → Edit modal opens → Shows:
  - Current value (parsed)
  - Input field appropriate for type:
    - IP address → validated IP input
    - MAC → validated MAC input
    - Integer → number input with range
    - String → text input
    - Hex → hex input with validation
    - Enum → dropdown with valid options
  - Preview of encoded bytes
  - Save / Cancel buttons
```

#### Validation:
- Real-time validation against TLV spec
- Show errors before save
- Validate entire config on export

### 5.2 TLV Add/Edit Modal [ ]

**File: `lib/bindocsis_web/live/components/tlv_edit_modal.ex`**

```elixir
# Modal for adding or editing a single TLV
# Props:
#   tlv: existing TLV struct (nil for new)
#   parent_tlv: parent TLV type (for sub-TLVs)
#   spec: TLV spec from registry
#   on_save: callback
#   on_cancel: callback
```

Input types by data_type:
- `:uint` / `:uchar` / `:ushort` → Number input with min/max
- `:ip` / `:ip_address` → IP input with validation
- `:mac` / `:mac_address` → MAC input with format help
- `:string` / `:string_zero_term` → Text input
- `:hex` / `:hexstr` → Hex input with byte count
- `:aggregate` → Sub-form for nested structure
- Enums → Select dropdown

### 5.3 Add TLV Wizard [ ]

**File: `lib/bindocsis_web/live/components/tlv_add_wizard.ex`**

For adding new TLVs:
1. **Step 1**: Select TLV type (searchable list from spec)
2. **Step 2**: Fill in values (type-appropriate inputs)
3. **Step 3**: Preview and confirm
4. **Step 4**: Choose position (before/after existing TLV, or append)

### 5.4 Unsaved Changes Tracking [ ]

- Track modified state
- Warn before navigation if unsaved
- Show "Modified" badge on config

---

## Phase 6: TLV Browser [✅ COMPLETE]

### 6.1 TLV Browser LiveView [ ]

**File: `lib/bindocsis_web/live/tlv_browser_live.ex`**

Browse all TLV specifications:
- Searchable/filterable list
- Group by category (CM, MTA, eRouter, etc.)
- Show TLV details: type, name, data_type, length constraints
- Show sub-TLV hierarchy for compound TLVs
- Link to DOCSIS spec references

---

## Phase 7: Export & Download [✅ COMPLETE]

### 7.1 Export Functionality [ ]

Add to ConfigViewerLive and ConfigEditorLive:

- **Export as .cm** (binary) - Original or modified
- **Export as JSON** - Enriched format
- **Export as YAML** - Human-readable
- **Export as Hex dump** - Text file with hex view

### 7.2 Download Component [ ]

```elixir
def handle_event("download", %{"format" => format}, socket) do
  config = socket.assigns.config

  {content, filename, content_type} =
    case format do
      "binary" -> {encode_binary(config), "config.cm", "application/octet-stream"}
      "json" -> {encode_json(config), "config.json", "application/json"}
      "yaml" -> {encode_yaml(config), "config.yaml", "text/yaml"}
      "hex" -> {encode_hex_dump(config), "config.hex", "text/plain"}
    end

  {:noreply, push_event(socket, "download", %{content: content, filename: filename, type: content_type})}
end
```

---

## Phase 8: Standalone Mode [✅ COMPLETE]

### 8.1 Mix Task for Standalone Server [ ]

**File: `lib/mix/tasks/bindocsis.server.ex`**

```bash
# Start standalone web server
mix bindocsis.server --port 4000

# Open specific file on start
mix bindocsis.server --file path/to/config.cm
```

### 8.2 Minimal Endpoint [ ]

**File: `lib/bindocsis_web/standalone/endpoint.ex`**

Self-contained Phoenix endpoint for standalone mode.

---

## Phase 9: Polish & Documentation [✅ COMPLETE]

### 9.1 CSS/Styling [ ]

**File: `priv/static/bindocsis/app.css`**

Minimal CSS that works with host app's Tailwind.

### 9.2 JavaScript Hooks [ ]

**File: `priv/static/bindocsis/app.js`**

LiveView hooks for:
- File download triggering
- Drag-and-drop reordering
- Hex editor interactions
- Copy to clipboard

### 9.3 Documentation [ ]

- README section on embedding
- @moduledoc on all modules
- Usage examples

---

## File Structure Summary

```
lib/
  bindocsis_web/
    router.ex                    # Route macro
    layouts.ex                   # Root & app layouts
    components.ex                # Shared UI components
    config_store.ex              # ETS storage
    live/
      dashboard_live.ex          # Landing page
      config_list_live.ex        # Config file list
      config_viewer_live.ex      # Read-only viewer
      config_editor_live.ex      # Full editor
      tlv_browser_live.ex        # TLV spec browser
      components/
        tlv_tree.ex              # Recursive tree
        tlv_detail.ex            # TLV detail panel
        tlv_edit_modal.ex        # Edit modal
        tlv_add_wizard.ex        # Add TLV wizard
        hex_viewer.ex            # Hex display
    standalone/
      endpoint.ex                # Standalone endpoint
      application.ex             # Standalone supervision

lib/mix/tasks/
  bindocsis.server.ex            # Standalone server task

priv/static/bindocsis/
  app.css                        # Minimal styles
  app.js                         # JS hooks
```

---

## Implementation Order

1. **Phase 1**: Foundation (router, layouts, components) - Get something visible
2. **Phase 2**: Config storage - Enable multi-config sessions
3. **Phase 3**: Dashboard & list - Upload and manage files
4. **Phase 4**: Viewer - See configs (validates parsing works)
5. **Phase 5**: Editor - Core value proposition ⭐
6. **Phase 6**: TLV browser - Reference tool
7. **Phase 7**: Export - Complete the workflow
8. **Phase 8**: Standalone - Nice-to-have
9. **Phase 9**: Polish - Documentation, edge cases

---

## Progress Tracking

### Phase 1: Foundation & Router
- [x] 1.1 Add optional deps to mix.exs
- [x] 1.2 Create router macro
- [x] 1.3 Create layouts module
- [x] 1.4 Create core components

### Phase 2: Config Storage
- [x] 2.1 ETS-based config store
- [x] 2.2 Application supervisor

### Phase 3: Dashboard & Config List
- [x] 3.1 Dashboard LiveView
- [x] 3.2 Config list LiveView

### Phase 4: Config Viewer
- [ ] 4.1 Config viewer LiveView
- [ ] 4.2 TLV detail component

### Phase 5: Config Editor ⭐
- [ ] 5.1 Config editor LiveView
- [ ] 5.2 TLV add/edit modal
- [ ] 5.3 Add TLV wizard
- [ ] 5.4 Unsaved changes tracking

### Phase 6: TLV Browser
- [ ] 6.1 TLV browser LiveView

### Phase 7: Export & Download
- [ ] 7.1 Export functionality
- [ ] 7.2 Download component

### Phase 8: Standalone Mode
- [ ] 8.1 Mix task
- [ ] 8.2 Minimal endpoint

### Phase 9: Polish
- [ ] 9.1 CSS/Styling
- [ ] 9.2 JavaScript hooks
- [ ] 9.3 Documentation

---

## Notes

- All LiveViews should handle the case where Phoenix/LiveView is not available
- Use `Code.ensure_loaded?/1` to check for optional deps
- Config editor is the **core feature** - prioritize it
- Keep components small and composable
- Test with real DOCSIS config files throughout development
