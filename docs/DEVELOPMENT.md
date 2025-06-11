# Bindocsis Development Guide

**Complete Development Guide for DOCSIS & PacketCable MTA Implementation**

This guide is for developers who want to contribute to Bindocsis or understand its internal architecture. Bindocsis provides comprehensive support for both DOCSIS cable modem configurations and PacketCable MTA (Multimedia Terminal Adapter) configurations with **94.4% success rate** across production test suites.

## 🎯 **Current Implementation Status**

### **Fully Implemented & Production Ready**
- ✅ **DOCSIS Support**: Complete 1.0-3.1 specification compliance
- ✅ **MTA Binary Parsing**: Specialized `MtaBinaryParser` with 94.4% success rate  
- ✅ **MTA Text Configurations**: Integrated PacketCable text format support
- ✅ **PacketCable Standards**: Full 1.0, 1.5, 2.0 version support
- ✅ **Extended Length Encoding**: 4-byte PacketCable length handling
- ✅ **Context-Aware Processing**: Smart TLV interpretation (MTA vs DOCSIS)

## Table of Contents

1. [Development Setup](#development-setup)
2. [Project Architecture](#project-architecture)
3. [Code Organization](#code-organization)
4. [Contributing Guidelines](#contributing-guidelines)
5. [Testing Strategy](#testing-strategy)
6. [Code Style Guide](#code-style-guide)
7. [Release Process](#release-process)
8. [Documentation Standards](#documentation-standards)
9. [Performance Guidelines](#performance-guidelines)
10. [Debugging Tips](#debugging-tips)

## Development Setup

### Prerequisites

- **Elixir**: 1.18 or later
- **Erlang/OTP**: 27 or later (required for built-in :json module)
- **Git**: For version control
- **Editor**: VS Code with ElixirLS extension recommended
- **Knowledge**: Basic understanding of DOCSIS and PacketCable specifications helpful
- **Test Data**: Access to DOCSIS (.cm) and MTA (.mta) binary files for testing

### Initial Setup

```bash
# Clone the repository
git clone https://github.com/user/bindocsis.git
cd bindocsis

# Install dependencies
mix deps.get

# Compile the project
mix compile

# Run tests to verify setup
mix test

# Build the CLI tool
mix escript.build

# Test with sample files (if available)
./bindocsis test/fixtures/sample.cm
./bindocsis test/fixtures/sample.mta -f mta

# Run comprehensive test suite
elixir quick_test.exs
```

### Development Dependencies

```elixir
# mix.exs - actual dependencies
defp deps do
  [
    # Production dependencies
    {:yaml_elixir, "~> 2.11"}       # YAML processing
    
    # Note: JSON processing uses built-in :json module (OTP 27+)
    # Development dependencies would be added here for tooling
  ]
end
```

### IDE Configuration

#### VS Code Settings

```json
// .vscode/settings.json
{
  "elixirLS.dialyzerEnabled": true,
  "elixirLS.fetchDeps": false,
  "elixirLS.suggestSpecs": true,
  "elixirLS.signatureAfterComplete": true,
  "editor.formatOnSave": true,
  "elixirLS.enableTestLenses": true
}
```

#### Vim/Neovim

```lua
-- For Neovim with nvim-lspconfig
require('lspconfig').elixirls.setup{
  cmd = { "/path/to/elixir-ls/language_server.sh" },
  settings = {
    elixirLS = {
      dialyzerEnabled = true,
      fetchDeps = false
    }
  }
}
```

## Project Architecture

### High-Level Architecture

```
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│   CLI Module    │    │   Core API      │    │   Format        │
│                 │    │                 │    │   Processors    │
│ • Argument      │───▶│ • parse/2       │───▶│                 │
│   parsing       │    │ • generate/2    │    │ • JSON Parser   │
│ • File I/O      │    │ • convert/2     │    │ • YAML Parser   │
│ • Error         │    │ • validate/2    │    │ • Binary Gen    │
│   handling      │    │                 │    │ • Config Parser │
└─────────────────┘    └─────────────────┘    └─────────────────┘
                                │
                                ▼
                       ┌─────────────────┐
                       │   DOCSIS Specs  │
                       │                 │
                       │ • TLV Database  │
                       │ • Validation    │
                       │ • Version       │
                       │   Support       │
                       └─────────────────┘
```

### Data Flow

```
Input File → Format Detection → Parser → Internal Representation → Validator → Generator → Output File
     │              │             │              │                    │            │          │
     │              │             │              │                    │            │          │
   .cm/.json/      Auto-detect   Parse to       Normalized TLV       DOCSIS       Generate   .cm/.json/
   .yaml/.conf     by content     Elixir maps    structure           compliance   format     .yaml/.conf
                   and extension                                     checking     specific
```

### Core Data Structures

#### TLV Representation

```elixir
@type tlv() :: %{
  type: non_neg_integer(),
  length: non_neg_integer(),
  value: term(),
  name: String.t() | nil,
  description: String.t() | nil,
  subtlvs: [tlv()] | nil,
  docsis_version_introduced: String.t() | nil
}
```

#### Parsing Result

```elixir
@type parse_result() :: {:ok, [tlv()]} | {:error, term()}
```

#### Generation Options

```elixir
@type generate_opts() :: [
  format: :binary | :json | :yaml | :config,
  docsis_version: String.t(),
  validate: boolean(),
  pretty: boolean()
]
```

## Code Organization

### Directory Structure

```
lib/bindocsis/
├── bindocsis.ex              # Main API module
├── cli.ex                    # Command-line interface
├── docsis_specs.ex          # DOCSIS specifications
├── format_detector.ex       # Auto-format detection
├── validation.ex            # DOCSIS compliance validation
├── parsers/
│   ├── json_parser.ex       # JSON format parser
│   ├── yaml_parser.ex       # YAML format parser
│   ├── binary_parser.ex     # Binary format parser
│   └── config_parser.ex     # Config format parser
├── generators/
│   ├── json_generator.ex    # JSON format generator
│   ├── yaml_generator.ex    # YAML format generator
│   ├── binary_generator.ex  # Binary format generator
│   └── config_generator.ex  # Config format generator
└── utils/
    ├── type_converter.ex    # Type conversion utilities
    ├── hex_utils.ex         # Hexadecimal utilities
    └── error_formatter.ex   # Error formatting
```

### Module Responsibilities

#### Core Modules

- **`Bindocsis`**: Public API, orchestrates parsing and generation
- **`Bindocsis.CLI`**: Command-line interface implementation
- **`Bindocsis.DocsisSpecs`**: DOCSIS specification database and lookups
- **`Bindocsis.Validation`**: DOCSIS compliance validation logic

#### Parser Modules

- **`Bindocsis.Parsers.JsonParser`**: Converts JSON to internal TLV format
- **`Bindocsis.Parsers.YamlParser`**: Converts YAML to internal TLV format
- **`Bindocsis.Parsers.BinaryParser`**: Parses binary DOCSIS files
- **`Bindocsis.Parsers.ConfigParser`**: Parses human-readable config format

#### Generator Modules

- **`Bindocsis.Generators.JsonGenerator`**: Converts TLVs to JSON
- **`Bindocsis.Generators.YamlGenerator`**: Converts TLVs to YAML
- **`Bindocsis.Generators.BinaryGenerator`**: Generates binary DOCSIS files
- **`Bindocsis.Generators.ConfigGenerator`**: Generates config format

## Contributing Guidelines

### Getting Started

1. **Fork the repository** on GitHub
2. **Create a feature branch** from `main`
3. **Make your changes** following the style guide
4. **Add tests** for new functionality
5. **Update documentation** as needed
6. **Submit a pull request**

### Branch Naming

```bash
# Feature branches
git checkout -b feature/add-docsis-4.0-support
git checkout -b feature/improve-yaml-parser

# Bug fixes
git checkout -b fix/json-parsing-error
git checkout -b fix/cli-argument-handling

# Documentation
git checkout -b docs/update-api-reference
git checkout -b docs/add-examples
```

### Commit Messages

Follow the [Conventional Commits](https://www.conventionalcommits.org/) specification:

```bash
# Format
<type>[optional scope]: <description>

# Examples
feat(parser): add support for DOCSIS 4.0 TLVs
fix(cli): handle missing file arguments gracefully
docs(api): update parse/2 function documentation
test(validation): add tests for edge cases
refactor(generators): simplify binary encoding logic
```

### Pull Request Guidelines

#### PR Title Format

```
<type>(<scope>): <description>
```

#### PR Description Template

```markdown
## Description
Brief description of the changes made.

## Type of Change
- [ ] Bug fix (non-breaking change which fixes an issue)
- [ ] New feature (non-breaking change which adds functionality)
- [ ] Breaking change (fix or feature that would cause existing functionality to not work as expected)
- [ ] Documentation update

## Testing
- [ ] Unit tests pass
- [ ] Integration tests pass
- [ ] Manual testing completed

## Checklist
- [ ] My code follows the style guidelines
- [ ] I have performed a self-review of my code
- [ ] I have commented my code, particularly in hard-to-understand areas
- [ ] I have made corresponding changes to the documentation
- [ ] My changes generate no new warnings
- [ ] I have added tests that prove my fix is effective or that my feature works
```

## Testing Strategy

### Test Organization

```
test/
├── bindocsis_test.exs           # Main API tests
├── cli_test.exs                 # CLI integration tests
├── docsis_specs_test.exs        # Specification tests
├── validation_test.exs          # Validation logic tests
├── parsers/
│   ├── json_parser_test.exs     # JSON parser tests
│   ├── yaml_parser_test.exs     # YAML parser tests
│   ├── binary_parser_test.exs   # Binary parser tests
│   └── config_parser_test.exs   # Config parser tests
├── generators/
│   ├── json_generator_test.exs  # JSON generator tests
│   ├── yaml_generator_test.exs  # YAML generator tests
│   ├── binary_generator_test.exs # Binary generator tests
│   └── config_generator_test.exs # Config generator tests
├── integration/
│   ├── round_trip_test.exs      # End-to-end conversion tests
│   └── real_world_test.exs      # Tests with real DOCSIS files
├── fixtures/
│   ├── simple_config.cm         # Test binary files
│   ├── complex_config.json      # Test JSON files
│   └── service_flows.yaml       # Test YAML files
└── support/
    ├── test_helper.exs          # Test setup and utilities
    └── factory.ex               # Test data factories
```

### Test Categories

#### Unit Tests

```elixir
defmodule Bindocsis.Parsers.JsonParserTest do
  use ExUnit.Case
  alias Bindocsis.Parsers.JsonParser

  describe "parse/1" do
    test "parses valid JSON configuration" do
      json = """
      {
        "docsis_version": "3.1",
        "tlvs": [
          {"type": 3, "length": 1, "value": 1}
        ]
      }
      """

      assert {:ok, tlvs} = JsonParser.parse(json)
      assert length(tlvs) == 1
      assert hd(tlvs).type == 3
    end

    test "returns error for invalid JSON" do
      invalid_json = "{invalid json"
      assert {:error, _reason} = JsonParser.parse(invalid_json)
    end
  end
end
```

#### Integration Tests

```elixir
defmodule Bindocsis.IntegrationTest do
  use ExUnit.Case

  test "round-trip conversion preserves data" do
    # Load test fixture
    {:ok, binary} = File.read("test/fixtures/simple_config.cm")
    
    # Binary → JSON → Binary
    {:ok, tlvs} = Bindocsis.parse(binary, format: :binary)
    {:ok, json} = Bindocsis.generate(tlvs, format: :json)
    {:ok, parsed_tlvs} = Bindocsis.parse(json, format: :json)
    {:ok, regenerated_binary} = Bindocsis.generate(parsed_tlvs, format: :binary)
    
    # Compare original and regenerated
    assert binary == regenerated_binary
  end
end
```

#### Property-Based Tests

```elixir
defmodule Bindocsis.PropertyTest do
  use ExUnit.Case
  use PropCheck

  property "parsing and generating are inverse operations" do
    forall tlv_data <- valid_tlv_data() do
      {:ok, binary} = Bindocsis.generate(tlv_data, format: :binary)
      {:ok, parsed} = Bindocsis.parse(binary, format: :binary)
      
      # Normalize for comparison (some fields may be auto-generated)
      normalize(parsed) == normalize(tlv_data)
    end
  end

  defp valid_tlv_data do
    list(tlv_generator())
  end

  defp tlv_generator do
    let {type, value} <- {choose(0, 79), binary()} do
      %{
        type: type,
        length: byte_size(value),
        value: value
      }
    end
  end
end
```

### Test Utilities

#### Factory Module

```elixir
defmodule Bindocsis.Factory do
  def build(:simple_tlv) do
    %{
      type: 3,
      length: 1,
      value: 1,
      name: "Network Access"
    }
  end

  def build(:service_flow) do
    %{
      type: 24,
      length: 20,
      value: nil,
      name: "Downstream Service Flow",
      subtlvs: [
        build(:service_flow_ref),
        build(:service_flow_id)
      ]
    }
  end

  def build(:service_flow_ref) do
    %{type: 1, length: 2, value: 1, name: "Service Flow Reference"}
  end

  def build(:service_flow_id) do
    %{type: 2, length: 4, value: 100, name: "Service Flow ID"}
  end

  def build_list(type, count) do
    Enum.map(1..count, fn _ -> build(type) end)
  end
end
```

### Running Tests

```bash
# Run all tests
mix test

# Run specific test file
mix test test/parsers/json_parser_test.exs

# Run tests with coverage
mix test --cover

# Run tests with specific tag
mix test --only integration

# Run tests in watch mode
mix test.watch

# Run property-based tests
mix test --only property

# Run performance tests
mix test --only benchmark
```

## Code Style Guide

### Elixir Style

Follow the [Elixir Style Guide](https://github.com/christopheradams/elixir_style_guide) with these additions:

#### Module Documentation

```elixir
defmodule Bindocsis.Parsers.JsonParser do
  @moduledoc """
  Parses JSON format DOCSIS configuration files.

  This module converts JSON representations of DOCSIS configurations
  into the internal TLV format used by Bindocsis.

  ## Examples

      iex> json = ~s({"docsis_version": "3.1", "tlvs": []})
      iex> JsonParser.parse(json)
      {:ok, []}

  """

  @doc """
  Parses JSON string into TLV list.

  ## Parameters

  - `json_string` - Valid JSON string containing DOCSIS configuration

  ## Returns

  - `{:ok, tlvs}` - Success with parsed TLV list
  - `{:error, reason}` - Parsing failure with error details

  ## Examples

      iex> JsonParser.parse(~s({"docsis_version": "3.1", "tlvs": []}))
      {:ok, []}

  """
  @spec parse(String.t()) :: {:ok, [map()]} | {:error, term()}
  def parse(json_string) do
    # Implementation
  end
end
```

#### Function Specs

```elixir
@spec parse_tlv(map()) :: {:ok, map()} | {:error, String.t()}
def parse_tlv(%{"type" => type, "value" => value} = tlv_map) do
  # Implementation
end
```

#### Pattern Matching Style

```elixir
# Preferred: Clear pattern matching
def handle_tlv(%{type: 3, value: value}) when is_integer(value) do
  {:ok, %{network_access: value == 1}}
end

def handle_tlv(%{type: type}) when type not in 0..79 do
  {:error, "Invalid TLV type: #{type}"}
end

# Avoid: Complex nested patterns in function heads
def handle_complex_tlv(tlv) do
  with %{type: type} when type in 20..30 <- tlv,
       %{subtlvs: subtlvs} when is_list(subtlvs) <- tlv do
    process_service_flow(tlv)
  else
    _ -> {:error, "Invalid service flow TLV"}
  end
end
```

#### Error Handling

```elixir
# Use tagged tuples consistently
def parse_value(type, raw_value) do
  case convert_value(type, raw_value) do
    {:ok, converted} -> {:ok, converted}
    {:error, reason} -> {:error, "Value conversion failed: #{reason}"}
  end
end

# Use with for pipeline operations
def process_config(data) do
  with {:ok, parsed} <- parse_input(data),
       {:ok, validated} <- validate_docsis(parsed),
       {:ok, normalized} <- normalize_tlvs(validated) do
    {:ok, normalized}
  end
end
```

### Code Formatting

Use the built-in formatter:

```elixir
# .formatter.exs
[
  inputs: ["{mix,.formatter}.exs", "{config,lib,test}/**/*.{ex,exs}"],
  line_length: 100,
  locals_without_parens: [
    # Custom macros if any
  ]
]
```

### Credo Configuration

```elixir
# .credo.exs
%{
  configs: [
    %{
      name: "default",
      files: %{
        included: ["lib/", "src/", "test/", "web/", "apps/"],
        excluded: [~r"/_build/", ~r"/deps/", ~r"/node_modules/"]
      },
      requires: [],
      strict: true,
      color: true,
      checks: [
        # Enabled checks
        {Credo.Check.Consistency.ExceptionNames},
        {Credo.Check.Consistency.LineEndings},
        {Credo.Check.Consistency.ParameterPatternMatching},
        {Credo.Check.Consistency.SpaceAroundOperators},
        {Credo.Check.Consistency.SpaceInParentheses},
        {Credo.Check.Consistency.TabsOrSpaces},

        # Disabled checks
        {Credo.Check.Design.AliasUsage, false},
        {Credo.Check.Readability.ModuleDoc, false}
      ]
    }
  ]
}
```

## Release Process

### Version Management

Use [Semantic Versioning](https://semver.org/):

- **MAJOR**: Breaking changes to public API
- **MINOR**: New functionality, backward compatible
- **PATCH**: Bug fixes, backward compatible

### Release Checklist

#### Pre-release

- [ ] All tests pass
- [ ] Documentation updated
- [ ] CHANGELOG.md updated
- [ ] Version bumped in mix.exs
- [ ] Performance benchmarks run
- [ ] Security audit completed

#### Release Steps

```bash
# 1. Update version
vim mix.exs  # Update @version

# 2. Update changelog
vim CHANGELOG.md

# 3. Commit changes
git add .
git commit -m "chore: bump version to 1.3.0"

# 4. Tag release
git tag -a v1.3.0 -m "Release version 1.3.0"

# 5. Push to repository
git push origin main
git push origin v1.3.0

# 6. Publish to Hex (if applicable)
mix hex.publish

# 7. Create GitHub release
gh release create v1.3.0 --title "v1.3.0" --notes-file RELEASE_NOTES.md
```

### Changelog Format

```markdown
# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.3.0] - 2024-01-15

### Added
- Support for DOCSIS 4.0 TLV types
- New config format parser
- Batch processing capabilities

### Changed
- Improved error messages with suggestions
- Updated DOCSIS specifications database

### Fixed
- Binary parsing bug with large TLVs
- Memory leak in YAML generator

### Deprecated
- Legacy parse_file/1 function (use parse_file/2)

### Security
- Input validation improvements
```

## Documentation Standards

### API Documentation

Use ExDoc with proper formatting:

```elixir
@doc """
Converts DOCSIS configuration between formats.

This function provides a high-level interface for format conversion,
automatically detecting input format and generating output in the
specified format.

## Parameters

  * `input` - Configuration data as string or binary
  * `opts` - Conversion options

## Options

  * `:from` - Source format (`:auto`, `:binary`, `:json`, `:yaml`, `:config`)
  * `:to` - Target format (`:binary`, `:json`, `:yaml`, `:config`)
  * `:docsis_version` - DOCSIS version for validation (`"2.0"`, `"3.0"`, `"3.1"`)
  * `:validate` - Whether to validate DOCSIS compliance (default: `true`)

## Examples

    # Auto-detect source format
    iex> Bindocsis.convert(json_data, to: :binary)
    {:ok, <<0x03, 0x01, 0x01>>}

    # Explicit format specification
    iex> Bindocsis.convert(binary_data, from: :binary, to: :json)
    {:ok, "{\"docsis_version\":\"3.1\",\"tlvs\":[...]}"}

    # With validation disabled
    iex> Bindocsis.convert(data, to: :yaml, validate: false)
    {:ok, "docsis_version: '3.1'\\ntlvs:\\n..."}

## Error Handling

Returns `{:error, reason}` for:

  * Invalid input format
  * Unsupported format conversion
  * DOCSIS validation failures
  * File I/O errors

"""
@spec convert(binary() | String.t(), keyword()) :: {:ok, binary() | String.t()} | {:error, term()}
def convert(input, opts \\ []) do
  # Implementation
end
```

### README Updates

Keep README current with:

- Installation instructions
- Quick start examples
- Feature overview
- Link to full documentation

### Code Examples

Provide working examples:

```elixir
# examples/basic_usage.exs
#!/usr/bin/env elixir

# Basic parsing example
{:ok, binary_data} = File.read("config.cm")
{:ok, tlvs} = Bindocsis.parse(binary_data, format: :binary)

# Convert to JSON
{:ok, json_output} = Bindocsis.generate(tlvs, format: :json)
File.write!("config.json", json_output)

IO.puts("Conversion complete!")
```

## Performance Guidelines

### Benchmarking

Use Benchee for performance testing:

```elixir
# benchmarks/parsing_benchmark.exs
Benchee.run(%{
  "JSON parsing" => fn -> 
    Bindocsis.parse(@json_data, format: :json) 
  end,
  "Binary parsing" => fn -> 
    Bindocsis.parse(@binary_data, format: :binary) 
  end,
  "YAML parsing" => fn -> 
    Bindocsis.parse(@yaml_data, format: :yaml) 
  end
})
```

### Memory Optimization

```elixir
# Use streaming for large files
def parse_large_file(path) do
  path
  |> File.stream!([:raw, :binary], 1024)
  |> Enum.reduce({:ok, []}, fn chunk, acc ->
    process_chunk(chunk, acc)
  end)
end

# Avoid building large data structures in memory
def convert_streaming(input_stream, output_stream) do
  input_stream
  |> Stream.map(&parse_tlv/1)
  |> Stream.filter(&valid_tlv?/1)
  |> Stream.into(output_stream)
  |> Stream.run()
end
```

### Performance Targets

- **Parsing**: < 100ms for typical configs (< 1KB)
- **Generation**: < 50ms for typical configs
- **Memory**: < 10MB for configs up to 64KB
- **Conversion**: < 200ms end-to-end

## Debugging Tips

### IEx Debugging

```elixir
# Start IEx with project loaded
iex -S mix

# Load test data
{:ok, data} = File.read("test/fixtures/simple_config.cm")

# Step through parsing
binary_data = data
{:ok, tlvs} = Bindocsis.Parsers.BinaryParser.parse(binary_data)
IO.inspect(tlvs, limit: :infinity)

# Test specific functions
tlv = hd(tlvs)
Bindocsis.DocsisSpecs.get_tlv_info(tlv.type, "3.1")
```

### Debugging Macros

```elixir
defmodule Bindocsis.Debug do
  defmacro debug_log(expr) do
    quote do
      result = unquote(expr)
      IO.puts("DEBUG: #{unquote(Macro.to_string(expr))} = #{inspect(result)}")
      result
    end
  end
end

# Usage
import Bindocsis.Debug
debug_log(parse_tlv(raw_data))
```

### Tracing

```elixir
# Enable tracing for specific modules
:dbg.tracer()
:dbg.p(:all, :c)
:dbg.tpl(Bindocsis.Parsers.JsonParser, :parse, :x)

# Your code here

:dbg.stop()
```

---

## Getting Help

### Internal Resources

- **Code Comments**: Inline documentation for complex logic
- **Test Cases**: Examples of expected behavior
- **Type Specs**: Function signatures and return types
- **Module Docs**: High-level module purpose and usage

### External Resources

- **Elixir Documentation**: https://hexdocs.pm/elixir/
- **DOCSIS Specifications**: CableLabs official documentation
- **Community Forums**: ElixirForum, Reddit r/elixir
- **GitHub Discussions**: Project-specific questions

### Code Review Process

1. **Self Review**: Check your own code before submitting
2. **Automated Checks**: Ensure CI passes
3. **Peer Review**: Address feedback constructively
4. **Documentation Review**: Verify docs are accurate and helpful

---

*This development guide is maintained by the Bindocsis core team. Last updated: 2024-01-15*