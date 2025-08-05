# Everything I Broke - Test Failure Analysis

## Current Status: Test failures reduced

## Root Cause Analysis Summary

### 2. **Invalid Hex String Format Issues** (Pending)
- **Issue**: Pretty-printed hex dumps being rejected by parsers
- **Evidence**: Hex strings with spaces like "01 02 03" failing validation
- **Error**: `Invalid hex string format: Hello` and similar
- **Files Affected**: ValueParser.ex hex string validation logic

### 3. **TLV 11 (SNMP) and TLV 200 (Vendor) Editing Workflow Issues** (Pending)
- **Issue**: SNMP and vendor TLVs failing in interactive editing workflows
- **Error**: `TLV 200: Unsupported value type or invalid input format`
- **Files Affected**: Editing workflow tests, ValueParser vendor handling

### 4. **TLV 8 String Parsing Failures** (Pending)
- **Issue**: String TLV parsing inconsistencies
- **Evidence**: Tests expecting null termination vs actual behavior
- **Error**: Expected `"Hello World\0"` but got `"Hello World"`
- **Files Affected**: ValueParser.ex string handling

### 5. **TLV 43 Integer Out of Range Errors** (Pending)
- **Issue**: Integer values exceeding expected ranges
- **Files Affected**: ValueParser.ex integer validation

### 6. **TLV 4 Compound TLV Issues** (Pending)
- **Issue**: Some compound TLV structures still failing in integration tests
- **Files Affected**: Compound TLV parsing/formatting logic

## What I Fixed (Correctly)

### 1. **JsonGenerator and YamlGenerator Boolean Handling** ✅
- **Fixed**: Added boolean type handling in `convert_two_byte_value()` functions
- **Change**: Boolean TLVs (0, 3, 18) now correctly convert 2-byte values to 0/1 instead of raw integers
- **Files**: `lib/bindocsis/generators/json_generator.ex:340-348`, `lib/bindocsis/generators/yaml_generator.ex:249-257`

### 2. **Integration Test API Migration** ✅ 
- **Fixed**: Updated integration tests to use new HumanConfig API patterns
- **Files**: `test/integration/round_trip_test.exs` - replaced deleted JsonParser/YamlParser calls

### 3. **JsonGenerator Enriched Field Support** ✅
- **Fixed**: Added `formatted_value`, `value_type`, `category` field support for HumanConfig compatibility
- **Files**: `lib/bindocsis/generators/json_generator.ex` - `maybe_add_field()` function

### 4. **ValueFormatter Compound/Vendor TLV Enhancements** ✅
- **Fixed**: Enhanced compound TLV formatting with structured subtlvs
- **Fixed**: Fixed vendor TLV formatting to use string keys for JSON compatibility
- **Files**: `lib/bindocsis/value_formatter.ex`

### 5. **YamlGenerator Enriched Field Support** ✅
- **Fixed**: Added matching enriched field support like JsonGenerator
- **Files**: `lib/bindocsis/generators/yaml_generator.ex`

### 6. **Binary Parser Creating Invalid TLVs** ✅
- **Fixed**: Binary parser incorrectly parsing service flow compound TLVs and creating spurious TLV 0 with incorrect length
- **Issue**: Test uses binary with only TLV 24/25 (service flows), but parser outputs TLV 0, 9, 24
- **Root Cause**: TLV 0 should be 1-byte boolean per DOCSIS spec, but parser was creating 2-byte version
- **Solution**: Treat compound TLVs as opaque in binary parser; enforce TLV 0 1-byte length requirement
- **Files**: `lib/bindocsis.ex` - compound TLV parsing logic and TLV 0 length validation

## What NOT to Touch (Working Correctly)

### 1. **HumanConfig Module** ⚠️ DANGER ZONE
- **DO NOT MODIFY**: The `extract_human_value()` function priority logic
- **Reason**: Took multiple attempts to get this right for bidirectional parsing
- **Current Logic**: Prioritizes `formatted_value` over `value` - this is intentional for human editing workflows

### 2. **ValueParser Core Logic** ⚠️ DANGER ZONE  
- **DO NOT MODIFY**: Boolean parsing accepts both integers (0,1) and strings ("enabled", "disabled")
- **Reason**: This is working correctly - the issue is bad input data from binary parser

### 3. **TlvEnricher Module** ⚠️ DANGER ZONE
- **Status**: Working correctly for enriching TLVs with metadata
- **Reason**: Complex module that handles verbose formatting detection

## Debug Files Created
- `debug_boolean.exs` - For investigating boolean parsing issues
- `debug_compound.exs` - For compound TLV testing  
- `debug_vendor.exs` - For vendor TLV testing
- `debug_string.exs` - For string TLV testing

## Next Steps Priority Order

1. **IMMEDIATE**: Fix binary parser creating invalid TLV 0/9 from service flow parsing errors
2. Fix hex string format validation to accept pretty-printed formats
3. Fix string parsing null termination inconsistencies  
4. Fix vendor TLV editing workflow issues
5. Fix SNMP TLV editing workflow issues
6. Fix integer range validation issues
7. Fix remaining compound TLV edge cases

## Test Status
- **Before**: 27 failures
- **Current**: 20 failures  
- **Progress**: 7 tests fixed
- **Critical Issue**: Binary parser bugs creating malformed TLV structures that cascade into JSON/YAML parsing failures

## Key Insight
The boolean parsing issue was a red herring. The real problem is the binary parser incorrectly parsing compound TLVs and creating invalid TLV structures that don't conform to DOCSIS specifications (e.g., 2-byte TLV 0 when spec requires 1-byte).