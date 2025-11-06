# MIC API Design

## Overview

This document specifies the API design for DOCSIS Message Integrity Check (MIC) functionality in Bindocsis. The API provides three main capabilities:

1. **Validation during parsing** - Automatically validate MICs when parsing binary configs
2. **Manual validation** - Programmatically validate MICs on parsed TLVs
3. **MIC generation** - Automatically compute and inject MICs when generating binaries

## Core Module: `Bindocsis.Crypto.MIC`

### Module Structure

```elixir
defmodule Bindocsis.Crypto.MIC do
  @moduledoc """
  DOCSIS Message Integrity Check (MIC) computation and validation.
  
  Implements HMAC-MD5 based authentication for DOCSIS configuration files
  as specified in DOCSIS 3.1 spec section 7.2.
  """
  
  # Public API
  @spec compute_cm_mic([map()], binary()) :: {:ok, binary()} | {:error, term()}
  @spec compute_cmts_mic([map()], binary()) :: {:ok, binary()} | {:error, term()}
  @spec validate_cm_mic([map()], binary()) :: {:ok, :valid} | {:error, term()}
  @spec validate_cmts_mic([map()], binary()) :: {:ok, :valid} | {:error, term()}
end
```

### Function Signatures

#### `compute_cm_mic/2`

Computes TLV 6 (CM MIC) for a configuration.

```elixir
@spec compute_cm_mic(tlvs :: [map()], shared_secret :: binary()) ::
  {:ok, mic :: binary()} | {:error, reason :: term()}
```

**Parameters:**
- `tlvs` - List of parsed TLV maps (must have `:type`, `:length`, `:value` keys)
- `shared_secret` - Binary string of the shared secret (used as-is, no normalization)

**Returns:**
- `{:ok, mic}` - 16-byte HMAC-MD5 digest
- `{:error, reason}` - Error tuple with descriptive reason

**Example:**
```elixir
tlvs = [
  %{type: 3, length: 1, value: <<1>>},
  %{type: 24, length: 7, value: <<1, 2, 0, 1, 6, 1, 7>>}
]
{:ok, mic} = Bindocsis.Crypto.MIC.compute_cm_mic(tlvs, "my_secret")
byte_size(mic) # => 16
```

---

#### `compute_cmts_mic/2`

Computes TLV 7 (CMTS MIC) for a configuration.

```elixir
@spec compute_cmts_mic(tlvs :: [map()], shared_secret :: binary()) ::
  {:ok, mic :: binary()} | {:error, reason :: term()}
```

**Parameters:**
- `tlvs` - List of parsed TLV maps (must include TLV 6 or it will be computed)
- `shared_secret` - Binary string of the shared secret

**Returns:**
- `{:ok, mic}` - 16-byte HMAC-MD5 digest
- `{:error, reason}` - Error tuple if TLV 6 cannot be computed or found

**Behavior:**
- If TLV 6 not present in `tlvs`, it will be computed automatically
- TLV 7 computation requires TLV 6 to be present in the preimage

**Example:**
```elixir
tlvs_with_cm_mic = [
  %{type: 3, length: 1, value: <<1>>},
  %{type: 6, length: 16, value: <<...>>}  # CM MIC already present
]
{:ok, mic} = Bindocsis.Crypto.MIC.compute_cmts_mic(tlvs_with_cm_mic, "my_secret")
```

---

#### `validate_cm_mic/2`

Validates TLV 6 (CM MIC) in a configuration.

```elixir
@spec validate_cm_mic(tlvs :: [map()], shared_secret :: binary()) ::
  {:ok, :valid} | {:error, {:missing | :invalid, details :: term()}}
```

**Parameters:**
- `tlvs` - List of parsed TLV maps (must include TLV 6)
- `shared_secret` - Binary string of the shared secret

**Returns:**
- `{:ok, :valid}` - MIC is valid
- `{:error, {:missing, msg}}` - TLV 6 not found
- `{:error, {:invalid, details}}` - MIC validation failed, includes stored vs computed MICs

**Example:**
```elixir
case Bindocsis.Crypto.MIC.validate_cm_mic(tlvs, "my_secret") do
  {:ok, :valid} ->
    IO.puts("✓ CM MIC valid")
  
  {:error, {:missing, msg}} ->
    IO.puts("⚠ Missing: #{msg}")
  
  {:error, {:invalid, %{stored: s, computed: c}}} ->
    IO.puts("✗ Invalid MIC")
    IO.puts("  Stored:   #{s}")
    IO.puts("  Computed: #{c}")
end
```

---

#### `validate_cmts_mic/2`

Validates TLV 7 (CMTS MIC) in a configuration.

