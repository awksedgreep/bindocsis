# Bindocsis Troubleshooting Guide

This guide helps you diagnose and resolve common issues when using Bindocsis.

## Table of Contents

1. [Quick Diagnostics](#quick-diagnostics)
2. [Parse Errors](#parse-errors)
3. [Validation Errors](#validation-errors)
4. [Format Conversion Issues](#format-conversion-issues)
5. [CLI Problems](#cli-problems)
6. [Installation Issues](#installation-issues)
7. [Performance Issues](#performance-issues)
8. [Integration Problems](#integration-problems)
9. [Debug Techniques](#debug-techniques)
10. [Getting Help](#getting-help)

## Quick Diagnostics

### Check Your Installation

```bash
# Verify Bindocsis is installed
bindocsis --version

# Check if Elixir is working
elixir --version

# Test basic functionality
echo '{"docsis_version": "3.1", "tlvs": []}' | bindocsis convert --format json
```

### Common Quick Fixes

1. **File not found**: Check file path and permissions
2. **Permission denied**: Use `sudo` or check file ownership
3. **Command not found**: Ensure bindocsis is in your PATH
4. **Invalid format**: Check file extension and content format

## Parse Errors

### JSON Parse Errors

#### Error: "Invalid JSON format"

**Symptoms:**
```
{:error, "Invalid JSON format at line 5, column 12"}
```

**Common Causes:**
1. Missing commas between elements
2. Trailing commas in objects/arrays
3. Unquoted object keys
4. Invalid escape sequences

**Solutions:**

```bash
# Validate JSON syntax
cat config.json | python -m json.tool

# Fix common issues
sed 's/,\s*}/}/g' config.json > fixed.json  # Remove trailing commas
```

**Example Fix:**
```json
// ❌ Broken
{
  "docsis_version": "3.1",
  "tlvs": [
    {
      "type": 3,
      "value": 1,  // ← trailing comma
    }
  ]
}

// ✅ Fixed
{
  "docsis_version": "3.1",
  "tlvs": [
    {
      "type": 3,
      "value": 1
    }
  ]
}
```

#### Error: "Missing required field"

**Symptoms:**
```
{:error, {:validation, "Missing required field: docsis_version"}}
```

**Solution:**
```json
{
  "docsis_version": "3.1",  // ← Add this
  "tlvs": [...]
}
```

### YAML Parse Errors

#### Error: "Invalid YAML indentation"

**Symptoms:**
```
{:error, "YAML parse error: invalid indentation at line 8"}
```

**Common Causes:**
1. Mixed tabs and spaces
2. Inconsistent indentation levels
3. Missing colons after keys

**Solutions:**

```bash
# Check for mixed tabs/spaces
cat -A config.yaml | grep -E '[\t ]'

# Fix indentation (convert tabs to spaces)
expand -t 2 config.yaml > fixed.yaml
```

**Example Fix:**
```yaml
# ❌ Broken (mixed indentation)
docsis_version: "3.1"
tlvs:
  - type: 3
	value: 1  # ← tab instead of spaces

# ✅ Fixed (consistent spaces)
docsis_version: "3.1"
tlvs:
  - type: 3
    value: 1
```

### Binary Parse Errors

#### Error: "Invalid TLV structure"

**Symptoms:**
```
{:error, "Invalid TLV structure: length exceeds remaining bytes"}
```

**Common Causes:**
1. Corrupted binary file
2. Truncated file
3. Wrong file format

**Diagnostic Steps:**

```bash
# Check file size
ls -la config.cm

# Examine file header
hexdump -C config.cm | head -5

# Verify it's a valid DOCSIS file
file config.cm
```

**Solutions:**
1. Re-download the original file
2. Check file transfer method (ensure binary mode)
3. Verify file isn't corrupted

### Config Format Parse Errors

#### Error: "Unexpected token"

**Symptoms:**
```
{:error, "Parse error: unexpected token 'value' at line 12"}
```

**Common Causes:**
1. Missing semicolons or braces
2. Unquoted strings with spaces
3. Invalid block structure

**Example Fix:**
```
# ❌ Broken
downstream_service_flow {
    service_flow_ref 1          # ← missing colon
    max_rate_sustained 1000000  # ← missing colon
}

# ✅ Fixed
downstream_service_flow {
    service_flow_ref: 1
    max_rate_sustained: 1000000
}
```

## Validation Errors

### DOCSIS Compliance Errors

#### Error: "Invalid TLV type for DOCSIS version"

**Symptoms:**
```
{:error, {:validation, "TLV type 61 not supported in DOCSIS 3.0"}}
```

**Solution:**
```bash
# Check which TLVs are version-specific
bindocsis validate config.json --docsis-version 3.1

# Convert to appropriate version
bindocsis convert config.json --to-version 3.1
```

#### Error: "Missing required TLV"

**Symptoms:**
```
{:error, {:validation, "Required TLV 3 (Network Access) missing"}}
```

**Solution:**
```json
{
  "docsis_version": "3.1",
  "tlvs": [
    {
      "type": 3,
      "name": "Network Access",
      "length": 1,
      "value": 1
    }
    // ... other TLVs
  ]
}
```

### Value Validation Errors

#### Error: "Invalid value range"

**Symptoms:**
```
{:error, {:validation, "Value 300 out of range for TLV 3 (0-1)"}}
```

**Solution:**
Check the valid range for each TLV type:

```bash
# Get TLV information
bindocsis info --tlv-type 3

# Valid ranges for common TLVs:
# TLV 3 (Network Access): 0-1
# TLV 4 (Class of Service): varies by subtlv
# TLV 5 (Modem Capabilities): bitfield
```

## Format Conversion Issues

### Binary → JSON Issues

#### Error: "Unknown TLV type"

**Symptoms:**
```
{:error, "Unknown TLV type 255 encountered"}
```

**Solutions:**
```bash
# Parse with permissive mode
bindocsis convert config.cm --format json --permissive

# Or specify DOCSIS version
bindocsis convert config.cm --format json --docsis-version 3.1
```

### JSON → Binary Issues

#### Error: "Invalid binary encoding"

**Symptoms:**
```
{:error, "Cannot encode value 'invalid' as binary"}
```

**Common Causes:**
1. Non-numeric values where numbers expected
2. Invalid Base64 encoding
3. Malformed IP/MAC addresses

**Solutions:**
```json
// ❌ Broken
{
  "type": 11,
  "value": "invalid_ip"  // ← should be valid IP
}

// ✅ Fixed
{
  "type": 11,
  "value": "192.168.1.1"
}
```

## CLI Problems

### Command Not Found

**Symptoms:**
```bash
bindocsis: command not found
```

**Solutions:**

```bash
# Check if escript is built
ls -la bindocsis

# Build escript if missing
mix escript.build

# Add to PATH
export PATH=$PATH:$(pwd)

# Or use mix run
mix run bin/bindocsis parse config.json
```

### Permission Denied

**Symptoms:**
```bash
./bindocsis: Permission denied
```

**Solutions:**
```bash
# Make executable
chmod +x bindocsis

# Or run with mix
mix escript.build && ./bindocsis
```

### Argument Parsing Issues

#### Error: "Invalid argument"

**Symptoms:**
```
Invalid argument: --unknown-flag
```

**Solution:**
```bash
# Check available options
bindocsis --help
bindocsis parse --help

# Use correct syntax
bindocsis parse config.json --format json  # ✅
bindocsis parse --format json config.json  # ❌
```

## Installation Issues

### Mix Dependencies

#### Error: "Package not found"

**Symptoms:**
```
** (Mix) Package fetch failed
```

**Solutions:**
```bash
# Update hex
mix local.hex --force

# Clear dependencies
rm -rf deps _build
mix deps.get

# Check network connectivity
ping hex.pm
```

### Elixir Version Issues

#### Error: "Elixir version requirement not met"

**Symptoms:**
```
** (Mix) You're trying to run :bindocsis on Elixir v1.10.0 but it requires ~> 1.12
```

**Solutions:**
```bash
# Check current version
elixir --version

# Install correct version (using asdf)
asdf install elixir 1.14.0
asdf global elixir 1.14.0

# Or use kiex
kiex install 1.14.0
kiex use 1.14.0
```

## Performance Issues

### Slow Parsing

**Symptoms:**
- Parsing takes longer than expected (>5 seconds for small files)
- High memory usage during parsing

**Diagnostic Steps:**
```bash
# Time the operation
time bindocsis parse large_config.json

# Monitor memory usage
top -p $(pgrep beam.smp)

# Check file size
ls -lh large_config.json
```

**Solutions:**

1. **Large Files:**
```bash
# Use streaming mode
bindocsis parse --stream large_config.json

# Split large files
split -l 1000 large_config.json part_
```

2. **Disable Validation:**
```bash
# Skip validation for speed
bindocsis parse --no-validate config.json
```

3. **Use Binary Format:**
```bash
# Binary is fastest
bindocsis convert config.json --format binary
```

### Memory Issues

**Symptoms:**
```
** (EXIT) out of memory
```

**Solutions:**
```bash
# Increase VM memory
export ERL_MAX_PORTS=32768
export ERL_MAX_ETS_TABLES=32768

# Use streaming
bindocsis parse --stream --chunk-size 100 large_config.json
```

## Integration Problems

### Phoenix/Web Application Issues

#### Error: "Module not found"

**Symptoms:**
```elixir
** (UndefinedFunctionError) function Bindocsis.parse/2 is undefined
```

**Solutions:**

1. **Add to dependencies:**
```elixir
# mix.exs
defp deps do
  [
    {:bindocsis, "~> 1.0"}
  ]
end
```

2. **Import correctly:**
```elixir
# In your module
alias Bindocsis
# or
import Bindocsis, only: [parse: 2, generate: 2]
```

### GenServer Integration Issues

#### Error: "Process timeout"

**Symptoms:**
```elixir
** (GenServer.call timeout)
```

**Solutions:**
```elixir
# Increase timeout
GenServer.call(server, {:parse, data}, 30_000)  # 30 seconds

# Use async processing
GenServer.cast(server, {:parse_async, data, callback})
```

## Debug Techniques

### Enable Debug Logging

```elixir
# In config/config.exs
config :logger, level: :debug

# Or at runtime
Logger.configure(level: :debug)
```

### Inspect Data Structures

```elixir
# Add debugging to your code
tlvs = Bindocsis.parse(data)
IO.inspect(tlvs, label: "Parsed TLVs", limit: :infinity)
```

### Step-by-Step Debugging

```bash
# Parse with verbose output
bindocsis parse config.json --verbose

# Validate step by step
bindocsis validate config.json --verbose

# Check intermediate formats
bindocsis convert config.cm --format json --output temp.json
bindocsis convert temp.json --format binary --output temp.cm
diff config.cm temp.cm
```

### Binary Analysis

```bash
# Examine binary structure
hexdump -C config.cm | head -20

# Compare binary files
cmp -l file1.cm file2.cm

# Check TLV boundaries
bindocsis parse config.cm --debug --format json | jq '.tlvs[0]'
```

### Memory Profiling

```elixir
# In iex
:observer.start()

# Or use :fprof
:fprof.start()
result = Bindocsis.parse(large_data)
:fprof.stop()
:fprof.analyse()
```

## Common Error Patterns

### Pattern 1: File Format Mismatch

**Error Pattern:**
```
Parse error → Unknown format → Conversion failure
```

**Solution:**
```bash
# Always verify format first
file config.unknown
bindocsis detect-format config.unknown
```

### Pattern 2: Version Incompatibility

**Error Pattern:**
```
Parse success → Validation failure → TLV not supported
```

**Solution:**
```bash
# Check version compatibility
bindocsis info config.json
bindocsis validate config.json --docsis-version 3.1
```

### Pattern 3: Encoding Issues

**Error Pattern:**
```
File loads → Parse error → Invalid characters
```

**Solution:**
```bash
# Check file encoding
file -bi config.json
iconv -f utf-8 -t utf-8 config.json > clean.json
```

## Environment-Specific Issues

### Docker Environment

**Issue**: Path and permission problems

**Solutions:**
```dockerfile
# Dockerfile
FROM elixir:1.14-alpine
WORKDIR /app
COPY . .
RUN mix deps.get && mix escript.build
RUN chmod +x bindocsis
```

### Windows Environment

**Issue**: Path separator and encoding problems

**Solutions:**
```powershell
# Use proper path separators
bindocsis parse "C:\configs\config.json"

# Handle encoding
bindocsis parse config.json --encoding utf-8
```

### macOS Environment

**Issue**: Gatekeeper blocking execution

**Solutions:**
```bash
# Allow execution
xattr -d com.apple.quarantine bindocsis

# Or build from source
git clone https://github.com/user/bindocsis.git
cd bindocsis && mix escript.build
```

## Getting Help

### Before Asking for Help

1. **Check this troubleshooting guide**
2. **Search existing issues on GitHub**
3. **Try the latest version**
4. **Prepare a minimal example**

### Information to Include

When reporting issues, include:

```bash
# System information
elixir --version
bindocsis --version
uname -a

# Error details
bindocsis parse config.json --verbose 2>&1 | tee error.log

# File samples (if possible)
head -20 config.json
```

### Useful Commands for Diagnostics

```bash
# Full system diagnostic
bindocsis diagnose

# Test with sample data
bindocsis test --sample-data

# Export debug information
bindocsis debug-export --output debug.zip
```

### Community Resources

- **GitHub Issues**: Report bugs and feature requests
- **Documentation**: Complete API reference and examples
- **Examples Repository**: Real-world configuration examples
- **Discord/Slack**: Community chat and quick help

---

## Appendix: Error Code Reference

| Code | Type | Description | Severity |
|------|------|-------------|----------|
| E001 | Parse | Invalid JSON syntax | Error |
| E002 | Parse | Invalid YAML syntax | Error |
| E003 | Parse | Invalid binary structure | Error |
| E004 | Validation | Missing required TLV | Error |
| E005 | Validation | Invalid TLV value | Error |
| E006 | Validation | DOCSIS version mismatch | Warning |
| E007 | IO | File not found | Error |
| E008 | IO | Permission denied | Error |
| E009 | Network | Connection timeout | Error |
| E010 | Memory | Out of memory | Critical |

---

*Last updated: 2024-01-15 - Bindocsis v1.2.0*