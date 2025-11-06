# Error Catalog

**Version:** 0.1.0  
**Last Updated:** 2025-11-06  
**Status:** Initial implementation complete

This document catalogs all error types in Bindocsis, their causes, and suggested solutions.

---

## Error Types

Bindocsis uses structured errors with the following types:

| Error Type | Description | Common Causes |
|------------|-------------|---------------|
| `:parse_error` | Failed to parse input data | Invalid binary format, truncated files, syntax errors |
| `:validation_error` | Data parsed but semantically invalid | Out of range values, missing required fields |
| `:generation_error` | Failed to generate output | Missing data, invalid TLV structure |
| `:file_error` | File system operation failed | File not found, permission denied |
| `:mic_error` | Message Integrity Check failed | Wrong secret, modified config, algorithm mismatch |
| `:tlv_error` | TLV structure issue | Invalid type, unknown TLV |
| `:format_error` | Format detection/conversion issue | Wrong format specified, corrupted file |

---

## Parse Errors

### Invalid Length

**Error:**
```
Parse Error:
Invalid length value 300 exceeds maximum allowed (255)

Location: byte 419 (0x1A3) in TLV 24 → Sub-TLV 1

Suggestion:
  - Verify this is a valid DOCSIS configuration file
  - Check file isn't corrupted or truncated
  - Ensure file format matches the parser being used
```

**Causes:**
- Corrupted binary file
- Wrong file format (e.g., trying to parse JSON as binary)
- Truncated download
- Extended length encoding not handled (lengths > 255)

**Solutions:**
1. Verify file integrity with `md5sum` or similar
2. Check file extension matches content
3. Re-download or regenerate the file
4. For extended lengths, ensure using DOCSIS 3.0+ parser

---

### Unexpected EOF

**Error:**
```
Parse Error:
Unexpected end of file: expected 50 more bytes, got 0

Location: byte 512 (0x200)

Suggestion:
  - File may be truncated or corrupted
  - Try downloading/copying the file again
  - Check source system is generating complete configs
  - Verify network transfer completed successfully
```

**Causes:**
- File truncated during transfer
- Incomplete file generation
- Disk full during write
- Network interruption during download

**Solutions:**
1. Check file size: `ls -lh config.cm`
2. Compare with known good configs
3. Re-download from source
4. Verify source system logs for generation errors

---

### Invalid TLV Structure

**Error:**
```
Parse Error:
Invalid TLV structure: missing type byte

Location: byte 0 (0x0)

Suggestion:
  - Verify the file is a valid DOCSIS binary config
  - Check that type-length-value format is correct
  - Ensure this isn't a different file format (JSON/YAML/text)
```

**Causes:**
- Wrong file format
- Not a DOCSIS config file
- Binary corruption
- Incorrect file content

**Solutions:**
1. Check file header: `hexdump -C config.cm | head`
2. Verify file magic bytes
3. Try format auto-detection: `Bindocsis.parse_file(path, format: :auto)`
4. Specify format explicitly if known

---

## TLV Errors

### Unknown TLV

**Error:**
```
TLV Error:
Unknown TLV type 250 encountered

Location: byte 100 (0x64) in TLV 250

Suggestion:
  - This may be a vendor-specific TLV (type 250)
  - Check if config is for a newer DOCSIS version
  - Use parse option 'unknown_tlvs: :preserve' to keep parsing
  - Consult vendor documentation for custom TLV definitions
```

**Causes:**
- Vendor-specific TLV extensions
- Newer DOCSIS version features
- Custom TLV definitions
- Unsupported TLV in library

**Solutions:**
1. Identify vendor: Check TLV type ranges
2. Use preserve mode: `Bindocsis.parse(binary, unknown_tlvs: :preserve)`
3. Check DOCSIS version compatibility
4. Consult vendor documentation for TLV definitions

---

## Validation Errors

### Invalid Value Range

**Error:**
```
Validation Error:
Invalid value 1000000000 for downstream_frequency (must be in range 88-860 MHz)

Location: line 42 in TLV 1 (Downstream Frequency)

Suggestion:
  - Check value is within the valid range: 88-860 MHz
  - Verify source data is correct
  - Consult DOCSIS specification for valid ranges
```

