# Bindocsis CLI Guide

**Complete Command-Line Interface Guide for DOCSIS Configuration Management**

---

## 🚀 Quick Start

The Bindocsis CLI provides powerful Mix tasks for working with DOCSIS configuration files. Convert between formats, validate configurations, and analyze bootfiles with simple, memorable commands.

### Available Commands

```bash
mix bindocsis.convert     # Convert between formats (binary ↔ JSON ↔ YAML)
mix bindocsis.validate    # Validate DOCSIS configurations  
mix bindocsis.analyze     # Analyze and compare configurations
```

### Basic Workflow

```bash
# 1. Analyze a bootfile
mix bindocsis.analyze bootfile.cm --summary-only

# 2. Convert to editable format
mix bindocsis.convert bootfile.cm --to yaml

# 3. Edit the YAML file (use your preferred editor)
vim bootfile.yaml

# 4. Convert back with validation
mix bindocsis.convert bootfile.yaml --to binary --validate

# 5. Final validation
mix bindocsis.validate bootfile.cm --docsis-version 3.1
```

---

## 📖 Command Reference

### `mix bindocsis.convert` - Format Converter

Convert DOCSIS configuration files between different formats with automatic file naming and validation.

#### Usage
```bash
mix bindocsis.convert <input_file> --to <format> [options]
```

#### Supported Formats
- **`json`** - Pretty-formatted JSON with human-readable descriptions
- **`yaml`** - YAML format (easiest for editing)  
- **`binary`** - DOCSIS binary format (.cm files)
- **`analyze`** - Enhanced analysis with summary (JSON format)

#### Examples
```bash
# Convert .cm to JSON
mix bindocsis.convert config.cm --to json

# Convert .cm to YAML for editing
mix bindocsis.convert config.cm --to yaml

# Convert YAML back to binary with custom name
mix bindocsis.convert config.yaml --to binary --output new_config.cm

# Batch convert all .cm files to JSON
mix bindocsis.convert *.cm --to json

# Convert with validation
mix bindocsis.convert config.yaml --to binary --validate
```

#### Options
- `--to FORMAT` - Output format (required)
- `--output PATH` - Custom output file path (optional, auto-generated if not specified)
- `--validate` - Validate the output after conversion
- `--quiet` - Suppress progress output

#### Auto-naming Examples
```bash
config.cm → config.json        (--to json)
config.cm → config.yaml        (--to yaml) 
config.yaml → config.cm        (--to binary)
config.cm → config_analysis.json (--to analyze)
```

---

### `mix bindocsis.validate` - Configuration Validator

Validate DOCSIS configuration files for compliance and correctness.

#### Usage
```bash
mix bindocsis.validate <file_or_directory> [options]
```

#### Examples
```bash
# Validate single file
mix bindocsis.validate config.cm

# Validate all .cm files in directory
mix bindocsis.validate configs/

# Validate with specific DOCSIS version
mix bindocsis.validate config.cm --docsis-version 3.1

# Quiet validation (only errors)
mix bindocsis.validate config.cm --quiet

# Verbose validation with details
mix bindocsis.validate config.cm --verbose
```

#### Options
- `--docsis-version VERSION` - Target DOCSIS version (3.0, 3.1)
- `--quiet` - Only show errors
- `--verbose` - Show detailed validation info

#### Exit Codes
- `0` - All files are valid
- `1` - One or more files are invalid

#### Batch Validation Examples
```bash
# Validate all configs in production
mix bindocsis.validate production_configs/ --docsis-version 3.1

# CI/CD integration
mix bindocsis.validate *.cm --quiet && deploy_configs

# Development workflow
mix bindocsis.validate test_configs/ --verbose
```

---

### `mix bindocsis.analyze` - Configuration Analyzer

Create detailed analysis of DOCSIS configuration files with comprehensive summaries and comparison capabilities.

