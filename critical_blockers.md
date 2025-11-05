# Critical Blockers - Implementation Plan

**Status:** Planning Phase  
**Target:** v0.1.0-rc1 Release  
**Timeline:** 2-3 weeks  
**Last Updated:** November 5, 2025

---

## Overview

These are **P0 blockers** that prevent public release. Each must be fixed before publishing to Hex.pm.

**Completion Status:** 2/6 complete (33%)

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

## 🔴 Blocker #3: JSON/YAML Round-Trip Conversion Failures
**Status:** 🔴 **IN PROGRESS**  
**Priority:** P0 - CRITICAL  
**Complexity:** High  
**Estimated Time:** 3-5 days

### Problem Statement
The core value proposition of Bindocsis is "human-friendly editing" via JSON/YAML. This is fundamentally broken due to value serialization bugs:

1. **Integer-to-ASCII Bug:** Integer values like `1000000` are converted to ASCII string bytes (`"31303030303030"` in hex), then those bytes are interpreted as integers, causing "out of range" errors
2. **Value Type Misidentification:** uint32 values incorrectly classified as `hex_string` instead of `uint32`
3. **Length Mismatches:** After round-trip, byte counts don't match (e.g., 15 bytes → 14 bytes)

### Impact
- ❌ Users cannot edit configs via JSON/YAML
- ❌ Breaks integration with config management tools
- ❌ Two integration tests currently skipped
- ❌ Undermines primary differentiator from competitors

### Root Cause Analysis

#### File: `lib/bindocsis/human_config.ex`
**Lines:** 130-180 (from_json/from_yaml functions)

**Issue:** When parsing human-readable values back to binary, the value conversion logic doesn't properly handle all data types.

```elixir
# Current problematic flow:
JSON: {"formatted_value": "1000000", "type": 9}
  ↓
Parser sees string "1000000"
  ↓
Converts to bytes: <<49, 48, 48, 48, 48, 48, 48>> (ASCII for "1000000")
  ↓
Expected: <<0, 0, 15, 66, 64>> (uint32 for 1,000,000)
```

#### File: `lib/bindocsis/value_parser.ex`
**Lines:** ~750-1000 (parse_value functions)

**Issues:**
1. Missing proper uint32 parsing from string representation
2. No validation of string-to-integer conversion
3. Inconsistent handling of hex_string vs integer types

#### File: `lib/bindocsis/value_formatter.ex`
**Lines:** ~80-150 (format_value functions)

**Issues:**
1. Some uint32 values being formatted as hex_string
2. Inconsistent formatting between similar types
3. No round-trip guarantee

#### File: `lib/bindocsis/tlv_enricher.ex`
**Lines:** ~700-750 (compound TLV parsing)

**Issues:**
1. Failed compound parsing falls back to hex_string incorrectly
2. Value type override logic too aggressive

### Implementation Plan

#### Phase 3.1: Diagnosis & Test Cases (Day 1) ✅ COMPLETE
**Goal:** Understand exact failure modes

**Tasks:**
1. ✅ Create comprehensive debug script
   ```bash
   elixir debug_value_roundtrip.exs
   ```
   - Test each value type (uint8, uint16, uint32, string, hex, etc.)
   - Track value transformations at each step
   - Document where values go wrong

2. ✅ Analyze actual library flow
   - Tested value parsers directly
   - Analyzed HumanConfig.from_json flow
   - Identified code path: formatted_value → ValueParser.parse_value

3. ✅ Map data flow
   ```
   TLV (binary) → Enrichment → JSON (formatted_value) → Parse → Binary
   ```

**Findings:**
- ✅ Basic value types (uint8, uint16, uint32, ipv4, string, hex_string) PASS round-trip tests
- ⚠️ Minor issue: Frequency formatting shows raw value (591131072) instead of Hz or MHz
- ✅ ValueParser.parse_value(:uint32, "1000000", []) correctly returns <<0, 15, 66, 64>>
- ✅ String-to-integer parsing already implemented and working
- ❓ Need to test with ACTUAL library through full TLV round-trip to find real bug

**Deliverables:**
- ✅ `debug_value_roundtrip.exs` - comprehensive diagnostic (20/22 tests pass)
- ✅ Code flow analysis complete
- ✅ `isolate_byte_loss_bug.exs` - found the exact bug!

**ROOT CAUSE IDENTIFIED:**
Sub-TLV 3 (Class of Service → Maximum Upstream Rate) is incorrectly identified as `hex_string` instead of `uint32`:
- Original value: `<<0, 3, 13, 64>>` (200,000 as uint32 = 4 bytes)
- Formatted as hex_string: `"20 00 00"` (only shows 3 bytes! Leading 00 dropped)
- Parsed back: 3 bytes instead of 4
- **Result:** Length mismatch 15 → 14 bytes