**Causes:**
- Typo in configuration value
- Wrong units (e.g., Hz instead of MHz)
- Out-of-spec configuration
- Copy/paste error

**Solutions:**
1. Check DOCSIS spec for valid ranges
2. Verify units are correct
3. Use common values (e.g., 591 MHz for downstream)
4. Validate with cable provider specifications

---

### Missing Required TLV

**Error:**
```
Validation Error:
Missing required TLV: Downstream Frequency (TLV 1)

Suggestion:
  - Add the required TLV 1 (Downstream Frequency)
  - Check DOCSIS version requirements
  - Verify configuration is complete
```

**Causes:**
- Incomplete configuration
- Manual editing removed required field
- Template/example not complete
- Wrong DOCSIS version template

**Solutions:**
1. Add missing TLV
2. Use complete template: `Bindocsis.Templates.basic_config()`
3. Check DOCSIS version requirements
4. Compare with working configuration

---

### Duplicate TLV

**Error:**
```
Validation Error:
TLV Network Access (TLV 3) appears multiple times (must be unique)

Suggestion:
  - Remove duplicate Network Access entries
  - Keep only one instance of this TLV
  - Check for merge/concatenation errors
```

**Causes:**
- Configuration merge gone wrong
- Copy/paste duplication
- Multiple file concatenation
- Template misuse

**Solutions:**
1. Remove duplicate entries
2. Check for accidental concatenation
3. Verify merge logic if programmatically generated
4. Use validation before generation

---

## MIC Errors

### Invalid CM MIC

**Error:**
```
MIC Error:
CM MIC (Message Integrity Check) validation failed

Suggestion:
  - Verify the shared secret is correct
  - Ensure config hasn't been modified after MIC generation
  - Check that MIC algorithm matches DOCSIS version
  - Use --no-validate-mic if MIC validation isn't needed
```

**Causes:**
- Wrong shared secret
- Config modified after MIC generation
- Algorithm mismatch (DOCSIS version)
- MIC TLV corruption

**Solutions:**
1. Verify shared secret with provider
2. Re-generate MIC: `Bindocsis.generate(tlvs, add_mic: true, shared_secret: "...")`
3. Check DOCSIS version compatibility
4. Skip validation if testing: `parse(binary, validate_mic: false)`

---

### Invalid CMTS MIC

**Error:**
```
MIC Error:
CMTS MIC (Message Integrity Check) validation failed

Suggestion:
  - Verify the shared secret is correct
  - Ensure config hasn't been modified after MIC generation
  - Check that MIC algorithm matches DOCSIS version
  - Use --no-validate-mic if MIC validation isn't needed
```

**Causes:**
- Same as CM MIC but for CMTS signature
- Provider-side shared secret mismatch
- Algorithm incompatibility

**Solutions:**
- Same as CM MIC solutions
- Verify provider-side configuration
- Check CMTS version compatibility

---

## File Errors

### File Not Found

**Error:**
```
File Error:
File not found: /path/to/config.cm

Suggestion:
  - Verify the file path is correct
  - Check file exists at specified location
  - Ensure you have read permissions
```

**Causes:**
- Typo in file path
- Wrong working directory
- File doesn't exist
- Permission issue

**Solutions:**
1. Check file exists: `ls /path/to/config.cm`
2. Verify working directory: `pwd`
3. Check permissions: `ls -l /path/to/config.cm`
4. Use absolute path if relative path issues

---

### File Permission Denied

**Error:**
```
File Error:
File operation failed: permission denied

Suggestion:
  - Check file permissions
  - Verify disk space is available
  - Ensure path is accessible
```

**Causes:**
- Insufficient read permissions
- File owned by different user
- SELinux/AppArmor restrictions
- File locked by another process

**Solutions:**
1. Check permissions: `ls -l file.cm`
2. Use sudo if appropriate: `sudo bindocsis ...`
3. Change ownership: `sudo chown $USER file.cm`
4. Check file locks: `lsof file.cm`

---

## Format Errors

### Unsupported Format

**Error:**
```
Format Error:
Unsupported format: :pdf

Suggestion:
  - Supported formats: binary, json, yaml, config, asn1, mta
  - Check format specification is correct
  - Use :auto to auto-detect format
```

**Causes:**
- Typo in format specification
- Unsupported format requested
- API misuse

