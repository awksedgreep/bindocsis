# DOCSIS Message Integrity Check (MIC) Algorithm

## Overview

DOCSIS configurations use HMAC-MD5 message authentication codes to ensure integrity and authenticity of configuration files. Two MIC TLVs are used:

- **TLV 6 (CM MIC)**: Cable Modem Message Integrity Check
- **TLV 7 (CMTS MIC)**: Cable Modem Termination System MIC

Both are 16-byte HMAC-MD5 digests computed over the configuration binary with a shared secret.

## References

- **DOCSIS 3.1 Specification**, Section 7.2: Message Integrity Check
- **RFC 2104**: HMAC: Keyed-Hashing for Message Authentication
- **RFC 1321**: The MD5 Message-Digest Algorithm

## Algorithm Details

### HMAC-MD5 Computation

Both MICs use HMAC-MD5 as the authentication algorithm:

```elixir
mic = :crypto.mac(:hmac, :md5, shared_secret, preimage_data)
```

The `preimage_data` is the binary TLV stream with specific rules for each MIC type.

### Shared Secret Handling

**CRITICAL SECURITY RULES:**

1. **Binary as-is**: Treat the secret as a raw binary string (UTF-8 encoded as provided)
2. **No normalization**: Do NOT trim whitespace, change case, or remove trailing newlines
3. **No logging**: NEVER log secrets in plain text - always redact as `"****"` or `"(redacted)"`
4. **No storage**: Do not persist secrets; accept them transiently via API/CLI only

**Example:**
```elixir
# Correct
secret = "my_docsis_secret"  # Used exactly as-is

# Incorrect
secret = String.trim(user_input)  # ❌ Don't normalize
secret = String.downcase(user_input)  # ❌ Don't change case
```

### TLV Binary Encoding

All TLVs are encoded as:
```
<<type::8, length::8, value::binary-size(length)>>
```

For TLVs longer than 255 bytes, extended length encoding is used (see DOCSIS spec).

## CM MIC (TLV 6) Algorithm

### Purpose
Authenticates the entire configuration file from the Cable Modem's perspective.

### Computation Steps

1. **Remove existing MICs**: Strip any existing TLV 6 and TLV 7 from the TLV list
2. **Generate binary**: Serialize all remaining TLVs to binary **without** the 0xFF terminator
3. **Append placeholder**: Append TLV 6 header with 16 zero bytes: `<<6, 16, 0::128>>`
4. **Compute HMAC-MD5**: Hash the entire preimage with the shared secret
5. **Result**: 16-byte binary digest

### Pseudocode

```elixir
# Step 1: Remove existing MICs
tlvs_no_mic = Enum.reject(tlvs, &(&1.type in [6, 7]))

# Step 2: Generate binary without terminator
binary_no_mic = serialize_tlvs(tlvs_no_mic, terminate: false)

# Step 3: Append TLV 6 placeholder
tlv6_placeholder = <<6, 16, 0::128>>
preimage = binary_no_mic <> tlv6_placeholder

# Step 4: Compute HMAC-MD5
cm_mic = :crypto.mac(:hmac, :md5, shared_secret, preimage)
```

### Example

Given configuration:
```
TLV 3:  <<3, 1, 1>>
TLV 24: <<24, 7, 1, 2, 0, 1, 6, 1, 7>>
```

Preimage for CM MIC:
```
<<3, 1, 1, 24, 7, 1, 2, 0, 1, 6, 1, 7, 6, 16, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0>>
```

## CMTS MIC (TLV 7) Algorithm

### Purpose
Authenticates the configuration including the CM MIC, from the CMTS's perspective.

### Computation Steps

1. **Remove TLV 7 only**: Strip any existing TLV 7 from the TLV list
2. **Ensure TLV 6 present**: If TLV 6 doesn't exist, compute it first and insert it into the list
3. **Generate binary**: Serialize TLVs (including TLV 6) to binary **without** the 0xFF terminator
4. **Append placeholder**: Append TLV 7 header with 16 zero bytes: `<<7, 16, 0::128>>`
5. **Compute HMAC-MD5**: Hash the entire preimage with the shared secret
6. **Result**: 16-byte binary digest

### Pseudocode

