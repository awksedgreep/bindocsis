# Bindocsis: Next Steps Roadmap

This document outlines concrete phases to move Bindocsis from its current ~70–80% completeness toward a robust, field-ready tool.

Each phase is small enough to tackle in focused sessions. We can check these off as we go.

---

## Phase 1 – Stabilize TLV 11 (SNMP MIB Object)

**Goal:** TLV 11 (and its sub-TLV 48) should *never* raise exceptions in any path and should always show something human-usable.

### 1.1 Harden ASN.1 DER formatting for SNMP MIB objects
- **Files:**
  - `lib/bindocsis/value_formatter.ex`
  - `lib/bindocsis/value_parser.ex`
- **Tasks:**
  - Ensure `format_value(:asn1_der, ...)` only returns these shapes:
    - A bare OID string (e.g. `"1.3.6.1.2.1.1.3.0"`), or
    - A map `%{oid: string, type: string, value: term}`, or
    - A hex string for fallback.
  - Audit all branches for `:asn1_der` and remove/normalize any other structures.
  - Confirm `ValueParser.parse_value(:asn1_der, ...)` accepts exactly those and nothing else.

### 1.2 Make TLV 11 display robust in the interactive editor
- **Files:**
  - `lib/bindocsis/interactive_editor.ex`
- **Tasks:**
  - In `format_subtlv_value/1`, wrap just the SNMP MIB object case in `try/rescue`:
    - On success: print a nice `"OID=<oid> TYPE=<type> VALUE=<value>"` representation.
    - On failure: fall back to hex and log a short note: `"<hex> (unparsable SNMP MIB object)"`.
  - Ensure `show_subtlvs/2` prints the `formatted_value` even when it is hex, so users at least see *some* content.
  - Add a small safety net around sub-TLV 48 specifically (SNMP object) in case vendor configs put garbage there.

### 1.3 Tests for TLV 11 round-trip and fallbacks
- **Files:**
  - `test/bindocsis/value_types_test.exs`
  - (Possibly a new `test/bindocsis/tlv11_snmp_test.exs`)
- **Tasks:**
  - Add tests that:
    - Encode a valid SNMP MIB object (TLV 11 / sub-TLV 48) → format → parse back → binary matches.
    - Feed malformed ASN.1 to `format_value(:asn1_der, ...)` and ensure it returns hex, not an exception.
    - Verify CLI/pretty-print and editor do not crash or raise for any of these cases.


## Phase 2 – Enriched vs. Basic TLVs: Strict Boundaries

**Goal:** Any code doing strict validation or binary encoding should operate only on *unenriched* TLVs.

### 2.1 Audit all encode/validate call sites
- **Files:**
  - `lib/bindocsis/generators/binary_generator.ex`
  - `lib/bindocsis/generators/mta_binary_generator.ex` (if present)
  - `lib/bindocsis/interactive_editor.ex`
  - `lib/bindocsis/cli.ex`
  - `lib/bindocsis.ex`
- **Tasks:**
  - Grep for `encode_tlv`, `encode_single_tlv`, `ConfigValidator.validate`.
  - For each call, confirm inputs are plain `%{type, length, value}` TLVs (not enriched with `formatted_value`, `subtlvs`, etc.).
  - Where necessary, explicitly call `TlvEnricher.unenrich_tlvs/2` before validation/encoding.

### 2.2 Add regression tests for unenrich-before-encode
- **Files:**
  - `test/bindocsis/interactive_editor_test.exs` (or a new test file)
- **Tasks:**
  - Build a small configuration with:
    - Service flows (enriched).
    - TLV 11 with a valid SNMP object.
  - Ensure editor validation and CLI pretty/validate paths:
    - Do not raise,
    - Preserve binary output unchanged.


## Phase 3 – PacketAce Padding and Scalar Robustness

**Goal:** All known PacketAce-style padded integer cases are explicitly supported and covered by tests.