The issue is in **TLV enrichment**: When enriching sub-TLVs, the value_type is being set to `hex_string` instead of looking up the correct type from DocsisSpecs/SubTlvSpecs.

**Next Step:** Fix the enrichment logic to use the correct value_type from specs.

---

#### Phase 3.2: Fix Value Type Detection (In Progress)
**Goal:** Ensure sub-TLVs get correct value_type from specs

**Root Cause:** 
Sub-TLV 3 in Class of Service (parent TLV 4) is defined in SubTlvSpecs as:
```elixir
3 => %{
  name: "Maximum Upstream Rate",
  value_type: :uint32,  # ← Correct type in specs
  max_length: 4
}
```

But during enrichment, it's being set to `:hex_string` instead, likely through:
1. Fallback logic in `parse_compound_tlv_subtlvs` (lines 726-729, 742-745)
2. OR incorrect metadata lookup in `enrich_subtlv_with_specs`

**Investigation needed:**
- Why isn't the SubTlvSpecs lookup working for TLV 4 Sub-TLV 3?
- Is the parent context being passed correctly?
- Is there a code path that's overriding the spec value_type?

**Files to modify:**
- `lib/bindocsis/tlv_enricher.ex` - Fix value_type assignment logic

---

#### Phase 3.3: Value Formatter Consistency (Day 3-4)
**Goal:** Ensure formatters produce consistent output

**File:** `lib/bindocsis/value_formatter.ex`

**Changes Needed:**

1. **Standardize uint32 formatting**
   ```elixir
   def format_value(:uint32, <<value::32>>, _opts) do
     # Always format as decimal string
     {:ok, Integer.to_string(value)}
   end
   ```

2. **Fix hex_string formatting**
   ```elixir
   def format_value(:hex_string, value, opts) when is_binary(value) do
     # Always use space-separated uppercase hex
     formatted = value
       |> :binary.bin_to_list()
       |> Enum.map(&String.upcase(Integer.to_string(&1, 16)))
       |> Enum.map(&String.pad_leading(&1, 2, "0"))
       |> Enum.join(" ")
     
     {:ok, formatted}
   end
   ```

3. **Add round-trip validation**
   ```elixir
   # Internal function to verify formatting can be parsed back
   defp validate_round_trip(value_type, formatted_value) do
     case Bindocsis.ValueParser.parse_value(value_type, formatted_value, []) do
       {:ok, _} -> :ok
       {:error, reason} ->
         Logger.warning("Format/parse mismatch for #{value_type}: #{reason}")
         :error
     end
   end
   ```

**Testing:**
- Verify every formatted value can be parsed back
- Check uint32 values don't become hex_string
- Test frequency formatting round-trip

---

#### Phase 3.4: Enricher Value Type Logic (Day 4)
**Goal:** Fix value type classification in enricher

**File:** `lib/bindocsis/tlv_enricher.ex`

**Changes Needed:**

1. **Fix compound TLV fallback** (lines ~726-745)
   ```elixir
   # Current: Falls back to hex_string on parse failure
   # Better: Use spec-defined value_type as fallback
   
   case parse_compound_tlv_subtlvs(parent_type, value, opts) do
     {:ok, subtlvs} ->
       # Success - use compound
       metadata
       |> Map.put(:subtlvs, subtlvs)
       |> Map.put(:value_type, :compound)
     
     {:error, _reason} ->
       # Failed - use SPEC value type, not hex_string
       spec_value_type = case DocsisSpecs.get_tlv_info(type) do
         {:ok, info} -> info.value_type
         _ -> :hex_string  # Only if no spec
       end
       
       formatted = format_for_value_type(value, spec_value_type, opts)
       metadata
       |> Map.put(:formatted_value, formatted)
       |> Map.put(:value_type, spec_value_type)
   end
   ```

2. **Add value type override validation**
   ```elixir
   defp should_override_value_type?(spec_type, detected_type) do
     # Only override if spec type is generic
     spec_type in [:binary, :hex_string] and 
       detected_type in [:uint8, :uint16, :uint32, :frequency]
   end
   ```

**Testing:**
- Verify TLV 4 sub-TLVs maintain uint32 type
- Check service flow sub-TLVs (types 24/25)
- Test vendor TLVs don't get misclassified

---

#### Phase 3.5: HumanConfig Integration (Day 5)
**Goal:** Fix JSON/YAML conversion entry points

**File:** `lib/bindocsis/human_config.ex`

**Changes Needed:**