```elixir
@spec validate_cmts_mic(tlvs :: [map()], shared_secret :: binary()) ::
  {:ok, :valid} | {:error, {:missing | :invalid, details :: term()}}
```

**Parameters:**
- `tlvs` - List of parsed TLV maps (must include both TLV 6 and TLV 7)
- `shared_secret` - Binary string of the shared secret

**Returns:**
- `{:ok, :valid}` - MIC is valid
- `{:error, {:missing, msg}}` - TLV 6 or TLV 7 not found
- `{:error, {:invalid, details}}` - MIC validation failed

**Note:** Requires TLV 6 to be present and valid before validating TLV 7.

---

## Parser Integration

### `Bindocsis.parse/2` and `Bindocsis.parse_file/2`

Add MIC validation options to parsing functions.

#### New Options

```elixir
@spec parse(input :: binary(), opts :: keyword()) :: 
  {:ok, [map()]} | {:error, term()}

@spec parse_file(path :: String.t(), opts :: keyword()) :: 
  {:ok, [map()]} | {:error, term()}
```

**Options:**
- `:validate_mic` - Boolean, enable MIC validation (default: `false`)
- `:shared_secret` - Binary string, shared secret for validation (required if validate_mic is true)
- `:strict` - Boolean, treat invalid MIC as parse error (default: `false`)

#### Behavior

**When `validate_mic: true` and `shared_secret` provided:**

1. Parse TLVs normally first
2. If TLV 6 present, validate CM MIC:
   - Success: Log debug message
   - Failure: Log warning (non-strict) or return error (strict)
3. If TLV 7 present, validate CMTS MIC:
   - Success: Log debug message  
   - Failure: Log warning (non-strict) or return error (strict)
4. Return parsed TLVs (with optional MIC validation metadata)

**Strict vs Non-Strict Mode:**

| Mode | Invalid MIC Behavior |
|------|---------------------|
| `strict: false` (default) | Log warning, continue parsing |
| `strict: true` | Return `{:error, {:mic_invalid, details}}` |

#### Examples

**Non-strict validation (default):**
```elixir
{:ok, tlvs} = Bindocsis.parse_file("config.cm",
  validate_mic: true,
  shared_secret: "my_secret"
)
# Parsing succeeds even if MIC is invalid (warning logged)
```

**Strict validation:**
```elixir
case Bindocsis.parse_file("config.cm",
  validate_mic: true,
  shared_secret: "my_secret",
  strict: true
) do
  {:ok, tlvs} ->
    # Both TLV 6 and 7 validated successfully
    :ok
  
  {:error, {:mic_invalid, %{tlv: 6, reason: :invalid}}} ->
    # CM MIC validation failed - parsing stopped
    :error
end
```

**Skip validation (default behavior):**
```elixir
{:ok, tlvs} = Bindocsis.parse_file("config.cm")
# No MIC validation performed
```

---

## Manual Validation API

For programmatic validation after parsing.

### Example Usage

```elixir
# Parse without validation
{:ok, tlvs} = Bindocsis.parse_file("config.cm")

# Validate manually later
secret = System.get_env("DOCSIS_SECRET")

case Bindocsis.Crypto.MIC.validate_cm_mic(tlvs, secret) do
  {:ok, :valid} ->
    Logger.info("CM MIC validation passed")
    
  {:error, {:missing, _}} ->
    Logger.warn("No CM MIC found (unsigned config)")
    
  {:error, {:invalid, details}} ->
    Logger.error("CM MIC validation failed: #{inspect(details)}")
end

# Validate CMTS MIC separately
case Bindocsis.Crypto.MIC.validate_cmts_mic(tlvs, secret) do
  {:ok, :valid} ->
    Logger.info("CMTS MIC validation passed")
    
  {:error, reason} ->
    Logger.error("CMTS MIC validation failed: #{inspect(reason)}")
end
```

---

## Generator Integration

### `Bindocsis.generate/2`

Add MIC generation options to output generation.

#### New Options

```elixir
@spec generate(tlvs :: [map()], opts :: keyword()) :: 
  {:ok, binary()} | {:error, term()}
```

**Options:**
- `:add_mic` - Boolean, compute and inject MICs (default: `false`)
- `:shared_secret` - Binary string, shared secret for computation (required if add_mic is true)

#### Behavior

**When `add_mic: true` and `shared_secret` provided:**

1. Remove any existing TLV 6 and TLV 7 from TLV list
2. Compute TLV 6 (CM MIC) using the algorithm
3. Insert TLV 6 at the end of TLV list (before where TLV 7 will go)
4. Compute TLV 7 (CMTS MIC) with TLV 6 included
5. Insert TLV 7 at the end of TLV list
6. Generate binary with 0xFF terminator

