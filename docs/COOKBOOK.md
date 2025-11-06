# Bindocsis Cookbook

**Version:** 0.1.0  
**Last Updated:** 2025-11-06

Practical recipes and code examples for working with DOCSIS configurations using Bindocsis.

---

## Table of Contents

- [Basic Operations](#basic-operations)
- [Format Conversion](#format-conversion)
- [Validation](#validation)
- [Error Handling](#error-handling)
- [Configuration Generation](#configuration-generation)
- [Advanced Operations](#advanced-operations)
- [Troubleshooting](#troubleshooting)

---

## Basic Operations

### Parse a Binary Config File

```elixir
# Simple parse
{:ok, tlvs} = Bindocsis.parse_file("config.cm")

# Parse with options
{:ok, tlvs} = Bindocsis.parse_file("config.cm",
  format: :binary,
  enhanced: true,
  validate_mic: true,
  shared_secret: System.get_env("DOCSIS_SECRET")
)
```

### Parse from Memory

```elixir
# Binary data in memory
binary_data = File.read!("config.cm")
{:ok, tlvs} = Bindocsis.parse(binary_data, format: :binary)

# JSON string
json_string = ~s({"tlvs": [{"type": 1, "formatted_value": "591000000"}]})
{:ok, tlvs} = Bindocsis.parse(json_string, format: :json)
```

### Read a Specific TLV Value

```elixir
{:ok, tlvs} = Bindocsis.parse_file("config.cm")

# Find downstream frequency (TLV 1)
downstream_freq = Enum.find(tlvs, fn tlv -> tlv.type == 1 end)

case downstream_freq do
  %{value: <<freq::32>>} ->
    IO.puts "Downstream frequency: #{freq} Hz (#{div(freq, 1_000_000)} MHz)"
  
  nil ->
    IO.puts "No downstream frequency configured"
end
```

### List All TLVs in a Config

```elixir
{:ok, tlvs} = Bindocsis.parse_file("config.cm")

IO.puts "Configuration contains #{length(tlvs)} TLVs:\n"

Enum.each(tlvs, fn tlv ->
  case Bindocsis.DocsisSpecs.get_tlv_info(tlv.type) do
    {:ok, %{name: name}} ->
      IO.puts "  TLV #{tlv.type}: #{name} (#{tlv.length} bytes)"
    
    _ ->
      IO.puts "  TLV #{tlv.type}: Unknown (#{tlv.length} bytes)"
  end
end)
```

---

## Format Conversion

### Binary to JSON

```elixir
# Read binary, convert to JSON
{:ok, tlvs} = Bindocsis.parse_file("config.cm", format: :binary)
{:ok, json} = Bindocsis.generate(tlvs, format: :json)
File.write!("config.json", json)

# One-step conversion
{:ok, json} = Bindocsis.convert(
  File.read!("config.cm"),
  from: :binary,
  to: :json
)
File.write!("config.json", json)
```

### JSON to Binary

```elixir
{:ok, tlvs} = Bindocsis.parse_file("config.json", format: :json)
{:ok, binary} = Bindocsis.generate(tlvs, format: :binary)
File.write!("config.cm", binary)
```

### Binary to Human-Readable Config

```elixir
{:ok, tlvs} = Bindocsis.parse_file("config.cm")
{:ok, config_text} = Bindocsis.generate(tlvs, format: :config)
File.write!("config.txt", config_text)
```

### Batch Convert All Files in Directory

```elixir
# Convert all .cm files to JSON
Path.wildcard("configs/*.cm")
|> Enum.each(fn file ->
  output = String.replace(file, ".cm", ".json")
  
  with {:ok, tlvs} <- Bindocsis.parse_file(file),
       {:ok, json} <- Bindocsis.generate(tlvs, format: :json) do
    File.write!(output, json)
    IO.puts "✓ Converted #{Path.basename(file)} → #{Path.basename(output)}"
  else
    {:error, reason} ->
      IO.puts "✗ Failed to convert #{Path.basename(file)}: #{reason}"
  end
end)
```

---

## Validation

### Basic Validation

```elixir
alias Bindocsis.Validation.Framework

{:ok, tlvs} = Bindocsis.parse_file("config.cm")
{:ok, result} = Framework.validate(tlvs)

if result.valid? do
  IO.puts "✓ Configuration is valid"
else
  IO.puts "✗ Configuration has #{length(result.errors)} errors"
  
  Enum.each(result.errors, fn error ->
    IO.puts "  • #{error.message}"
  end)
end
```

### Validate with Specific DOCSIS Version

```elixir
{:ok, result} = Framework.validate(tlvs, 
  level: :compliance,
  docsis_version: "3.0"
)

IO.puts Framework.format_result(result)
```

### Auto-Detect DOCSIS Version

```elixir
{:ok, tlvs} = Bindocsis.parse_file("config.cm")
version = Framework.detect_version(tlvs)

IO.puts "Detected DOCSIS version: #{version}"

# Validate against detected version
{:ok, result} = Framework.validate(tlvs, docsis_version: version)
```

### Strict Validation (Warnings as Errors)

```elixir
# Normal validation allows warnings
{:ok, normal_result} = Framework.validate(tlvs)
IO.puts "Normal: #{if normal_result.valid?, do: "PASS", else: "FAIL"}"

# Strict mode treats warnings as errors
{:ok, strict_result} = Framework.validate(tlvs, strict: true)
IO.puts "Strict: #{if strict_result.valid?, do: "PASS", else: "FAIL"}"
```

### Validate Multiple Configs

```elixir
configs = %{
  "prod" => Bindocsis.parse_file!("prod.cm"),
  "dev" => Bindocsis.parse_file!("dev.cm"),
  "test" => Bindocsis.parse_file!("test.cm")
}

{:ok, results} = Framework.validate_batch(configs)

Enum.each(results, fn {name, result} ->
  status = if result.valid?, do: "✓", else: "✗"
  stats = Framework.stats(result)
  IO.puts "#{status} #{name}: #{stats.errors} errors, #{stats.warnings} warnings"
end)
```

### Validation Before Deployment

```elixir
defmodule ConfigValidator do
  alias Bindocsis.Validation.Framework
  
  def validate_for_deployment(file_path) do
    with {:ok, tlvs} <- Bindocsis.parse_file(file_path),
         {:ok, result} <- Framework.validate(tlvs, strict: true, level: :compliance) do
      
      if result.valid? do
        {:ok, "Configuration ready for deployment"}
      else
        {:error, "Validation failed", result}
      end
    end
  end
end

case ConfigValidator.validate_for_deployment("config.cm") do
  {:ok, msg} ->
    IO.puts msg
    deploy_config()
  
  {:error, reason, result} ->
    IO.puts "Cannot deploy: #{reason}"
    IO.puts Framework.format_result(result)
end
```

---

## Error Handling

### Handling Parse Errors

```elixir
alias Bindocsis.Error

case Bindocsis.parse_file("config.cm") do
  {:ok, tlvs} ->
    process_config(tlvs)
  
  {:error, %Error{type: :parse_error} = error} ->
    IO.puts "Parse failed: #{error.message}"
    IO.puts "Location: #{error.location}"
    IO.puts "Suggestion: #{error.suggestion}"
  
  {:error, %Error{type: :file_error}} ->
    IO.puts "File not found or inaccessible"
  
  {:error, reason} when is_binary(reason) ->
    IO.puts "Error: #{reason}"
end
```

### Retry on MIC Validation Failure

```elixir
case Bindocsis.parse_file("config.cm", validate_mic: true, shared_secret: secret) do
  {:ok, tlvs} ->
    {:ok, tlvs}
  
  {:error, %Error{type: :mic_error}} ->
    # Retry without MIC validation
    Logger.warning("MIC validation failed, retrying without validation")
    Bindocsis.parse_file("config.cm", validate_mic: false)
  
  {:error, error} ->
    {:error, error}
end
```

### Logging Errors with Context

```elixir
require Logger

case Bindocsis.parse_file("config.cm") do
  {:ok, tlvs} ->
    {:ok, tlvs}
  
  {:error, %Error{} = error} ->
    Logger.error("Parse failed",
      error_type: error.type,
      message: error.message,
      location: error.location,
      context: error.context
    )
    
    {:error, error}
end
```

---

## Configuration Generation

### Create a Basic Config from Scratch

```elixir
tlvs = [
  # Downstream frequency: 591 MHz
  %{type: 1, length: 4, value: <<591_000_000::32>>},
  
  # Upstream channel ID
  %{type: 2, length: 1, value: <<3>>},
  
  # Network access enabled
  %{type: 3, length: 1, value: <<1>>},
  
  # Max CPE
  %{type: 21, length: 1, value: <<5>>}
]

# Add MICs
{:ok, binary} = Bindocsis.generate(tlvs, 
  format: :binary,
  add_mic: true,
  shared_secret: "my_secret"
)

File.write!("new_config.cm", binary)
```

### Modify Existing Config

```elixir
{:ok, tlvs} = Bindocsis.parse_file("config.cm")

# Change downstream frequency to 600 MHz
modified_tlvs = Enum.map(tlvs, fn
  %{type: 1} = tlv ->
    %{tlv | value: <<600_000_000::32>>, length: 4}
  
  other ->
    other
end)

{:ok, binary} = Bindocsis.generate(modified_tlvs, format: :binary)
File.write!("modified_config.cm", binary)
```

### Add a TLV to Existing Config

```elixir
{:ok, tlvs} = Bindocsis.parse_file("config.cm")

# Add Software Upgrade Filename (TLV 9)
filename = "firmware_v2.bin"
new_tlv = %{
  type: 9,
  length: byte_size(filename),
  value: filename
}

# Remove MICs (6, 7) and end marker (255)
tlvs_without_mics = Enum.reject(tlvs, &(&1.type in [6, 7, 255]))

# Add new TLV and regenerate with MICs
updated_tlvs = tlvs_without_mics ++ [new_tlv]

{:ok, binary} = Bindocsis.generate(updated_tlvs,
  format: :binary,
  add_mic: true,
  shared_secret: secret
)

File.write!("updated_config.cm", binary)
```

### Generate Config for Different DOCSIS Versions

```elixir
defmodule ConfigGenerator do
  def basic_docsis_10() do
    [
      %{type: 1, length: 4, value: <<591_000_000::32>>},
      %{type: 2, length: 1, value: <<3>>},
      %{type: 3, length: 1, value: <<1>>}
    ]
  end
  
  def basic_docsis_11() do
    basic_docsis_10() ++ [
      %{type: 6, length: 16, value: <<0::128>>},  # CM MIC
      %{type: 7, length: 16, value: <<0::128>>}   # CMTS MIC
    ]
  end
  
  def basic_docsis_31() do
    basic_docsis_11() ++ [
      # OFDM channel configuration
      %{type: 65, length: 10, value: <<0::80>>}
    ]
  end
end

# Generate for DOCSIS 3.1
tlvs = ConfigGenerator.basic_docsis_31()
{:ok, binary} = Bindocsis.generate(tlvs, format: :binary)
```

---

## Advanced Operations

### Compare Two Configurations

```elixir
{:ok, config1} = Bindocsis.parse_file("config1.cm")
{:ok, config2} = Bindocsis.parse_file("config2.cm")

# Group by TLV type
types1 = MapSet.new(config1, & &1.type)
types2 = MapSet.new(config2, & &1.type)

only_in_1 = MapSet.difference(types1, types2)
only_in_2 = MapSet.difference(types2, types1)
common = MapSet.intersection(types1, types2)

IO.puts "Common TLVs: #{MapSet.size(common)}"
IO.puts "Only in config1: #{inspect(MapSet.to_list(only_in_1))}"
IO.puts "Only in config2: #{inspect(MapSet.to_list(only_in_2))}"

# Compare values for common TLVs
Enum.each(common, fn type ->
  tlv1 = Enum.find(config1, &(&1.type == type))
  tlv2 = Enum.find(config2, &(&1.type == type))
  
  if tlv1.value != tlv2.value do
    IO.puts "TLV #{type} differs"
  end
end)
```

### Extract Service Flow Configuration

```elixir
{:ok, tlvs} = Bindocsis.parse_file("config.cm")

# Find all service flows
upstream_flows = Enum.filter(tlvs, &(&1.type == 17))
downstream_flows = Enum.filter(tlvs, &(&1.type == 18))

IO.puts "Upstream Service Flows: #{length(upstream_flows)}"
IO.puts "Downstream Service Flows: #{length(downstream_flows)}"

# Extract QoS parameters from each flow
Enum.with_index(upstream_flows, 1)
|> Enum.each(fn {flow, index} ->
  if Map.has_key?(flow, :subtlvs) do
    max_rate = Enum.find(flow.subtlvs, &(&1.type == 8))
    min_rate = Enum.find(flow.subtlvs, &(&1.type == 9))
    
    IO.puts "\nUpstream Flow #{index}:"
    
    if max_rate do
      <<rate::32>> = max_rate.value
      IO.puts "  Max rate: #{rate} bps (#{div(rate, 1_000_000)} Mbps)"
    end
    
    if min_rate do
      <<rate::32>> = min_rate.value
      IO.puts "  Min rate: #{rate} bps (#{div(rate, 1_000_000)} Mbps)"
    end
  end
end)
```

### Merge Multiple Configs

```elixir
defmodule ConfigMerger do
  def merge(configs) do
    # Collect all TLVs except MICs and end marker
    all_tlvs =
      configs
      |> Enum.flat_map(& &1)
      |> Enum.reject(&(&1.type in [6, 7, 255]))
      |> Enum.uniq_by(&{&1.type, &1.value})
    
    all_tlvs
  end
end

{:ok, base} = Bindocsis.parse_file("base.cm")
{:ok, overrides} = Bindocsis.parse_file("overrides.cm")

merged = ConfigMerger.merge([base, overrides])

{:ok, binary} = Bindocsis.generate(merged,
  format: :binary,
  add_mic: true,
  shared_secret: secret
)

File.write!("merged.cm", binary)
```

### Round-Trip Verification

```elixir
defmodule RoundTripVerifier do
  def verify(input_file) do
    # Read original
    {:ok, original_binary} = File.read(input_file)
    
    # Parse to TLVs
    {:ok, tlvs} = Bindocsis.parse(original_binary, format: :binary)
    
    # Generate back to binary
    {:ok, regenerated_binary} = Bindocsis.generate(tlvs, format: :binary)
    
    # Compare
    if original_binary == regenerated_binary do
      {:ok, "Perfect round-trip"}
    else
      # Calculate difference
      diff_bytes = byte_size(original_binary) - byte_size(regenerated_binary)
      {:error, "Binary differs by #{diff_bytes} bytes"}
    end
  end
end

case RoundTripVerifier.verify("config.cm") do
  {:ok, msg} -> IO.puts "✓ #{msg}"
  {:error, msg} -> IO.puts "✗ #{msg}"
end
```

### Custom Validation Rules

```elixir
defmodule CustomValidator do
  alias Bindocsis.Validation.Result
  
  def validate_company_policy(tlvs) do
    result = Result.new()
    
    # Rule 1: Frequency must be in allowed range
    result = check_frequency_policy(result, tlvs)
    
    # Rule 2: Max CPE must not exceed 10
    result = check_max_cpe_policy(result, tlvs)
    
    # Rule 3: Must have vendor ID
    result = check_vendor_id_required(result, tlvs)
    
    result
  end
  
  defp check_frequency_policy(result, tlvs) do
    case Enum.find(tlvs, &(&1.type == 1)) do
      %{value: <<freq::32>>} when freq >= 550_000_000 and freq <= 600_000_000 ->
        result
      
      %{value: <<freq::32>>} ->
        Result.add_error(result,
          "Frequency #{div(freq, 1_000_000)} MHz not allowed (must be 550-600 MHz)",
          %{tlv: 1}
        )
      
      nil ->
        Result.add_error(result, "Missing downstream frequency", %{tlv: 1})
    end
  end
  
  defp check_max_cpe_policy(result, tlvs) do
    case Enum.find(tlvs, &(&1.type == 21)) do
      %{value: <<count>>} when count > 10 ->
        Result.add_error(result,
          "Max CPE count #{count} exceeds company limit (10)",
          %{tlv: 21}
        )
      
      _ ->
        result
    end
  end
  
  defp check_vendor_id_required(result, tlvs) do
    if Enum.any?(tlvs, &(&1.type == 8)) do
      result
    else
      Result.add_warning(result, "Vendor ID (TLV 8) recommended", %{tlv: 8})
    end
  end
end

# Use custom validator
{:ok, tlvs} = Bindocsis.parse_file("config.cm")
result = CustomValidator.validate_company_policy(tlvs)

if result.valid? do
  IO.puts "✓ Passes company policy"
else
  IO.puts "✗ Violates company policy"
  
  Enum.each(result.errors, fn error ->
    IO.puts "  #{error.message}"
  end)
end
```

---

## Troubleshooting

### Debug Parsing Issues

```elixir
# Enable debug logging
Logger.configure(level: :debug)

case Bindocsis.parse_file("config.cm") do
  {:ok, tlvs} ->
    IO.puts "Parsed #{length(tlvs)} TLVs"
    
    # Inspect first TLV in detail
    IO.inspect(List.first(tlvs), label: "First TLV")
  
  {:error, error} ->
    IO.inspect(error, label: "Parse Error", pretty: true)
end
```

### Inspect Binary Content

```elixir
binary = File.read!("config.cm")

IO.puts "File size: #{byte_size(binary)} bytes"
IO.puts "First 32 bytes (hex):"

binary
|> binary_part(0, min(32, byte_size(binary)))
|> :binary.bin_to_list()
|> Enum.map(&Integer.to_string(&1, 16))
|> Enum.map(&String.pad_leading(&1, 2, "0"))
|> Enum.chunk_every(16)
|> Enum.each(fn chunk ->
  IO.puts "  #{Enum.join(chunk, " ")}"
end)
```

### Validate File Format

```elixir
def check_format(file_path) do
  binary = File.read!(file_path)
  
  cond do
    String.starts_with?(binary, "{") ->
      IO.puts "Likely JSON format"
    
    String.starts_with?(binary, "---") or String.contains?(binary, "tlvs:") ->
      IO.puts "Likely YAML format"
    
    byte_size(binary) > 0 and :binary.at(binary, 0) < 100 ->
      IO.puts "Likely binary TLV format"
    
    true ->
      IO.puts "Unknown format"
  end
end

check_format("config.cm")
```

---

## Tips and Best Practices

### Always Use Error Handling

```elixir
# ✓ Good
case Bindocsis.parse_file(path) do
  {:ok, tlvs} -> process(tlvs)
  {:error, error} -> handle_error(error)
end

# ✗ Bad
tlvs = Bindocsis.parse_file!(path)  # Will crash on error
```

### Validate Before Writing

```elixir
# ✓ Good: Validate before writing
{:ok, tlvs} = Bindocsis.parse_file("config.cm")
{:ok, result} = Framework.validate(tlvs)

if result.valid? do
  {:ok, binary} = Bindocsis.generate(tlvs, format: :binary)
  File.write!("output.cm", binary)
else
  IO.puts "Cannot write invalid config"
end
```

### Use Transactions for Critical Operations

```elixir
defmodule SafeConfigUpdate do
  def update_config(path, update_fn) do
    backup_path = "#{path}.backup"
    
    with {:ok, tlvs} <- Bindocsis.parse_file(path),
         updated_tlvs = update_fn.(tlvs),
         {:ok, result} <- Framework.validate(updated_tlvs),
         true <- result.valid?,
         {:ok, binary} <- Bindocsis.generate(updated_tlvs, format: :binary),
         :ok <- File.cp(path, backup_path),
         :ok <- File.write(path, binary) do
      File.rm(backup_path)
      {:ok, "Config updated successfully"}
    else
      {:error, reason} ->
        {:error, "Update failed: #{reason}"}
      
      false ->
        {:error, "Validation failed"}
    end
  end
end
```

---

## See Also

- [ERROR_CATALOG.md](ERROR_CATALOG.md) - Complete error reference
- [API_REFERENCE.md](API_REFERENCE.md) - API documentation  
- [USER_GUIDE.md](USER_GUIDE.md) - User guide
- [TROUBLESHOOTING.md](TROUBLESHOOTING.md) - Troubleshooting guide
