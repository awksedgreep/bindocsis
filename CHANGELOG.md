# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.13.0] - 2026-11-08

PacketCable MTA support checked against ~2,500 production eMTA files
(BASIC flow). Minor bump because MTA output and `MtaSpecs` change.

### Added
- Parse and auto-detect the `docsis-configfile` YAML dialect
  (`MtaConfigDelimiter`, `SnmpMibObject`, `VendorSpecific`), the format eMTA
  provisioning templates use. 2,331 of 2,339 well-formed production templates
  generate their deployed `.bin` byte for byte.
- `format: :docsis_configfile_yaml` generation (MTA binary to that dialect),
  with a built-in check that the YAML converts back to the same bytes.
- `HumanConfig.to_yaml/from_yaml` edit MTA files through that dialect; they
  raised `FunctionClauseError` on every MTA file before.
- `MtaBinaryParser.parse_document/1` returns the DOCSIS End-of-Data trailer
  (0xFF + zero padding); `MtaBinaryGenerator` writes it back with `trailer:`.
- `Bindocsis.MtaTlvLength`: PacketCable length fields.
- Fixture comparison task and YAML-to-MTA benchmark.

### Changed (breaking)
- MTA wire format follows PKT-SP-PROV1.5 §9.1: a 1-byte length for every
  type except TLV 64 (2 bytes). There are no DOCSIS 0x81/0x82/0x84 extended
  lengths. A TLV 11 over 254 bytes is refused; the YAML dialect writes such
  objects as TLV 64.
- The MTA generator no longer appends 0xFF by default (a PacketCable file
  ends with its TLV 254 = 0xFF end marker). Use `terminate: true` or
  `trailer:` for DOCSIS-style output.