### 3.1 Confirm and document padded scalar handling
- **Files:**
  - `lib/bindocsis/value_formatter.ex`
  - `lib/bindocsis/tlv_enricher.ex`
- **Tasks:**
  - Re-confirm logic for:
    - 4-byte zero-padded `uint8` (`00 00 00 07` → `7`).
    - 4-byte zero-padded `uint16` (`00 00 02 58` → `600`).
  - Ensure these cases:
    - Format to clean integers for humans,
    - Unenrich back to the original padded width when regenerating binary.

### 3.2 Add focused tests for padded values
- **Files:**
  - `test/bindocsis/value_types_test.exs`
  - Possibly a dedicated `test/bindocsis/service_flow_padding_test.exs`
- **Tasks:**
  - For each padded case:
    - Start from real on-wire bytes.
    - Parse → enrich → show `formatted_value` → unenrich → encode.
    - Assert the output binary equals the input binary.


## Phase 4 – Error Messages and Debuggability

**Goal:** When something is off-spec or malformed, users see *where* and *why* without the tool crashing.

### 4.1 Localize error handling in the editor
- **Files:**
  - `lib/bindocsis/interactive_editor.ex`
- **Tasks:**
  - Narrow `try/rescue ArgumentError` in `show_configuration/2`:
    - Prefer smaller scopes around `show_tlv/4` and `format_subtlv_value/1`.
    - On error, print which TLV/sub-TLV failed (e.g. `"Error displaying TLV 11, SubTLV 48: ..."`).
  - Keep the top-level rescue only as a last resort.

### 4.2 Improve CLI error messages
- **Files:**
  - `lib/bindocsis/cli.ex`
- **Tasks:**
  - Wrap risky operations (parse, pretty-print, validate) with context-aware error messages.
  - When possible, include TLV index/type in the error output instead of a raw `argument error`.


## Phase 5 – Compatibility Layer Documentation

**Goal:** Make all intentional off-spec behaviors explicit and discoverable.

### 5.1 Create a compatibility document
- **Files:**
  - New: `COMPATIBILITY.md` (or expand `CLAUDE.md` if you prefer a single doc)
- **Tasks:**
  - Document for each known off-spec pattern:
    - Description (e.g. `4-byte zero-padded uint16 for service-flow IDs`).
    - Origin (e.g. PacketAce, specific vendor).
    - How Bindocsis interprets it (parsing and formatting rules).
    - Where it is implemented in code.
  - Include TLV 11 behavior: when we fall back to hex vs. structured SNMP map.

### 5.2 Link from README / help output
- **Files:**
  - `README.md`
  - `lib/bindocsis/cli.ex` (help text)
- **Tasks:**
  - Add a short note and link to the compatibility doc so users know what to expect.


## Phase 6 – Shared Rendering / Refactor (Optional, Later)

**Goal:** Reduce duplicated logic between `pretty_print/2` and the interactive editor.

### 6.1 Introduce a shared TLV rendering helper
- **Files:**
  - `lib/bindocsis.ex`
  - `lib/bindocsis/interactive_editor.ex`
- **Tasks:**
  - Design a function like `render_tlv/2` that returns a pure data structure:
    - `%{type, name, length, formatted_value, subtlvs: [...]}`.
  - Refactor:
    - `Bindocsis.pretty_print/2` to print from this structure.
    - `InteractiveEditor.show_tlv/4` and `show_subtlvs/2` to reuse it.

### 6.2 Regression tests for rendering
- **Files:**
  - New tests focused on rendering only (no binary regeneration).
- **Tasks:**
  - Ensure rendering of representative TLVs (service flows, TLV 11, QoS, etc.) remains stable.

---

This roadmap is meant to be living documentation. As we discover new off-spec patterns or edge cases in the field, we can:

- Add them to **Phase 1 or 3** (if they’re value/ASN.1 related),
- Extend **Phase 5** with new compatibility rules, and
- Keep the core invariants (round-trip safety, human-editable `formatted_value`) intact.
