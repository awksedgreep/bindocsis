# Bindocsis API Reference

**Complete Programmatic Interface Documentation**

---

## Table of Contents

1. [Core API](#core-api)
2. [DocsisSpecs Module](#docsisSpecs-module)
3. [Parser Modules](#parser-modules)
4. [Generator Modules](#generator-modules)
5. [Validation Module](#validation-module)
6. [CLI Module](#cli-module)
7. [Types and Structures](#types-and-structures)
8. [Error Handling](#error-handling)
9. [Examples](#examples)
10. [Integration Patterns](#integration-patterns)

---

## Core API

### Module: `Bindocsis`

The main module providing high-level functions for DOCSIS configuration processing.

#### `parse/2`

Parse DOCSIS data from binary format.

```elixir
@spec parse(binary(), keyword()) :: {:ok, [map()]} | {:error, String.t()}
```

**Parameters:**
- `binary` - Raw DOCSIS binary data
- `opts` - Options (optional)
  - `:format` - Force input format (`:binary`, `:json`, `:yaml`)
  - `:validate` - Validate after parsing (boolean)
  - `:docsis_version` - DOCSIS version for validation

**Returns:**
- `{:ok, tlvs}` - List of parsed TLV maps
- `{:error, reason}` - Error description

**Example:**
```elixir
binary_data = File.read!("config.cm")
{:ok, tlvs} = Bindocsis.parse(binary_data)

# With validation
{:ok, tlvs} = Bindocsis.parse(binary_data, validate: true, docsis_version: "3.1")
```

#### `parse_file/2`

Parse DOCSIS configuration file.

```elixir
@spec parse_file(String.t(), keyword()) :: {:ok, [map()]} | {:error, String.t()}
```

**Parameters:**
- `path` - File path to parse
- `opts` - Options (same as `parse/2`)

**Returns:**
- `{:ok, tlvs}` - List of parsed TLV maps
- `{:error, reason}` - Error description

**Example:**
```elixir
{:ok, tlvs} = Bindocsis.parse_file("config.cm")
{:ok, tlvs} = Bindocsis.parse_file("config.json", format: :json)
```

#### `generate/2`

Generate output in specified format from TLV list.

```elixir
@spec generate([map()], keyword()) :: {:ok, binary() | String.t()} | {:error, String.t()}
```

**Parameters:**
- `tlvs` - List of TLV maps
- `opts` - Options
  - `:format` - Output format (`:binary`, `:json`, `:yaml`, `:pretty`)
  - `:docsis_version` - DOCSIS version for metadata

**Returns:**
- `{:ok, data}` - Generated data in requested format
- `{:error, reason}` - Error description

**Example:**
```elixir
{:ok, json_data} = Bindocsis.generate(tlvs, format: :json)
{:ok, yaml_data} = Bindocsis.generate(tlvs, format: :yaml)
{:ok, binary_data} = Bindocsis.generate(tlvs, format: :binary)
```

#### `write_file/3`

Write TLV list to file in specified format.

```elixir
@spec write_file([map()], String.t(), keyword()) :: :ok | {:error, String.t()}
```

**Parameters:**
- `tlvs` - List of TLV maps
- `path` - Output file path
- `opts` - Options (same as `generate/2`)

**Returns:**
- `:ok` - Success
- `{:error, reason}` - Error description

**Example:**
```elixir
:ok = Bindocsis.write_file(tlvs, "output.json", format: :json)
:ok = Bindocsis.write_file(tlvs, "output.cm", format: :binary)
```

#### `convert/2`

Convert between formats in a single operation.

```elixir
@spec convert(String.t() | binary(), keyword()) :: {:ok, binary() | String.t()} | {:error, String.t()}
```

**Parameters:**
- `input` - Input data (file path or binary data)
- `opts` - Options
  - `:input_format` - Input format
  - `:output_format` - Output format
  - `:validate` - Validate during conversion

**Example:**
```elixir
{:ok, json_data} = Bindocsis.convert("config.cm", 
  input_format: :binary, 
  output_format: :json)
```

#### `pretty_print/1`

Format TLV for human-readable display.

```elixir
@spec pretty_print(map()) :: :ok
```

**Parameters:**
- `tlv` - Single TLV map

**Returns:**
- `:ok` - Prints formatted output to stdout

**Example:**
```elixir
tlv = %{type: 68, length: 4, value: <<0, 0, 3, 232>>}
Bindocsis.pretty_print(tlv)
# Output:
# Type: 68 (Default Upstream Target Buffer) Length: 4
# Description: Default upstream target buffer size
# Value: 1000
```

---

## DocsisSpecs Module

### Module: `Bindocsis.DocsisSpecs`

Comprehensive DOCSIS TLV specifications and metadata.

#### `get_tlv_info/2`

Retrieve complete TLV information.

```elixir
@spec get_tlv_info(non_neg_integer(), String.t()) :: 
  {:ok, tlv_info()} | {:error, :unknown_tlv | :unsupported_version}
```

**Parameters:**
- `type` - TLV type (1-255)
- `version` - DOCSIS version ("3.0", "3.1", default: "3.1")

**Returns:**
- `{:ok, tlv_info}` - TLV information map
- `{:error, :unknown_tlv}` - Unknown TLV type
- `{:error, :unsupported_version}` - TLV not supported in version

**Example:**
```elixir
{:ok, info} = Bindocsis.DocsisSpecs.get_tlv_info(68)
# => %{
#   name: "Default Upstream Target Buffer",
#   description: "Default upstream target buffer size",
#   introduced_version: "3.0",
#   subtlv_support: false,
#   value_type: :uint32,
#   max_length: 4
# }

{:error, :unsupported_version} = Bindocsis.DocsisSpecs.get_tlv_info(77, "3.0")
```

#### `get_supported_types/1`

Get list of all supported TLV types for a DOCSIS version.

```elixir
@spec get_supported_types(String.t()) :: [non_neg_integer()]
```

**Parameters:**
- `version` - DOCSIS version (default: "3.1")

**Returns:**
- List of supported TLV type numbers

**Example:**
```elixir
types_31 = Bindocsis.DocsisSpecs.get_supported_types("3.1")
# => [1, 2, 3, ..., 85, 200, 201, ..., 255]

types_30 = Bindocsis.DocsisSpecs.get_supported_types("3.0")  
# => [1, 2, 3, ..., 76, 200, 201, ..., 255]
```

#### `valid_tlv_type?/2`

Check if TLV type is valid for DOCSIS version.

```elixir
@spec valid_tlv_type?(non_neg_integer(), String.t()) :: boolean()
```

**Example:**
```elixir
true = Bindocsis.DocsisSpecs.valid_tlv_type?(68, "3.1")
false = Bindocsis.DocsisSpecs.valid_tlv_type?(77, "3.0")
```

#### `supports_subtlvs?/2`

Check if TLV supports SubTLVs.

```elixir
@spec supports_subtlvs?(non_neg_integer(), String.t()) :: boolean()
```

**Example:**
```elixir
true = Bindocsis.DocsisSpecs.supports_subtlvs?(24)   # Service Flow
false = Bindocsis.DocsisSpecs.supports_subtlvs?(68)  # Simple value
```

#### `get_tlv_name/2`

Get human-readable TLV name.

```elixir
@spec get_tlv_name(non_neg_integer(), String.t()) :: String.t()
```

**Example:**
```elixir
"Default Upstream Target Buffer" = Bindocsis.DocsisSpecs.get_tlv_name(68)
"Unknown TLV 999" = Bindocsis.DocsisSpecs.get_tlv_name(999)
```

#### `get_tlv_description/2`

Get detailed TLV description.

```elixir
@spec get_tlv_description(non_neg_integer(), String.t()) :: String.t()
```

#### `get_tlv_value_type/2`

Get TLV value type information.

```elixir
@spec get_tlv_value_type(non_neg_integer(), String.t()) :: atom()
```

**Returns:**
- `:uint8`, `:uint16`, `:uint32` - Integer types
- `:ipv4` - IPv4 address
- `:string` - Text string
- `:binary` - Raw binary data
- `:compound` - Contains SubTLVs
- `:vendor` - Vendor-specific data

**Example:**
```elixir
:uint32 = Bindocsis.DocsisSpecs.get_tlv_value_type(68)
:compound = Bindocsis.DocsisSpecs.get_tlv_value_type(24)
```

---

## Parser Modules

### Module: `Bindocsis.Parsers.JsonParser`

Parse JSON format DOCSIS configurations.

#### `parse/1`

Parse JSON string into TLV representation.

```elixir
@spec parse(String.t()) :: {:ok, [map()]} | {:error, String.t()}
```

**Example:**
```elixir
json = ~s({"tlvs": [{"type": 3, "length": 1, "value": "01"}]})
{:ok, tlvs} = Bindocsis.Parsers.JsonParser.parse(json)
```

#### `parse_file/1`

Parse JSON file.

```elixir
@spec parse_file(String.t()) :: {:ok, [map()]} | {:error, String.t()}
```

### Module: `Bindocsis.Parsers.YamlParser`

Parse YAML format DOCSIS configurations.

#### `parse/1`

Parse YAML string into TLV representation.

```elixir
@spec parse(String.t()) :: {:ok, [map()]} | {:error, String.t()}
```

**Example:**
```elixir
yaml = """
tlvs:
  - type: 3
    length: 1
    value: "01"
"""
{:ok, tlvs} = Bindocsis.Parsers.YamlParser.parse(yaml)
```

---

## Generator Modules

### Module: `Bindocsis.Generators.BinaryGenerator`

Generate DOCSIS binary format.

#### `generate/2`

Generate binary data from TLV list.

```elixir
@spec generate([map()], keyword()) :: {:ok, binary()} | {:error, String.t()}
```

**Options:**
- `:add_terminator` - Add end-of-data marker (default: true)
- `:validate` - Validate before generation

**Example:**
```elixir
tlvs = [%{type: 3, length: 1, value: <<1>>}]
{:ok, binary} = Bindocsis.Generators.BinaryGenerator.generate(tlvs)
```

#### `write_file/3`

Write binary data to file.

```elixir
@spec write_file([map()], String.t(), keyword()) :: :ok | {:error, String.t()}
```

### Module: `Bindocsis.Generators.JsonGenerator`

Generate JSON format.

#### `generate/2`

Generate JSON from TLV list.

```elixir
@spec generate([map()], keyword()) :: {:ok, String.t()} | {:error, String.t()}
```

**Options:**
- `:docsis_version` - Include DOCSIS version metadata
- `:pretty` - Pretty-print JSON (default: true)

### Module: `Bindocsis.Generators.YamlGenerator`

Generate YAML format.

#### `generate/2`

Generate YAML from TLV list.

```elixir
@spec generate([map()], keyword()) :: {:ok, String.t()} | {:error, String.t()}
```

---

## Validation Module

### Module: `Bindocsis.Validation`

DOCSIS compliance validation functions.

#### `validate_docsis_compliance/2`

Validate TLV list against DOCSIS specifications.

```elixir
@spec validate_docsis_compliance([map()], String.t()) :: 
  :ok | {:error, [validation_error()]}
```

**Parameters:**
- `tlvs` - List of TLV maps
- `version` - DOCSIS version ("3.0", "3.1")

**Returns:**
- `:ok` - Validation passed
- `{:error, errors}` - List of validation errors

**Example:**
```elixir
:ok = Bindocsis.Validation.validate_docsis_compliance(tlvs, "3.1")

{:error, errors} = Bindocsis.Validation.validate_docsis_compliance(tlvs, "3.0")
# errors = [
#   {:invalid_tlv, 77, "Not supported in DOCSIS 3.0"},
#   {:missing_required, 3, "Network Access Control is required"}
# ]
```

#### `validate_tlv/2`

Validate individual TLV structure.

```elixir
@spec validate_tlv(map(), String.t()) :: :ok | {:error, String.t()}
```

#### `validate_subtlvs/2`

Validate SubTLV structure and requirements.

```elixir
@spec validate_subtlvs([map()], non_neg_integer()) :: :ok | {:error, [String.t()]}
```

---

## CLI Module

### Module: `Bindocsis.CLI`

Command-line interface implementation.

#### `main/1`

Main CLI entry point.

```elixir
@spec main([String.t()]) :: :ok
```

**Example:**
```elixir
# Programmatic CLI usage
Bindocsis.CLI.main(["-i", "config.cm", "-t", "json"])
```

---

## Types and Structures

### TLV Map Structure

Standard TLV representation:

```elixir
@type tlv() :: %{
  type: non_neg_integer(),
  length: non_neg_integer(),
  value: binary(),
  subtlvs: [tlv()] | nil
}
```

**Example:**
```elixir
# Simple TLV
%{
  type: 3,
  length: 1,
  value: <<1>>
}

# Compound TLV with SubTLVs
%{
  type: 24,
  length: 7,
  value: <<1, 2, 0, 1, 6, 1, 7>>,
  subtlvs: [
    %{type: 1, length: 2, value: <<0, 1>>},
    %{type: 6, length: 1, value: <<7>>}
  ]
}
```

### TLV Info Structure

TLV specification information:

```elixir
@type tlv_info() :: %{
  name: String.t(),
  description: String.t(),
  introduced_version: String.t(),
  subtlv_support: boolean(),
  value_type: atom(),
  max_length: non_neg_integer() | :unlimited
}
```

### Validation Error Types

```elixir
@type validation_error() :: 
  {:invalid_tlv, non_neg_integer(), String.t()} |
  {:missing_required, non_neg_integer(), String.t()} |
  {:value_out_of_range, non_neg_integer(), any(), String.t()} |
  {:version_incompatible, non_neg_integer(), String.t(), String.t()}
```

---

## Error Handling

### Common Error Types

#### Parse Errors
```elixir
{:error, "Invalid TLV format at byte 23"}
{:error, "Insufficient data for claimed length"}
{:error, "JSON parsing error: invalid syntax"}
```

#### Validation Errors
```elixir
{:error, [
  {:invalid_tlv, 77, "Not supported in DOCSIS 3.0"},
  {:missing_required, 3, "Network Access Control is required"}
]}
```

#### File Errors
```elixir
{:error, "File not found: config.cm"}
{:error, "Permission denied writing to output.json"}
```

### Error Handling Patterns

#### Basic Error Handling
```elixir
case Bindocsis.parse_file("config.cm") do
  {:ok, tlvs} ->
    process_tlvs(tlvs)
  {:error, reason} ->
    Logger.error("Failed to parse config: #{reason}")
    {:error, reason}
end
```

#### With Validation
```elixir
with {:ok, tlvs} <- Bindocsis.parse_file("config.cm"),
     :ok <- Bindocsis.Validation.validate_docsis_compliance(tlvs, "3.1") do
  {:ok, tlvs}
else
  {:error, reason} when is_binary(reason) ->
    {:error, "Parse error: #{reason}"}
  {:error, validation_errors} when is_list(validation_errors) ->
    {:error, "Validation failed: #{format_validation_errors(validation_errors)}"}
end
```

#### Comprehensive Error Handling
```elixir
defmodule MyApp.DocsisProcessor do
  def process_config_file(path, docsis_version \\ "3.1") do
    with {:ok, tlvs} <- parse_with_retry(path),
         :ok <- validate_config(tlvs, docsis_version),
         {:ok, json} <- Bindocsis.generate(tlvs, format: :json) do
      {:ok, json}
    else
      {:error, :file_not_found} ->
        {:error, "Configuration file not found: #{path}"}
      {:error, :validation_failed, errors} ->
        {:error, "Configuration invalid", errors}
      {:error, reason} ->
        {:error, "Processing failed: #{reason}"}
    end
  end

  defp parse_with_retry(path, retries \\ 3) do
    case Bindocsis.parse_file(path) do
      {:ok, tlvs} -> {:ok, tlvs}
      {:error, reason} when retries > 0 ->
        :timer.sleep(100)
        parse_with_retry(path, retries - 1)
      {:error, reason} ->
        {:error, reason}
    end
  end

  defp validate_config(tlvs, version) do
    case Bindocsis.Validation.validate_docsis_compliance(tlvs, version) do
      :ok -> :ok
      {:error, errors} -> {:error, :validation_failed, errors}
    end
  end
end
```

---

## Examples

### Basic Usage

#### Parse and Convert
```elixir
defmodule Examples.BasicUsage do
  def convert_config_to_json(input_path, output_path) do
    with {:ok, tlvs} <- Bindocsis.parse_file(input_path),
         {:ok, json} <- Bindocsis.generate(tlvs, format: :json),
         :ok <- File.write(output_path, json) do
      {:ok, "Conversion successful"}
    else
      {:error, reason} -> {:error, "Conversion failed: #{reason}"}
    end
  end

  def analyze_config(path) do
    with {:ok, tlvs} <- Bindocsis.parse_file(path) do
      analysis = %{
        total_tlvs: length(tlvs),
        tlv_types: Enum.map(tlvs, & &1.type) |> Enum.uniq() |> Enum.sort(),
        has_docsis_31_features: Enum.any?(tlvs, &(&1.type in 77..85)),
        estimated_docsis_version: estimate_version(tlvs)
      }
      {:ok, analysis}
    end
  end

  defp estimate_version(tlvs) do
    types = Enum.map(tlvs, & &1.type)
    cond do
      Enum.any?(types, &(&1 in 77..85)) -> "3.1"
      Enum.any?(types, &(&1 in 64..76)) -> "3.0"
      true -> "2.0 or earlier"
    end
  end
end
```

#### Validation Workflow
```elixir
defmodule Examples.ValidationWorkflow do
  def validate_and_deploy(config_path, docsis_version) do
    with {:ok, tlvs} <- Bindocsis.parse_file(config_path),
         :ok <- validate_comprehensive(tlvs, docsis_version),
         {:ok, binary} <- Bindocsis.generate(tlvs, format: :binary) do
      deploy_to_modems(binary)
    else
      {:error, :validation_failed, errors} ->
        log_validation_errors(errors)
        {:error, "Configuration validation failed"}
      {:error, reason} ->
        {:error, "Deployment preparation failed: #{reason}"}
    end
  end

  defp validate_comprehensive(tlvs, version) do
    with :ok <- Bindocsis.Validation.validate_docsis_compliance(tlvs, version),
         :ok <- validate_business_rules(tlvs),
         :ok <- validate_security_requirements(tlvs) do
      :ok
    else
      {:error, errors} -> {:error, :validation_failed, errors}
    end
  end

  defp validate_business_rules(tlvs) do
    # Custom business logic validation
    required_tlvs = [3, 24, 25]  # Network access, upstream/downstream flows
    
    missing = required_tlvs -- Enum.map(tlvs, & &1.type)
    if Enum.empty?(missing) do
      :ok
    else
      {:error, "Missing required TLVs: #{inspect(missing)}"}
    end
  end

  defp validate_security_requirements(tlvs) do
    # Ensure security features are enabled
    network_access = Enum.find(tlvs, &(&1.type == 3))
    case network_access do
      %{value: <<1>>} -> :ok  # Enabled
      _ -> {:error, "Network access control must be enabled"}
    end
  end
end
```

### Advanced Usage

#### Configuration Template System
```elixir
defmodule Examples.TemplateSystem do
  def create_service_tier_config(template_path, service_tier, customer_opts \\ []) do
    with {:ok, base_tlvs} <- Bindocsis.parse_file(template_path),
         modified_tlvs <- apply_service_tier(base_tlvs, service_tier),
         customized_tlvs <- apply_customer_options(modified_tlvs, customer_opts),
         :ok <- Bindocsis.Validation.validate_docsis_compliance(customized_tlvs, "3.1") do
      {:ok, customized_tlvs}
    end
  end

  defp apply_service_tier(tlvs, tier) do
    speed_limits = get_speed_limits(tier)
    
    tlvs
    |> update_service_flow_speeds(24, speed_limits.upstream)  # Upstream
    |> update_service_flow_speeds(25, speed_limits.downstream)  # Downstream
  end

  defp get_speed_limits(:gold), do: %{upstream: 50_000_000, downstream: 1_000_000_000}
  defp get_speed_limits(:silver), do: %{upstream: 25_000_000, downstream: 500_000_000}
  defp get_speed_limits(:bronze), do: %{upstream: 10_000_000, downstream: 100_000_000}

  defp update_service_flow_speeds(tlvs, flow_type, speed) do
    Enum.map(tlvs, fn tlv ->
      if tlv.type == flow_type and tlv.subtlvs do
        subtlvs = Enum.map(tlv.subtlvs, fn subtlv ->
          if subtlv.type == 9 do  # Maximum Sustained Traffic Rate
            %{subtlv | value: <<speed::32>>}
          else
            subtlv
          end
        end)
        %{tlv | subtlvs: subtlvs}
      else
        tlv
      end
    end)
  end

  defp apply_customer_options(tlvs, opts) do
    tlvs
    |> maybe_add_static_ip(Keyword.get(opts, :static_ip))
    |> maybe_add_port_forwarding(Keyword.get(opts, :port_forwarding))
  end

  defp maybe_add_static_ip(tlvs, nil), do: tlvs
  defp maybe_add_static_ip(tlvs, ip) when is_binary(ip) do
    ip_tlv = %{
      type: 12,  # Modem IP Address
      length: 4,
      value: ip_to_binary(ip)
    }
    [ip_tlv | tlvs]
  end

  defp ip_to_binary(ip_string) do
    ip_string
    |> String.split(".")
    |> Enum.map(&String.to_integer/1)
    |> Enum.reduce(<<>>, fn octet, acc -> acc <> <<octet>> end)
  end
end
```

#### Monitoring and Analytics
```elixir
defmodule Examples.Analytics do
  def analyze_config_collection(config_dir) do
    config_dir
    |> File.ls!()
    |> Enum.filter(&String.ends_with?(&1, ".cm"))
    |> Enum.map(&Path.join(config_dir, &1))
    |> Enum.map(&analyze_single_config/1)
    |> Enum.reduce(%{}, &merge_analytics/2)
  end

  defp analyze_single_config(path) do
    case Bindocsis.parse_file(path) do
      {:ok, tlvs} ->
        %{
          path: path,
          tlv_count: length(tlvs),
          tlv_types: extract_tlv_stats(tlvs),
          docsis_features: detect_features(tlvs),
          estimated_version: estimate_docsis_version(tlvs),
          validation_status: validate_config(tlvs)
        }
      {:error, reason} ->
        %{path: path, error: reason}
    end
  end

  defp extract_tlv_stats(tlvs) do
    tlvs
    |> Enum.group_by(& &1.type)
    |> Enum.map(fn {type, occurrences} ->
      {type, %{
        count: length(occurrences),
        name: Bindocsis.DocsisSpecs.get_tlv_name(type),
        total_size: Enum.sum(Enum.map(occurrences, & &1.length))
      }}
    end)
    |> Enum.into(%{})
  end

  defp detect_features(tlvs) do
    types = Enum.map(tlvs, & &1.type)
    %{
      bonding: Enum.any?(types, &(&1 in [25, 26])),  # Downstream/Upstream Channel List
      packetcable: 64 in types,
      ipv6: Enum.any?(types, &(&1 in [67, 61])),  # IPv6 features
      security: Enum.any?(types, &(&1 in 30..42)),  # Security TLVs
      docsis_31: Enum.any?(types, &(&1 in 77..85))
    }
  end

  defp validate_config(tlvs) do
    case Bindocsis.Validation.validate_docsis_compliance(tlvs, "3.1") do
      :ok -> :valid
      {:error, _} -> :invalid
    end
  end
end
```

---

## Integration Patterns

### Phoenix Web Application

```elixir
defmodule MyAppWeb.DocsisController do
  use MyAppWeb, :controller

  def upload_config(conn, %{"config" => config_params}) do
    with {:ok, upload} <- handle_upload(config_params),
         {:ok, tlvs} <- Bindocsis.parse_file(upload.path),
         :ok <- Bindocsis.Validation.validate_docsis_compliance(tlvs, "3.1"),
         {:ok, json} <- Bindocsis.generate(tlvs, format: :json) do
      
      conn
      |> put_status(:ok)
      |> json(%{status: "success", config: json})
    else
      {:error, reason} ->
        conn
        |> put_status(:unprocessable_entity)
        |> json(%{status: "error", message: reason})
    end
  end

  def convert_format(conn, %{"input" => input, "format" => format}) do
    with {:ok, tlvs} <- parse_input(input),
         {:ok, output} <- Bindocsis.generate(tlvs, format: String.to_atom(format)) do
      
      conn
      |> put_resp_content_type(content_type_for_format(format))
      |> send_resp(200, output)
    else
      {:error, reason} ->
        conn
        |> put_status(:bad_request)
        |> json(%{error: reason})
    end
  end
end
```

### GenServer for Background Processing

```elixir
defmodule MyApp.DocsisProcessor do
  use GenServer

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  def process_config_async(config_path, callback) do
    GenServer.cast(__MODULE__, {:process_config, config_path, callback})
  end

  def init(_opts) do
    {:ok, %{queue: :queue.new(), processing: false}}
  end

  def handle_cast({:process_config, path, callback}, state) do
    new_queue = :queue.in({path, callback}, state.queue)
    new_state = %{state | queue: new_queue}
    
    if not state.processing do
      send(self(), :process_next)
      {:noreply, %{new_state | processing: true}}
    else
      {:noreply, new_state}
    end
  end

  def handle_info(:process_next, state) do
    case :queue.out(state.queue) do
      {{:value, {path, callback}}, new_queue} ->
        Task.start(fn ->
          result = Bindocsis.parse_file(path)
          callback.(result)
          send(self(), :process_next)
        end)
        {:noreply, %{state | queue: new_queue}}
      
      {:empty, _} ->
        {:noreply, %{state | processing: false}}
    end
  end
end
```

## Configuration Management

### Environment-Specific Settings

Bindocsis supports different configuration approaches for various deployment environments:

```elixir
# config/config.exs
config :bindocsis,
  default_docsis_version: "3.1",
  validation_level: :strict,
  output_format: :json,
  temp_dir: "/tmp/bindocsis"

# config/prod.exs
config :bindocsis,
  validation_level: :strict,
  enable_logging: true,
  max_file_size: 10_000_000  # 10MB
```

### Runtime Configuration

```elixir
# Set configuration at runtime
Bindocsis.configure(
  default_docsis_version: "3.0",
  validation_level: :permissive
)

# Get current configuration
config = Bindocsis.get_config()
```

## Performance Considerations

### Memory Usage

- Large configuration files are processed in streaming mode
- TLV structures are optimized for minimal memory footprint
- Validation can be disabled for performance-critical applications

### Benchmarking

```elixir
defmodule Bindocsis.Benchmark do
  def benchmark_parsing(file_path, iterations \\ 1000) do
    {time, _result} = :timer.tc(fn ->
      Enum.each(1..iterations, fn _ ->
        Bindocsis.parse_file(file_path)
      end)
    end)
    
    IO.puts("Average parse time: #{time / iterations / 1000} ms")
  end
end
```

## Security Considerations

### Input Validation

Always validate input files before processing:

```elixir
defmodule SecureProcessor do
  @max_file_size 1_000_000  # 1MB
  
  def safe_parse(file_path) do
    with {:ok, %{size: size}} <- File.stat(file_path),
         :ok <- validate_file_size(size),
         {:ok, content} <- File.read(file_path),
         :ok <- validate_content(content) do
      Bindocsis.parse(content)
    end
  end
  
  defp validate_file_size(size) when size > @max_file_size do
    {:error, "File too large"}
  end
  defp validate_file_size(_), do: :ok
  
  defp validate_content(content) do
    # Add content validation logic
    :ok
  end
end
```

## Testing

### Unit Testing

```elixir
defmodule BindocsisTest do
  use ExUnit.Case
  
  test "parses valid JSON configuration" do
    json_config = """
    {
      "tlvs": [
        {"type": 3, "length": 4, "value": "test"}
      ]
    }
    """
    
    assert {:ok, tlvs} = Bindocsis.parse(json_config, format: :json)
    assert length(tlvs) == 1
  end
  
  test "validates DOCSIS compliance" do
    tlvs = [%{type: 3, length: 4, value: "test"}]
    
    assert {:ok, _} = Bindocsis.Validation.validate_docsis_compliance(tlvs, "3.1")
  end
end
```

### Integration Testing

```elixir
defmodule BindocsisIntegrationTest do
  use ExUnit.Case
  
  test "end-to-end configuration processing" do
    input_file = "test/fixtures/sample_config.json"
    output_file = "test/tmp/output.bin"
    
    {:ok, tlvs} = Bindocsis.parse_file(input_file)
    {:ok, binary} = Bindocsis.generate(tlvs, format: :binary)
    :ok = Bindocsis.write_file(output_file, binary, format: :binary)
    
    assert File.exists?(output_file)
    {:ok, content} = File.read(output_file)
    assert byte_size(content) > 0
  end
end
```

## Troubleshooting

### Common Issues

#### Parse Errors

**Problem**: `{:error, "Invalid JSON format"}`
**Solution**: Validate JSON syntax using a JSON validator

**Problem**: `{:error, "Unknown TLV type"}`
**Solution**: Check if the TLV type is supported in the specified DOCSIS version

#### Validation Errors

**Problem**: `{:error, {:validation, "Invalid length"}}`
**Solution**: Ensure TLV length matches the actual value length

**Problem**: `{:error, {:validation, "Missing required TLV"}}`
**Solution**: Add required TLVs for the specified DOCSIS version

### Debug Mode

Enable debug logging for detailed information:

```elixir
# Enable debug logging
Logger.configure(level: :debug)

# Parse with debug information
{:ok, tlvs} = Bindocsis.parse(content, debug: true)
```

### Performance Issues

If experiencing slow parsing:

1. Check file size - consider streaming for large files
2. Disable validation for non-critical applications
3. Use binary format for better performance

## Changelog

### Version 1.0.0
- Initial release
- Support for DOCSIS 3.0 and 3.1
- JSON, YAML, and Binary format support
- Basic validation

### Version 1.1.0
- Added extended TLV support
- Improved error handling
- Performance optimizations
- CLI tool enhancements

### Version 1.2.0
- Added configuration templates
- Enhanced validation rules
- Better error messages
- Documentation improvements

## License

Bindocsis is released under the MIT License. See LICENSE file for details.

## Contributing

Contributions are welcome! Please read CONTRIBUTING.md for guidelines.

## Support

For issues and questions:
- GitHub Issues: [project repository]
- Documentation: [documentation site]
- Community: [discussion forum]
      send(self(), :process_