1. **Fix from_json conversion** (lines ~130-180)
   ```elixir
   defp convert_json_to_tlvs(json_data, opts) do
     tlvs = get_in(json_data, ["tlvs"]) || []
     
     Enum.map(tlvs, fn tlv_map ->
       # Get TLV spec to know expected value type
       spec = case DocsisSpecs.get_tlv_info(tlv_map["type"]) do
         {:ok, spec_info} -> spec_info
         _ -> %{value_type: :hex_string}
       end
       
       # Parse value with spec context
       value = parse_json_value(tlv_map, spec, opts)
       
       # Handle sub-TLVs recursively
       subtlvs = if tlv_map["subtlvs"] do
         convert_json_to_tlvs(%{"tlvs" => tlv_map["subtlvs"]}, opts)
       else
         nil
       end
       
       %{
         type: tlv_map["type"],
         length: byte_size(value),
         value: value,
         subtlvs: subtlvs
       }
     end)
   end
   
   defp parse_json_value(tlv_map, spec, opts) do
     value_type = spec.value_type
     formatted_value = tlv_map["formatted_value"]
     
     case Bindocsis.ValueParser.parse_value(value_type, formatted_value, opts) do
       {:ok, binary_value} -> binary_value
       {:error, reason} ->
         # Log and fall back to hex parsing
         Logger.warning("Failed to parse #{value_type}: #{reason}")
         parse_hex_value(formatted_value)
     end
   end
   ```

2. **Add validation before binary generation**
   ```elixir
   defp validate_tlvs_before_generation(tlvs) do
     Enum.all?(tlvs, fn tlv ->
       # Check required fields
       Map.has_key?(tlv, :type) and
       Map.has_key?(tlv, :length) and
       Map.has_key?(tlv, :value) and
       # Check length matches value
       tlv.length == byte_size(tlv.value)
     end)
   end
   ```

**Testing:**
- Full round-trip test: binary → JSON → binary
- Verify byte-for-byte match on known good configs
- Test with real DOCSIS fixtures

---

#### Phase 3.6: Integration Testing (Day 5-6)
**Goal:** Verify all fixes work together

**Tasks:**

1. **Unskip integration tests**
   - Remove `@tag :skip` from round_trip_test.exs line 82
   - Remove `@tag :skip` from round_trip_test.exs line 255
   - Both should pass

2. **Create comprehensive round-trip test**
   ```elixir
   # test/integration/complete_round_trip_test.exs
   
   test "every value type survives round-trip" do
     test_cases = [
       {:uint8, <<1>>, "1"},
       {:uint16, <<1, 0>>, "256"},
       {:uint32, <<0, 15, 66, 64>>, "1000000"},
       {:frequency, <<35, 57, 241, 192>>, "591000000"},
       {:ipv4, <<192, 168, 1, 1>>, "192.168.1.1"},
       # ... etc
     ]
     
     for {type, binary, formatted} <- test_cases do
       # Test format → parse
       {:ok, parsed} = ValueParser.parse_value(type, formatted, [])
       assert parsed == binary, "#{type} parse failed"
       
       # Test parse → format
       {:ok, reformatted} = ValueFormatter.format_value(type, binary, [])
       assert reformatted == formatted, "#{type} format failed"
     end
   end
   ```

3. **Test with real fixtures**
   ```bash
   # Run against all test fixtures
   for file in test/fixtures/*.cm; do
     echo "Testing $file"
     elixir test_round_trip.exs $file
   done
   ```

4. **Regression test suite**
   ```bash
   mix test test/regression_test.exs
   # Should have 0 failures, 1 skipped (YAML bug)
   ```

**Success Criteria:**
- ✅ All unit tests pass
- ✅ Both integration tests pass (unskipped)
- ✅ All fixtures complete round-trip
- ✅ No data corruption detected
- ✅ Regression tests still pass

---

### Files to Modify

| File | Lines | Changes | Priority |
|------|-------|---------|----------|
| `lib/bindocsis/value_parser.ex` | ~750-1000 | Add string parsing for all integer types | P0 |
| `lib/bindocsis/value_formatter.ex` | ~80-150 | Standardize output formats | P0 |
| `lib/bindocsis/tlv_enricher.ex` | ~726-745 | Fix value type fallback logic | P0 |
| `lib/bindocsis/human_config.ex` | ~130-180 | Fix JSON/YAML conversion | P0 |
| `test/integration/round_trip_test.exs` | 82, 255 | Unskip tests | P0 |

### Testing Strategy

1. **Unit Tests:** Each value type in isolation
2. **Integration Tests:** Full round-trip workflows
3. **Fixture Tests:** Real DOCSIS configs
4. **Regression Tests:** Ensure previous fixes still work

### Risk Mitigation