#### Examples

**Generate with MICs:**
```elixir
tlvs = [
  %{type: 3, length: 1, value: <<1>>},
  %{type: 24, length: 7, value: <<...>>}
]

{:ok, binary} = Bindocsis.generate(tlvs,
  format: :binary,
  add_mic: true,
  shared_secret: "my_secret"
)

# Binary now includes TLV 6 and TLV 7 at the end
```

**Generate without MICs (default):**
```elixir
{:ok, binary} = Bindocsis.generate(tlvs, format: :binary)
# No MICs added
```

**Round-trip workflow:**
```elixir
# Parse with validation
{:ok, tlvs} = Bindocsis.parse_file("config.cm",
  validate_mic: true,
  shared_secret: "secret"
)

# Modify TLVs (edit config)
modified_tlvs = update_bandwidth(tlvs, new_rate)

# Generate with fresh MICs
{:ok, new_binary} = Bindocsis.generate(modified_tlvs,
  format: :binary,
  add_mic: true,
  shared_secret: "secret"
)

File.write!("new_config.cm", new_binary)
```

---

## Secret Management

### Environment Variable Support

```elixir
# CLI and API will check BINDOCSIS_SECRET environment variable
secret = System.get_env("BINDOCSIS_SECRET")

{:ok, tlvs} = Bindocsis.parse_file("config.cm",
  validate_mic: true,
  shared_secret: secret || raise("BINDOCSIS_SECRET not set")
)
```

### File-Based Secrets (CLI)

```bash
# Store secret in file (safer than CLI arguments)
echo -n "my_secret" > /secure/path/.bindocsis_secret
chmod 600 /secure/path/.bindocsis_secret

# Use secret file with CLI
./bindocsis -i config.cm --validate-mic --secret-file /secure/path/.bindocsis_secret
```

### Security Best Practices

1. **Never log secrets** - All log messages must redact secrets
2. **No persistence** - Don't write secrets to disk (except secure files)
3. **Transient only** - Accept secrets via API/CLI, use once, discard
4. **Strong secrets** - Minimum 16 characters, mixed case + symbols
5. **Rotate regularly** - Change secrets periodically

### Redaction Helper

```elixir
defmodule Bindocsis.Crypto.MIC do
  # Internal helper for safe logging
  defp redact_secret(message, secret) when is_binary(secret) do
    String.replace(message, secret, "****")
  end
  
  defp log_validation_start(tlv_type) do
    require Logger
    Logger.debug("Starting MIC validation for TLV #{tlv_type}")
  end
end
```

---

## Error Handling

### Error Tuple Format

All MIC functions return consistent error tuples:

```elixir
# Success
{:ok, result}

# Missing MIC
{:error, {:missing, message}}

# Invalid MIC
{:error, {:invalid, details_map}}

# Other errors
{:error, term()}
```

### Error Details Structure

```elixir
%{
  tlv: 6 | 7,                    # Which MIC failed
  stored: "HEXSTRING",           # What was in the file
  computed: "HEXSTRING",         # What we expected
  reason: :invalid | :missing    # High-level reason
}
```

### Example Error Handling

```elixir
case Bindocsis.Crypto.MIC.validate_cm_mic(tlvs, secret) do
  {:ok, :valid} ->
    :ok
    
  {:error, {:missing, msg}} ->
    Logger.warn("MIC missing: #{msg}")
    # Continue - unsigned config acceptable in some contexts
    :ok
    
  {:error, {:invalid, %{stored: s, computed: c}}} ->
    Logger.error("""
    CM MIC validation failed!
    
    This could indicate:
    - Wrong shared secret
    - File corruption
    - Configuration tampering
    
    Stored MIC:   #{s}
    Expected MIC: #{c}
    """)
    {:error, :mic_mismatch}
    
  {:error, other} ->
    Logger.error("Unexpected error: #{inspect(other)}")
    {:error, other}
end
```

---

## Metadata Annotations (Optional)

When validation occurs during parsing, optionally attach metadata to TLVs:

```elixir
%{
  type: 6,
  length: 16,
  value: <<...>>,
  # Optional validation metadata
  mic_validation: %{
    status: :valid | :invalid | :not_checked,
    validated_at: DateTime.utc_now(),
    secret_hash: :crypto.hash(:sha256, secret) |> Base.encode16()
  }
}
```

**Use case:** Allow downstream code to check if a config was validated without re-validating.

---

## CLI Integration

### Proposed CLI Flags

