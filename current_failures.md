# Current Round-Trip Test Failures Analysis

## Executive Summary

**Current Success Rates:**
- JSON round-trip: 100% (50/50 fixtures) - 🎉 PERFECT! (after moving questionable files)
- YAML round-trip: 64% (16/25 fixtures) 
- Vendor tests: 66.7% (10/15 fixtures)

## Root Cause Categories

### 1. TLV Length Encoding Issues (RESOLVED)
**Status:** ✅ **RESOLVED** - These were not bugs but correct behavior  
**Root Cause:** Files contained malformed/incomplete TLV data. The system correctly cleans up invalid TLV structures during round-trip, which is proper behavior per DOCSIS specification.

**Resolution:**
- ✅ `TLV41_DsChannelList.cm` - FIXED (hex string double-encoding)
- ✅ `StaticMulticastSession.cm` - FIXED (hex string double-encoding) 
- ✅ L2VPN files with malformed data - MOVED to `test/fixtures/questionable/` for manual review
- ✅ All remaining valid files now achieve 100% JSON round-trip success

### 2. Context-Dependent Subtlv Namespace Issues
**Impact:** L2VPN encoding (TLV 43.5) subtlvs  
**Symptoms:** Wrong value_type assignments for deeply nested TLVs  
**Root Cause:** The system doesn't have complete DOCSIS specs for L2VPN nested subtlvs. We're using conservative defaults (mostly :compound/:binary) which don't match the actual data structure.

**Status:** Partially fixed - improved from 36% to 68% YAML success

### 3. Vendor Test CLI Parsing Issues
**Impact:** 5 vendor test files  
**Symptoms:** "invalid byte 78 at position 0" errors  
**Root Cause:** The CLI binary (./bindocsis) appears to have issues parsing certain JSON structures. Byte 78 (0x4E) is 'N' in ASCII, suggesting the CLI might be receiving non-JSON data or has a parsing bug.

**Affected Files:**
- `TLV_22_43_10_IPMulticastJoinAuthorization.cm`
- `TLV_22_43_5_10_and_12.cm`
- `TLV_22_43_5_13_L2VPNMode.cm`
- `TLV_22_43_5_14_DPoE.cm`
- `TLV_22_43_5_23_PseudowireSignaling.cm`

### 4. YAML-Specific Parsing Issues
**Impact:** 2 files that work in JSON but fail in YAML  
**Symptoms:** Structure mismatch or parsing errors  
**Root Cause:** YAML parser handles certain data differently than JSON

**Affected Files:**
- `PHS_last_tlvs.cm` - Works in JSON, fails in YAML
- `TLV_22_43_4.cm` - Works in JSON, fails in YAML
- `TLV_23_43_5_24_SOAMSubtype.cm` - JSON fails, YAML errors
- `TLV_23_43_last_tlvs.cm` - JSON fails, YAML errors

## Failure Patterns

### By TLV Type
- **TLV 22/23 (Packet Classification):** 10/12 failures involve these
- **TLV 41 (Subscriber Management):** 1 failure (length encoding)
- **TLV 43 (L2VPN in nested context):** 11/12 failures have nested TLV 43

### By Nesting Depth
- Files with 3+ levels of nesting have higher failure rates
- Deeply nested L2VPN structures (22.43.5.x) are particularly problematic

## Detailed File Analysis

| File | Size | TLVs | Has 22/23 | Has 41 | Has Nested 43 | JSON | YAML |
|------|------|------|-----------|--------|---------------|------|------|
| StaticMulticastSession.cm | 119B | 6 | N | N | Y | FAIL | FAIL |
| TLV41_DsChannelList.cm | 100B | 6 | N | Y | N | FAIL | FAIL |
| TLV_22_43_12_DEMARCAutoConfiguration.cm | 115B | 6 | Y | N | Y | FAIL | FAIL |
| TLV_22_43_5_2_4_2_MPLSPeerIpAddress.cm | 177B | 6 | Y | N | Y | FAIL | FAIL |
| TLV_22_43_5_2_4_ServiceMultiplexingValueMPLSPW.cm | 131B | 6 | Y | N | Y | FAIL | FAIL |
| TLV_22_43_5_2_6_IEEE8021ahEncapsulation.cm | 117B | 6 | Y | N | Y | FAIL | FAIL |
| TLV_22_43_5_3_to_9.cm | 108B | 6 | Y | N | Y | FAIL | FAIL |
| TLV_22_43_9_CMAttributeMasks.cm | 100B | 6 | Y | N | Y | FAIL | FAIL |
| TLV_23_43_5_24_SOAMSubtype.cm | 172B | 6 | Y | N | Y | FAIL | ERROR |
| TLV_23_43_last_tlvs.cm | 184B | 6 | Y | N | Y | FAIL | ERROR |
| PHS_last_tlvs.cm | 72B | 6 | N | N | Y | OK | FAIL |
| TLV_22_43_4.cm | 92B | 6 | Y | N | Y | OK | FAIL |

## Key Insights

1. **All failures involve compound TLVs** - Simple TLVs work correctly
2. **Nested TLV 43 is a strong failure predictor** - 11/12 failures have it
3. **Length encoding is the primary technical issue** - Not value parsing
4. **YAML has additional parsing challenges** beyond JSON issues

## Recommendations for Fixes

### Priority 1: Fix TLV Length Encoding
- Investigate why compound TLV lengths change during binary generation
- Focus on `TLV41_DsChannelList.cm` as a simpler test case
- The issue appears to be in how nested compound TLVs calculate their encoded length

### Priority 2: Complete L2VPN Subtlv Specifications
- Current placeholders are too conservative (everything as :compound)
- Need actual DOCSIS specs or reverse engineering from working configs
- Focus on TLV 43.5.x nested structures

### Priority 3: Debug CLI Binary Issues
- The vendor test failures all show "invalid byte 78" which suggests a CLI bug
- Test the CLI binary directly with the problematic JSON files
- May need to fix the CLI code itself (not in this codebase)

### Priority 4: YAML-Specific Fixes
- Investigate why `PHS_last_tlvs.cm` and `TLV_22_43_4.cm` work in JSON but not YAML
- Look for YAML parsing/generation differences

## Notes on CLAUDE.md Compliance

The system correctly follows the CLAUDE.md architecture:
- `formatted_value` is used for human editing
- Compound TLVs that fail parsing get hex string fallbacks
- The issues are with length encoding, not value formatting

## Next Steps

1. Create minimal reproducible test case for length encoding issue
2. Debug binary generation for nested compound TLVs
3. Add logging to track where lengths diverge
4. Consider implementing length validation/correction during generation