```elixir
# Step 1: Remove only TLV 7
tlvs_no_cmts_mic = Enum.reject(tlvs, &(&1.type == 7))

# Step 2: Ensure TLV 6 is present
tlvs_with_cm_mic = case find_tlv(tlvs_no_cmts_mic, 6) do
  {:ok, _} -> tlvs_no_cmts_mic
  {:error, _} -> 
    cm_mic = compute_cm_mic(tlvs_no_cmts_mic, shared_secret)
    insert_tlv(tlvs_no_cmts_mic, %{type: 6, length: 16, value: cm_mic})
end

# Step 3: Generate binary without terminator
binary_with_cm = serialize_tlvs(tlvs_with_cm_mic, terminate: false)

# Step 4: Append TLV 7 placeholder
tlv7_placeholder = <<7, 16, 0::128>>
preimage = binary_with_cm <> tlv7_placeholder

# Step 5: Compute HMAC-MD5
cmts_mic = :crypto.mac(:hmac, :md5, shared_secret, preimage)
```

### Example

Given configuration with TLV 6 already computed:
```
TLV 3:  <<3, 1, 1>>
TLV 24: <<24, 7, 1, 2, 0, 1, 6, 1, 7>>
TLV 6:  <<6, 16, 0x1A, 0x3B, ...>> (16 bytes)
```

Preimage for CMTS MIC:
```
<<3, 1, 1, 24, 7, 1, 2, 0, 1, 6, 1, 7, 6, 16, [16 bytes of CM MIC], 7, 16, 0::128>>
```

## Critical Implementation Rules

### 1. TLV Ordering

**PRESERVE ORDER EXACTLY**
- MIC is sensitive to byte-for-byte ordering
- NEVER sort or reorder TLVs during computation
- Insert computed MICs at the end, before the 0xFF terminator
- Order matters: MIC will fail if TLVs are rearranged

### 2. Terminator Handling

**EXCLUDE 0xFF FROM PREIMAGE**
- The 0xFF terminator byte is NEVER included in MIC computation
- Any bytes after 0xFF are ignored (trailing junk)
- Generate preimage without terminator, then add it after MIC insertion

### 3. Placeholder Format

**EXACT BYTE SEQUENCE**
```elixir
# TLV 6 placeholder (type + length + 16 zero bytes)
<<6, 16, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0>>

# TLV 7 placeholder (type + length + 16 zero bytes)
<<7, 16, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0>>
```

Using `:binary.copy(<<0>>, 16)` or `0::128` produces the same result.

### 4. MIC Length

**ALWAYS 16 BYTES**
- HMAC-MD5 always produces 16 bytes (128 bits)
- Reject any TLV 6 or TLV 7 with length ≠ 16 as invalid

## Validation Algorithm

### CM MIC Validation

```elixir
def validate_cm_mic(tlvs, shared_secret) do
  # Find existing CM MIC
  case find_tlv(tlvs, 6) do
    {:ok, stored_mic} ->
      # Compute expected MIC
      {:ok, computed_mic} = compute_cm_mic(tlvs, shared_secret)
      
      # Compare binaries
      if stored_mic == computed_mic do
        {:ok, :valid}
      else
        {:error, {:invalid, %{
          tlv: 6,
          stored: Base.encode16(stored_mic),
          computed: Base.encode16(computed_mic)
        }}}
      end
    
    {:error, _} ->
      {:error, {:missing, "TLV 6 (CM MIC) not found"}}
  end
end
```

### CMTS MIC Validation

```elixir
def validate_cmts_mic(tlvs, shared_secret) do
  # Ensure TLV 6 exists first
  case find_tlv(tlvs, 6) do
    {:error, _} ->
      {:error, {:missing, "TLV 6 required before validating TLV 7"}}
    
    {:ok, _} ->
      # Find existing CMTS MIC
      case find_tlv(tlvs, 7) do
        {:ok, stored_mic} ->
          # Compute expected MIC
          {:ok, computed_mic} = compute_cmts_mic(tlvs, shared_secret)
          
          # Compare binaries
          if stored_mic == computed_mic do
            {:ok, :valid}
          else
            {:error, {:invalid, %{
              tlv: 7,
              stored: Base.encode16(stored_mic),
              computed: Base.encode16(computed_mic)
            }}}
          end
        
        {:error, _} ->
          {:error, {:missing, "TLV 7 (CMTS MIC) not found"}}
      end
  end
end
```

## Edge Cases

### Duplicate MIC TLVs

**Rule**: Use the LAST occurrence for validation
- Log a warning if duplicates found
- DOCSIS spec doesn't allow duplicates, but be defensive
- Example: If file has two TLV 6 entries, validate against the last one