- `MtaSpecs` lists only spec-defined types (254, 11, 64, 38, 43, plus the
  DOCSIS 6/7 MICs). The invented types 1-5 and 64-85 ("MTA Configuration
  File", "Kerberos Realm", "Line Package", ...) are gone, so text-config MTA
  names change accordingly.
- `Bindocsis.parse/2` reads a binary that starts with TLV 254 = 0x01 as an
  MTA file. It was parsed as ASN.1.

### Fixed
- MTA files ending in 0xFF + padding (DOCSIS-tool built) failed to parse
  (102 of 2,538 production files).
- Negative `INTEGER` values in docsis-configfile YAML were mis-encoded (-1
  was written as 0).
- Forward conversion options to both parsing and generation.

## [0.12.0] - 2026-09-10

Every open GitHub issue (#5-#17) triaged and worked on branch `gh_issues`;
see `docs/dev/gh_issues_plan.md` for the per-issue evaluation. Minor bump
because the text config format change below is breaking.

### Changed (breaking)
- **Text config format rebuilt on the specification tables** (#6). Names
  are now derived from `DocsisSpecs`/`MtaSpecs`/`SubTlvSpecs`
  (`NetworkAccessControl`, `SWUpgradeFilename`, `UpstreamServiceFlow`,
  sub-TLV names by parent path, `TLV<n>` for anything unnamed). The
  hand-written tables that contradicted the spec (`WebAccessControl`,
  `TFTPServer`, `IPAddress`, `cmic`=9, ...) are gone. Values use the same
  human forms as JSON/YAML `formatted_value`; `0x...` hex is accepted for
  any type; compounds nest to any depth; every bad line fails the parse
  with its line number; `generate |> parse` is byte-exact. See
  `docs/FORMAT_SPECIFICATIONS.md`.
- Binary parser no longer swallows a trailing byte or non-zero bytes after
  the `0xFF` End-of-Data marker; both are `{:error, reason}` (#5). The
  format validator's verdict is honoured instead of discarded.
- MTA parser reports a length that exceeds the data instead of inventing a
  zero-length TLV (#9). `test/fixtures/test_mta.bin` is malformed and is
  now asserted to be rejected.
- `ValueParser`: integers out of range for `uint8`/`uint16`/`uint32` are
  errors instead of being widened; hex input for `uint32` is never
  truncated (#8).
- `TlvEnricher.unenrich_tlv/2` keeps the original bytes for an unchanged
  `formatted_value` and honours the edited length otherwise; it no longer
  zero-pads a shortened value (#8).
- Strict MIC validation failure is `{:error, "MIC validation failed: ..."}`
  (a string, as `parse/2`'s spec says) instead of a tuple (#8).
- Parents with `subtlvs` no longer carry a `formatted_value` in the
  enricher or the YAML generator (#7).

### Added
- `Bindocsis.TlvLength`: the single TLV length-field codec used by the
  binary/MTA generators, the binary parser, the enricher and the config
  parser (#6, #7).
- `Bindocsis.ConfigNames`: spec-derived identifier table for the config
  format (#6).
- Web: the LiveView origin check is enabled in prod (`check_origin: true`,
  host must match `PHX_HOST`) with a `CHECK_ORIGIN` override (#10);
  `BindocsisWeb.Params` safe decoding of LiveView params (#11);
  `BindocsisWeb.Uploads` policy with server-side extension checks and a
  bounded, LRU-evicting `ConfigStore` with per-owner quota (#12);
  registration policy (`REGISTRATION_MODE` = open/closed/allowlist,
  `REGISTRATION_ALLOWLIST`) and in-memory rate limiting of password login,
  magic links, registration and uploads (#13).
- GitHub Actions workflow running `mix format --check-formatted` and
  `mix test` on pushes and pull requests (#16).
- SQLite WAL journaling and a busy timeout for the accounts database (#16).
- `mix test` creates and migrates its own `bindocsis_test.db` (#15).

### Fixed
- `mix test` was red on a clean checkout: the Phoenix `DataCase`/`ConnCase`
  support modules were missing (#15).
- JSON/YAML sub-TLV detection used a wrong length-field size, so compounds
  whose sub-TLVs have 128-255 byte values lost their `subtlvs` (#7).
- The JSON hex heuristic could rewrite a `:string` value such as `"beef"`
  into bytes (#7).
- LiveViews crashed on non-numeric URL/`phx-value` params and leaked atoms
  from `String.to_atom/1` on client input (#11).
- Magic-link login revealed whether an email is registered (#13).
- Build artifacts (compiled escript, dev SQLite DB, `.DS_Store`, scratch
  scripts) were tracked in git; `.gitignore` extended (#14).
- `mix.exs` documentation source links pointed at two stale tags; they now
  derive from the project version (#16).

### Removed
- Nine debug/verify scratch scripts from `test/`, two of which ran (and
  printed) on every `mix test` (#15).

## [0.11.0] - 2026-09-08

### Added
- **`bindocsis tui` full-screen terminal browser** (read-only Phase 1) — TLV tree,
  detail, and hex panes with search/filter, validation overlay, and key help,
  built on `ex_ratatui` (LiveView-style callback runtime, headless-tested).
  Requires a TTY and the ExRatatui NIF (mix/release builds); escript and
  piped invocations fail with guidance toward `parse`/`validate`.
- **TUI editing (Phase 2)** - edit leaf-TLV `formatted_value` inline (`e`),
  commit via `ValueParser` with unenrich/re-enrich round trip, save (`s`) with
  CM MIC recomputation (CMTS MIC needs `BINDOCSIS_SHARED_SECRET`), export
  overlay (`X`: binary/json/yaml/config), unsaved-changes quit confirm.
- `snmpkit` dependency for upcoming MIB/ASN.1 bootfile (TLV 11) support.

### Fixed
- Compiler warning cleanup (bitstring pins, dead clauses, heredoc indent).
- Unknown-type TLVs now survive config-format round-trips (generic `TLVnnn`
  syntax, quoted-empty raw values).

## [0.10.0] - 2026-08

### Added
- Citation-backed TLV registry (`priv/tlv_registry.json`) and
  registry-generated round-trip tests: every leaf path is synthesised and
  pushed through binary -> JSON/YAML -> binary.
- Corpus ratchet test with shrink-only gap snapshots in `test/known_gaps/`.
- Optional differential harness against the `docsis` reference tool.
- eRouter (TLV 202) sub-TLV specs per CM-SP-eRouter Annex B.4.
- Email-based (magic link / password) authentication for the web UI and a
  Fly.io deployment; multi-arch container builds via GitHub Actions.
- Binary DOCSIS content detected regardless of file extension.

### Changed
- Spec audit: fabricated TLV specs purged, Annex C tables completed.
- CM MIC computed as plain MD5 and CMTS MIC over the spec-ordered subset.

## [0.9.x] - 2026

### Added
- Phoenix LiveView web UI ("Cable Guy Gets a GUI"): dashboard, config list,
  viewer (tree/table/hex), editor, TLV browser, embeddable via the
  `bindocsis_live` router macro or the standalone server.
- Editor and SNMP TLV display fixes.

## [0.8.1] - 2026

### Fixed
- All Elixir compile warnings eliminated.

## [0.8.0] - 2025-11

### Added
- **DOCSIS 3.1 OFDM/OFDMA profiles**: TLV 62 (Downstream OFDM Profile, 12
  sub-TLVs) and TLV 63 (Downstream OFDMA Profile, 13 sub-TLVs) with
  enumerations for subcarrier spacing, cyclic prefix, roll-off, interleaver
  depth, pilot pattern; unknown sub-TLVs fall back to hex strings.
- Unit and integration tests for the new profiles (binary <-> JSON <-> YAML).
- Documentation: `docs/OFDM_OFDMA_Specification.md`, updated
  `docs/Important_TLVs.md`, `docs/PHASE_1_COMPLETE.md`, `docs/PHASE_2_PLAN.md`
  (the earlier `support_31.md` plan file has been removed).

### Fixed
- Incorrect TLV 62/63 descriptions in `Important_TLVs.md`.
- Missing sub-TLV specifications for DOCSIS 3.1 channel profiles.

## [0.7.0] - 2025

### Features
- DOCSIS 1.0, 1.1, 2.0, 3.0 support
- TLV 77-85 (DOCSIS 3.1 extension TLVs)
- TLV 86-110+ (extended TLVs)
- Multi-format support (Binary, JSON, YAML, Config)
- Interactive CLI editor
- PacketCable/MTA ASN.1 support
- Validation framework
- Human-friendly tools (bandwidth setting, config analysis)
