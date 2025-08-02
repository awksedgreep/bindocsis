# Bindocsis Utilities

Human-friendly command-line utilities for common DOCSIS configuration tasks.

## Overview

These utilities make it easy to perform common operations on DOCSIS configuration files without needing to understand the complex TLV structure or work with ugly JSON files.

## Available Utilities

### 1. Bandwidth Setter (`set_bandwidth.exs`)

**Purpose:** Easily modify upstream bandwidth in DOCSIS configuration files.

**Usage:**
```bash
elixir -S mix run set_bandwidth.exs <input.cm> <bandwidth> [output.cm]
```

**Examples:**
```bash
# Set to 75 Mbps (creates input_modified.cm)
elixir -S mix run set_bandwidth.exs modem.cm 75M

# Set to 100 Mbps with custom output name
elixir -S mix run set_bandwidth.exs modem.cm 100Mbps modem_100M.cm

# Using raw bits per second
elixir -S mix run set_bandwidth.exs modem.cm 75000000 modem_75M.cm

# Using kilobits
elixir -S mix run set_bandwidth.exs modem.cm 50000K modem_50M.cm
```

**Supported Bandwidth Formats:**
- `75M`, `100M` - Megabits per second
- `75Mbps`, `100Mbps` - Megabits per second (explicit)
- `500K`, `1000K` - Kilobits per second  
- `500kbps` - Kilobits per second (explicit)
- `75000000` - Raw bits per second

**Features:**
- ✅ Automatic pattern detection and replacement
- ✅ Verifies output file parses correctly
- ✅ Shows what bandwidth values were changed
- ✅ Supports multiple common bandwidth patterns

**Output Example:**
```
🔧 Setting upstream bandwidth to 75M
📂 Input:  modem.cm
📂 Output: modem_modified.cm

✅ Parsed bandwidth: 75000000 bps (75 Mbps)
🔄 Replaced bandwidth pattern: 55 Mbps → 75 Mbps
✅ Successfully created: modem_modified.cm
🔍 File verified and parses correctly
```

### 2. Configuration Describer (`describe_config.exs`)

**Purpose:** Create human-readable analysis of DOCSIS configuration files with automatic bandwidth detection and key settings identification.

**Usage:**
```bash
elixir -S mix run describe_config.exs <input.cm> [output.json]
```

**Examples:**
```bash
# Create described analysis (creates input_described.json)
elixir -S mix run describe_config.exs modem.cm

# Custom output filename
elixir -S mix run describe_config.exs modem.cm analysis.json
```

**Features:**
- ✅ **Configuration Summary** with TLV counts and key metrics
- ✅ **Bandwidth Detection** - automatically finds and reports bandwidth settings
- ✅ **Key Settings Analysis** - Web access, max CPEs, etc.
- ✅ **Pretty JSON Output** - properly formatted and indented
- ✅ **Certificate Counting** - reports number of embedded certificates

**Output Example:**
```
📋 Creating human-readable description of: modem.cm
📂 Output: modem_described.json

✅ Created described configuration: modem_described.json
📊 File size: 9800 bytes

📋 Configuration Summary:
  • Total TLVs: 38
  • Service Flows: 1 upstream, 1 downstream  
  • Certificates: 4
  • Bandwidth Settings:
    - Upstream: 55 Mbps
    - Downstream: 100 Mbps
  • Key Settings:
    - Web Access: Enabled
    - Max CPEs: 20
```

**JSON Output Structure:**
```json
{
  "_description": "DOCSIS Configuration File Analysis",
  "_summary": {
    "total_tlvs": 38,
    "service_flows": {
      "upstream": 1,
      "downstream": 1
    },
    "certificates": 4,
    "bandwidth_settings": ["Upstream: 55 Mbps", "Downstream: 100 Mbps"],
    "key_settings": ["Web Access: Enabled", "Max CPEs: 20"]
  },
  "docsis_version": "3.1",
  "tlvs": [
    {
      "description": "Web access enabled/disabled",
      "length": 1,
      "name": "Web Access Control", 
      "type": 3,
      "value": 1
    }
    // ... rest of TLVs with pretty formatting
  ]
}
```

## Improved JSON Generation

The core library now supports **pretty JSON formatting** by default:

**Programmatic Usage:**
```elixir
# Pretty formatted JSON (default)
{:ok, tlvs} = Bindocsis.parse_file("modem.cm")
{:ok, pretty_json} = Bindocsis.generate(tlvs, format: :json, pretty: true)
File.write!("modem_pretty.json", pretty_json)

# Compact JSON (if needed)
{:ok, compact_json} = Bindocsis.generate(tlvs, format: :json, pretty: false)
```

**Before (ugly):**
```json
{"docsis_version":"3.1","tlvs":[{"description":"Web access enabled/disabled","length":1,"name":"Web Access Control","type":3,"value":1},{"length":26,"subtlvs":[{"description":"Frequency in Hz","length":2,"name":"Downstream Frequency","type":1,"value":1}]}]}
```

**After (pretty):**
```json
{
  "docsis_version": "3.1",
  "tlvs": [
    {
      "description": "Web access enabled/disabled",
      "length": 1,
      "name": "Web Access Control",
      "type": 3,
      "value": 1
    },
    {
      "length": 26,
      "subtlvs": [
        {
          "description": "Frequency in Hz",
          "length": 2,
          "name": "Downstream Frequency",
          "type": 1,
          "value": 1
        }
      ]
    }
  ]
}
```

## Common Workflows

### 1. Analyze then Modify Bandwidth
```bash
# First, understand the current configuration
elixir -S mix run describe_config.exs modem.cm

# Then modify bandwidth based on analysis
elixir -S mix run set_bandwidth.exs modem.cm 75M modem_75M.cm
```

### 2. Create Human-Readable Export for Editing
```bash
# Export to pretty JSON for manual editing
elixir -S mix run describe_config.exs modem.cm

# Edit the JSON file manually
nano modem_described.json

# Convert back to DOCSIS format (using core library)
elixir -S mix run -e '{:ok, json} = File.read("modem_described.json"); {:ok, tlvs} = Bindocsis.parse(json, format: :json); {:ok, binary} = Bindocsis.generate(tlvs, format: :binary); File.write!("modem_edited.cm", binary)'
```

### 3. Production Bandwidth Updates
```bash
# Backup original
cp production_modem.cm production_modem.cm.backup

# Update bandwidth
elixir -S mix run set_bandwidth.exs production_modem.cm 100M production_modem_100M.cm

# Verify changes
elixir -S mix run describe_config.exs production_modem_100M.cm
```

## Error Handling

Both utilities include comprehensive error handling:

- **File not found** - Clear error messages
- **Invalid bandwidth formats** - Shows supported formats  
- **Parsing failures** - Reports parsing issues
- **Pattern not found** - Warns when bandwidth patterns aren't detected
- **Output verification** - Always verifies generated files parse correctly

## Integration with Core Library

These utilities are built on top of the core Bindocsis library and take advantage of:

- ✅ **Multi-byte length parsing fixes** - Handles complex TLV structures
- ✅ **Pretty JSON formatting** - Built-in readable formatting
- ✅ **Comprehensive TLV descriptions** - Human-readable names and descriptions
- ✅ **Format auto-detection** - Automatically detects file formats
- ✅ **Validation** - Ensures output files are valid

## Tips for Development Teams

1. **Use `describe_config.exs` first** - Always analyze before modifying
2. **Backup originals** - Keep copies of working configurations
3. **Verify outputs** - Both utilities automatically verify generated files
4. **Check logs** - Debug output shows exactly what patterns were modified
5. **Use version control** - Track configuration changes over time