**Risk:** Breaking existing parsing  
**Mitigation:** Run full test suite after each phase

**Risk:** Missing edge cases  
**Mitigation:** Test boundary values (0, max, overflow)

**Risk:** Performance degradation  
**Mitigation:** Benchmark before/after

---

## 🔴 Blocker #4: Binary Integrity Validation (MIC)
**Status:** 🔴 **NOT STARTED**  
**Priority:** P0 - CRITICAL  
**Complexity:** High  
**Estimated Time:** 4-6 days

### Problem Statement
DOCSIS configs must have cryptographic signatures (MIC - Message Integrity Check) to be accepted by cable modems. The library currently:
- ❌ Does not validate MIC on parse
- ❌ Does not generate MIC on binary creation
- ❌ No warning when MIC is missing
- ❌ Accepts invalid/corrupted signatures

This is a **security and compliance issue**.

### Background
DOCSIS uses HMAC-MD5 for message authentication:
- **TLV 6 (CM MIC):** Cable Modem Message Integrity Check
- **TLV 7 (CMTS MIC):** Cable Modem Termination System MIC

Both require a shared secret (password) to compute.

### Implementation Plan

#### Phase 4.1: Research & Design (Day 1)
**Goal:** Understand DOCSIS MIC requirements

**Tasks:**
1. Review DOCSIS specification sections on MIC
   - Read: DOCSIS 3.1 spec, Section 7.2
   - Understand: MIC computation algorithm
   - Note: TLV ordering requirements

2. Study existing implementations
   - Look at: docsis_config_lib (Ruby)
   - Look at: netsnmp code
   - Document: Algorithm details

3. Design API
   ```elixir
   # Option 1: Automatic validation (recommended)
   {:ok, tlvs} = Bindocsis.parse_file("config.cm", 
     validate_mic: true,
     shared_secret: "my_secret"
   )
   
   # Option 2: Manual validation
   {:ok, tlvs} = Bindocsis.parse_file("config.cm")
   {:ok, valid?} = Bindocsis.validate_mic(tlvs, "my_secret")
   
   # Option 3: Generate MIC
   {:ok, binary} = Bindocsis.generate(tlvs,
     format: :binary,
     add_mic: true,
     shared_secret: "my_secret"
   )
   ```

**Deliverables:**
- `docs/mic_algorithm.md` - technical spec
- `docs/mic_api_design.md` - API proposal
- `test/fixtures/mic_test_vectors.txt` - test data

---

#### Phase 4.2: Core MIC Algorithm (Day 2-3)
**Goal:** Implement HMAC-MD5 computation

**File:** `lib/bindocsis/crypto/mic.ex` (new)