```bash
# Validation during parse
bindocsis -i config.cm --validate-mic --secret "my_secret"
bindocsis -i config.cm --validate-mic --secret-file /path/to/secret
bindocsis -i config.cm --validate-mic --secret "$BINDOCSIS_SECRET" --strict

# Generation with MICs
bindocsis -i config.json -o config.cm --add-mic --secret "my_secret"

# Check MIC only (don't convert)
bindocsis -i config.cm --check-mic --secret "my_secret"
```

### CLI Exit Codes

| Code | Meaning |
|------|---------|
| 0 | Success (or valid MIC in non-strict mode) |
| 1 | Invalid MIC in strict mode |
| 2 | Missing MIC when validation requested |
| 3 | Other error (parsing, file not found, etc.) |

---

## Backward Compatibility

### Default Behavior (No Breaking Changes)

All new options default to OFF:

```elixir
# Existing code continues to work unchanged
Bindocsis.parse_file("config.cm")              # No MIC validation
Bindocsis.generate(tlvs, format: :binary)      # No MIC generation
```

### Opt-In Features

Users must explicitly enable MIC functionality:

```elixir
# Opt in to validation
Bindocsis.parse_file("config.cm", validate_mic: true, shared_secret: s)

# Opt in to generation  
Bindocsis.generate(tlvs, format: :binary, add_mic: true, shared_secret: s)
```

---

## Performance Considerations

### HMAC-MD5 Performance

- HMAC-MD5 is fast (native Erlang NIF)
- Typical config file: ~1KB → <1ms to compute MIC
- Large config file: ~100KB → ~5ms to compute MIC
- Validation adds negligible overhead to parsing

### Optimization Strategies

1. **Cache computed MICs** during generation (reuse TLV 6 when computing TLV 7)
2. **Skip validation** when secret not provided (default behavior)
3. **Lazy validation** only when requested

---

## Testing Strategy

### Unit Tests

```elixir
describe "Bindocsis.Crypto.MIC" do
  test "compute_cm_mic returns 16-byte digest" do
    tlvs = [%{type: 3, length: 1, value: <<1>>}]
    {:ok, mic} = MIC.compute_cm_mic(tlvs, "test_secret")
    assert byte_size(mic) == 16
  end
  
  test "validate_cm_mic succeeds with correct secret" do
    # Load fixture with known good MIC
    {:ok, tlvs} = Bindocsis.parse_file("test/fixtures/valid_mic.cm")
    assert {:ok, :valid} = MIC.validate_cm_mic(tlvs, "known_secret")
  end
  
  test "validate_cm_mic fails with wrong secret" do
    {:ok, tlvs} = Bindocsis.parse_file("test/fixtures/valid_mic.cm")
    assert {:error, {:invalid, _}} = MIC.validate_cm_mic(tlvs, "wrong")
  end
end
```

### Integration Tests

```elixir
test "parse with validate_mic option" do
  {:ok, tlvs} = Bindocsis.parse_file("test/fixtures/valid_mic.cm",
    validate_mic: true,
    shared_secret: "test_secret"
  )
  assert length(tlvs) > 0
end

test "generate with add_mic option creates valid MICs" do
  tlvs = [%{type: 3, length: 1, value: <<1>>}]
  
  {:ok, binary} = Bindocsis.generate(tlvs,
    format: :binary,
    add_mic: true,
    shared_secret: "test_secret"
  )
  
  # Parse back and validate
  {:ok, parsed} = Bindocsis.parse(binary, format: :binary)
  assert {:ok, :valid} = MIC.validate_cm_mic(parsed, "test_secret")
  assert {:ok, :valid} = MIC.validate_cmts_mic(parsed, "test_secret")
end
```

---

## Documentation Requirements

### User Guide Section

Add to `docs/USER_GUIDE.md`:

```markdown
## Message Integrity Checks (MIC)

DOCSIS configurations can include cryptographic signatures to ensure integrity...

### Validating MICs

### Generating MICs

### Troubleshooting

### Security Best Practices
```

### API Reference

Add to `docs/API_REFERENCE.md`:

```markdown
## Bindocsis.Crypto.MIC

### Functions

#### compute_cm_mic/2
...
```

---

## Summary

This API design provides:

✅ **Three access patterns**: Automatic (parser), manual (explicit calls), generation  
✅ **Backward compatible**: All features opt-in, no breaking changes  
✅ **Secure**: Secret redaction, no persistence, transient handling  
✅ **Flexible**: Strict/non-strict modes, environment variable support  
✅ **Well-tested**: Unit and integration test coverage  
✅ **Documented**: User guide, API reference, examples  

---

**Version**: 1.0  
**Status**: Design Specification  
**Last Updated**: November 6, 2025
