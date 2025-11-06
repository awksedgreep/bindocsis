# Critical Blockers - Implementation Plan

**Status:** Planning Phase  
**Target:** v0.1.0-rc1 Release  
**Timeline:** 2-3 weeks  
**Last Updated:** November 6, 2025

---

## Overview

These are **P0 blockers** that prevent public release. Each must be fixed before publishing to Hex.pm.

**Completion Status:** 4/6 complete (67%)

---

## ✅ Blocker #1: Context-Aware Sub-TLV Naming
**Status:** ✅ **COMPLETED** (November 5, 2025)  
**Priority:** P0  
**Complexity:** Medium

### Problem
Sub-TLV 6 was showing incorrect names in different contexts:
- In service flows (TLV 24/25): Should be "QoS Parameter Set" 
- At global level: Should be "CM Message Integrity Check"

### Solution Implemented
- Updated `lib/bindocsis/sub_tlv_specs.ex` to use context-aware lookups
- Modified lookup logic to check parent TLV type
- Added regression tests in `test/regression_test.exs`

### Test Coverage
- ✅ Service flow context tests passing
- ✅ Global context tests passing  
- ✅ JSON/YAML generator tests passing
- ✅ 7/8 regression tests passing (1 skipped for unrelated YAML bug)

---

## ✅ Blocker #2: ASN.1 DER Parsing Bug
**Status:** ✅ **COMPLETED** (November 5, 2025)  
**Priority:** P0  
**Complexity:** Medium

### Problem
TLV 11 (SNMP MIB Object) sub-TLV 48 (Object Value) with ASN.1 DER bytes was being incorrectly parsed as TLV structures instead of being treated as atomic data.

### Solution Implemented
- Added `:asn1_der` to atomic value types in enrichment logic
- Fixed TLV 11 spec: changed from `:asn1_der` (incorrect) to `:compound` (correct)
- Sub-TLV 48 properly marked as `:asn1_der` in specs
- Added regression tests

### Test Coverage
- ✅ ASN.1 DER not parsed as TLVs
- ✅ TLV 11 enrichment works correctly
- ✅ Sub-TLV 48 maintains atomic data

---

## ✅ Blocker #3: JSON/YAML Round-Trip Conversion Failures
**Status:** ✅ **COMPLETED** (November 6, 2025)  
**Priority:** P0 - CRITICAL  
**Complexity:** High

### Problem Statement
The core value proposition of Bindocsis is "human-friendly editing" via JSON/YAML. This was fundamentally broken due to value serialization bugs:

1. **Integer-to-ASCII Bug:** Integer values like `1000000` were converted to ASCII string bytes
2. **Value Type Misidentification:** uint32 values incorrectly classified as `hex_string` instead of `uint32`
3. **Length Mismatches:** After round-trip, byte counts didn't match (e.g., 15 bytes → 14 bytes)
4. **Edge Case Handling:** TLVs with binary lengths that didn't match DOCSIS spec caused round-trip failures

### Impact (RESOLVED)
- ✅ Users can now edit configs via JSON/YAML
- ✅ Integration with config management tools works
- ✅ All integration tests passing
- ✅ Primary differentiator from competitors now functional

### Root Causes & Solutions Implemented

#### Issue 3.1: Value Type Detection ✅ COMPLETE (November 5, 2025)
**Root Cause:** 
The JSON generator's `correct_hex_string_value_type` function was incorrectly changing enriched uint32 values to hex_string, causing byte loss.

**Solution:**
Modified `lib/bindocsis/generators/json_generator.ex` to skip hex_string correction for TLVs successfully enriched with atomic value types.

---

#### Issue 3.2: Edge Case TLV Length Handling ✅ COMPLETE (November 6, 2025)
**Root Cause:**
TLVs with binary data lengths that didn't match their DOCSIS spec's `max_length` were being formatted according to the spec's `value_type`, causing round-trip failures.

**Examples:**
- **test_mta.bin**: TLV 69 had 2 bytes but spec says uint8 (max_length: 1)
- **simple_edge_case.cm**: TLV 43 had 254 bytes but spec says uint8 (max_length: 1)

**Solution Implemented:**
Modified `lib/bindocsis/tlv_enricher.ex` to validate binary length matches expected length for fixed-length value types. When there's a mismatch, format as hex_string instead.

**Testing Results:**
- ✅ All 985 tests pass (0 failures)
- ✅ All 11 integration round-trip tests pass
- ✅ Edge case tests pass
- ✅ Malformed TLV data handled gracefully

**Files Modified:**
1. `lib/bindocsis/generators/json_generator.ex` - Fixed hex_string correction
2. `lib/bindocsis/tlv_enricher.ex` - Added length validation
3. Multiple test files - All passing

---

## ✅ Blocker #4: Binary Integrity Validation (MIC)
**Status:** ✅ **COMPLETED** (November 6, 2025)  
**Priority:** P0 - CRITICAL  
**Complexity:** High

### Problem Statement
DOCSIS configurations require Message Integrity Check (MIC) TLVs to ensure authenticity:
- **TLV 6 (CM MIC)**: Cable Modem Message Integrity Check
- **TLV 7 (CMTS MIC)**: Cable Modem Termination System MIC

### Implementation Phases

#### Phase 4.1: Documentation & Test Vectors ✅
- `docs/mic_algorithm.md` - HMAC-MD5 specification
- `docs/mic_api_design.md` - API design patterns
- Test vectors with documented secrets

#### Phase 4.2: Core MIC Module ✅
- **File:** `lib/bindocsis/crypto/mic.ex` (390 lines)
- **API:** compute/validate for CM MIC and CMTS MIC
- **Algorithm:** HMAC-MD5 per DOCSIS 3.1 spec
- **Tests:** 29 comprehensive tests

#### Phase 4.3: Parser Integration ✅
- Added `validate_mic`, `shared_secret`, `strict` options
- Strict mode fails on invalid MIC
- Warn mode logs and continues
- **Tests:** 13 integration tests

#### Phase 4.4: Generator Integration ✅
- Added `add_mic`, `shared_secret` options
- Strips existing MICs, computes fresh ones
- **Tests:** 12 integration tests

### Usage

```elixir
# Parse with validation
{:ok, tlvs} = Bindocsis.parse_file("config.cm",
  validate_mic: true, shared_secret: "secret")

# Generate with MIC
{:ok, binary} = Bindocsis.generate(tlvs,
  format: :binary, add_mic: true, shared_secret: "secret")
```

### Test Coverage
- ✅ 54 MIC-related tests (all passing)
- ✅ 1042 total tests (no regressions)
- ✅ End-to-end workflows validated

---

## Timeline Summary

| Blocker | Status | Start Date | Target Date |
|---------|--------|------------|-------------|
| 1. Context-Aware Naming | ✅ DONE | Nov 4 | Nov 5 |
| 2. ASN.1 DER Parsing | ✅ DONE | Nov 4 | Nov 5 |
| 3. JSON/YAML Round-Trip | ✅ DONE | Nov 5 | Nov 6 |
| 4. MIC Validation | 🔴 Next | Nov 7 | Nov 13 |
| 5. MTA Generation | 🔴 Pending | Nov 14 | Nov 16 |
| 6. Length Encoding | 🔴 Pending | Nov 17 | Nov 18 |

**Current Status: 50% complete, on track for Nov 18 release! 🎯**