**Implementation:**
```elixir
defmodule Bindocsis.Crypto.MIC do
  @moduledoc """
  DOCSIS Message Integrity Check (MIC) computation and validation.
  
  Implements HMAC-MD5 as specified in DOCSIS 3.1 spec section 7.2.
  """
  
  @doc """
  Computes the CM MIC (TLV 6) for a DOCSIS configuration.
  
  ## Algorithm:
  1. Remove existing TLV 6 and TLV 7 from config
  2. Append TLV 6 with 16 zero bytes
  3. Compute HMAC-MD5 over entire config
  4. Replace zero bytes with computed hash
  
  ## Example:
      iex> compute_cm_mic(tlvs, "my_shared_secret")
      {:ok, <<...16 bytes...>>}
  """
  @spec compute_cm_mic([map()], String.t()) :: {:ok, binary()} | {:error, String.t()}
  def compute_cm_mic(tlvs, shared_secret) do
    # 1. Remove existing MIC TLVs
    tlvs_no_mic = Enum.reject(tlvs, &(&1.type in [6, 7]))
    
    # 2. Generate binary without MIC
    {:ok, binary_no_mic} = Bindocsis.Generators.BinaryGenerator.generate(
      tlvs_no_mic, 
      terminate: false
    )
    
    # 3. Append TLV 6 with zero bytes
    tlv6_placeholder = <<6, 16>> <> <<0::128>>
    data_to_hash = binary_no_mic <> tlv6_placeholder
    
    # 4. Compute HMAC-MD5
    mic = :crypto.mac(:hmac, :md5, shared_secret, data_to_hash)
    
    {:ok, mic}
  end
  
  @doc """
  Computes the CMTS MIC (TLV 7) for a DOCSIS configuration.
  
  CMTS MIC includes the CM MIC in the hash computation.
  """
  @spec compute_cmts_mic([map()], String.t()) :: {:ok, binary()} | {:error, String.t()}
  def compute_cmts_mic(tlvs, shared_secret) do
    # Must include TLV 6 (CM MIC) in computation
    case find_cm_mic(tlvs) do
      {:ok, _cm_mic} ->
        # Remove only TLV 7
        tlvs_no_cmts_mic = Enum.reject(tlvs, &(&1.type == 7))
        
        # Generate binary with CM MIC but no CMTS MIC
        {:ok, binary_with_cm_mic} = Bindocsis.Generators.BinaryGenerator.generate(
          tlvs_no_cmts_mic,
          terminate: false
        )
        
        # Append TLV 7 with zero bytes
        tlv7_placeholder = <<7, 16>> <> <<0::128>>
        data_to_hash = binary_with_cm_mic <> tlv7_placeholder
        
        # Compute HMAC-MD5
        mic = :crypto.mac(:hmac, :md5, shared_secret, data_to_hash)
        {:ok, mic}
      
      {:error, _} = error ->
        error
    end
  end
  
  @doc """
  Validates the CM MIC in a configuration.
  """
  @spec validate_cm_mic([map()], String.t()) :: {:ok, :valid} | {:error, String.t()}
  def validate_cm_mic(tlvs, shared_secret) do
    case find_cm_mic(tlvs) do
      {:ok, stored_mic} ->
        case compute_cm_mic(tlvs, shared_secret) do
          {:ok, computed_mic} ->
            if stored_mic == computed_mic do
              {:ok, :valid}
            else
              {:error, "CM MIC validation failed: signature mismatch"}
            end
          
          error ->
            error
        end
      
      {:error, _} = error ->
        error
    end
  end
  
  @doc """
  Validates the CMTS MIC in a configuration.
  """
  @spec validate_cmts_mic([map()], String.t()) :: {:ok, :valid} | {:error, String.t()}
  def validate_cmts_mic(tlvs, shared_secret) do
    case find_tlv(tlvs, 7) do
      {:ok, stored_mic} ->
        case compute_cmts_mic(tlvs, shared_secret) do
          {:ok, computed_mic} ->
            if stored_mic == computed_mic do
              {:ok, :valid}
            else
              {:error, "CMTS MIC validation failed: signature mismatch"}
            end
          
          error ->
            error
        end
      
      {:error, _} = error ->
        error
    end
  end
  
  # Private helpers
  
  defp find_cm_mic(tlvs) do
    find_tlv(tlvs, 6)
  end
  
  defp find_tlv(tlvs, type) do
    case Enum.find(tlvs, &(&1.type == type)) do
      %{value: value} when byte_size(value) == 16 ->
        {:ok, value}
      %{value: value} ->
        {:error, "TLV #{type} has invalid length: #{byte_size(value)} (expected 16)"}
      nil ->
        {:error, "TLV #{type} not found in configuration"}
    end
  end
end
```

**Testing:**
```elixir
# test/crypto/mic_test.exs

defmodule Bindocsis.Crypto.MICTest do
  use ExUnit.Case
  alias Bindocsis.Crypto.MIC
  
  @shared_secret "test_secret"
  
  test "computes CM MIC correctly" do
    tlvs = [
      %{type: 3, length: 1, value: <<1>>},
      %{type: 4, length: 10, value: <<...>>}
    ]
    
    {:ok, mic} = MIC.compute_cm_mic(tlvs, @shared_secret)
    assert byte_size(mic) == 16
    assert mic != <<0::128>>
  end
  
  test "validates correct CM MIC" do
    # Load fixture with known good MIC
    {:ok, tlvs} = Bindocsis.parse_file("test/fixtures/valid_mic.cm")
    
    {:ok, :valid} = MIC.validate_cm_mic(tlvs, @shared_secret)
  end
  
  test "detects invalid CM MIC" do
    tlvs = [
      %{type: 6, length: 16, value: <<0::128>>},  # Wrong MIC
      %{type: 3, length: 1, value: <<1>>}
    ]
    
    {:error, msg} = MIC.validate_cm_mic(tlvs, @shared_secret)
    assert String.contains?(msg, "validation failed")
  end
end
```

---

#### Phase 4.3: Parser Integration (Day 4)
**Goal:** Add MIC validation to parser

**File:** `lib/bindocsis.ex`