#### Usage
```bash
mix bindocsis.analyze <input_file> [options]
mix bindocsis.analyze <file1> <file2> --compare
```

#### Examples
```bash
# Quick summary (no file output)
mix bindocsis.analyze config.cm --summary-only

# Create detailed analysis file
mix bindocsis.analyze config.cm

# Custom output file
mix bindocsis.analyze config.cm --output analysis.json

# Compare two configurations
mix bindocsis.analyze config1.cm config2.cm --compare
```

#### Analysis Features
- **File Statistics** - Size, modification date, TLV counts
- **DOCSIS Features** - Service flows, certificates, security settings  
- **Configuration Profile** - Automatic categorization (Production, Basic, Test, etc.)
- **Bandwidth Analysis** - Automatic detection of common bandwidth settings
- **Network Settings** - Max CPEs, SNMP objects, access controls

#### Sample Analysis Output
```
📊 Configuration Analysis Summary
═══════════════════════════════════════════════════
📄 File: 25ccatv-base-v2.cm
📐 Size: 440 bytes  
🔧 Profile: Standard Service

📋 TLV Statistics:
  • Total TLVs: 21
  • Unique Types: 10
  • Top Types: 11(11), 53(2), 3(1), 6(1), 7(1)

🚀 DOCSIS Features:
  • Service Flows: 2 (1 up, 1 down)
  • Certificates: 0
  • Security:
    - Network Access: Enabled
  • Network:
    - Max CPEs: 6
    - SNMP Objects: 11
```

#### Comparison Features
```bash
mix bindocsis.analyze original.cm modified.cm --compare
```

Shows:
- **Similarity Score** - Percentage of common elements
- **TLV Differences** - Added/removed/changed TLVs
- **Feature Changes** - Security, network, service flow changes
- **Unique Elements** - TLVs present in only one file

#### Options
- `--output PATH` - Output file path for detailed analysis
- `--summary-only` - Show summary without creating file
- `--compare` - Compare two configurations 
- `--quiet` - Suppress progress output

---

## 🔄 Complete Workflows

### Basic Edit Workflow

**Goal:** Edit a DOCSIS configuration file

```bash
# 1. Analyze the current configuration
mix bindocsis.analyze bootfile.cm --summary-only

# 2. Convert to YAML for easy editing
mix bindocsis.convert bootfile.cm --to yaml
# Creates: bootfile.yaml

# 3. Edit the YAML file
code bootfile.yaml  # or vim, nano, etc.

# 4. Convert back to binary with validation
mix bindocsis.convert bootfile.yaml --to binary --output bootfile_new.cm --validate

# 5. Compare old vs new
mix bindocsis.analyze bootfile.cm bootfile_new.cm --compare

# 6. Final validation
mix bindocsis.validate bootfile_new.cm --docsis-version 3.1
```

### Development Workflow

**Goal:** Develop and test configuration changes

```bash
# 1. Convert template to editable format
mix bindocsis.convert template.cm --to yaml --output development.yaml

# 2. Make your changes
vim development.yaml

# 3. Test conversion and validation
mix bindocsis.convert development.yaml --to binary --validate

# 4. Analyze the result
mix bindocsis.analyze development.cm --summary-only

# 5. Compare with original template
mix bindocsis.analyze template.cm development.cm --compare
```

### Production Deployment Workflow

**Goal:** Validate and deploy configuration changes

```bash
# 1. Validate all configs before deployment
mix bindocsis.validate production_configs/ --docsis-version 3.1 --quiet

# 2. Create analysis documentation
for config in production_configs/*.cm; do
  mix bindocsis.analyze "$config" --output "docs/$(basename "$config" .cm)_analysis.json"
done

# 3. Convert configs for backup/review
mix bindocsis.convert production_configs/*.cm --to json --quiet

# 4. Deploy (only if validation passed)
echo "All configs validated - ready for deployment"
```

### Batch Processing Workflow

**Goal:** Process multiple configuration files

