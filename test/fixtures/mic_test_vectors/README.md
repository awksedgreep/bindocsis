# MIC Test Vectors

This directory contains test fixtures for DOCSIS Message Integrity Check (MIC) validation and generation.

## Shared Secrets

All test vectors use documented shared secrets for reproducible testing:

| File | Secret | Notes |
|------|--------|-------|
| `good_cm.cm` | `bindocsis_test` | Valid TLV 6 and TLV 7 |
| `good_cm.json` | `bindocsis_test` | JSON equivalent of good_cm.cm |
| `bad_cm_wrong_secret.cm` | `wrong_secret` | Invalid MICs (computed with different secret) |
| `cm_without_mic.cm` | N/A | No MIC TLVs present (unsigned) |
| `cm_with_only_cm_mic.cm` | `bindocsis_test` | Only TLV 6, no TLV 7 |
| `cm_with_extra_bytes.cm` | `bindocsis_test` | Valid MICs + junk after 0xFF |

## File Descriptions

### `good_cm.cm`

**Purpose**: Primary test fixture with valid MICs

**Shared Secret**: `bindocsis_test`

**Contents**:
- TLV 3 (Network Access): `<<1>>`
- TLV 24 (Downstream Service Flow): Basic QoS parameters
- TLV 6 (CM MIC): Valid 16-byte HMAC-MD5
- TLV 7 (CMTS MIC): Valid 16-byte HMAC-MD5
- 0xFF terminator

**Expected MIC Values** (hex):
- TLV 6 (CM MIC): Will be computed during test generation
- TLV 7 (CMTS MIC): Will be computed during test generation

**Use Cases**:
- Positive validation tests
- Round-trip generation/validation
- Parser integration tests

---

### `good_cm.json`

**Purpose**: JSON representation of good_cm.cm for round-trip testing

**Format**:
```json
{
  "docsis_version": "3.1",
  "tlvs": [
    {
      "type": 3,
      "name": "Network Access Control",
      "formatted_value": "",
      "length": 0,
      "value_type": "marker"
    },
    {
      "type": 24,
      "name": "Downstream Service Flow",
      "subtlvs": [...]
    }
  ]
}
```

**Note**: MIC TLVs not included in JSON (will be computed on generation)

---

### `bad_cm_wrong_secret.cm`

**Purpose**: Test MIC validation failure detection

**Shared Secret Used**: `wrong_secret` (different from validation secret)

**Contents**: Same TLV structure as `good_cm.cm` but MICs computed with wrong secret

**Expected Behavior**:
- Validation with `bindocsis_test` should fail
- Error: `{:error, {:invalid, %{tlv: 6, ...}}}`

---

### `cm_without_mic.cm`

**Purpose**: Test unsigned config handling

**Contents**:
- TLV 3 (Network Access): `<<1>>`
- TLV 24 (Downstream Service Flow): Basic QoS
- 0xFF terminator
- **No TLV 6 or TLV 7**

**Expected Behavior**:
- Validation returns `{:error, {:missing, "TLV 6 not found"}}`
- Parsing succeeds (unsigned configs are valid)

---

### `cm_with_only_cm_mic.cm`

**Purpose**: Test partial MIC handling

**Shared Secret**: `bindocsis_test`

**Contents**:
- TLV 3, TLV 24
- TLV 6 (CM MIC): Valid
- **No TLV 7**
- 0xFF terminator

**Expected Behavior**:
- TLV 6 validation succeeds
- TLV 7 validation returns `{:error, {:missing, "TLV 7 not found"}}`

---

### `cm_with_extra_bytes.cm`

**Purpose**: Test trailing garbage handling

**Shared Secret**: `bindocsis_test`

**Contents**:
- Valid config with TLV 6 and TLV 7
- 0xFF terminator
- **Extra bytes**: `<<0xDE, 0xAD, 0xBE, 0xEF>>`

**Expected Behavior**:
- MIC validation ignores bytes after 0xFF
- Validation succeeds

---

## Test Configuration

### Base TLV Structure

All test files use this minimal valid configuration:

```elixir
[
  # TLV 3: Network Access (marker)
  %{type: 3, length: 0, value: <<>>},
  
  # TLV 24: Downstream Service Flow
  %{type: 24, length: 7, value: <<1, 2, 0, 1, 6, 1, 7>>}
]
```

### Service Flow Sub-TLVs (within TLV 24)

```
Sub-TLV 1: Service Flow Reference = 1
Sub-TLV 6: QoS Parameter Set Type = 7
```

## Generating Test Vectors

Test vectors should be generated programmatically during test setup:

```elixir
# Generate good_cm.cm
base_tlvs = [
  %{type: 3, length: 0, value: <<>>},
  %{type: 24, length: 7, value: <<1, 2, 0, 1, 6, 1, 7>>}
]

{:ok, binary} = Bindocsis.generate(base_tlvs,
  format: :binary,
  add_mic: true,
  shared_secret: "bindocsis_test"
)

File.write!("test/fixtures/mic_test_vectors/good_cm.cm", binary)
```

## Validation Test Examples

### Positive Test

```elixir
test "validates good_cm.cm with correct secret" do
  {:ok, tlvs} = Bindocsis.parse_file(
    "test/fixtures/mic_test_vectors/good_cm.cm"
  )
  
  assert {:ok, :valid} = Bindocsis.Crypto.MIC.validate_cm_mic(
    tlvs, 
    "bindocsis_test"
  )
  
  assert {:ok, :valid} = Bindocsis.Crypto.MIC.validate_cmts_mic(
    tlvs,
    "bindocsis_test"
  )
end
```

### Negative Test

```elixir
test "rejects bad_cm_wrong_secret.cm with correct secret" do
  {:ok, tlvs} = Bindocsis.parse_file(
    "test/fixtures/mic_test_vectors/bad_cm_wrong_secret.cm"
  )
  
  assert {:error, {:invalid, _details}} = 
    Bindocsis.Crypto.MIC.validate_cm_mic(tlvs, "bindocsis_test")
end
```

### Missing MIC Test

```elixir
test "reports missing MIC in unsigned config" do
  {:ok, tlvs} = Bindocsis.parse_file(
    "test/fixtures/mic_test_vectors/cm_without_mic.cm"
  )
  
  assert {:error, {:missing, msg}} = 
    Bindocsis.Crypto.MIC.validate_cm_mic(tlvs, "bindocsis_test")
  
  assert msg =~ "TLV 6"
end
```

## Security Notes

**⚠️ WARNING**: These are TEST secrets only!

- **Never use these secrets in production**
- Production secrets should be:
  - Minimum 16 characters
  - Mixed case + numbers + symbols
  - Randomly generated
  - Rotated regularly
  - Never committed to version control

**Test Secret Properties**:
- `bindocsis_test` - Simple, memorable, documented
- `wrong_secret` - Intentionally different for negative tests
- Both are intentionally weak for testing purposes

## Maintenance

### Regenerating Test Vectors

If the MIC algorithm changes or test structure needs updating:

```bash
# Run test vector generation script
mix run test/support/generate_mic_fixtures.exs

# Or during test setup
MIX_ENV=test mix test test/crypto/mic_test.exs --only generate_fixtures
```

### Verifying Test Vectors

```bash
# Validate all test vectors
mix test test/crypto/mic_test.exs --only verify_fixtures
```

---

**Last Updated**: November 6, 2025  
**Maintainer**: Bindocsis Test Suite  
**Version**: 1.0