**Changes:**
```elixir
# Update parse function
def parse(input, opts \\ []) do
  # ... existing parsing ...
  
  # Add MIC validation
  validate_mic = Keyword.get(opts, :validate_mic, false)
  shared_secret = Keyword.get(opts, :shared_secret)
  
  parsed_tlvs = case parse_result do
    {:ok, tlvs} -> tlvs
    error -> return error
  end
  
  validated_tlvs = if validate_mic and shared_secret do
    case validate_signatures(parsed_tlvs, shared_secret) do
      {:ok, :valid} ->
        Logger.info("✅ MIC validation passed")
        parsed_tlvs
      
      {:error, reason} ->
        Logger.error("❌ MIC validation failed: #{reason}")
        # Return error or warning based on strict mode
        if Keyword.get(opts, :strict, false) do
          return {:error, "MIC validation failed: #{reason}"}
        else
          Logger.warning("⚠️  Continuing with invalid MIC (use strict: true to error)")
          parsed_tlvs
        end
    end
  else
    parsed_tlvs
  end
  
  # Continue with enrichment...
end

defp validate_signatures(tlvs, shared_secret) do
  with {:ok, :valid} <- Bindocsis.Crypto.MIC.validate_cm_mic(tlvs, shared_secret),
       {:ok, :valid} <- Bindocsis.Crypto.MIC.validate_cmts_mic(tlvs, shared_secret) do
    {:ok, :valid}
  else
    {:error, reason} -> {:error, reason}
  end
end
```

**Testing:**
```elixir
test "validates MIC when option enabled" do
  {:ok, binary} = File.read("test/fixtures/valid_mic.cm")
  
  # Should pass with correct secret
  {:ok, _tlvs} = Bindocsis.parse(binary,
    format: :binary,
    validate_mic: true,
    shared_secret: "correct_secret"
  )
  
  # Should fail with wrong secret
  {:error, msg} = Bindocsis.parse(binary,
    format: :binary,
    validate_mic: true,
    shared_secret: "wrong_secret",
    strict: true
  )
  assert String.contains?(msg, "MIC validation failed")
end
```

---

#### Phase 4.4: Generator Integration (Day 5)
**Goal:** Add MIC generation to binary generator

**File:** `lib/bindocsis/generators/binary_generator.ex`

**Changes:**
```elixir
def generate(tlvs, opts \\ []) do
  add_mic = Keyword.get(opts, :add_mic, false)
  shared_secret = Keyword.get(opts, :shared_secret)
  
  final_tlvs = if add_mic and shared_secret do
    # Remove existing MIC TLVs
    tlvs_no_mic = Enum.reject(tlvs, &(&1.type in [6, 7]))
    
    # Compute MICs
    {:ok, cm_mic} = Bindocsis.Crypto.MIC.compute_cm_mic(tlvs_no_mic, shared_secret)
    {:ok, cmts_mic} = Bindocsis.Crypto.MIC.compute_cmts_mic(
      tlvs_no_mic ++ [%{type: 6, length: 16, value: cm_mic}],
      shared_secret
    )
    
    # Add MIC TLVs at the end (before terminator)
    tlvs_no_mic ++ [
      %{type: 6, length: 16, value: cm_mic},
      %{type: 7, length: 16, value: cmts_mic}
    ]
  else
    tlvs
  end
  
  # Continue with normal generation
  encode_tlvs(final_tlvs, opts)
end
```

**Testing:**
```elixir
test "generates valid MIC" do
  tlvs = [
    %{type: 3, length: 1, value: <<1>>},
    %{type: 4, length: 10, value: <<...>>}
  ]
  
  {:ok, binary} = Bindocsis.Generators.BinaryGenerator.generate(tlvs,
    add_mic: true,
    shared_secret: "test_secret"
  )
  
  # Parse it back and validate
  {:ok, parsed_tlvs} = Bindocsis.parse(binary, format: :binary)
  {:ok, :valid} = Bindocsis.Crypto.MIC.validate_cm_mic(parsed_tlvs, "test_secret")
end
```

---

#### Phase 4.5: CLI & Documentation (Day 6)
**Goal:** Make MIC functionality accessible

**CLI Updates:**
```bash
# Parse with validation
./bindocsis -i config.cm --validate-mic --secret "my_secret"

# Generate with MIC
./bindocsis -i config.json -o config.cm --add-mic --secret "my_secret"

# Check MIC only
./bindocsis -i config.cm --check-mic --secret "my_secret"
```

**Documentation:**
- Add MIC section to USER_GUIDE.md
- Security best practices guide
- Troubleshooting MIC errors
- API reference examples

**Testing:**
- CLI integration tests
- Documentation examples as doctests

---

### Success Criteria
- ✅ MIC validation works on known good configs
- ✅ MIC generation produces valid signatures
- ✅ Parser rejects invalid MICs (strict mode)
- ✅ Generator adds MICs automatically (opt-in)
- ✅ CLI exposes MIC functionality
- ✅ Documentation complete
- ✅ Test coverage >90%

---

## 🔴 Blocker #5: MTA Binary Generation
**Status:** 🔴 **NOT STARTED**  
**Priority:** P0 (if keeping MTA claims) / P2 (if scope reduction)  
**Complexity:** Medium  
**Estimated Time:** 2-3 days

