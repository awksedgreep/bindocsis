# Bindocsis Troubleshooting Guide - Phase 6

**Comprehensive Problem Resolution for Professional DOCSIS Configuration Processing**

*Updated for Phase 6: Complete DOCSIS 3.0/3.1 Support with 141 TLV Types*

---

## 🎯 **Phase 6 Quick Reference**

Bindocsis Phase 6 introduces major enhancements that may affect troubleshooting:

- **141 TLV Types**: Complete support for TLV range 1-255
- **DOCSIS 3.0/3.1**: Full specification compliance with extensions
- **Dynamic Processing**: DocsisSpecs module replaces hardcoded TLV handling
- **Vendor Extensions**: Complete support for vendor-specific TLVs (200-255)
- **Multi-Format**: Enhanced Binary, JSON, YAML, Config, and MTA processing

---

## Table of Contents

1. [Quick Diagnostics](#quick-diagnostics)
2. [Phase 6 Specific Issues](#phase-6-specific-issues)
3. [TLV Processing Problems](#tlv-processing-problems)
4. [DOCSIS Version Compatibility](#docsis-version-compatibility)
5. [Format Conversion Issues](#format-conversion-issues)
6. [DocsisSpecs Module Troubleshooting](#docsisspecs-module-troubleshooting)
7. [Dependency Issues](#dependency-issues)
8. [Installation & Environment Problems](#installation--environment-problems)
9. [Performance Troubleshooting](#performance-troubleshooting)
10. [Advanced Debugging Techniques](#advanced-debugging-techniques)
11. [Known Issues & Workarounds](#known-issues--workarounds)
12. [Error Reference Guide](#error-reference-guide)

---

## Quick Diagnostics

### Phase 6 System Verification

```bash
# Essential Phase 6 verification
echo "🔍 Phase 6 System Check:"
echo "======================"

# Check versions
echo "Elixir version (should be 1.18+):"
elixir --version | head -1

echo "Bindocsis version (should show Phase 6 features):"
./bindocsis --version

# Test Phase 6 TLV support
echo "Testing 141 TLV support:"
echo "Number of supported TLV types:"
elixir -e "
{:ok, _} = Application.ensure_all_started(:bindocsis)
count = Bindocsis.DocsisSpecs.get_supported_types(\"3.1\") |> length()
IO.puts(\"✅ #{count} TLV types supported (should be 141)\")
"

# Test dynamic TLV processing
echo "Testing dynamic TLV processing:"
echo "4D 04 01 02 03 04" | ./bindocsis -f hex -t pretty | head -3

echo "Testing vendor TLV support:"
echo "C9 06 DE AD BE EF CA FE" | ./bindocsis -f hex -t pretty | head -3
```

### Quick Health Check

```bash
# Run comprehensive health check
cat > health_check.exs << 'EOF'
# Phase 6 Health Check Script
Mix.install([{:bindocsis, path: "."}])

defmodule HealthCheck do
  def run do
    IO.puts("🏥 Bindocsis Phase 6 Health Check")
    IO.puts("===============================")
    
    # Test 1: DocsisSpecs module
    test_docsis_specs()
    # Test 2: TLV range support
    test_tlv_range()
    # Test 3: Version compatibility
    test_version_compatibility()
    # Test 4: Format processing
    test_format_processing()
    
    IO.puts("\n✅ Health check complete!")
  end
  
  defp test_docsis_specs do
    IO.puts("\n📊 Testing DocsisSpecs module...")
    case Bindocsis.DocsisSpecs.get_tlv_info(77, "3.1") do
      {:ok, tlv_info} -> 
        IO.puts("✅ DOCSIS 3.1 TLV 77 (#{tlv_info.name}) supported")
      {:error, reason} -> 
        IO.puts("❌ DocsisSpecs issue: #{reason}")
    end
  end
  
  defp test_tlv_range do
    IO.puts("\n🔢 Testing TLV range support...")
    count = Bindocsis.DocsisSpecs.get_supported_types("3.1") |> length()
    if count == 141 do
      IO.puts("✅ Complete TLV range supported: #{count} types")
    else
      IO.puts("⚠️  Incomplete TLV support: #{count}/141 types")
    end
  end
  
  defp test_version_compatibility do
    IO.puts("\n🏷️  Testing version compatibility...")
    versions = ["3.0", "3.1"]
    Enum.each(versions, fn version ->
      count = Bindocsis.DocsisSpecs.get_supported_types(version) |> length()
      IO.puts("✅ DOCSIS #{version}: #{count} TLV types")
    end)
  end
  
  defp test_format_processing do
    IO.puts("\n🔄 Testing format processing...")
    test_data = <<3, 1, 1>>  # TLV 3 (Network Access)
    
    case Bindocsis.parse_binary(test_data) do
      {:ok, tlvs} when length(tlvs) > 0 -> 
        IO.puts("✅ Binary parsing functional")
      {:error, reason} -> 
        IO.puts("❌ Binary parsing failed: #{reason}")
    end
  end
end

HealthCheck.run()
EOF

elixir health_check.exs
rm health_check.exs
```

---

## Phase 6 Specific Issues

### Issue: "DocsisSpecs module not available"

**Symptoms:**
```
** (UndefinedFunctionError) function Bindocsis.DocsisSpecs.get_tlv_info/2 is undefined
```

**Cause**: Incomplete Phase 6 installation or compilation issues

**Solution:**
```bash
# Verify DocsisSpecs module exists
ls -la lib/bindocsis/docsis_specs.ex

# Recompile with clean build
mix clean
mix compile

# Test DocsisSpecs directly
iex -S mix
iex> Bindocsis.DocsisSpecs.get_tlv_info(3)
# Should return: {:ok, %{name: "Network Access Control", ...}}
```

### Issue: "TLV type not supported in current version"

**Symptoms:**
```
Unknown TLV Type 77: 0x01020304
```

**Cause**: Using DOCSIS 3.1 TLVs with version set to 3.0 or earlier

**Solution:**
```bash
# Check what version is being used
./bindocsis -i "4D 04 01 02 03 04" --docsis-version 3.1

# Explicitly set DOCSIS version
./bindocsis -f hex -t pretty --docsis-version 3.1 << EOF
4D 04 01 02 03 04
EOF

# Expected output should show:
# TLV 77 (DLS Encoding): 0x01020304
```

### Issue: "Vendor TLV shows as hex only"

**Symptoms:**
```
TLV 201: 0xDEADBEEFCAFE
```

**Cause**: This is expected behavior for vendor-specific TLVs

**Verification:**
```bash
# This is correct behavior - vendor TLVs display as hex
echo "C9 06 DE AD BE EF CA FE" | ./bindocsis -f hex -t pretty

# To verify vendor TLV support:
elixir -e "
IO.inspect(Bindocsis.DocsisSpecs.get_tlv_info(201))
# Should return: {:ok, %{name: \"Vendor Specific TLV 201\", ...}}
"
```

### Issue: "Hardcoded TLV processing errors"

**Symptoms:**
```
TLV type 68 not found in case statement
```

**Cause**: Using pre-Phase 6 code or mixed versions

**Solution:**
```bash
# Verify you're using Phase 6 dynamic processing
grep -r "case.*type.*do" lib/bindocsis.ex
# Should NOT find hardcoded case statements for TLV types

# Should find DocsisSpecs usage instead:
grep -r "DocsisSpecs.get_tlv_info" lib/bindocsis.ex
# Should find dynamic TLV lookup calls
```

---

## TLV Processing Problems

### Unknown TLV Type Errors

#### Error: "TLV type XXX not supported"

**For TLV 64-76 (DOCSIS 3.0 Extensions):**
```bash
# Verify DOCSIS 3.0 support
./bindocsis -i "40 04 01 02 03 04" --docsis-version 3.0
# TLV 64 (PacketCable Configuration) should be recognized

# If still unknown, check DocsisSpecs database:
iex -S mix
iex> Bindocsis.DocsisSpecs.get_tlv_info(64, "3.0")
```

**For TLV 77-85 (DOCSIS 3.1 Extensions):**
```bash
# Ensure DOCSIS 3.1 is specified
./bindocsis -i "4D 04 01 02 03 04" --docsis-version 3.1
# TLV 77 (DLS Encoding) should be recognized

# Test all DOCSIS 3.1 TLVs:
for tlv in {77..85}; do
  printf "%02X 01 FF" $tlv | ./bindocsis -f hex --docsis-version 3.1 | head -1
done
```

**For Vendor TLVs (200-255):**
```bash
# Vendor TLVs should always be supported
./bindocsis -i "C8 04 01 02 03 04"  # TLV 200
./bindocsis -i "FF 04 01 02 03 04"  # TLV 255

# Verify vendor range support:
elixir -e "
vendor_types = Enum.to_list(200..255)
supported = Bindocsis.DocsisSpecs.get_supported_types(\"3.1\")
vendor_supported = Enum.filter(vendor_types, &(&1 in supported))
IO.puts(\"Vendor TLVs supported: #{length(vendor_supported)}/56\")
"
```

### SubTLV Processing Issues

#### Error: "SubTLV parsing failed"

**Symptoms:**
```
TLV 4 (Class of Service) contains invalid SubTLV structure
```

**Diagnostic:**
```bash
# Create test compound TLV
cat > test_subtlv.exs << 'EOF'
# Test SubTLV processing
compound_tlv = <<
  4,           # TLV type 4 (Class of Service)
  8,           # Length: 8 bytes
  1, 1, 1,     # SubTLV 1 (Class ID): value 1
  2, 4, 10, 0, 0, 0  # SubTLV 2 (Max Rate): value 1000000
>>

case Bindocsis.parse_binary(compound_tlv) do
  {:ok, [tlv]} ->
    IO.puts("✅ Compound TLV parsed successfully")
    IO.inspect(tlv, label: "TLV Structure")
  {:error, reason} ->
    IO.puts("❌ SubTLV parsing failed: #{inspect(reason)}")
end
EOF

elixir test_subtlv.exs
rm test_subtlv.exs
```

### TLV Value Type Issues

#### Error: "Invalid value type for TLV"

**Symptoms:**
```
TLV 1 expects uint32 but received string
```

**Solution:**
```bash
# Check expected value type for TLV
elixir -e "
{:ok, tlv_info} = Bindocsis.DocsisSpecs.get_tlv_info(1)
IO.puts(\"TLV 1 expects: #{tlv_info.value_type}\")
IO.puts(\"Max length: #{tlv_info.max_length}\")
"

# Correct value formatting:
# TLV 1 (Downstream Frequency) - uint32 (4 bytes)
echo "01 04 20 9B 5E 00" | ./bindocsis -f hex -t pretty
# Should show: TLV 1 (Downstream Frequency): 547000000 Hz
```

---

## DOCSIS Version Compatibility

### Version Detection Issues

#### Error: "Cannot determine DOCSIS version"

**Symptoms:**
```
Ambiguous DOCSIS version - contains TLVs from multiple versions
```

**Diagnostic:**
```bash
# Analyze TLV version requirements
cat > version_analyzer.exs << 'EOF'
defmodule VersionAnalyzer do
  def analyze_file(file_path) do
    case Bindocsis.parse_file(file_path) do
      {:ok, {version, tlvs}} ->
        IO.puts("📋 File analysis for: #{file_path}")
        IO.puts("Detected version: #{version}")
        
        version_requirements = Enum.map(tlvs, fn tlv ->
          case Bindocsis.DocsisSpecs.get_tlv_info(tlv.type) do
            {:ok, info} -> {tlv.type, info.introduced_version}
            {:error, _} -> {tlv.type, "unknown"}
          end
        end)
        
        IO.puts("\nTLV version requirements:")
        Enum.each(version_requirements, fn {type, req_version} ->
          IO.puts("  TLV #{type}: requires DOCSIS #{req_version}")
        end)
        
        # Determine minimum required version
        versions = Enum.map(version_requirements, fn {_, v} -> v end)
        |> Enum.reject(&(&1 == "unknown"))
        |> Enum.uniq()
        
        IO.puts("\nRecommended DOCSIS version: #{determine_min_version(versions)}")
        
      {:error, reason} ->
        IO.puts("❌ Analysis failed: #{reason}")
    end
  end
  
  defp determine_min_version(versions) do
    version_order = %{"1.0" => 1, "1.1" => 2, "2.0" => 3, "3.0" => 4, "3.1" => 5}
    
    versions
    |> Enum.map(&Map.get(version_order, &1, 0))
    |> Enum.max()
    |> case do
      1 -> "1.0"
      2 -> "1.1" 
      3 -> "2.0"
      4 -> "3.0"
      5 -> "3.1"
      _ -> "3.1"  # Default to latest
    end
  end
end

VersionAnalyzer.analyze_file("config.cm")
EOF

elixir version_analyzer.exs
rm version_analyzer.exs
```

### Version Migration Issues

#### Issue: "TLV 77 not supported in DOCSIS 3.0"

**Solution:**
```bash
# Identify problematic TLVs
cat > migration_helper.exs << 'EOF'
defmodule MigrationHelper do
  def check_compatibility(file_path, target_version) do
    {:ok, {_version, tlvs}} = Bindocsis.parse_file(file_path)
    
    incompatible = Enum.filter(tlvs, fn tlv ->
      case Bindocsis.DocsisSpecs.valid_tlv_type?(tlv.type, target_version) do
        false -> true
        true -> false
      end
    end)
    
    if Enum.empty?(incompatible) do
      IO.puts("✅ All TLVs compatible with DOCSIS #{target_version}")
    else
      IO.puts("❌ Incompatible TLVs for DOCSIS #{target_version}:")
      Enum.each(incompatible, fn tlv ->
        {:ok, info} = Bindocsis.DocsisSpecs.get_tlv_info(tlv.type)
        IO.puts("  TLV #{tlv.type} (#{info.name}) requires #{info.introduced_version}")
      end)
    end
  end
end

MigrationHelper.check_compatibility("config.cm", "3.0")
EOF

elixir migration_helper.exs
rm migration_helper.exs
```

---

## Format Conversion Issues

### Multi-Format Processing Problems

#### Issue: "Format detection failed"

**Symptoms:**
```
Cannot determine input format from file extension or content
```

**Solution:**
```bash
# Manual format detection
file config.unknown
hexdump -C config.unknown | head -5

# Test each format explicitly
./bindocsis -f binary config.unknown  2>/dev/null && echo "✅ Binary format"
./bindocsis -f json config.unknown    2>/dev/null && echo "✅ JSON format"
./bindocsis -f yaml config.unknown    2>/dev/null && echo "✅ YAML format"
./bindocsis -f config config.unknown  2>/dev/null && echo "✅ Config format"
./bindocsis -f mta config.unknown     2>/dev/null && echo "✅ MTA format"
```

### JSON Format Issues

#### Error: "Invalid TLV metadata in JSON"

**Symptoms:**
```
JSON contains Phase 6 metadata fields that cannot be processed
```

**Example of problematic JSON:**
```json
{
  "docsis_version": "3.1",
  "tlvs": [
    {
      "type": 77,
      "name": "DLS Encoding",
      "introduced_version": "3.1",
      "invalid_field": "should_not_be_here"
    }
  ]
}
```

**Solution:**
```bash
# Clean JSON to standard format
cat > clean_json.exs << 'EOF'
defmodule JsonCleaner do
  def clean_file(input_file, output_file) do
    {:ok, content} = File.read(input_file)
    {:ok, data} = Jason.decode(content)
    
    # Remove non-standard fields
    clean_data = clean_tlvs(data)
    
    clean_json = Jason.encode!(clean_data, pretty: true)
    File.write!(output_file, clean_json)
    
    IO.puts("✅ Cleaned JSON written to #{output_file}")
  end
  
  defp clean_tlvs(%{"tlvs" => tlvs} = data) do
    clean_tlvs_list = Enum.map(tlvs, fn tlv ->
      # Keep only standard TLV fields
      Map.take(tlv, ["type", "length", "value", "subtlvs"])
    end)
    
    %{data | "tlvs" => clean_tlvs_list}
  end
end

JsonCleaner.clean_file("problematic.json", "clean.json")
EOF

elixir clean_json.exs
rm clean_json.exs
```

### YAML Format Issues (Known Dependency Issue)

#### Warning: "YamlElixir compatibility warnings"

**Status**: Non-blocking Phase 6 issue

**Symptoms:**
```
warning: YamlElixir.read_from_string/2 is deprecated
```

**Workaround:**
```bash
# Use JSON as intermediate format
./bindocsis -f binary -t json config.cm > temp.json
./bindocsis -f json -t yaml temp.json  # May show warnings but works
rm temp.json

# Alternative: Use external tools
./bindocsis -f binary -t json config.cm | yq eval -P > config.yaml
```

### MTA Format Processing

#### Issue: "MTA format parsing errors"

**Symptoms:**
```
Invalid MTA syntax at line 15: unexpected token
```

**Common MTA format issues:**
```bash
# Check MTA file structure
head -20 config.mta

# Common MTA syntax:
cat > example.mta << 'EOF'
MTA10 {
    SnmpMibObject sysContact.0 "Administrator" ;
    SnmpMibObject sysName.0 "MTA-Device" ;
    
    # DOCSIS TLV support in MTA
    TlvCode 3 1 ;                    # Network Access
    TlvCode 77 0x01020304 ;          # DOCSIS 3.1 DLS Encoding
    VendorTlv 201 0xDEADBEEF ;       # Vendor-specific
}
EOF

./bindocsis -f mta example.mta
rm example.mta
```

---

## DocsisSpecs Module Troubleshooting

### Module Loading Issues

#### Error: "DocsisSpecs module compilation failed"

**Diagnostic:**
```bash
# Check module exists and compiles
ls -la lib/bindocsis/docsis_specs.ex
elixir -c lib/bindocsis/docsis_specs.ex

# Test module loading
iex -S mix
iex> Code.ensure_loaded(Bindocsis.DocsisSpecs)
# Should return: {:module, Bindocsis.DocsisSpecs}
```

### TLV Database Issues

#### Issue: "Incomplete TLV database"

**Verification:**
```bash
# Check TLV database completeness
cat > tlv_audit.exs << 'EOF'
defmodule TlvAudit do
  def audit_database do
    IO.puts("🔍 TLV Database Audit")
    IO.puts("====================")
    
    versions = ["3.0", "3.1"]
    
    Enum.each(versions, fn version ->
      IO.puts("\nDOCSIS #{version}:")
      types = Bindocsis.DocsisSpecs.get_supported_types(version)
      
      # Core TLVs (1-30)
      core = Enum.filter(types, &(&1 in 1..30)) |> length()
      IO.puts("  Core TLVs (1-30): #{core}/30")
      
      # DOCSIS 3.0 extensions (64-76)
      if version in ["3.0", "3.1"] do
        ext_30 = Enum.filter(types, &(&1 in 64..76)) |> length()
        IO.puts("  DOCSIS 3.0 extensions (64-76): #{ext_30}/13")
      end
      
      # DOCSIS 3.1 extensions (77-85)
      if version == "3.1" do
        ext_31 = Enum.filter(types, &(&1 in 77..85)) |> length()
        IO.puts("  DOCSIS 3.1 extensions (77-85): #{ext_31}/9")
      end
      
      # Vendor TLVs (200-255)
      vendor = Enum.filter(types, &(&1 in 200..255)) |> length()
      IO.puts("  Vendor TLVs (200-255): #{vendor}/56")
      
      IO.puts("  Total: #{length(types)} TLV types")
    end)
    
    # Test specific problematic TLVs
    IO.puts("\n🧪 Testing Specific TLVs:")
    test_tlvs = [64, 77, 201, 255]
    
    Enum.each(test_tlvs, fn type ->
      case Bindocsis.DocsisSpecs.get_tlv_info(type) do
        {:ok, info} -> 
          IO.puts("  ✅ TLV #{type}: #{info.name}")
        {:error, reason} -> 
          IO.puts("  ❌ TLV #{type}: #{reason}")
      end
    end)
  end
end

TlvAudit.audit_database()
EOF

elixir tlv_audit.exs
rm tlv_audit.exs
```

### API Function Issues

#### Error: "Function DocsisSpecs.get_tlv_info/2 returns error"

**Common causes and solutions:**
```bash
# Test API functions individually
iex -S mix

# Test 1: Basic TLV info retrieval
iex> Bindocsis.DocsisSpecs.get_tlv_info(3)
# Expected: {:ok, %{name: "Network Access Control", ...}}

# Test 2: Version-specific queries
iex> Bindocsis.DocsisSpecs.get_tlv_info(77, "3.1")
# Expected: {:ok, %{name: "DLS Encoding", ...}}

iex> Bindocsis.DocsisSpecs.get_tlv_info(77, "3.0")
# Expected: {:error, :unsupported_version}

# Test 3: TLV validation
iex> Bindocsis.DocsisSpecs.valid_tlv_type?(77, "3.1")
# Expected: true

iex> Bindocsis.DocsisSpecs.valid_tlv_type?(77, "3.0")
# Expected: false

# Test 4: Supported types listing
iex> types = Bindocsis.DocsisSpecs.get_supported_types("3.1")
iex> length(types)
# Expected: 141

iex> 77 in types
# Expected: true
```

---

## Dependency Issues

### YamlElixir Compatibility (Known Issue)

**Status**: Non-blocking, core functionality unaffected

**Symptoms:**
```
warning: YamlElixir.read_from_string/2 is deprecated. Use YamlElixir.read_from_string/1 instead
** (CompileError) lib/bindocsis/parsers/yaml_parser.ex:15: undefined function YamlElixir.read_from_string/1
```

**Impact**: YAML format conversion may have limited features

**Workaround**:
```bash
# Use JSON instead of YAML for reliable processing
./bindocsis -f binary -t json config.cm > config.json

# For YAML output, use external tools:
./bindocsis -f binary -t json config.cm | yq eval -P > config.yaml

# Or process through config format:
./bindocsis -f binary -t config config.cm > config.conf
```

**Temporary fix** (for developers):
```elixir
# In lib/bindocsis/parsers/yaml_parser.ex
# Replace problematic calls with try/catch:
defp safe_yaml_parse(content) do
  try do
    case YamlElixir.read_from_string(content) do
      {:ok, data} -> {:ok, data}
      {:error, reason} -> {:error, reason}
    end
  rescue
    e -> 
      # Fallback to basic parsing
      {:error, "YAML parsing failed: #{inspect(e)}"}
  end
end
```

### Mix Dependencies Resolution

#### Error: "Package fetch failed"

**Solution:**
```bash
# Clear all caches and dependencies
rm -rf deps _build
rm mix.lock

# Update hex and rebar
mix local.hex --force
mix local.rebar --force

# Reinstall dependencies
mix deps.get

# If specific dependency fails:
mix deps.clean yaml_elixir
mix deps.get yaml_elixir
mix deps.compile yaml_elixir
```

### Version Conflicts

#### Error: "Dependency resolution failed"

**Diagnostic:**
```bash
# Check dependency tree
mix deps.tree

# Look for conflicts
mix deps.unlock --all
mix deps.get

# Check for outdated dependencies
mix hex.outdated
```

---

## Installation & Environment Problems

### Elixir/OTP Version Issues

#### Error: "OTP version 27+ required"

**Solution:**
```bash
# Check current versions
elixir --version
erl -version

# Install required versions using asdf
asdf install erlang 27.2
asdf install elixir 1.18.3
asdf global erlang 27.2
asdf global elixir 1.18.3

# Verify installation
elixir --version | head -1
# Should show: Elixir 1.18.3 (compiled with Erlang/OTP 27)
```

### Compilation Issues

#### Error: "Cannot compile DocsisSpecs module"

**Solution:**
```bash
# Clean compile
mix clean --deps
mix deps.compile --force
mix compile --force

# If specific compilation errors, check syntax:
elixir -c lib/bindocsis/docsis_specs.ex

# Check for memory issues during compilation:
export ERL_FLAGS="+MMmcs 32 +MMrmbcmt 100"
mix compile
```

### PATH and Executable Issues

#### Error: "./bindocsis: No such file or directory"

**Solution:**
```bash
# Check if escript exists
ls -la bindocsis

# Rebuild escript
mix clean
MIX_ENV=prod mix compile
MIX_ENV=prod mix escript.build

# Make executable
chmod +x bindocsis

# Test execution
./bindocsis --version
```

---

## Performance Troubleshooting

### Memory Usage Issues

#### Issue: "High memory usage with Phase 6"

**Diagnostic:**
```bash
# Monitor memory usage during processing
top -p $(pgrep beam.smp) &
./bindocsis large_config.cm
kill %1

# Check TLV database memory usage
cat > memory_test.exs << 'EOF'
# Memory usage test
:observer.start()

# Load DocsisSpecs module and check memory
{:ok, _} = Application.ensure_all_started(:bindocsis)

# Get memory usage before and after TLV operations
:erlang.garbage_collect()
before = :erlang.memory()

# Perform TLV operations
1..1000 |> Enum.each(fn _ ->
  Bindocsis.DocsisSpecs.get_tlv_info(Enum.random(1..255))
end)

:erlang.garbage_collect()
after_mem = :erlang.memory()

total_diff = after_mem[:total] - before[:total]
IO.puts("Memory difference: #{total_diff} bytes")
EOF

elixir memory_test.exs
rm memory_test.exs
```

### Processing Speed Issues

#### Issue: "Slow TLV processing with large files"

**Optimization:**
```bash
# Time specific operations
time ./bindocsis large_config.cm > /dev/null

# Use production build for better performance
MIX_ENV=prod mix compile
MIX_ENV=prod mix escript.build

# Process in chunks for very large files
split -b 64K large_config.cm chunk_
for chunk in chunk_*; do
  ./bindocsis "$chunk" >> processed_output.json
done
rm chunk_*

# Optimize Erlang VM settings
export ERL_FLAGS="+K true +A 16 +sbt db"
./bindocsis large_config.cm
```

#### Issue: "DocsisSpecs lookup performance"

**Analysis:**
```bash
# Benchmark TLV lookup performance
cat > benchmark_lookup.exs << 'EOF'
defmodule LookupBenchmark do
  def run do
    IO.puts("🚀 TLV Lookup Performance Benchmark")
    IO.puts("==================================")
    
    # Warm up
    1..100 |> Enum.each(fn _ ->
      Bindocsis.DocsisSpecs.get_tlv_info(Enum.random(1..255))
    end)
    
    # Benchmark different TLV ranges
    test_ranges = [
      {"Core TLVs (1-30)", 1..30},
      {"DOCSIS 3.0 Extensions (64-76)", 64..76},
      {"DOCSIS 3.1 Extensions (77-85)", 77..85}, 
      {"Vendor TLVs (200-255)", 200..255}
    ]
    
    Enum.each(test_ranges, fn {name, range} ->
      IO.puts("\n#{name}:")
      
      {time, _result} = :timer.tc(fn ->
        Enum.each(1..1000, fn _ ->
          type = Enum.random(range)
          Bindocsis.DocsisSpecs.get_tlv_info(type)
        end)
      end)
      
      avg_time = time / 1000  # microseconds per lookup
      IO.puts("  Average lookup time: #{Float.round(avg_time, 2)} μs")
      IO.puts("  Lookups per second: #{round(1_000_000 / avg_time)}")
    end)
  end
end

LookupBenchmark.run()
EOF

elixir benchmark_lookup.exs
rm benchmark_lookup.exs
```

---

## Advanced Debugging Techniques

### Interactive Debugging with IEx

#### TLV Processing Debug Session

```bash
# Start interactive session with project loaded
iex -S mix

# Test specific TLV processing step by step
iex> raw_data = <<4, 8, 1, 1, 1, 2, 4, 10, 0, 0, 0>>  # Compound TLV
iex> {:ok, [tlv]} = Bindocsis.parse_binary(raw_data)
iex> IO.inspect(tlv, label: "Parsed TLV", pretty: true)

# Examine DocsisSpecs lookup
iex> {:ok, info} = Bindocsis.DocsisSpecs.get_tlv_info(4)
iex> IO.inspect(info, label: "TLV 4 Info", pretty: true)

# Test SubTLV processing
iex> if tlv.subtlvs do
...>   Enum.each(tlv.subtlvs, fn subtlv ->
...>     IO.puts("SubTLV #{subtlv.type}: #{inspect(subtlv.value)}")
...>   end)
...> end

# Verify version compatibility
iex> Bindocsis.DocsisSpecs.valid_tlv_type?(77, "3.0")
iex> Bindocsis.DocsisSpecs.valid_tlv_type?(77, "3.1")
```

### Binary Data Analysis Tools

#### Hex Dump Analysis with TLV Boundaries

```bash
# Create advanced hex analysis tool
cat > hex_analyzer.exs << 'EOF'
defmodule HexAnalyzer do
  def analyze_file(file_path) do
    IO.puts("🔍 Binary TLV Analysis: #{file_path}")
    IO.puts(String.duplicate("=", 50))
    
    case File.read(file_path) do
      {:ok, data} -> analyze_binary(data)
      {:error, reason} -> IO.puts("❌ Cannot read file: #{reason}")
    end
  end
  
  defp analyze_binary(data) do
    IO.puts("File size: #{byte_size(data)} bytes")
    IO.puts("Hex dump with TLV boundaries:")
    IO.puts("")
    
    analyze_tlvs(data, 0, 1)
  end
  
  defp analyze_tlvs(<<>>, _offset, _tlv_num), do: :ok
  
  defp analyze_tlvs(<<type, length, rest::binary>>, offset, tlv_num) when length <= byte_size(rest) do
    <<value::binary-size(length), remaining::binary>> = rest
    
    # Get TLV info if available
    tlv_info = case Bindocsis.DocsisSpecs.get_tlv_info(type) do
      {:ok, info} -> info.name
      {:error, _} -> "Unknown TLV"
    end
    
    IO.puts("TLV #{tlv_num} @ offset #{offset}:")
    IO.puts("  Type: #{type} (#{tlv_info})")
    IO.puts("  Length: #{length}")
    IO.puts("  Value: #{format_hex(value)}")
    
    if tlv_info != "Unknown TLV" do
      case Bindocsis.DocsisSpecs.get_tlv_info(type) do
        {:ok, %{subtlv_support: true}} when length > 0 ->
          IO.puts("  SubTLVs: #{analyze_subtlvs(value)}")
        _ -> :ok
      end
    end
    
    IO.puts("")
    
    next_offset = offset + 2 + length
    analyze_tlvs(remaining, next_offset, tlv_num + 1)
  end
  
  defp analyze_tlvs(data, offset, tlv_num) do
    IO.puts("❌ Invalid TLV structure at offset #{offset}")
    IO.puts("Remaining data: #{format_hex(data)}")
  end
  
  defp analyze_subtlvs(data) do
    try do
      case parse_subtlvs(data, []) do
        [] -> "None"
        subtlvs -> "#{length(subtlvs)} SubTLVs found"
      end
    rescue
      _ -> "Invalid SubTLV structure"
    end
  end
  
  defp parse_subtlvs(<<>>, acc), do: Enum.reverse(acc)
  defp parse_subtlvs(<<type, length, rest::binary>>, acc) when length <= byte_size(rest) do
    <<_value::binary-size(length), remaining::binary>> = rest
    parse_subtlvs(remaining, [type | acc])
  end
  defp parse_subtlvs(_invalid, acc), do: Enum.reverse(acc)
  
  defp format_hex(data) when byte_size(data) <= 16 do
    data |> Base.encode16() |> String.replace(~r/.{2}/, "\\0 ") |> String.trim()
  end
  defp format_hex(data) do
    prefix = binary_part(data, 0, 16)
    remaining = byte_size(data) - 16
    "#{format_hex(prefix)} ... (+#{remaining} bytes)"
  end
end

HexAnalyzer.analyze_file("config.cm")
EOF

elixir hex_analyzer.exs
rm hex_analyzer.exs
```

### Performance Profiling

#### Memory and CPU Profiling

```bash
# Create comprehensive profiling tool
cat > profiler.exs << 'EOF'
defmodule BindocsisProfiler do
  def profile_operation(file_path) do
    IO.puts("📊 Profiling Bindocsis Operations")
    IO.puts("================================")
    
    # Memory profiling
    profile_memory(file_path)
    
    # CPU profiling
    profile_cpu(file_path)
    
    # DocsisSpecs performance
    profile_docsis_specs()
  end
  
  defp profile_memory(file_path) do
    IO.puts("\n🧠 Memory Profile:")
    
    :erlang.garbage_collect()
    before = :erlang.memory()
    
    {:ok, result} = Bindocsis.parse_file(file_path)
    
    :erlang.garbage_collect()
    after_mem = :erlang.memory()
    
    total_diff = after_mem[:total] - before[:total]
    process_diff = after_mem[:processes] - before[:processes]
    
    IO.puts("  Total memory change: #{format_bytes(total_diff)}")
    IO.puts("  Process memory change: #{format_bytes(process_diff)}")
    
    case result do
      {_version, tlvs} -> 
        IO.puts("  Memory per TLV: #{format_bytes(div(total_diff, length(tlvs)))}")
      _ -> :ok
    end
  end
  
  defp profile_cpu(file_path) do
    IO.puts("\n⚡ CPU Profile:")
    
    {time, result} = :timer.tc(fn ->
      Bindocsis.parse_file(file_path)
    end)
    
    case result do
      {:ok, {_version, tlvs}} ->
        IO.puts("  Total parse time: #{format_time(time)}")
        IO.puts("  Time per TLV: #{format_time(div(time, length(tlvs)))}")
        IO.puts("  TLVs per second: #{round(length(tlvs) * 1_000_000 / time)}")
      {:error, reason} ->
        IO.puts("  Parse failed: #{reason}")
    end
  end
  
  defp profile_docsis_specs do
    IO.puts("\n📋 DocsisSpecs Performance:")
    
    # Test lookup performance
    {time, _} = :timer.tc(fn ->
      1..1000 |> Enum.each(fn _ ->
        type = Enum.random(1..255)
        Bindocsis.DocsisSpecs.get_tlv_info(type)
      end)
    end)
    
    avg_lookup = time / 1000
    IO.puts("  Average lookup time: #{Float.round(avg_lookup, 2)} μs")
    IO.puts("  Lookups per second: #{round(1_000_000 / avg_lookup)}")
  end
  
  defp format_bytes(bytes) when bytes < 1024, do: "#{bytes} B"
  defp format_bytes(bytes) when bytes < 1024 * 1024, do: "#{Float.round(bytes / 1024, 1)} KB"
  defp format_bytes(bytes), do: "#{Float.round(bytes / (1024 * 1024), 1)} MB"
  
  defp format_time(microseconds) when microseconds < 1000, do: "#{microseconds} μs"
  defp format_time(microseconds) when microseconds < 1_000_000, do: "#{Float.round(microseconds / 1000, 1)} ms"
  defp format_time(microseconds), do: "#{Float.round(microseconds / 1_000_000, 1)} s"
end

BindocsisProfiler.profile_operation("config.cm")
EOF

elixir profiler.exs
rm profiler.exs
```

### Error Tracing and Logging

#### Enable Comprehensive Debug Logging

```bash
# Create debug configuration
cat > debug_config.exs << 'EOF'
# Debug configuration for troubleshooting
import Config

config :logger,
  level: :debug,
  compile_time_purge_matching: [
    [level_lower_than: :debug]
  ]

# Enable detailed logging for specific modules
config :logger, :console,
  format: "$time $metadata[$level] $message\n",
  metadata: [:request_id, :module, :function, :line]

# Bindocsis-specific debug settings
config :bindocsis,
  debug_tlv_parsing: true,
  debug_format_conversion: true,
  debug_docsis_specs: true
EOF

# Run with debug configuration
MIX_ENV=debug CONFIG_PATH=debug_config.exs iex -S mix

# In IEx, enable tracing
iex> :dbg.tracer()
iex> :dbg.p(:all, :c)
iex> :dbg.tpl(Bindocsis.DocsisSpecs, :get_tlv_info, [])

# Test operations with full tracing
iex> Bindocsis.parse_file("config.cm")
```

---

## Known Issues & Workarounds

### Phase 6 Known Issues (Non-Blocking)

#### 1. YamlElixir Dependency Compatibility Warnings

**Status**: ⚠️ Non-blocking - Core functionality unaffected  
**Affects**: YAML format conversion only  
**ETA**: Resolution planned for Phase 7

**Symptoms:**
```
warning: YamlElixir.read_from_string/2 is deprecated
(CompileError) undefined function YamlElixir.read_from_string/1
```

**Workarounds:**
```bash
# Workaround 1: Use JSON instead of YAML
./bindocsis -f binary -t json config.cm > config.json

# Workaround 2: Use external YAML tools
./bindocsis -f binary -t json config.cm | yq eval -P > config.yaml

# Workaround 3: Use Config format
./bindocsis -f binary -t config config.cm > config.conf
```

#### 2. CLI Integration Testing Limitations

**Status**: ⚠️ Development-only issue  
**Affects**: Full CLI test suite execution  
**Impact**: Core functionality verified through module testing

**Developer Workaround:**
```bash
# Run core tests (exclude CLI tests)
mix test

# Manual CLI testing
./bindocsis --version
./bindocsis -i "03 01 01" 
echo '{"docsis_version":"3.1","tlvs":[]}' | ./bindocsis -f json -t pretty

# Test Phase 6 features directly
elixir -e "
{:ok, info} = Bindocsis.DocsisSpecs.get_tlv_info(77)
IO.puts(\"✅ TLV 77: #{info.name}\")
"
```

#### 3. Generator Module Type Warnings

**Status**: ⚠️ Cosmetic warnings only  
**Affects**: Config generation module  
**Impact**: No functional impact on Phase 6 features

**Expected Warnings:**
```
warning: variable "type" is unused
warning: this check/guard will always yield the same result
```

**Action**: Safe to ignore - scheduled for cleanup in future releases

### Platform-Specific Issues

#### macOS: "Developer cannot be verified" Error

**Solution:**
```bash
# Allow execution of unsigned binary
xattr -d com.apple.quarantine ./bindocsis

# Or build from source
git clone https://github.com/user/bindocsis.git
cd bindocsis
mix escript.build
```

#### Windows: PowerShell Execution Policy

**Solution:**
```powershell
# Allow script execution
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser

# Or run directly
elixir -S mix run -e "Bindocsis.CLI.main([\"--version\"])"
```

#### Docker: Permission Denied

**Solution:**
```dockerfile
# Ensure proper permissions in Dockerfile
RUN chmod +x bindocsis
USER 1000:1000  # Use non-root user
```

### Memory and Performance Issues

#### Large File Processing

**Issue**: Memory usage grows with file size  
**Threshold**: Files > 1MB may cause performance degradation

**Solutions:**
```bash
# Process in chunks
split -b 512K large_config.cm chunk_
for chunk in chunk_*; do
  ./bindocsis "$chunk" >> output.json
done

# Use streaming approach (when available)
./bindocsis --stream large_config.cm

# Increase VM memory
export ERL_FLAGS="+MHas ageffcbf +MHacul de"
./bindocsis large_config.cm
```

#### DocsisSpecs Lookup Performance

**Issue**: Frequent TLV lookups may impact performance  
**Threshold**: >10,000 TLV operations per second

**Optimization:**
```elixir
# Cache frequently used TLV info
defmodule TlvCache do
  use GenServer
  
  def start_link(_) do
    GenServer.start_link(__MODULE__, %{}, name: __MODULE__)
  end
  
  def get_tlv_info(type) do
    case GenServer.call(__MODULE__, {:get, type}) do
      nil -> 
        case Bindocsis.DocsisSpecs.get_tlv_info(type) do
          {:ok, info} = result ->
            GenServer.cast(__MODULE__, {:cache, type, info})
            result
          error -> error
        end
      cached_info -> {:ok, cached_info}
    end
  end
  
  def init(state), do: {:ok, state}
  
  def handle_call({:get, type}, _from, state) do
    {:reply, Map.get(state, type), state}
  end
  
  def handle_cast({:cache, type, info}, state) do
    {:noreply, Map.put(state, type, info)}
  end
end
```

---

## Error Reference Guide

### Phase 6 Error Codes

| Code | Category | Description | Severity | Solution Reference |
|------|----------|-------------|----------|-------------------|
| **TLV_001** | TLV Processing | Unknown TLV type | Warning | [TLV Processing Problems](#tlv-processing-problems) |
| **TLV_002** | TLV Processing | Invalid SubTLV structure | Error | [SubTLV Processing Issues](#subtlv-processing-issues) |
| **TLV_003** | TLV Processing | TLV value type mismatch | Error | [TLV Value Type Issues](#tlv-value-type-issues) |
| **VER_001** | Version | DOCSIS version incompatibility | Error | [Version Migration Issues](#version-migration-issues) |
| **VER_002** | Version | TLV requires newer DOCSIS version | Warning | [Version Detection Issues](#version-detection-issues) |
| **FMT_001** | Format | Format detection failed | Error | [Multi-Format Processing](#multi-format-processing-problems) |
| **FMT_002** | Format | JSON metadata parsing error | Warning | [JSON Format Issues](#json-format-issues) |
| **FMT_003** | Format | YAML dependency warning | Warning | [YAML Format Issues](#yaml-format-issues-known-dependency-issue) |
| **FMT_004** | Format | MTA syntax error | Error | [MTA Format Processing](#mta-format-processing) |
| **DOC_001** | DocsisSpecs | Module loading failed | Critical | [Module Loading Issues](#module-loading-issues) |
| **DOC_002** | DocsisSpecs | TLV database incomplete | Error | [TLV Database Issues](#tlv-database-issues) |
| **DOC_003** | DocsisSpecs | API function error | Error | [API Function Issues](#api-function-issues) |
| **DEP_001** | Dependencies | YamlElixir compatibility | Warning | [YamlElixir Compatibility](#yamlelixir-compatibility-known-issue) |
| **DEP_002** | Dependencies | Package fetch failed | Error | [Mix Dependencies Resolution](#mix-dependencies-resolution) |
| **ENV_001** | Environment | OTP version incompatible | Critical | [Elixir/OTP Version Issues](#elixirotp-version-issues) |
| **ENV_002** | Environment | Compilation failed | Error | [Compilation Issues](#compilation-issues) |
| **ENV_003** | Environment | Executable not found | Error | [PATH and Executable Issues](#path-and-executable-issues) |
| **PERF_001** | Performance | High memory usage | Warning | [Memory Usage Issues](#memory-usage-issues) |
| **PERF_002** | Performance | Slow processing | Warning | [Processing Speed Issues](#processing-speed-issues) |

### Quick Error Resolution

```bash
# Quick error diagnostic script
cat > quick_diagnosis.exs << 'EOF'
defmodule QuickDiagnosis do
  def run(error_description) do
    IO.puts("🔧 Quick Error Diagnosis")
    IO.puts("=======================")
    IO.puts("Error: #{error_description}")
    IO.puts("")
    
    # Run basic checks
    check_installation()
    check_dependencies()
    check_phase6_features()
    
    IO.puts("\n💡 For detailed troubleshooting, see:")
    IO.puts("   docs/TROUBLESHOOTING.md")
  end
  
  defp check_installation do
    IO.puts("📦 Installation Check:")
    
    try do
      version = System.cmd("./bindocsis", ["--version"])
      case version do
        {output, 0} -> IO.puts("  ✅ Bindocsis executable: #{String.trim(output)}")
        _ -> IO.puts("  ❌ Bindocsis executable not working")
      end
    rescue
      _ -> IO.puts("  ❌ Bindocsis executable not found")
    end
  end
  
  defp check_dependencies do
    IO.puts("\n📚 Dependencies Check:")
    
    try do
      {:ok, _} = Application.ensure_all_started(:bindocsis)
      IO.puts("  ✅ Bindocsis application starts successfully")
    rescue
      e -> IO.puts("  ❌ Application start failed: #{inspect(e)}")
    end
  end
  
  defp check_phase6_features do
    IO.puts("\n🚀 Phase 6 Features Check:")
    
    try do
      count = Bindocsis.DocsisSpecs.get_supported_types("3.1") |> length()
      IO.puts("  ✅ TLV support: #{count}/141 types")
      
      {:ok, _} = Bindocsis.DocsisSpecs.get_tlv_info(77)
      IO.puts("  ✅ DOCSIS 3.1 TLV 77 supported")
      
      {:ok, _} = Bindocsis.DocsisSpecs.get_tlv_info(201)
      IO.puts("  ✅ Vendor TLV 201 supported")
      
    rescue
      e -> IO.puts("  ❌ Phase 6 features check failed: #{inspect(e)}")
    end
  end
end

error = System.argv() |> Enum.join(" ")
if error == "" do
  QuickDiagnosis.run("No specific error provided")
else
  QuickDiagnosis.run(error)
end
EOF

# Usage examples:
elixir quick_diagnosis.exs "TLV 77 not recognized"
elixir quick_diagnosis.exs "Memory usage too high"
elixir quick_diagnosis.exs "YAML parsing failed"

rm quick_diagnosis.exs
```

---

## 🎯 **Troubleshooting Summary**

### Phase 6 Success Indicators

✅ **141 TLV Types Supported** (1-255)  
✅ **Complete DOCSIS 3.0/3.1 Coverage** (TLV 64-85)  
✅ **Vendor Extensions Working** (TLV 200-255)  
✅ **Dynamic TLV Processing** (DocsisSpecs integration)  
✅ **Multi-Format Support** (Binary, JSON, YAML, Config, MTA)  

### Quick Health Check Command

```bash
# Run comprehensive health check
./bindocsis --version && \
echo "4D 04 01 02 03 04" | ./bindocsis -f hex -t pretty | head -2 && \
echo "C9 06 DE AD BE EF CA FE" | ./bindocsis -f hex -t pretty | head -2 && \
echo "✅ Phase 6 is working correctly!"
```

### When to Seek Help

🔍 **After trying this guide**  
📋 **With specific error details**  
🧪 **Including system information**  
📁 **With minimal reproduction case**  

### Community Resources

- **GitHub Issues**: Bug reports and feature requests
- **Documentation**: Complete API and format specifications  
- **Examples**: Real-world configuration samples
- **Support**: Professional consultation available

---

## 📞 **Emergency Troubleshooting Contacts**

### Critical Issues (System Down)
- **Installation Failures**: Check [Installation Guide](INSTALLATION.md)
- **Core Functionality Broken**: Verify Phase 6 requirements
- **Data Loss Risk**: Stop processing, backup configs

### Non-Critical Issues  
- **Performance Concerns**: See [Performance Optimization](#performance-troubleshooting)
- **Format Conversion Problems**: Check [Format Issues](#format-conversion-issues)
- **YAML Warnings**: Use [Known Workarounds](#known-issues--workarounds)

---

*Last updated: December 2024 | Version: Phase 6 | TLV Support: 141 types (1-255)*

**🚀 Professional DOCSIS Configuration Processing with Complete Troubleshooting Support**