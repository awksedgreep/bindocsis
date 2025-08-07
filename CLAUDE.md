# CLAUDE.md - Critical Information for AI Assistant

## CRITICAL ARCHITECTURE UNDERSTANDING - READ THIS FIRST

### TLV Data Flow and Field Responsibilities

**NEVER CONFUSE THESE FIELDS:**

1. **`value`** - Raw binary data from the original TLV parsing
2. **`formatted_value`** - Human-editable representation for JSON/YAML/Config formats
3. **`raw_value`** - Internal metadata, NOT for human editing

### Round-Trip Conversion Architecture

```
Binary → TLV Parsing → Enrichment → JSON/Config Generation
                 ↓                        ↓
            Sets `value`              Sets `formatted_value`
                                     (for human editing)
```

**CRITICAL RULE**: `formatted_value` is what humans edit. Never use `raw_value` or `value` for human input parsing.

### Compound TLV Handling

When compound TLVs fail to parse as subtlvs:
- They should get a hex string `formatted_value` (e.g., "00 FF A1") 
- This allows humans to edit the binary data as hex
- Round-trip works: hex string → binary parsing → back to hex string

### What NOT to do (has been explained 70+ times):

❌ Don't parse `raw_value` as human input
❌ Don't use `value` field for human editing  
❌ Don't set `formatted_value` to `nil` for compound TLVs
❌ Don't create special JSON fields that aren't meant for humans
❌ **NEVER add formatted_value to parent TLVs that have subtlvs** (explained 10+ times)
❌ **Parent TLVs with subtlvs do NOT need formatted_value** - subtlvs contain the editable data

### Correct Fix for Compound TLV Round-Trip Issues:

When compound TLV subtlv parsing fails, provide a hex string as `formatted_value`:
```elixir
hex_value = binary_value
           |> :binary.bin_to_list()
           |> Enum.map(&Integer.to_string(&1, 16))
           |> Enum.map(&String.pad_leading(&1, 2, "0"))
           |> Enum.join(" ")

Map.put(metadata, :formatted_value, hex_value)
```

This ensures humans can edit compound TLVs that fail subtlv parsing as hex strings.