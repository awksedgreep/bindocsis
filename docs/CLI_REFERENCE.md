# Bindocsis CLI Reference

**Complete Command-Line Interface Documentation**

---

## Table of Contents

1. [Command Structure](#command-structure)
2. [Global Options](#global-options)
3. [Commands](#commands)
4. [Input/Output Formats](#inputoutput-formats)
5. [Examples by Use Case](#examples-by-use-case)
6. [Advanced Usage](#advanced-usage)
7. [Error Handling](#error-handling)
8. [Environment Variables](#environment-variables)
9. [Exit Codes](#exit-codes)
10. [Tips and Tricks](#tips-and-tricks)

---

## Command Structure

### Basic Syntax

```bash
bindocsis [COMMAND] [OPTIONS] [FILE]
```

### Command Pattern

```bash
# Most basic usage
bindocsis config.cm

# With explicit options
bindocsis -i input.cm -o output.json -t json

# Using commands
bindocsis validate config.cm --docsis-version 3.1

# Piping output
bindocsis -i config.cm -t json | jq '.tlvs[0]'
```

---

## Global Options

### Input/Output Options

| Option | Short | Type | Description | Example |
|--------|-------|------|-------------|---------|
| `--input FILE` | `-i` | string | Input file or hex string | `-i config.cm` |
| `--output FILE` | `-o` | string | Output file (default: stdout) | `-o output.json` |
| `--input-format FORMAT` | `-f` | string | Force input format | `-f binary` |
| `--output-format FORMAT` | `-t` | string | Output format | `-t json` |

### DOCSIS Options

| Option | Short | Type | Description | Example |
|--------|-------|------|-------------|---------|
| `--docsis-version VER` | `-d` | string | DOCSIS version (3.0\|3.1) | `-d 3.1` |
| `--validate` | `-V` | boolean | Validate DOCSIS compliance | `--validate` |

### Control Options

| Option | Short | Type | Description | Example |
|--------|-------|------|-------------|---------|
| `--verbose` | | boolean | Verbose output | `--verbose` |
| `--quiet` | `-q` | boolean | Suppress output | `-q` |
| `--help` | `-h` | boolean | Show help | `--help` |
| `--version` | `-v` | boolean | Show version | `--version` |
| `--pretty` | | boolean | Pretty-print output (default: true) | `--pretty` |

---

## Commands

### `parse` (Default Command)

Parse and display DOCSIS configuration files.

```bash
# Basic parsing
bindocsis config.cm
bindocsis parse config.cm  # explicit command

# Parse with options
bindocsis -i config.cm --verbose
bindocsis parse -i config.cm -d 3.1
```

**Output Example:**
```
Type: 3 (Network Access Control) Length: 1
Value: Enabled

Type: 68 (Default Upstream Target Buffer) Length: 4
Description: Default upstream target buffer size
Value: 1000
```

### `convert`

Convert between different file formats.

```bash
# Basic conversion
bindocsis convert -i config.cm -o config.json -t json

# Multiple format conversion
bindocsis convert -i config.cm -t yaml > config.yaml
bindocsis convert -i config.json -t binary -o output.cm
```

**Supported Conversions:**
- Binary ↔ JSON
- Binary ↔ YAML
- JSON ↔ YAML
- Any format → Pretty text

### `validate`

Validate DOCSIS configurations against specifications.

```bash
# Basic validation
bindocsis validate config.cm

# Version-specific validation
bindocsis validate config.cm --docsis-version 3.0
bindocsis validate config.cm -d 3.1

# Verbose validation
bindocsis validate config.cm --verbose
```

**Output Examples:**
```bash
# Success
✅ Configuration is valid for DOCSIS 3.1

# Failure
❌ Validation failed:
  • TLV 77: Not supported in DOCSIS 3.0 (introduced in 3.1)
  • TLV 25: Missing required SubTLV 1 (Service Flow Reference)
```

---

## Input/Output Formats

### Input Formats (`--input-format` / `-f`)

| Format | Value | Extensions | Description |
|--------|-------|------------|-------------|
| **Auto-detect** | `auto` | any | Automatic format detection (default) |
| **Binary** | `binary` | `.cm`, `.bin` | DOCSIS binary format |
| **JSON** | `json` | `.json` | JSON structured data |
| **YAML** | `yaml` | `.yaml`, `.yml` | YAML configuration |
| **Config** | `config` | `.conf`, `.txt` | Human-readable config |

### Output Formats (`--output-format` / `-t`)

| Format | Value | Description | Use Case |
|--------|-------|-------------|----------|
| **Pretty** | `pretty` | Human-readable text (default) | Analysis, debugging |
| **Binary** | `binary` | DOCSIS binary format | Cable modem deployment |
| **JSON** | `json` | JSON structured data | APIs, web applications |
| **YAML** | `yaml` | YAML configuration | DevOps, version control |
| **Config** | `config` | Human-readable config | Documentation |

### Format Examples

#### Binary Input
```bash
# Parse binary file
bindocsis config.cm

# Force binary interpretation
bindocsis -i data.bin -f binary
```

#### JSON Input/Output
```bash
# Convert binary to JSON
bindocsis -i config.cm -t json

# Parse JSON input
bindocsis -i config.json -f json

# JSON to binary
bindocsis -i config.json -t binary -o output.cm
```

#### YAML Input/Output
```bash
# Convert binary to YAML
bindocsis -i config.cm -t yaml

# YAML to JSON
bindocsis -i config.yaml -t json
```

#### Hex String Input
```bash
# Parse hex string directly
bindocsis -i "03 01 01 FF 00 00"

# Hex string with spaces
bindocsis -i "03010100000000FF0000"
```

---

## Examples by Use Case

### File Analysis

```bash
# Quick analysis
bindocsis config.cm

# Detailed analysis with descriptions
bindocsis config.cm --verbose

# Save analysis to file
bindocsis config.cm > analysis.txt

# Focus on specific TLV types
bindocsis config.cm | grep "Type: 24"
```

### Format Conversion

```bash
# Binary to JSON (API integration)
bindocsis -i config.cm -o api_data.json -t json

# Binary to YAML (configuration management)
bindocsis -i config.cm -o template.yaml -t yaml

# JSON to Binary (deployment)
bindocsis -i modified.json -o deploy.cm -t binary

# Batch conversion
for file in *.cm; do
  bindocsis -i "$file" -o "${file%.cm}.json" -t json
done
```

### Validation Workflows

```bash
# Pre-deployment validation
bindocsis validate production.cm -d 3.1

# Multi-version compatibility check
bindocsis validate config.cm -d 3.0  # Check 3.0 compatibility
bindocsis validate config.cm -d 3.1  # Check 3.1 compatibility

# Batch validation
find . -name "*.cm" -exec bindocsis validate {} -d 3.1 \;
```

### Configuration Development

```bash
# Create editable version
bindocsis -i base.cm -t yaml > editable.yaml

# Edit editable.yaml with your preferred editor
vim editable.yaml

# Convert back to binary
bindocsis -i editable.yaml -t binary -o modified.cm

# Validate changes
bindocsis validate modified.cm -d 3.1
```

### Debugging and Troubleshooting

```bash
# Verbose parsing for debugging
bindocsis config.cm --verbose

# Validate with detailed output
bindocsis validate config.cm --verbose

# Check specific DOCSIS version compatibility
bindocsis validate config.cm -d 3.0 --verbose

# Parse potentially corrupted file
bindocsis -i suspicious.cm --verbose 2> debug.log
```

---

## Advanced Usage

### Piping and Redirection

```bash
# Pipe to JSON processor
bindocsis -i config.cm -t json | jq '.tlvs[] | select(.type == 24)'

# Chain with other tools
bindocsis -i config.cm -t json | python process_tlvs.py

# Save both output and errors
bindocsis config.cm > output.txt 2> errors.log

# Conditional processing
bindocsis validate config.cm && bindocsis -i config.cm -t json > valid.json
```

### Batch Processing

```bash
#!/bin/bash
# Batch processing script

for config in configs/*.cm; do
  echo "Processing $config..."
  
  # Validate first
  if bindocsis validate "$config" -d 3.1 --quiet; then
    echo "✅ Valid: $config"
    
    # Convert to JSON
    bindocsis -i "$config" -t json -o "json/${config%.cm}.json"
    
    # Create YAML template
    bindocsis -i "$config" -t yaml -o "templates/${config%.cm}.yaml"
  else
    echo "❌ Invalid: $config"
    bindocsis validate "$config" -d 3.1 > "errors/${config%.cm}.log" 2>&1
  fi
done
```

### Configuration Comparison

```bash
#!/bin/bash
# Compare two configurations

CONFIG1=$1
CONFIG2=$2

# Convert both to JSON for comparison
bindocsis -i "$CONFIG1" -t json > /tmp/config1.json
bindocsis -i "$CONFIG2" -t json > /tmp/config2.json

# Compare using jq
echo "Differences between $CONFIG1 and $CONFIG2:"
jq -n \
  --argjson a "$(cat /tmp/config1.json)" \
  --argjson b "$(cat /tmp/config2.json)" \
  '($a.tlvs - $b.tlvs) as $only_in_a |
   ($b.tlvs - $a.tlvs) as $only_in_b |
   {only_in_first: $only_in_a, only_in_second: $only_in_b}'

# Cleanup
rm /tmp/config1.json /tmp/config2.json
```

### Template Generation

```bash
#!/bin/bash
# Generate configuration templates

BASE_CONFIG=$1
SERVICE_TIER=$2

# Convert to editable YAML
bindocsis -i "$BASE_CONFIG" -t yaml > "template_${SERVICE_TIER}.yaml"

# Add service-specific modifications using yq or manual editing
case $SERVICE_TIER in
  "gold")
    # Modify for gold tier service
    sed -i 's/value: 1000000/value: 10000000/' "template_${SERVICE_TIER}.yaml"
    ;;
  "silver")
    # Modify for silver tier service
    sed -i 's/value: 1000000/value: 5000000/' "template_${SERVICE_TIER}.yaml"
    ;;
  "bronze")
    # Modify for bronze tier service
    sed -i 's/value: 1000000/value: 1000000/' "template_${SERVICE_TIER}.yaml"
    ;;
esac

# Generate final binary
bindocsis -i "template_${SERVICE_TIER}.yaml" -t binary -o "${SERVICE_TIER}_config.cm"

# Validate result
bindocsis validate "${SERVICE_TIER}_config.cm" -d 3.1
```

---

## Error Handling

### Common Errors and Solutions

#### File Not Found
```bash
$ bindocsis nonexistent.cm
❌ Error: Input file does not exist: nonexistent.cm

# Solution: Check file path
$ ls -la *.cm
$ bindocsis existing_file.cm
```

#### Invalid Format
```bash
$ bindocsis corrupted_file.cm
❌ Error: Invalid TLV format at byte 23

# Solution: Use verbose mode for debugging
$ bindocsis corrupted_file.cm --verbose
$ hexdump -C corrupted_file.cm | head -5
```

#### Version Compatibility
```bash
$ bindocsis validate new_config.cm -d 3.0
❌ Validation failed:
  • TLV 77: Not supported in DOCSIS 3.0 (introduced in 3.1)

# Solution: Use correct DOCSIS version
$ bindocsis validate new_config.cm -d 3.1
✅ Configuration is valid for DOCSIS 3.1
```

#### Permission Denied
```bash
$ bindocsis -i config.cm -o /protected/output.json
❌ Error: Permission denied writing to /protected/output.json

# Solution: Use writable directory
$ bindocsis -i config.cm -o output.json
```

### Debugging Options

```bash
# Enable verbose output
bindocsis config.cm --verbose

# Capture debug information
bindocsis config.cm --verbose 2> debug.log

# Test format detection
bindocsis -i unknown_file --verbose

# Validate with detailed error reporting
bindocsis validate config.cm --verbose
```

---

## Environment Variables

### Configuration Variables

| Variable | Description | Default | Example |
|----------|-------------|---------|---------|
| `BINDOCSIS_DEFAULT_VERSION` | Default DOCSIS version | `3.1` | `export BINDOCSIS_DEFAULT_VERSION=3.0` |
| `BINDOCSIS_LOG_LEVEL` | Logging verbosity | `info` | `export BINDOCSIS_LOG_LEVEL=debug` |
| `BINDOCSIS_CONFIG_DIR` | Configuration directory | `~/.bindocsis` | `export BINDOCSIS_CONFIG_DIR=/etc/bindocsis` |

### Usage Examples

```bash
# Set default DOCSIS version
export BINDOCSIS_DEFAULT_VERSION=3.0
bindocsis validate config.cm  # Uses DOCSIS 3.0

# Enable debug logging
export BINDOCSIS_LOG_LEVEL=debug
bindocsis config.cm

# Custom config directory
export BINDOCSIS_CONFIG_DIR=/opt/bindocsis/config
bindocsis config.cm
```

---

## Exit Codes

| Code | Meaning | Description |
|------|---------|-------------|
| `0` | Success | Operation completed successfully |
| `1` | General Error | Unspecified error occurred |
| `2` | Invalid Arguments | Command-line arguments are invalid |
| `3` | File Not Found | Input file does not exist |
| `4` | Permission Denied | Insufficient permissions for file operation |
| `5` | Format Error | Invalid file format or corrupted data |
| `6` | Validation Failed | DOCSIS validation failed |
| `7` | Version Error | DOCSIS version compatibility issue |

### Using Exit Codes

```bash
#!/bin/bash
# Script using exit codes

bindocsis validate config.cm -d 3.1
case $? in
  0)
    echo "✅ Configuration is valid"
    deploy_config config.cm
    ;;
  6)
    echo "❌ Validation failed"
    exit 1
    ;;
  7)
    echo "❌ Version compatibility issue"
    exit 1
    ;;
  *)
    echo "❌ Unexpected error"
    exit 1
    ;;
esac
```

---

## Tips and Tricks

### Performance Optimization

```bash
# Use quiet mode for batch processing
bindocsis validate *.cm --quiet

# Pipe output efficiently
bindocsis -i config.cm -t json --quiet | process_json.py

# Process large files
export ERL_MAX_MEMORY=2048m
bindocsis large_config.cm
```

### Workflow Integration

```bash
# Git pre-commit hook
#!/bin/bash
for config in $(git diff --cached --name-only | grep '\.cm$'); do
  bindocsis validate "$config" || exit 1
done

# Makefile integration
validate-configs:
	@for config in configs/*.cm; do \
		bindocsis validate "$$config" -d 3.1 || exit 1; \
	done

# CI/CD pipeline
script:
  - bindocsis validate configs/*.cm -d 3.1
  - bindocsis -i template.yaml -t binary -o deploy.cm
  - bindocsis validate deploy.cm -d 3.1
```

### Shell Aliases

Add to your `~/.bashrc` or `~/.zshrc`:

```bash
# Useful aliases
alias bd='bindocsis'
alias bdv='bindocsis validate'
alias bdj='bindocsis -t json'
alias bdy='bindocsis -t yaml'

# Functions
bd_convert() {
  bindocsis -i "$1" -t "$2" -o "${1%.*}.$2"
}

bd_validate_all() {
  find . -name "*.cm" -exec bindocsis validate {} -d "${1:-3.1}" \;
}
```

### JSON Processing

```bash
# Extract specific TLV types
bindocsis -i config.cm -t json | jq '.tlvs[] | select(.type == 24)'

# Count TLV types
bindocsis -i config.cm -t json | jq '.tlvs | group_by(.type) | map({type: .[0].type, count: length})'

# Find DOCSIS 3.1 specific TLVs
bindocsis -i config.cm -t json | jq '.tlvs[] | select(.type >= 77 and .type <= 85)'
```

### YAML Processing

```bash
# Use yq for YAML processing
bindocsis -i config.cm -t yaml | yq '.tlvs[] | select(.type == 24)'

# Modify YAML configurations
bindocsis -i config.cm -t yaml | yq '.tlvs[0].value = "new_value"' > modified.yaml
bindocsis -i modified.yaml -t binary -o modified.cm
```

---

## Quick Reference Card

### Most Common Commands

```bash
# Parse and display
bindocsis config.cm

# Convert formats
bindocsis -i config.cm -t json -o config.json
bindocsis -i config.json -t binary -o config.cm

# Validate
bindocsis validate config.cm -d 3.1

# Help
bindocsis --help
```

### Format Shortcuts

```bash
# To JSON: bindocsis -i file.cm -t json
# To YAML: bindocsis -i file.cm -t yaml  
# To Binary: bindocsis -i file.yaml -t binary
# Validate: bindocsis validate file.cm
```

### Debugging

```bash
# Verbose: bindocsis file.cm --verbose
# Debug: bindocsis file.cm --verbose 2> debug.log
# Version check: bindocsis validate file.cm -d 3.0
```

---

**Need More Help?**

- **[User Guide](USER_GUIDE.md)** - Comprehensive usage guide
- **[API Reference](API_REFERENCE.md)** - Programmatic usage
- **[Examples](EXAMPLES.md)** - More practical examples
- **[Troubleshooting](TROUBLESHOOTING.md)** - Common issues and solutions

---

*This CLI reference covers all available command-line options and usage patterns. For the most up-to-date information, use `bindocsis --help` or check the latest documentation.*