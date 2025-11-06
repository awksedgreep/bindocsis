# Bindocsis

A comprehensive DOCSIS configuration file parser and generator with human-friendly tools for cable modem configuration management.

## ✨ Features

- **✅ Complete DOCSIS Support**: Full support for DOCSIS 1.0, 1.1, 2.0, 3.0, and **3.1**
- **✅ DOCSIS 3.1 OFDM/OFDMA**: Complete TLV 62/63 support with 25 sub-TLV specifications
- **✅ Multiple Format Support**: Binary (.cm), JSON, YAML, and human-readable config files
- **✅ Round-Trip Conversion**: Lossless conversion between all supported formats
- **✅ Interactive Editor**: Built-in CLI for live configuration editing
- **✅ PacketCable/MTA Support**: ASN.1 parsing for MTA provisioning (TLV 64)
- **✅ Validation Framework**: DOCSIS version detection and compliance checking
- **✅ Human-Friendly Tools**: Easy bandwidth setting, configuration analysis
- **✅ Comprehensive Testing**: 1249+ tests with >85% code coverage

## 🚀 Quick Start - Human-Friendly Tools

### Set Bandwidth (Easy Way)
```bash
# Set upstream bandwidth to 75 Mbps
elixir -S mix run set_bandwidth.exs modem.cm 75M

# Set bandwidth with custom output file
elixir -S mix run set_bandwidth.exs modem.cm 100Mbps modem_100M.cm
```

### Analyze Configuration 
```bash
# Get human-readable analysis with bandwidth detection
elixir -S mix run describe_config.exs modem.cm

# Creates a pretty JSON file with configuration summary
```

### Pretty JSON Export
```bash
# Convert to pretty-formatted JSON (much more readable!)
elixir -S mix run -e '{:ok, tlvs} = Bindocsis.parse_file("modem.cm"); {:ok, json} = Bindocsis.generate(tlvs, format: :json, pretty: true); File.write!("modem_pretty.json", json)}'
```

### ⌨️ Interactive Configuration Editor
For more advanced and dynamic configuration management, `Bindocsis` provides an interactive command-line editor. This allows you to load, modify, validate, and save DOCSIS configurations in a live session.

To enter the interactive editor:
```bash
./bindocsis edit
# Or to edit an existing file:
./bindocsis edit modem.cm
```
Once inside the editor, you can exit by typing `quit` or `exit` and pressing Enter. For a comprehensive guide on all interactive commands and features, please refer to the [Interactive CLI Guide](docs/INTERACTIVE_CLI.md).

## Installation

If [available in Hex](https://hex.pm/docs/publish), the package can be installed
by adding `bindocsis` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:bindocsis, "~> 0.1.0"}
  ]
end
```

## Testing

The project includes comprehensive test suites organized by scope and execution speed. Tests are tagged to allow selective execution:

### Quick Tests (Default)
Run the core test suite excluding slow CLI and comprehensive fixture tests:
```bash
mix test
```

This excludes tests tagged with `:cli`, `:comprehensive_fixtures`, and `:performance` for faster feedback during development.

### CLI Tests
CLI tests are excluded by default as they involve system interactions and are slower. Run them specifically:
```bash
mix test --include cli
```

### Comprehensive Fixture Tests
Run tests with extensive fixture data (slower, more thorough):
```bash
mix test --include comprehensive_fixtures
```

### Performance Tests
Run performance benchmarks and stress tests (excluded by default):
```bash
mix test --include performance
```

### Full Test Suite
Run all tests including CLI, comprehensive fixtures, and performance tests:
```bash
mix test --include cli --include comprehensive_fixtures --include performance
```

### Test Categories
- **Unit Tests** (`test/unit/`): Fast, isolated component tests
- **Integration Tests** (`test/integration/`): Cross-component interaction tests
- **CLI Tests** (tagged `:cli`): Command-line interface tests
- **Comprehensive Tests** (tagged `:comprehensive_fixtures`): Extended fixture coverage
- **Performance Tests** (tagged `:performance`): Benchmarks and stress tests

### Continuous Integration
For CI environments, run the full test suite:
```bash
mix test --include cli --include comprehensive_fixtures --include performance --cover
```

## Documentation

Documentation can be generated with [ExDoc](https://github.com/elixir-lang/ex_doc)
and published on [HexDocs](https://hexdocs.pm). Once published, the docs can
be found at <https://hexdocs.pm/bindocsis>.