```bash
# 1. Batch convert all .cm files to JSON
mix bindocsis.convert configs/*.cm --to json

# 2. Batch validate all configurations
mix bindocsis.validate configs/ --verbose

# 3. Create analysis for each config
for config in configs/*.cm; do
  echo "Analyzing $config..."
  mix bindocsis.analyze "$config" --summary-only
done

# 4. Find configurations that need attention
echo "Checking for minimal/test profiles..."
for config in configs/*.cm; do
  profile=$(mix bindocsis.analyze "$config" --summary-only --quiet | grep "Profile:" | cut -d' ' -f3-)
  if [[ "$profile" =~ "Test" || "$profile" =~ "Minimal" ]]; then
    echo "⚠️  $config has profile: $profile"
  fi
done
```

---

## 📋 Common Use Cases

### Format Conversion

```bash
# Binary to human-readable
mix bindocsis.convert modem.cm --to json
mix bindocsis.convert modem.cm --to yaml

# Human-readable to binary  
mix bindocsis.convert config.yaml --to binary
mix bindocsis.convert config.json --to binary

# Create analysis report
mix bindocsis.convert config.cm --to analyze
```

### Configuration Analysis

```bash
# Quick overview
mix bindocsis.analyze config.cm --summary-only

# Detailed analysis with file output
mix bindocsis.analyze config.cm

# Compare configurations
mix bindocsis.analyze old_config.cm new_config.cm --compare

# Analyze with custom output
mix bindocsis.analyze config.cm --output detailed_report.json
```

### Validation Scenarios

```bash
# Single file validation
mix bindocsis.validate bootfile.cm --verbose

# Directory validation
mix bindocsis.validate production_configs/ --docsis-version 3.1

# CI/CD validation (quiet mode)
mix bindocsis.validate *.cm --quiet
if [ $? -eq 0 ]; then
  echo "✅ All configurations valid"
else
  echo "❌ Validation failed"
  exit 1
fi
```

---

## 🛠 Advanced Features

### Batch Operations

```bash
# Convert all .cm files to multiple formats
for file in *.cm; do
  mix bindocsis.convert "$file" --to json
  mix bindocsis.convert "$file" --to yaml
done

# Validate entire directory tree
mix bindocsis.validate . --verbose

# Create analysis reports for all configs
mix bindocsis.convert *.cm --to analyze
```

### Integration with Other Tools

```bash
# Use with jq for JSON processing
mix bindocsis.convert config.cm --to json | jq '.tlvs[] | select(.type == 24)'

# Pipe to grep for filtering
mix bindocsis.analyze config.cm --summary-only | grep "Service Flows"

# Use in shell scripts
if mix bindocsis.validate config.cm --quiet; then
  deploy_config config.cm
else
  echo "Validation failed, aborting deployment"
fi
```

### Configuration Comparison Workflows

```bash
# Compare before/after changes
cp original.cm backup.cm
# ... make edits to original.cm ...
mix bindocsis.analyze backup.cm original.cm --compare

# Compare different service tiers
mix bindocsis.analyze basic_service.cm premium_service.cm --compare

# Batch comparison
for config in tier_*.cm; do
  echo "Comparing $config with base_config.cm:"
  mix bindocsis.analyze base_config.cm "$config" --compare --quiet
done
```

---

## 🔧 Troubleshooting

### Common Issues

#### Conversion Errors
```bash
# If YAML conversion fails, check the JSON first
mix bindocsis.convert problematic.cm --to json --verbose

# If binary conversion fails, validate the source
mix bindocsis.validate source.yaml --verbose
```

#### Validation Failures
```bash
# Use verbose mode to see detailed errors
mix bindocsis.validate config.cm --verbose

# Check different DOCSIS versions
mix bindocsis.validate config.cm --docsis-version 3.0
mix bindocsis.validate config.cm --docsis-version 3.1
```