### TLVs After Terminator

**Rule**: IGNORE trailing bytes
- Some files have garbage after 0xFF terminator
- Do not include these bytes in preimage
- Parser should stop at 0xFF; MIC computation uses only parsed TLVs

### Missing MICs

**Validation**: 
- No TLV 6: Report as missing, don't fail parsing
- No TLV 7: Report as missing, don't fail parsing
- Both missing: Valid for unsigned configs (test files, drafts)

**Generation**:
- If `add_mic: false`, preserve existing behavior
- If `add_mic: true`, compute and inject both MICs

### Wrong Secret

**Behavior**:
- Validation will return `{:error, {:invalid, ...}}`
- Do NOT treat as a parsing error in non-strict mode
- Log warning and continue parsing
- In strict mode, return error and stop

## Testing Guidelines

### Test Vectors Required

1. **Known-good config**: Valid TLV 6 and 7 with known secret
2. **Wrong secret**: Same config, validate with incorrect secret (should fail)
3. **Missing MICs**: Config without TLV 6/7 (should report missing, not error)
4. **Partial MICs**: Config with only TLV 6 (TLV 7 validation should fail gracefully)
5. **Trailing bytes**: Config with junk after 0xFF (should ignore junk)
6. **Duplicate MICs**: Config with two TLV 6 entries (should use last one and warn)

### Validation Assertions

```elixir
# Round-trip property
tlvs_no_mic = strip_mics(original_tlvs)
{:ok, cm_mic} = compute_cm_mic(tlvs_no_mic, secret)
{:ok, cmts_mic} = compute_cmts_mic(tlvs_no_mic ++ [tlv6], secret)
tlvs_with_mics = tlvs_no_mic ++ [tlv6, tlv7]
{:ok, :valid} = validate_cm_mic(tlvs_with_mics, secret)
{:ok, :valid} = validate_cmts_mic(tlvs_with_mics, secret)

# Binary equality
computed == stored  # Exact 16-byte match required

# Wrong secret fails
{:error, {:invalid, _}} = validate_cm_mic(tlvs, "wrong_secret")
```

## Security Considerations

### Secret Management

1. **Never log secrets**: Redact in all log messages
2. **Accept transiently**: Don't persist secrets to disk
3. **Environment variables**: Support `BINDOCSIS_SECRET` env var
4. **File input**: Support `--secret-file` to read from file (safer than CLI arg)
5. **Memory clearing**: Secrets are binaries; Erlang GC will clean up

### Attack Vectors

1. **Timing attacks**: Not a concern for offline validation
2. **Secret brute force**: Use strong secrets (16+ chars, mixed case, symbols)
3. **Man-in-the-middle**: MIC only validates integrity, not freshness
4. **Replay attacks**: MIC doesn't prevent config reuse

### Best Practices

1. **Rotate secrets**: Change shared secrets periodically
2. **Strong secrets**: Minimum 16 characters, random
3. **Validate on parse**: Always validate MICs when secret is available
4. **Strict mode for production**: Use `strict: true` in production environments

## Implementation Checklist

- [ ] HMAC-MD5 computation working
- [ ] TLV 6 algorithm correct (placeholder at end)
- [ ] TLV 7 algorithm correct (requires TLV 6)
- [ ] Validation functions return correct error tuples
- [ ] Secret redaction in logs
- [ ] Test vectors pass
- [ ] Round-trip property holds
- [ ] Edge cases handled (duplicates, trailing bytes, missing MICs)
- [ ] Documentation complete
- [ ] CLI integration

## References for Implementation

### Erlang Crypto Module

```elixir
# HMAC-MD5
:crypto.mac(:hmac, :md5, key, data)
# Returns: <<_::binary-size(16)>>

# Available in Erlang/OTP 22+
# For older versions, use :crypto.hmac(:md5, key, data)
```

### Binary Operations

```elixir
# Concatenation
preimage = part1 <> part2 <> part3

# Zero bytes
zeros_16 = <<0::128>>
zeros_16 = :binary.copy(<<0>>, 16)

# Size check
byte_size(mic) == 16
```

### Common Pitfalls

1. **Including terminator in preimage** ❌
2. **Not stripping existing MICs before recomputation** ❌
3. **Changing TLV order during computation** ❌
4. **Logging secrets** ❌
5. **Normalizing/trimming shared secret** ❌

---

**Last Updated**: November 6, 2025  
**Status**: Implementation Specification  
**Version**: 1.0
