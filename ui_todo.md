# Bindocsis Web UI - Remaining Work

This document tracks remaining work to get a fully functional web UI for editing DOCSIS configuration files.

## Current Status

**Working:**
- ✅ Standalone server (`mix bindocsis.server --port 4001`)
- ✅ Dashboard with file upload
- ✅ Config list view
- ✅ Config viewer (tree/table/hex views)
- ✅ TLV selection and detail panel
- ✅ TLV Browser (spec reference)
- ✅ Export functionality (binary, JSON, YAML, config, hex dump)
- ✅ Basic editor structure

**Partially Working:**
- ⚠️ TLV value display - fixed field name mismatch (`formatted_value` vs `human_value`)
- ⚠️ TLV editing - basic structure exists but encoding/decoding needs work
- ⚠️ Value type detection - using library's `value_type` but may miss edge cases

**Not Working:**
- ❌ Proper value encoding on edit save
- ❌ Sub-TLV editing (compound TLVs)
- ❌ Validation feedback
- ❌ Undo/redo

---

## Phase 1: Fix Value Display (Priority: Critical)

### 1.1 Verify Enrichment Pipeline
- [ ] Confirm `Bindocsis.parse(bytes, format: :binary, enhanced: true)` returns `formatted_value`
- [ ] Add debug logging to see actual TLV structure returned
- [ ] Test with sample file to verify field names

### 1.2 Handle All Value Types
- [ ] Map all `value_type` atoms from library to display format:
  - `:uint`, `:uint8`, `:uint16`, `:uint32` → integer display
  - `:boolean` → "Enabled"/"Disabled" or "1"/"0"
  - `:ip`, `:ipv4`, `:ipv6` → dotted decimal / colon-hex
  - `:mac`, `:mac_address` → colon-separated hex
  - `:string`, `:string_zero` → text
  - `:hex`, `:hex_string` → hex with spaces
  - `:frequency` → Hz with unit suffix
  - `:oid` → dotted decimal OID
  - `:bitfield` → bit flags display

### 1.3 Handle Missing Enrichment
- [ ] Fallback display for TLVs without `formatted_value`
- [ ] Show hex dump with length annotation for unknown types

---

## Phase 2: Fix Value Editing (Priority: Critical)

### 2.1 Type-Aware Input Fields
Current inputs exist but may not map correctly to library expectations.

- [ ] Verify input field type selection uses `value_type` from TLV
- [ ] Add custom input components:
  - IP address input with validation (IPv4/IPv6)
  - MAC address input with colon formatting
  - Hex input with byte grouping
  - OID input with dotted decimal
  - Bitfield input with checkboxes

### 2.2 Value Encoding on Save
The `update_tlv_value/2` function needs to properly encode edited values back to binary.

- [ ] Use `Bindocsis.TlvEnricher.unenrich_tlv/2` to convert back
- [ ] Or use library's `Bindocsis.ValueFormatter` for encoding
- [ ] Test round-trip: parse → edit → generate → parse → verify same value

### 2.3 Save to ConfigStore
- [ ] `update_tlv_at_path/3` should update both `parsed` and `enriched` fields
- [ ] Mark config as `modified: true`
- [ ] Regenerate binary preview

---

## Phase 3: Sub-TLV Editing (Priority: High)

### 3.1 Compound TLV Support
TLVs like 17 (Baseline Privacy), 22 (Upstream Packet Classification), 24/25 (Service Flows) contain sub-TLVs.

- [ ] Detect compound TLVs via `has_sub_tlvs?/1`
- [ ] Render nested editor for sub-TLVs
- [ ] Add sub-TLV button when parent supports it
- [ ] Delete sub-TLV within parent

### 3.2 Sub-TLV Path Navigation
- [ ] Use dot-separated paths: "2.0.1" for TLV index 2, sub-TLV 0, sub-sub-TLV 1
- [ ] `update_tlv_at_path/3` must handle nested updates

### 3.3 Sub-TLV Specs
- [ ] Get sub-TLV specs from library for add dialog
- [ ] Show valid sub-TLV types based on parent type

---

## Phase 4: Add New TLV (Priority: High)

### 4.1 TLV Type Picker
- [ ] Modal with searchable TLV type list
- [ ] Group by category (Basic, Security, Service Flow, etc.)
- [ ] Show TLV spec preview (name, description, value type)

### 4.2 Initial Value Form
- [ ] Generate form based on selected TLV's `value_type`
- [ ] Pre-fill with sensible defaults from specs
- [ ] Validate before adding

### 4.3 Insert Position
- [ ] Add at end (default)
- [ ] Add after selected TLV
- [ ] Validate ordering constraints (e.g., MIC TLVs at end)

---

## Phase 5: Delete TLV (Priority: High)

