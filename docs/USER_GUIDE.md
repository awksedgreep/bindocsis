# Bindocsis User Guide

**Complete Guide to DOCSIS Configuration File Management**

---

## Table of Contents

1. [Getting Started](#getting-started)
2. [Basic Operations](#basic-operations)
3. [Format Conversion](#format-conversion)
4. [Advanced Features](#advanced-features)
5. [DOCSIS Compliance](#docsis-compliance)
6. [Common Workflows](#common-workflows)
7. [Troubleshooting](#troubleshooting)
8. [Best Practices](#best-practices)

---

## Getting Started

### What You'll Learn

This guide will teach you how to:
- Parse and analyze DOCSIS configuration files
- Convert between different file formats
- Validate DOCSIS compliance
- Work with advanced TLV types
- Integrate Bindocsis into your workflow

### Prerequisites

- Basic understanding of DOCSIS technology
- Familiarity with command-line interfaces
- Understanding of network configuration concepts

### Installation

```bash
# Clone the repository
git clone https://github.com/your-org/bindocsis.git
cd bindocsis

# Install dependencies
mix deps.get

# Compile the project
mix compile

# Build CLI executable
mix escript.build
```

---

## Basic Operations

### Parsing DOCSIS Files

The most common operation is parsing a DOCSIS binary configuration file:

```bash
# Parse and display a DOCSIS file
./bindocsis config.cm
```

**Example Output:**
```
Type: 3 (Network Access Control) Length: 1
Value: Enabled

Type: 1 (Downstream Frequency) Length: 4
Value: 93.0 MHz

Type: 2 (Maximum Upstream Transmit Power) Length: 1
Value: 15.0 dBmV

Type: 24 (Upstream Service Flow Configuration) Length: 7
SubTLVs:
  Type: 1 (Service Flow Ref) Length: 2 Value: 1
  Type: 6 (Min Rsrvd Traffic Rate) Length: 1 Value: 7 bits/second
```

### Understanding TLV Structure

DOCSIS configurations use Type-Length-Value (TLV) encoding:

- **Type**: Identifies what parameter this is (1-255)
- **Length**: How many bytes the value contains
- **Value**: The actual configuration data

**TLV Categories:**
- **1-30**: Core DOCSIS parameters (frequency, power, etc.)
- **31-42**: Security and privacy settings
- **43-63**: Advanced features
- **64-76**: DOCSIS 3.0 extensions
- **77-85**: DOCSIS 3.1 extensions
- **200-255**: Vendor-specific extensions

### Getting Help

```bash
# Show all available commands
./bindocsis --help

# Show version information
./bindocsis --version
```

---

## Format Conversion

### Supported Formats

| Format | Extension | Description | Use Case |
|--------|-----------|-------------|----------|
| **Binary** | `.cm` | Standard DOCSIS binary | Cable modem deployment |
| **JSON** | `.json` | Structured data format | API integration, web apps |
| **YAML** | `.yaml` | Human-readable format | Configuration management |
| **Pretty** | `.txt` | Human-readable text | Analysis and documentation |

### Basic Conversion Examples

```bash
# Binary to JSON
./bindocsis -i config.cm -o config.json -t json

# Binary to YAML
./bindocsis -i config.cm -o config.yaml -t yaml

# JSON to Binary
./bindocsis -i config.json -o output.cm -t binary

# YAML to JSON
./bindocsis -i config.yaml -o config.json -t json
```

### Format-Specific Examples

#### JSON Format
```json
{
  "docsis_version": "3.1",
  "tlvs": [
    {
      "type": 3,
      "length": 1,
      "value": "01",
      "description": "Network Access Control: Enabled"
    },
    {
      "type": 68,
      "length": 4,
      "value": "000003E8",
      "description": "Default Upstream Target Buffer: 1000"
    }
  ]
}
```

#### YAML Format
```yaml
docsis_version: "3.1"
tlvs:
  - type: 3
    length: 1
    value: "01"
    description: "Network Access Control: Enabled"
  - type: 68
    length: 4
    value: "000003E8"
    description: "Default Upstream Target Buffer: 1000"
```

### Piping and Chaining

```bash
# Convert and validate in one step
./bindocsis -i config.cm -t json --validate

# Output to stdout and pipe to other tools
./bindocsis -i config.cm -t json | jq '.tlvs[0]'

# Convert multiple files
for file in *.cm; do
  ./bindocsis -i "$file" -o "${file%.cm}.json" -t json
done
```

---

## Advanced Features

### DOCSIS 3.0/3.1 Extended TLVs

Bindocsis supports all advanced TLV types introduced in DOCSIS 3.0 and 3.1:

#### DOCSIS 3.0 Extensions (TLV 64-76)

```bash
# Parse file with DOCSIS 3.0 extensions
./bindocsis docsis30_config.cm
```

**Example Output:**
```
Type: 64 (PacketCable Configuration) Length: 12
Description: PacketCable configuration parameters
SubTLVs:
  Type: 1 (PacketCable Version) Length: 2 Value: 2.0
  Type: 2 (DHCP Option) Length: 6 Value: 43:06:01:04:AC:10:00:01

Type: 68 (Default Upstream Target Buffer) Length: 4
Description: Default upstream target buffer size
Value: 1000

Type: 72 (Metro Ethernet Service Profile) Length: 8
Description: Metro Ethernet service profile
SubTLVs:
  Type: 1 (Service Profile ID) Length: 4 Value: 100
```

#### DOCSIS 3.1 Extensions (TLV 77-85)

```bash
# Parse file with DOCSIS 3.1 features
./bindocsis docsis31_config.cm
```

**Example Output:**
```
Type: 77 (DLS Encoding) Length: 12
Description: Downstream Service (DLS) encoding
SubTLVs:
  Type: 1 (DLS Service Flow ID) Length: 4 Value: 100
  Type: 2 (DLS Application Identifier) Length: 4 Value: 200

Type: 83 (DBC Request) Length: 16
Description: Dynamic Bonding Change request
SubTLVs:
  Type: 1 (Transaction ID) Length: 4 Value: 12345
  Type: 2 (Channel Set) Length: 8 Value: 01:02:03:04:05:06:07:08
```

### Vendor-Specific TLVs

Handle vendor extensions (TLV 200-255):

```bash
# Parse file with vendor extensions
./bindocsis vendor_config.cm
```

**Example Output:**
```
Type: 201 (Vendor Specific TLV 201) Length: 8
Description: Vendor-specific configuration
Value: 12:34:56:78:9A:BC:DE:F0 (vendor-specific)

Type: 254 (Pad) Length: 4
Description: Padding TLV for alignment
Value: 00:00:00:00

Type: 255 (End-of-Data Marker) Length: 0
Description: End of configuration data marker
Value: (end marker)
```

### Working with SubTLVs

Complex TLVs contain SubTLVs for hierarchical configuration:

```bash
# Analyze service flow configuration
./bindocsis service_flow.cm
```

**Example Output:**
```
Type: 24 (Upstream Service Flow Configuration) Length: 25
SubTLVs:
  Type: 1 (Service Flow Reference) Length: 2 Value: 1
  Type: 2 (Service Class Name) Length: 8 Value: "GOLD_SLA"
  Type: 6 (QoS Parameter Set Type) Length: 1 Value: 7
  Type: 8 (Traffic Priority) Length: 1 Value: 3
  Type: 9 (Maximum Sustained Traffic Rate) Length: 4 Value: 1000000
  Type: 10 (Maximum Traffic Burst) Length: 4 Value: 16000
```

---

## DOCSIS Compliance

### Version-Specific Validation

Validate configurations against specific DOCSIS versions:

```bash
# Validate for DOCSIS 3.1
./bindocsis validate config.cm --docsis-version 3.1
✅ Configuration is valid for DOCSIS 3.1

# Validate for DOCSIS 3.0
./bindocsis validate config.cm --docsis-version 3.0
❌ Validation failed:
  • TLV 77: Not supported in DOCSIS 3.0 (introduced in 3.1)
```

### Common Validation Errors

#### Version Compatibility Issues
```bash
$ ./bindocsis validate docsis31_config.cm -d 3.0
❌ Validation failed:
  • TLV 77 (DLS Encoding): Not supported in DOCSIS 3.0
  • TLV 83 (DBC Request): Not supported in DOCSIS 3.0
```

#### Missing Required TLVs
```bash
$ ./bindocsis validate incomplete.cm
❌ Validation failed:
  • Missing required TLV 3 (Network Access Control)
  • Service Flow 1: Missing required SubTLV 1 (Service Flow Reference)
```

#### Value Range Errors
```bash
$ ./bindocsis validate invalid_values.cm
❌ Validation failed:
  • TLV 1 (Downstream Frequency): Value 50000000 Hz outside valid range
  • TLV 2 (Max Upstream Power): Value 65 dBmV exceeds maximum of 65 dBmV
```

### Compliance Checking

```bash
# Comprehensive compliance check
./bindocsis validate full_config.cm --verbose
✅ Configuration is valid for DOCSIS 3.1

Validation Details:
  ✅ All required TLVs present
  ✅ TLV types valid for DOCSIS 3.1
  ✅ All value ranges within specification
  ✅ Service flow configurations complete
  ✅ Security settings properly configured
  ✅ No conflicting parameters detected
```

---

## Common Workflows

### 1. Configuration Analysis

Analyze an existing DOCSIS configuration:

```bash
# Step 1: Parse and review
./bindocsis config.cm > analysis.txt

# Step 2: Convert to structured format for processing
./bindocsis -i config.cm -t json > config.json

# Step 3: Validate compliance
./bindocsis validate config.cm --docsis-version 3.1
```

### 2. Configuration Migration

Migrate from DOCSIS 3.0 to 3.1:

```bash
# Step 1: Validate current config for 3.0
./bindocsis validate old_config.cm -d 3.0

# Step 2: Convert to editable format
./bindocsis -i old_config.cm -t yaml > migration.yaml

# Step 3: Edit YAML file to add DOCSIS 3.1 features
# (Add TLV 77-85 as needed)

# Step 4: Convert back to binary
./bindocsis -i migration.yaml -t binary -o new_config.cm

# Step 5: Validate for DOCSIS 3.1
./bindocsis validate new_config.cm -d 3.1
```

### 3. Template Creation

Create reusable configuration templates:

```bash
# Step 1: Start with base configuration
./bindocsis -i base_config.cm -t yaml > template.yaml

# Step 2: Modify template for different service tiers
cp template.yaml gold_template.yaml
cp template.yaml silver_template.yaml
cp template.yaml bronze_template.yaml

# Step 3: Generate specific configurations
./bindocsis -i gold_template.yaml -t binary -o gold_config.cm
./bindocsis -i silver_template.yaml -t binary -o silver_config.cm
./bindocsis -i bronze_template.yaml -t binary -o bronze_config.cm
```

### 4. Batch Processing

Process multiple configuration files:

```bash
#!/bin/bash
# Batch validation script

for file in configs/*.cm; do
  echo "Validating $file..."
  if ./bindocsis validate "$file" -d 3.1 > /dev/null 2>&1; then
    echo "✅ $file: Valid"
    ./bindocsis -i "$file" -t json > "validated/${file%.cm}.json"
  else
    echo "❌ $file: Invalid"
    ./bindocsis validate "$file" -d 3.1 2> "errors/${file%.cm}.log"
  fi
done
```

### 5. Configuration Comparison

Compare two configuration files:

```bash
# Convert both to JSON for comparison
./bindocsis -i config1.cm -t json > config1.json
./bindocsis -i config2.cm -t json > config2.json

# Use diff or jq to compare
diff config1.json config2.json

# Or use jq for structured comparison
jq -n --argjson a "$(cat config1.json)" --argjson b "$(cat config2.json)" \
  '$a.tlvs - $b.tlvs'
```

---

## Troubleshooting

### Common Issues and Solutions

#### 1. File Format Detection

**Problem**: "Unknown file format" error
```bash
$ ./bindocsis unknown_file.dat
❌ Error: Unable to detect file format
```

**Solution**: Specify the input format explicitly
```bash
$ ./bindocsis -i unknown_file.dat -f binary
```

#### 2. Corrupted Binary Files

**Problem**: "Invalid TLV format" error
```bash
$ ./bindocsis corrupted.cm
❌ Error: Invalid TLV format at byte 23
```

**Solution**: Use hex dump to inspect the file
```bash
$ hexdump -C corrupted.cm | head -10
$ ./bindocsis -i corrupted.cm --verbose
```

#### 3. Large File Processing

**Problem**: Out of memory with large files
```bash
$ ./bindocsis huge_config.cm
❌ Error: Memory allocation failed
```

**Solution**: Use streaming mode or increase memory
```bash
$ ./bindocsis -i huge_config.cm --stream-mode
$ export ERL_MAX_MEMORY=2048m && ./bindocsis huge_config.cm
```

#### 4. Version Compatibility

**Problem**: TLV not recognized in older DOCSIS version
```bash
$ ./bindocsis validate new_config.cm -d 3.0
❌ TLV 77: Not supported in DOCSIS 3.0
```

**Solution**: Use appropriate DOCSIS version or upgrade
```bash
$ ./bindocsis validate new_config.cm -d 3.1
✅ Configuration is valid for DOCSIS 3.1
```

### Debug Mode

Enable verbose output for troubleshooting:

```bash
# Verbose parsing
./bindocsis config.cm --verbose

# Debug TLV processing
./bindocsis config.cm --debug

# Trace format detection
./bindocsis config.cm --trace-format
```

### Log Files

Check log files for detailed error information:

```bash
# View recent errors
tail -f ~/.bindocsis/logs/error.log

# Search for specific issues
grep "TLV" ~/.bindocsis/logs/debug.log
```

---

## Best Practices

### 1. File Organization

```
docsis-configs/
├── templates/
│   ├── gold_tier.yaml
│   ├── silver_tier.yaml
│   └── bronze_tier.yaml
├── production/
│   ├── site1/
│   └── site2/
├── testing/
└── backup/
```

### 2. Version Control

- Store configurations in YAML format for better diffs
- Use meaningful commit messages
- Tag releases with DOCSIS version compatibility

```bash
# Convert binary to YAML for version control
./bindocsis -i config.cm -t yaml > config.yaml
git add config.yaml
git commit -m "Add gold tier service configuration (DOCSIS 3.1)"
git tag -a v1.0-docsis3.1 -m "DOCSIS 3.1 compatible configuration"
```

### 3. Validation Workflow

Always validate configurations before deployment:

```bash
#!/bin/bash
# Pre-deployment validation script

CONFIG_FILE=$1
DOCSIS_VERSION=${2:-3.1}

echo "Validating $CONFIG_FILE for DOCSIS $DOCSIS_VERSION..."

# Validate syntax
if ! ./bindocsis validate "$CONFIG_FILE" -d "$DOCSIS_VERSION"; then
  echo "❌ Validation failed - stopping deployment"
  exit 1
fi

# Check for required TLVs
if ! ./bindocsis "$CONFIG_FILE" | grep -q "Network Access Control"; then
  echo "❌ Missing required Network Access Control TLV"
  exit 1
fi

echo "✅ Configuration is ready for deployment"
```

### 4. Performance Optimization

- Use binary format for production deployments
- Use JSON/YAML for configuration management
- Batch process multiple files when possible
- Monitor memory usage with large files

### 5. Security Considerations

- Validate all configurations before deployment
- Use proper file permissions for configuration files
- Audit configuration changes
- Keep backups of working configurations

### 6. Documentation

Document your configuration standards:

```yaml
# Configuration Template: Gold Tier Service
# DOCSIS Version: 3.1
# Last Updated: 2024-12-19
# Service Level: Premium residential

docsis_version: "3.1"
service_tier: "gold"
tlvs:
  - type: 3    # Network Access Control
    value: 1   # Enabled
  - type: 68   # Default Upstream Target Buffer (DOCSIS 3.0+)
    value: 2000  # 2000 bytes for premium service
```

---

## Next Steps

Now that you understand the basics, explore:

1. **[API Reference](API_REFERENCE.md)** - Programmatic usage
2. **[CLI Reference](CLI_REFERENCE.md)** - Complete command reference
3. **[Format Specifications](FORMAT_SPECIFICATIONS.md)** - Technical details
4. **[Examples](EXAMPLES.md)** - More practical examples
5. **[Development Guide](DEVELOPMENT.md)** - Contributing to Bindocsis

---

**Need Help?**

- Check the [Troubleshooting Guide](TROUBLESHOOTING.md)
- Review [Common Examples](EXAMPLES.md)
- Open an issue on [GitHub](https://github.com/your-org/bindocsis/issues)
- Join our community discussions

---

*This guide covers the essential usage patterns for Bindocsis. For the most up-to-date information, always refer to the latest documentation and release notes.*