**Solutions:**
1. Use supported format: `:binary`, `:json`, `:yaml`, `:config`, `:asn1`, `:mta`
2. Use auto-detection: `format: :auto`
3. Check documentation for available formats

---

### Format Detection Failed

**Error:**
```
Format Error:
Format detection failed: ambiguous format

Suggestion:
  - Specify format explicitly with format: option
  - Verify file extension matches content type
  - Check file isn't corrupted
```

**Causes:**
- Ambiguous file content
- Wrong file extension
- Corrupted header
- Empty file

**Solutions:**
1. Specify format: `Bindocsis.parse(data, format: :binary)`
2. Check file content: `file config.cm`
3. Verify file isn't empty: `ls -l config.cm`
4. Check first bytes: `hexdump -C config.cm | head`

---

## JSON/YAML Specific Errors

### JSON Parse Error

**Error:**
```
Parse Error:
JSON parsing failed: unexpected token

Location: line 42 in json data

Suggestion:
  - Verify JSON syntax is valid
  - Check for missing quotes, commas, or brackets
  - Use a JSON validator to identify syntax errors
  - Ensure file encoding is UTF-8
```

**Causes:**
- Invalid JSON syntax
- Missing quotes
- Trailing commas
- Wrong encoding

**Solutions:**
1. Validate JSON: `jq . config.json`
2. Check for common issues: missing commas, quotes
3. Verify encoding: `file -i config.json`
4. Use JSON formatter/linter

---

### YAML Parse Error

**Error:**
```
Parse Error:
YAML parsing failed: invalid indentation

Location: line 42 in yaml data

Suggestion:
  - Verify YAML syntax is valid
  - Check indentation (YAML is whitespace-sensitive)
  - Ensure file encoding is UTF-8
  - Use a YAML validator to identify syntax errors
```

**Causes:**
- Incorrect indentation
- Mixed tabs/spaces
- Invalid YAML structure
- Wrong encoding

**Solutions:**
1. Check indentation (use spaces, not tabs)
2. Validate YAML: `yamllint config.yaml`
3. Verify encoding: `file -i config.yaml`
4. Use YAML formatter

---

## Best Practices

### Error Handling in Code

```elixir
# Good: Handle structured errors
case Bindocsis.parse(binary, format: :binary) do
  {:ok, tlvs} ->
    # Process TLVs
    process_tlvs(tlvs)
  
  {:error, %Bindocsis.Error{type: :parse_error} = error} ->
    Logger.error("Parse failed at #{error.location}: #{error.message}")
    Logger.info("Suggestion: #{error.suggestion}")
    {:error, :parse_failed}
  
  {:error, %Bindocsis.Error{type: :mic_error}} ->
    # Maybe retry without MIC validation
    Bindocsis.parse(binary, format: :binary, validate_mic: false)
end

# Bad: Ignore error details
case Bindocsis.parse(binary) do
  {:ok, tlvs} -> tlvs
  {:error, _} -> []  # Loses all error information!
end
```

### Debugging Errors

1. **Enable verbose logging:**
   ```elixir
   Logger.configure(level: :debug)
   ```

2. **Check error details:**
   ```elixir
   {:error, error} = Bindocsis.parse(binary)
   IO.inspect(error, label: "Error Details")
   ```

3. **Examine context:**
   ```elixir
   IO.puts("Error at: #{error.location}")
   IO.inspect(error.context, label: "Context")
   ```

---

## Getting Help

If you encounter an error not documented here:

1. Check the error type and message
2. Review the suggestion provided
3. Enable debug logging for more details
4. Search issues: https://github.com/your-org/bindocsis/issues
5. Ask for help with full error details and context

---

## Error Statistics

Track common errors to improve documentation and error messages.

| Error Type | Frequency | Top Causes |
|------------|-----------|------------|
| parse_error | High | Corrupted files, wrong format |
| tlv_error | Medium | Vendor-specific TLVs |
| mic_error | Medium | Wrong shared secret |
| validation_error | Low | Out of range values |
| file_error | Low | File not found |

---

## Version History

- **v0.1.0** (2025-11-06): Initial structured error system implementation
  - Added Error, ParseContext, ErrorFormatter modules
  - Comprehensive error types and suggestions
  - Location tracking for better debugging
