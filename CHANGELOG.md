# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added
- **COMPLETE DOCSIS 3.1 Support** - TLV 62 and 63 sub-TLV specifications
- Downstream OFDM Profile (TLV 62) with 12 sub-TLV specifications
  - Profile ID, Channel ID, Configuration Change Count
  - Subcarrier Spacing (25 kHz / 50 kHz enum)
  - Cyclic Prefix (8 options: 192-1024 samples)
  - Roll-off Period (5 options: 0-256 samples)
  - Interleaver Depth (6 options: 1-32)
  - Modulation Profile (compound)
  - Start/End Frequency (uint32 Hz)
  - Number of Subcarriers (uint16)
  - Pilot Pattern (Scattered/Continuous/Mixed enum)
- Downstream OFDMA Profile (TLV 63) with 13 sub-TLV specifications
  - All OFDM sub-TLVs plus:
  - Mini-slot Size (uint8, OFDMA-specific)
  - Power Control (int8 dB, OFDMA-specific)
- Comprehensive test coverage for OFDM/OFDMA profiles
  - 36 unit tests for sub-TLV specifications
  - 9 integration tests for round-trip conversion
  - Binary ↔ JSON ↔ YAML round-trip verification
  - Unknown sub-TLV fallback to hex string
- Complete DOCSIS 3.1 documentation
  - Technical specification: `docs/OFDM_OFDMA_Specification.md`
  - Updated TLV reference: `docs/Important_TLVs.md`
  - Implementation plan: `support_31.md`
  - Phase 2 planning: `docs/PHASE_2_PLAN.md`

### Fixed
- Documentation error in `Important_TLVs.md` (TLV 62/63 descriptions were incorrect)
- Missing sub-TLV specifications for DOCSIS 3.1 channel profiles

### Changed
- Updated README with DOCSIS 3.1 OFDM/OFDMA feature highlights
- Updated test suite: 1249 tests, 0 failures (45 new tests added)

## [0.7.0] - Previous Release

### Features
- DOCSIS 1.0, 1.1, 2.0, 3.0 support
- TLV 77-85 (DOCSIS 3.1 extension TLVs)
- TLV 86-110+ (extended TLVs)
- Multi-format support (Binary, JSON, YAML, Config)
- Interactive CLI editor
- PacketCable/MTA ASN.1 support
- Validation framework
- Human-friendly tools (bandwidth setting, config analysis)

---

## Notes

### DOCSIS 3.1 Implementation Timeline
- **Phase 1 (Complete)**: TLV 62/63 OFDM/OFDMA Profile implementation
  - Completion: November 6, 2025
  - Duration: 4 days (ahead of 7-day estimate)
  - Git commits: 7 commits with comprehensive documentation
- **Phase 2 (Planned)**: Documentation polish and test fixtures (1-2 days)

### Breaking Changes
None. This release only adds new functionality without modifying existing TLV handling.

### Migration Guide
No migration required. New DOCSIS 3.1 OFDM/OFDMA support is backward compatible with existing configurations.

### Acknowledgments
- CableLabs for DOCSIS 3.1 specifications
- Community feedback on OFDM/OFDMA support requirements