#### File Permission Issues
```bash
# Ensure you have write permissions for output
ls -la output_directory/

# Use custom output paths if needed
mix bindocsis.convert config.cm --to yaml --output /tmp/config.yaml
```

### Debug Mode

For debugging issues, use verbose flags:

```bash
# Maximum verbosity for troubleshooting
mix bindocsis.convert config.cm --to json --verbose
mix bindocsis.validate config.cm --verbose  
mix bindocsis.analyze config.cm --verbose
```

---

## 🎯 Performance Tips

### Large File Processing

```bash
# For large files, use quiet mode to reduce output
mix bindocsis.convert large_config.cm --to json --quiet

# Batch process with parallel execution (requires GNU parallel)
parallel mix bindocsis.validate {} --quiet ::: configs/*.cm
```

### CI/CD Integration

```bash
# Optimized for CI/CD pipelines
mix bindocsis.validate *.cm --quiet --docsis-version 3.1

# Create deployment reports
mix bindocsis.convert *.cm --to analyze --quiet
```

---

## 🆚 Before vs After

### Old Workflow (Verbose)
```bash
# Convert to JSON (80+ characters)
elixir -S mix run -e '{:ok, tlvs} = Bindocsis.parse_file("file.cm"); {:ok, json} = Bindocsis.generate(tlvs, format: :json, pretty: true); File.write!("file.json", json)'

# Create analysis  
elixir -S mix run describe_config.exs file.cm

# Manual validation
elixir -S mix run -e 'case Bindocsis.parse_file("file.cm") do {:ok, _} -> IO.puts("Valid"); {:error, reason} -> IO.puts("Invalid: #{reason}") end'
```

### New Workflow (Simple)
```bash
# Convert to JSON (35 characters - 75% shorter!)
mix bindocsis.convert file.cm --to json

# Create analysis
mix bindocsis.analyze file.cm --summary-only

# Validate
mix bindocsis.validate file.cm --verbose
```

### Benefits
- **75% shorter commands** for common operations
- **Consistent CLI patterns** - all commands follow `mix bindocsis.*` format
- **Auto-naming** - no manual file management
- **Built-in validation** - integrated into workflow
- **Batch processing** - handle multiple files easily
- **Professional UX** - progress indicators, error handling, help system

---

## 📚 Quick Reference

### Most Common Commands
```bash
# Quick analysis
mix bindocsis.analyze config.cm --summary-only

# Edit workflow  
mix bindocsis.convert config.cm --to yaml
# ... edit config.yaml ...
mix bindocsis.convert config.yaml --to binary --validate

# Validation
mix bindocsis.validate config.cm --verbose

# Comparison
mix bindocsis.analyze old.cm new.cm --compare
```

### Format Quick Reference
```bash
# To JSON:    mix bindocsis.convert file.cm --to json
# To YAML:    mix bindocsis.convert file.cm --to yaml  
# To Binary:  mix bindocsis.convert file.yaml --to binary
# Analysis:   mix bindocsis.convert file.cm --to analyze
```

### Help Commands
```bash
mix help bindocsis.convert
mix help bindocsis.validate  
mix help bindocsis.analyze
```

---

## 🚀 Getting Started Checklist

1. **✅ Install Dependencies**
   ```bash
   mix deps.get
   mix compile
   ```

2. **✅ Verify Installation**
   ```bash
   mix help | grep bindocsis
   ```

3. **✅ Test with Your First File**
   ```bash
   mix bindocsis.analyze your_config.cm --summary-only
   ```

4. **✅ Try Format Conversion**
   ```bash
   mix bindocsis.convert your_config.cm --to yaml
   ```

5. **✅ Validate Configuration**
   ```bash
   mix bindocsis.validate your_config.cm --verbose
   ```

**You're ready to use the enhanced Bindocsis CLI! 🎉**

---

*For more detailed information, see the complete [CLI Reference](docs/CLI_REFERENCE.md) and [API Documentation](docs/API_REFERENCE.md).*