### Decision Point: Scope MTA Support?

**Option A:** Complete MTA support (recommended)
- Implement MTA binary generation
- Add MTA-specific validation
- Position as "DOCSIS + MTA" tool
- Timeline: +3 days

**Option B:** Reduce MTA scope
- Mark MTA as "experimental"
- Document parsing-only capability
- Focus on DOCSIS first
- Timeline: -0 days (documentation only)

### Implementation Plan (Option A)

#### Phase 5.1: Research MTA Format (Day 1)
**Goal:** Understand MTA binary differences

**Tasks:**
1. Document MTA vs DOCSIS differences
2. Review PacketCable specs
3. Analyze existing MTA parser
4. Create test vectors

**Deliverables:**
- `docs/mta_format.md` - format differences
- `test/fixtures/mta_test_vectors/` - test data

---

#### Phase 5.2: MTA Binary Generator (Day 2)
**Goal:** Implement generation logic

**File:** `lib/bindocsis/generators/mta_binary_generator.ex` (new)

**Implementation:**
```elixir
defmodule Bindocsis.Generators.MtaBinaryGenerator do
  @moduledoc """
  Generates PacketCable MTA binary configuration files.
  
  Similar to DOCSIS binary generation but with MTA-specific:
  - TLV ordering rules
  - Encoding differences
  - Signature computation (different from DOCSIS)
  """
  
  def generate(tlvs, opts \\ []) do
    # MTA-specific generation logic
    # Handle MTA TLVs (64, 67, 122, etc.)
    # Different encoding rules than DOCSIS
  end
end
```

---

#### Phase 5.3: Integration & Testing (Day 3)
**Goal:** Test MTA generation

**Tasks:**
1. Round-trip tests (MTA binary → JSON → MTA binary)
2. Compare with known good MTA files
3. Update CLI for MTA output
4. Documentation

---

## 🔴 Blocker #6: Extended Length Encoding Validation
**Status:** 🔴 **NOT STARTED**  
**Priority:** P1  
**Complexity:** Low-Medium  
**Estimated Time:** 1-2 days

### Problem Statement
Previous code had a bug where single-byte lengths 0x80-0xFF were incorrectly treated as extended length indicators. This has been partially fixed but needs thorough testing.

### Implementation Plan

#### Phase 6.1: Test Coverage (Day 1)
**Goal:** Ensure all length encodings work

**Create:** `test/unit/length_encoding_test.exs`

```elixir
defmodule Bindocsis.LengthEncodingTest do
  use ExUnit.Case
  
  describe "single-byte lengths" do
    test "lengths 0-127 (0x00-0x7F)" do
      for len <- 0..127 do
        tlv = %{type: 100, length: len, value: <<0::len*8>>}
        {:ok, binary} = Bindocsis.Generators.BinaryGenerator.generate([tlv])
        {:ok, [parsed]} = Bindocsis.parse(binary)
        assert parsed.length == len
      end
    end
    
    test "lengths 128-255 (0x80-0xFF)" do
      for len <- 128..255 do
        tlv = %{type: 100, length: len, value: <<0::len*8>>}
        {:ok, binary} = Bindocsis.Generators.BinaryGenerator.generate([tlv])
        {:ok, [parsed]} = Bindocsis.parse(binary)
        assert parsed.length == len, "Length #{len} failed"
      end
    end
  end
  
  describe "extended lengths" do
    test "0x81 indicator (1-byte length)" do
      # TLV: type=100, length=200, value=(200 bytes)
      # Binary: <<100, 0x81, 200, (200 bytes)>>
      len = 200
      tlv = %{type: 100, length: len, value: <<0::len*8>>}
      {:ok, binary} = Bindocsis.Generators.BinaryGenerator.generate([tlv])
      {:ok, [parsed]} = Bindocsis.parse(binary)
      assert parsed.length == len
    end
    
    test "0x82 indicator (2-byte length)" do
      len = 1000
      tlv = %{type: 100, length: len, value: <<0::len*8>>}
      {:ok, binary} = Bindocsis.Generators.BinaryGenerator.generate([tlv])
      {:ok, [parsed]} = Bindocsis.parse(binary)
      assert parsed.length == len
    end
    
    test "0x84 indicator (4-byte length)" do
      len = 100_000
      tlv = %{type: 100, length: len, value: <<0::len*8>>}
      {:ok, binary} = Bindocsis.Generators.BinaryGenerator.generate([tlv])
      {:ok, [parsed]} = Bindocsis.parse(binary)
      assert parsed.length == len
    end
  end
  
  describe "edge cases" do
    test "length exactly 127 (boundary)" do
      len = 127
      tlv = %{type: 100, length: len, value: <<0::len*8>>}
      {:ok, binary} = Bindocsis.Generators.BinaryGenerator.generate([tlv])
      {:ok, [parsed]} = Bindocsis.parse(binary)
      assert parsed.length == len
    end
    
    test "length exactly 128 (boundary)" do
      len = 128
      tlv = %{type: 100, length: len, value: <<0::len*8>>}
      {:ok, binary} = Bindocsis.Generators.BinaryGenerator.generate([tlv])
      {:ok, [parsed]} = Bindocsis.parse(binary)
      assert parsed.length == len
    end
    
    test "length exactly 255 (boundary)" do
      len = 255
      tlv = %{type: 100, length: len, value: <<0::len*8>>}
      {:ok, binary} = Bindocsis.Generators.BinaryGenerator.generate([tlv])
      {:ok, [parsed]} = Bindocsis.parse(binary)
      assert parsed.length == len
    end
    
    test "length exactly 256 (requires extended)" do
      len = 256
      tlv = %{type: 100, length: len, value: <<0::len*8>>}
      {:ok, binary} = Bindocsis.Generators.BinaryGenerator.generate([tlv])
      {:ok, [parsed]} = Bindocsis.parse(binary)
      assert parsed.length == len
    end
  end
end
```

