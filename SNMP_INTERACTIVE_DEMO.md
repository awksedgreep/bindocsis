# Interactive Editor - SNMP MIB Object Support

## New Feature: Add SNMP MIB Objects Interactively

The interactive editor now supports adding vendor-specific SNMP MIB Objects (TLV 11) directly from the command line!

## Usage

### Start Interactive Editor

```bash
./bindocsis edit 25ccatv-base-v2.cm
```

### Add SNMP MIB Object Command

```
add snmp <oid> <type> <value>
```

**Parameters:**
- `<oid>` - Object Identifier in dotted notation (e.g., `1.3.6.1.4.1.8595.20.17.1.4.0`)
- `<type>` - Data type: `integer`, `int`, `string`, `octetstring`, or `octet`
- `<value>` - The value (integer number or quoted string)

### Examples

#### Add an INTEGER SNMP Object

```
bindocsis> add snmp 1.3.6.1.4.1.8595.20.17.1.4.0 integer 2
```

This creates:
- TLV 11 (SNMP MIB Object)
- With sub-TLV 48 (Object Value)
- Containing ASN.1 DER encoded SEQUENCE(OID, INTEGER value)

#### Add a STRING SNMP Object

```
bindocsis> add snmp 1.3.6.1.2.1.1.5.0 string "MyModem"
```

```
bindocsis> add snmp 1.3.6.1.4.1.4491.2.5.1.1.2.1.2.1 octetstring "config_data"
```

### Complete Workflow

```bash
# 1. Start editor with existing config
./bindocsis edit 25ccatv-base-v2.cm

# 2. View current configuration
bindocsis> list

# 3. Add your vendor-specific OID
bindocsis> add snmp 1.3.6.1.4.1.8595.20.17.1.4.0 integer 2

# Output:
# ✅ Added SNMP MIB Object (TLV 11)
#    OID: 1.3.6.1.4.1.8595.20.17.1.4.0
#    Type: INTEGER
#    Value: 2

# 4. Validate configuration
bindocsis> validate

# 5. Save updated config
bindocsis> save 25ccatv-base-v2-with-snmp.cm

# 6. Exit
bindocsis> quit
```

### View Added SNMP Objects

```
bindocsis> list -v
```

This will show all TLVs including detailed information about the SNMP MIB Objects with their OIDs, types, and values.

## Technical Details

The command automatically:
1. Parses the OID string into integer components
2. Creates ASN.1 DER encoded SEQUENCE containing:
   - OBJECT IDENTIFIER (0x06)
   - INTEGER (0x02) or OCTET STRING (0x04)
3. Wraps in TLV 11 (SNMP MIB Object) with sub-TLV 48 (Object Value)
4. Validates the structure for DOCSIS compliance

## Supported Types

| Type | Aliases | ASN.1 Tag | Example |
|------|---------|-----------|---------|
| `integer` | `int` | 0x02 | `add snmp 1.3.6.1.4.1.8595.20.17.1.4.0 integer 2` |
| `string` | `octetstring`, `octet` | 0x04 | `add snmp 1.3.6.1.2.1.1.5.0 string "text"` |

## Error Handling

The editor validates:
- OID format (must be dotted decimal notation)
- Type (must be supported type)
- Value (must match type - integer for integer type, string for string type)
- ASN.1 encoding (proper DER format)

Example error messages:
```
❌ Error: Invalid OID format. Use dotted notation like 1.3.6.1.4.1.8595
❌ Error: Unsupported SNMP type: boolean. Use: integer or string
❌ Error: Invalid integer value: abc
```

## Comparison: Interactive vs JSON Editing

### Before (JSON Editing):
1. Convert to JSON: `./bindocsis convert -i config.cm -o config.json -t json`
2. Edit JSON manually with complex structure
3. Convert back: `./bindocsis convert -i config.json -o config.cm -t binary`

### Now (Interactive):
```bash
./bindocsis edit config.cm
bindocsis> add snmp 1.3.6.1.4.1.8595.20.17.1.4.0 integer 2
bindocsis> save
```

Much simpler! 🎉
