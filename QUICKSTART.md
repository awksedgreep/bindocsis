# Bindocsis CLI Quick Start Guide

Welcome to Bindocsis v0.1.0! Here's how to start using the enhanced CLI right away.

## Installation

The CLI is ready to use:

```bash
# Build the escript (if not already built)
mix escript.build

# The CLI is now available as ./bindocsis
./bindocsis --help
```

## Quick Examples

### 1. Parse a Binary Config File

```bash
# Simple parse and display
./bindocsis config.cm

# Parse with validation
./bindocsis config.cm --validate

# Verbose output with details
./bindocsis config.cm --verbose
```

### 2. Convert Between Formats

```bash
# Binary to JSON
./bindocsis convert config.cm -o config.json

# JSON to YAML
./bindocsis convert config.json -o config.yaml

# Binary to human-readable config format
./bindocsis convert config.cm -o config.txt -t config

# Auto-detect input format
./bindocsis convert config.json -o output.cm -t binary
```

### 3. Validate Configurations

```bash
# Validate for DOCSIS 3.1 (default)
./bindocsis validate config.cm

# Validate for specific DOCSIS version
./bindocsis validate config.cm -d 3.0

# Validate with verbose output
./bindocsis validate config.cm --verbose
```

### 4. Describe Configurations

```bash
# Get human-readable summary
./bindocsis describe config.cm

# Show detailed information
./bindocsis describe config.cm --verbose
```

### 5. Interactive Editor

```bash
# Edit existing config
./bindocsis edit config.cm

# Start with empty config
./bindocsis edit
```

### 6. Parse Hex Strings

```bash
# Parse hex string directly
./bindocsis -i "01 04 FF FF FF FF"

# Parse and validate
./bindocsis -i "03 01 01" --validate
```

## Common Workflows

### Workflow 1: Inspect a Config File

```bash
# Quick look at what's in the file
./bindocsis describe config.cm

# Full details with validation
./bindocsis config.cm --validate --verbose
```

### Workflow 2: Convert and Validate

```bash
# Convert binary to JSON and validate in one step
./bindocsis convert config.cm -o config.json --validate

# The output will show validation results before conversion
```

### Workflow 3: Batch Processing

```bash
# Convert all .cm files to JSON
for file in *.cm; do
  ./bindocsis convert "$file" -o "${file%.cm}.json"
done

# Validate all configs
for file in *.cm; do
  echo "Validating $file..."
  ./bindocsis validate "$file"
done
```

### Workflow 4: Edit and Convert

```bash
# 1. Convert binary to editable format
./bindocsis convert config.cm -o config.txt -t config

# 2. Edit the text file with your favorite editor
vim config.txt

# 3. Convert back to binary
./bindocsis convert config.txt -o new_config.cm -t binary

# 4. Validate the result
./bindocsis validate new_config.cm
```

## Understanding Output

### Parse Output

When you parse a file, you'll see:
```
✓ Parsed DOCSIS 3.1 configuration (1,234 bytes)
✓ Found 23 TLVs

Configuration Summary:
  • Downstream Frequency: 591 MHz
  • Upstream Channel ID: 3
  • Network Access: Enabled
  ...
```

### Validation Output

Successful validation:
```
✓ Configuration is valid

Statistics:
  Valid: true
  Errors: 0
  Warnings: 0
  Info: 0
```

With errors:
```
✗ Configuration has errors

Errors (2):
  • Network access must be 0 or 1, got 2 (TLV 3)
  • Downstream frequency out of range (TLV 1)

Warnings (1):
  • CMTS MIC not present - config is not secure (TLV 7)
```

### Conversion Output

```
✓ Successfully converted to json format

Statistics:
  Input: config.cm (1,234 bytes)
  Output: config.json (3,456 bytes)
  TLVs: 23
  Format: binary → json
```

## Tips & Tricks

### 1. Use Auto-Detection

The CLI automatically detects input format:
```bash
# No need to specify -f, it figures it out
./bindocsis config.cm -o output.json
./bindocsis config.json -o output.yaml
```

### 2. Combine Operations

```bash
# Parse, validate, and convert in one command
./bindocsis convert config.cm -o config.json --validate --verbose
```

### 3. Quiet Mode for Scripts

```bash
# Use in scripts with -q for clean output
if ./bindocsis validate config.cm -q; then
  echo "Valid!"
else
  echo "Invalid!"
fi
```

### 4. Pipe to Other Tools

```bash
# Parse to JSON and pipe to jq
./bindocsis convert config.cm -t json | jq '.tlvs[] | select(.type == 1)'
```

## Error Messages

The CLI provides helpful error messages:

```bash
$ ./bindocsis convert invalid.cm -o output.json

❌ Parse Error:
Invalid length value 300 exceeds maximum allowed (255)

Location: byte 419 (0x1A3) in TLV 24 (Downstream Service Flow) → Sub-TLV 1

Suggestion:
  - Verify this is a valid DOCSIS configuration file
  - Check file isn't corrupted or truncated
  - Ensure file format matches the parser being used
```

## Getting Help

```bash
# General help
./bindocsis --help

# Version info
./bindocsis --version
```

## Next Steps

- Check out `docs/COOKBOOK.md` for 30+ code recipes
- See `docs/ERROR_CATALOG.md` for error reference
- Read `docs/USER_GUIDE.md` for detailed documentation

## Troubleshooting

### "bindocsis: command not found"

Run `mix escript.build` first to build the CLI executable.

### Parse errors with valid files

Try specifying the format explicitly:
```bash
./bindocsis -i config.cm -f binary
```

### Need more details?

Use `--verbose` flag for detailed output:
```bash
./bindocsis config.cm --verbose
```

---

**Enjoy using Bindocsis! 🎉**

For more help, see the full documentation in the `docs/` directory.