---

#### Phase 6.2: Fix Any Issues (Day 2)
**Goal:** Fix any bugs found in testing

**Likely Issues:**
1. Binary generator not using extended encoding when needed
2. Parser mishandling boundary cases
3. Inconsistent length representation

**Files to Check:**
- `lib/bindocsis.ex` - `extract_multi_byte_length/2`
- `lib/bindocsis/generators/binary_generator.ex` - length encoding

---

## Timeline Summary

| Blocker | Status | Days | Start Date | Target Date |
|---------|--------|------|------------|-------------|
| 1. Context-Aware Naming | ✅ DONE | - | Nov 4 | Nov 5 |
| 2. ASN.1 DER Parsing | ✅ DONE | - | Nov 4 | Nov 5 |
| 3. JSON/YAML Round-Trip | 🔴 In Progress | 5-6 | Nov 6 | Nov 12 |
| 4. MIC Validation | 🔴 Not Started | 6 | Nov 13 | Nov 19 |
| 5. MTA Generation | 🔴 Not Started | 3 | Nov 20 | Nov 22 |
| 6. Length Encoding | 🔴 Not Started | 2 | Nov 23 | Nov 24 |

**Total Timeline:** ~16-17 working days (3-4 weeks)  
**Target Release:** v0.1.0-rc1 by November 24, 2025

---

## Daily Progress Tracking

### Week 1 (Nov 6-10)
- [ ] Day 1: JSON/YAML Phase 3.1 (Diagnosis)
- [ ] Day 2: JSON/YAML Phase 3.2 (ValueParser)
- [ ] Day 3: JSON/YAML Phase 3.3 (ValueFormatter)
- [ ] Day 4: JSON/YAML Phase 3.4 (Enricher)
- [ ] Day 5: JSON/YAML Phase 3.5 (HumanConfig)

### Week 2 (Nov 11-15)
- [ ] Day 6: JSON/YAML Phase 3.6 (Testing)
- [ ] Day 7: MIC Phase 4.1 (Research)
- [ ] Day 8: MIC Phase 4.2 (Algorithm)
- [ ] Day 9: MIC Phase 4.3 (Parser Integration)
- [ ] Day 10: MIC Phase 4.4 (Generator Integration)

### Week 3 (Nov 18-22)
- [ ] Day 11: MIC Phase 4.5 (CLI & Docs)
- [ ] Day 12: MTA Phase 5.1 (Research)
- [ ] Day 13: MTA Phase 5.2 (Generator)
- [ ] Day 14: MTA Phase 5.3 (Testing)
- [ ] Day 15: Length Phase 6.1 (Tests)

### Week 4 (Nov 25-26)
- [ ] Day 16: Length Phase 6.2 (Fixes)
- [ ] Day 17: Final integration testing
- [ ] Release: v0.1.0-rc1

---

## Success Metrics

- [ ] All P0 blockers resolved
- [ ] Test coverage >85%
- [ ] No critical bugs in test suite
- [ ] Documentation updated
- [ ] Ready for alpha users

---

## Next Steps

1. **Review this plan** - Validate timeline and approach
2. **Set up tracking** - Create GitHub issues/project board
3. **Begin Phase 3.1** - Start with JSON/YAML diagnosis
4. **Daily standups** - Track progress and blockers
5. **Weekly demos** - Show working features

---

**Ready to begin? Let's start with Blocker #3 (JSON/YAML) Phase 3.1!**
