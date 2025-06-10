# Bindocsis Format Specifications

This document provides detailed technical specifications for all formats supported by Bindocsis.

## Table of Contents

1. [Overview](#overview)
2. [Binary Format](#binary-format)
3. [JSON Format](#json-format)
4. [YAML Format](#yaml-format)
5. [Config Format](#config-format)
6. [Format Conversion Rules](#format-conversion-rules)
7. [Validation Specifications](#validation-specifications)
8. [DOCSIS Version Compatibility](#docsis-version-compatibility)

## Overview

Bindocsis supports four primary formats for DOCSIS configuration representation:

| Format | Extension | MIME Type | Use Case |
|--------|-----------|-----------|----------|
| Binary | `.cm`, `.bin` | `application/octet-stream` | Native DOCSIS format |
| JSON | `.json` | `application/json` | API integration, web services |
| YAML | `.yaml`, `.yml` | `application/x-yaml` | Human-readable configuration |
| Config | `.conf`, `.cfg` | `text/plain` | Network engineer workflows |

## Binary Format

### Structure

The binary format follows the DOCSIS specification for configuration files:

```
TLV Structure:
+--------+--------+--------+--------+
|  Type  | Length |      Value      |
+--------+--------+--------+--------+
|  1-2   |  1-2   |    Variable     |
| bytes  | bytes  |                 |
+--------+--------+--------+--------+
```

### Type Field

- **Size**: 1-2 bytes
- **Range**: 0-255 (standard), 256-65535 (extended)
- **Encoding**: Network byte order (big-endian)

### Length Field

- **Size**: 1-2 bytes for standard TLVs, 1-3 bytes for extended TLVs
- **Encoding**: Network byte order (big-endian)
- **Special Values**:
  - `0`: Empty value
  - `255`: Extended length indicator (for values > 254 bytes)

### Value Field

- **Size**: Variable, determined by Length field
- **Encoding**: Format-specific (binary, string, numeric)

### Example Binary Structure

```
Type 3 (Network Access): 0x03
Length: 0x01
Value: 0x01 (enabled)

Complete TLV: 0x03 0x01 0x01
```

### Compound TLVs

Service flows and other complex structures use nested TLV encoding:

```
Main TLV:
+--------+--------+------------------------+
|  Type  | Length |      Sub-TLVs          |
+--------+--------+------------------------+

Sub-TLV Structure:
+--------+--------+--------+
|  Type  | Length | Value  |
+--------+--------+--------+
```

## JSON Format

### Root Structure

```json
{
  "docsis_version": "3.1",
  "tlvs": [
    {
      "type": 3,
      "name": "Network Access",
      "length": 1,
      "value": 1,
      "description": "Enable network access",
      "subtlvs": []
    }
  ],
  "metadata": {
    "created_at": "2024-01-15T10:30:00Z",
    "source_format": "binary",
    "validation_status": "valid"
  }
}
```

### Field Specifications

#### Root Object

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `docsis_version` | String | Yes | DOCSIS version ("2.0", "3.0", "3.1") |
| `tlvs` | Array | Yes | Array of TLV objects |
| `metadata` | Object | No | Additional metadata |

#### TLV Object

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `type` | Integer | Yes | TLV type identifier (0-65535) |
| `name` | String | No | Human-readable TLV name |
| `length` | Integer | Yes | Value length in bytes |
| `value` | Mixed | Yes | TLV value (type-dependent) |
| `description` | String | No | TLV description |
| `subtlvs` | Array | No | Nested TLV objects |
| `docsis_version_introduced` | String | No | Minimum DOCSIS version |

#### Value Types

- **Integer**: Numeric values (1, 2, 4, or 8 bytes)
- **String**: Text values (UTF-8 encoded)
- **Binary**: Base64-encoded binary data
- **IP Address**: Dotted decimal notation ("192.168.1.1")
- **MAC Address**: Colon-separated hex ("00:11:22:33:44:55")
- **Boolean**: `true` or `false`

### Example: Service Flow Configuration

```json
{
  "docsis_version": "3.1",
  "tlvs": [
    {
      "type": 24,
      "name": "Downstream Service Flow",
      "length": 45,
      "value": null,
      "subtlvs": [
        {
          "type": 1,
          "name": "Service Flow Reference",
          "length": 2,
          "value": 1
        },
        {
          "type": 2,
          "name": "Service Flow ID",
          "length": 4,
          "value": 100
        },
        {
          "type": 7,
          "name": "Traffic Priority",
          "length": 1,
          "value": 5
        }
      ]
    }
  ]
}
```

## YAML Format

### Root Structure

```yaml
docsis_version: "3.1"
tlvs:
  - type: 3
    name: "Network Access"
    length: 1
    value: 1
    description: "Enable network access"
  - type: 6
    name: "CM MIC"
    length: 16
    value: "base64encodedvalue=="
metadata:
  created_at: "2024-01-15T10:30:00Z"
  source_format: "binary"
  validation_status: "valid"
```

### Nested TLVs

```yaml
docsis_version: "3.1"
tlvs:
  - type: 24
    name: "Downstream Service Flow"
    subtlvs:
      - type: 1
        name: "Service Flow Reference"
        value: 1
      - type: 2
        name: "Service Flow ID"
        value: 100
      - type: 7
        name: "Traffic Priority"
        value: 5
```

### YAML-Specific Features

- **Comments**: Lines starting with `#`
- **Multi-line strings**: Using `|` or `>`
- **Arrays**: Using `-` or `[]`
- **Inline objects**: `{key: value}`

## Config Format

### Structure

The Config format provides a human-readable representation optimized for network engineers:

```
# DOCSIS 3.1 Configuration
docsis_version: 3.1

# Basic Settings
network_access: enabled
max_cpe: 1
privacy_enable: yes

# Service Flows
downstream_service_flow {
    service_flow_ref: 1
    service_flow_id: 100
    traffic_priority: 5
    max_rate_sustained: 10000000
}

upstream_service_flow {
    service_flow_ref: 2
    service_flow_id: 200
    max_rate_sustained: 1000000
}
```

### Syntax Rules

#### Comments

```
# Single line comment
// Alternative comment style
/* Multi-line
   comment */
```

#### Key-Value Pairs

```
key: value
key = value        # Alternative syntax
key "string value" # Quoted strings
```

#### Blocks

```
block_name {
    nested_key: value
    another_key: value
}
```

#### Arrays

```
array_name: [value1, value2, value3]
# Or
array_name {
    value1
    value2
    value3
}
```

#### Data Types

- **Boolean**: `yes`, `no`, `true`, `false`, `enabled`, `disabled`
- **Integer**: `123`, `0x7B` (hex), `0b1111011` (binary)
- **String**: `"quoted string"` or `unquoted_string`
- **IP Address**: `192.168.1.1`
- **MAC Address**: `00:11:22:33:44:55`

### Example: Complete Configuration

```
# DOCSIS 3.1 Cable Modem Configuration
docsis_version: 3.1

# Basic Settings
network_access: enabled
max_cpe: 1
global_privacy_enable: yes
max_classifiers: 16

# TFTP Settings
software_upgrade_filename: "cm_firmware_v3.1.bin"
snmp_write_control: "private"
snmp_mib_object: "1.3.6.1.2.1.1.6.0=Cable Modem"

# Service Flows
downstream_service_flow {
    service_flow_ref: 1
    service_flow_id: 100
    service_class_id: 1
    
    # QoS Parameters
    traffic_priority: 5
    max_rate_sustained: 10000000  # 10 Mbps
    max_rate_burst: 12000000      # 12 Mbps
    min_rate_reserved: 1000000    # 1 Mbps
    
    # Packet Classification
    classifier {
        classifier_ref: 1
        service_flow_ref: 1
        rule_priority: 64
        ip_packet {
            src_addr: 0.0.0.0
            src_mask: 0.0.0.0
            dst_addr: 0.0.0.0
            dst_mask: 0.0.0.0
        }
    }
}

upstream_service_flow {
    service_flow_ref: 2
    service_flow_id: 200
    max_rate_sustained: 1000000   # 1 Mbps
    max_concat_burst: 1522
    scheduling_type: 2            # Best Effort
}

# Security
baseline_privacy {
    auth_timeout: 10
    reauth_timeout: 10
    auth_grace_time: 600
    op_timeout: 4
    rekey_timeout: 4
    tek_grace_time: 600
    auth_reject_timeout: 60
}

# Vendor Extensions
vendor_specific {
    vendor_id: 0x00000315        # Cisco
    vendor_options: "custom_config_data"
}
```

## Format Conversion Rules

### General Principles

1. **Lossless Conversion**: All format conversions preserve data integrity
2. **Metadata Preservation**: Format-specific metadata is maintained when possible
3. **Type Coercion**: Values are converted to appropriate types for target format
4. **Validation**: All conversions include validation steps

### Binary ↔ JSON Conversion

#### Binary → JSON

```
Binary TLV:        JSON Object:
Type: 3           → "type": 3
Length: 1         → "length": 1
Value: 0x01       → "value": 1
```

#### JSON → Binary

```
JSON Object:       Binary TLV:
"type": 3         → Type: 3
"length": 1       → Length: 1
"value": 1        → Value: 0x01
```

### Value Type Mapping

| DOCSIS Type | Binary | JSON | YAML | Config |
|-------------|--------|------|------|--------|
| UINT8 | 1 byte | Number | Number | Integer |
| UINT16 | 2 bytes BE | Number | Number | Integer |
| UINT32 | 4 bytes BE | Number | Number | Integer |
| STRING | UTF-8 bytes | String | String | String |
| IPADDR | 4 bytes | "w.x.y.z" | "w.x.y.z" | w.x.y.z |
| ETHER | 6 bytes | "aa:bb:cc:dd:ee:ff" | "aa:bb:cc:dd:ee:ff" | aa:bb:cc:dd:ee:ff |
| BINARY | Raw bytes | Base64 | Base64 | Hex string |

## Validation Specifications

### Structural Validation

#### JSON Schema Validation

```json
{
  "$schema": "http://json-schema.org/draft-07/schema#",
  "type": "object",
  "required": ["docsis_version", "tlvs"],
  "properties": {
    "docsis_version": {
      "type": "string",
      "enum": ["2.0", "3.0", "3.1"]
    },
    "tlvs": {
      "type": "array",
      "items": {
        "$ref": "#/definitions/tlv"
      }
    }
  },
  "definitions": {
    "tlv": {
      "type": "object",
      "required": ["type", "length"],
      "properties": {
        "type": {
          "type": "integer",
          "minimum": 0,
          "maximum": 65535
        },
        "length": {
          "type": "integer",
          "minimum": 0
        },
        "value": {},
        "subtlvs": {
          "type": "array",
          "items": {
            "$ref": "#/definitions/tlv"
          }
        }
      }
    }
  }
}
```

### DOCSIS Compliance Validation

#### Required TLVs by Version

**DOCSIS 2.0 Minimum:**
- Type 3: Network Access
- Type 6: CM MIC
- Type 7: CMTS MIC

**DOCSIS 3.0 Additional:**
- Type 50: MAC Domain Descriptor
- Type 51: Receive Channel Profile

**DOCSIS 3.1 Additional:**
- Type 61: OFDM Downstream Profile
- Type 62: OFDMA Upstream Profile

#### Value Range Validation

```yaml
tlv_constraints:
  type_3:  # Network Access
    values: [0, 1]
    description: "0=disabled, 1=enabled"
  
  type_4:  # Class of Service
    subtlv_1:  # Class ID
      range: [1, 16]
    subtlv_2:  # Max Rate Sustained
      range: [0, 4294967295]
```

### Error Reporting

#### Validation Error Structure

```json
{
  "errors": [
    {
      "type": "validation_error",
      "severity": "error",
      "code": "INVALID_TLV_TYPE",
      "message": "TLV type 999 is not valid for DOCSIS 3.1",
      "location": {
        "tlv_index": 5,
        "field": "type"
      },
      "suggestion": "Valid TLV types for DOCSIS 3.1 are 0-79"
    }
  ],
  "warnings": [
    {
      "type": "compatibility_warning",
      "severity": "warning",
      "code": "VERSION_MISMATCH",
      "message": "TLV 61 requires DOCSIS 3.1 but document specifies 3.0",
      "location": {
        "tlv_index": 8
      }
    }
  ]
}
```

## DOCSIS Version Compatibility

### Version-Specific Features

#### DOCSIS 2.0 (Legacy Support)

- **TLV Range**: 0-43
- **Max Config Size**: 1KB
- **Key Features**: Basic QoS, Privacy, SNMP

#### DOCSIS 3.0

- **TLV Range**: 0-60
- **Max Config Size**: 64KB  
- **New Features**: Bonding, IPv6, Enhanced QoS
- **Key TLVs**: 50-60 (Channel descriptors, bonding)

#### DOCSIS 3.1

- **TLV Range**: 0-79
- **Max Config Size**: 64KB
- **New Features**: OFDM/OFDMA, Low Latency, Enhanced Security
- **Key TLVs**: 61-79 (OFDM profiles, energy management)

### Backward Compatibility

```yaml
compatibility_matrix:
  docsis_2.0:
    supported_tlvs: [0-43]
    max_file_size: 1024
    
  docsis_3.0:
    supported_tlvs: [0-60]
    backward_compatible: [0-43]
    max_file_size: 65536
    
  docsis_3.1:
    supported_tlvs: [0-79]
    backward_compatible: [0-60]
    max_file_size: 65536
```

### Migration Guidelines

#### 2.0 → 3.0 Migration

```
# Automatic conversions:
- TLV 4 (CoS) → Enhanced with new subtypes
- TLV 22/23 (US/DS Service Flow) → Enhanced QoS parameters
- Add TLV 50 (MAC Domain Descriptor) if bonding required

# Manual review required:
- Channel assignments
- QoS parameter adjustments
- New privacy features
```

#### 3.0 → 3.1 Migration

```
# Automatic conversions:
- Channel profiles → OFDM profiles where applicable
- Maintain backward compatibility for non-OFDM features

# New opportunities:
- Low latency service flows
- Enhanced energy management
- Improved security features
```

---

## Implementation Notes

### Parser Behavior

1. **Format Detection**: Automatic detection based on file extension and content analysis
2. **Error Recovery**: Partial parsing with detailed error reporting
3. **Memory Efficiency**: Streaming parser for large files
4. **Unicode Support**: Full UTF-8 support for string values

### Generator Behavior  

1. **Pretty Printing**: Formatted output with proper indentation
2. **Compression**: Optional binary compression for large configurations
3. **Validation**: Pre-generation validation with error prevention
4. **Optimization**: Minimal output size while maintaining readability

### Performance Characteristics

| Format | Parse Speed | Generate Speed | Memory Usage |
|--------|-------------|----------------|--------------|
| Binary | Fastest | Fastest | Lowest |
| JSON | Fast | Fast | Medium |
| YAML | Medium | Medium | Medium |
| Config | Medium | Slow | Highest |

---

*This specification document is version 1.0 and corresponds to Bindocsis version 1.2.0+*