### 5.1 Delete Confirmation
- [ ] Modal confirming deletion
- [ ] Show TLV name and value being deleted
- [ ] Warn if deleting required TLV (type 3, 5, 6)

### 5.2 Cascade Delete
- [ ] Deleting compound TLV removes all sub-TLVs
- [ ] Update indices after deletion

---

## Phase 6: Reorder TLVs (Priority: Medium)

### 6.1 Drag-and-Drop
- [ ] Add drag handles to TLV rows
- [ ] Use LiveView JS hooks for drag events
- [ ] Update TLV list order on drop

### 6.2 Move Up/Down Buttons
- [ ] Simpler alternative to drag-and-drop
- [ ] Keyboard shortcuts (Alt+Up, Alt+Down)

### 6.3 Ordering Validation
- [ ] Warn if reorder violates DOCSIS ordering requirements
- [ ] Auto-fix option to move TLVs to valid positions

---

## Phase 7: Validation (Priority: Medium)

### 7.1 Real-Time Validation
- [ ] Validate on input change (debounced)
- [ ] Show inline errors below inputs
- [ ] Highlight invalid TLVs in tree

### 7.2 Use Library Validator
- [ ] Integrate `Bindocsis.Validator.validate/2`
- [ ] Display validation errors in sidebar
- [ ] Allow "Save anyway" for warnings

### 7.3 Value Range Validation
- [ ] Check value against TLV spec constraints
- [ ] Min/max for integers
- [ ] Length constraints for strings/hex

---

## Phase 8: Binary Preview (Priority: Medium)

### 8.1 Live Binary Preview
- [ ] Show encoded binary in hex view pane
- [ ] Highlight bytes for selected TLV
- [ ] Update preview on any edit

### 8.2 Size Tracking
- [ ] Show total config size
- [ ] Warn if approaching TFTP limits (~16KB typical)

---

## Phase 9: Save & Export (Priority: High)

### 9.1 Save to ConfigStore
- [ ] Save modified TLVs back to store
- [ ] Update `modified` flag
- [ ] Extend TTL on save

### 9.2 Download Edited Config
- [ ] Generate binary via `Bindocsis.generate/2`
- [ ] Use `TlvEnricher.unenrich_tlvs/1` first
- [ ] Download with original filename

### 9.3 Export Formats
Already implemented, but verify they work with edited configs:
- [ ] Binary (.cm)
- [ ] JSON
- [ ] YAML
- [ ] Human-readable config
- [ ] Hex dump

---

## Phase 10: Polish & UX (Priority: Low)

### 10.1 Keyboard Navigation
- [ ] Arrow keys to navigate TLV tree
- [ ] Enter to edit selected
- [ ] Delete key to delete
- [ ] Escape to cancel

### 10.2 Undo/Redo
- [ ] Track edit history
- [ ] Ctrl+Z / Ctrl+Shift+Z
- [ ] Show undo stack in UI

### 10.3 Copy/Paste TLVs
- [ ] Copy TLV to clipboard (as JSON)
- [ ] Paste TLV from clipboard
- [ ] Duplicate TLV shortcut

### 10.4 Dark Theme Refinements
- [ ] Ensure all components use gray-900/800/700
- [ ] Consistent focus rings (blue-500)
- [ ] Loading states and skeleton screens

---

## Testing Checklist

### Unit Tests
- [ ] ConfigStore CRUD operations
- [ ] TLV path navigation
- [ ] Value encoding/decoding round-trip

### Integration Tests
- [ ] Upload → View → Edit → Save → Download
- [ ] All export formats produce valid output
- [ ] Sub-TLV editing preserves parent structure

### Manual Testing
- [ ] Test with real DOCSIS config files
- [ ] Verify edited configs work on actual CMTS
- [ ] Test error handling for malformed files

---

## File Reference

| File | Purpose |
|------|---------|
| `lib/bindocsis_web/config_store.ex` | ETS storage for parsed configs |
| `lib/bindocsis_web/live/dashboard_live.ex` | Upload and config list |
| `lib/bindocsis_web/live/config_viewer_live.ex` | Read-only TLV display |
| `lib/bindocsis_web/live/config_editor_live.ex` | Full editing UI |
| `lib/bindocsis_web/live/tlv_browser_live.ex` | TLV spec reference |
| `lib/bindocsis_web/components.ex` | Shared UI components |
| `lib/bindocsis_web/layouts.ex` | Root and app layouts |
| `lib/mix/tasks/bindocsis.server.ex` | Standalone server task |

---

## Notes

- The library uses `formatted_value` for human-readable values, not `human_value`
- The library uses `value_type` atom to indicate data type
- Use `Bindocsis.TlvEnricher.unenrich_tlvs/1` before generating binary
- Sub-TLVs are in `:sub_tlvs` or `:children` depending on TLV type
