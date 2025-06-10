# Bindocsis

**Professional DOCSIS Configuration File Parser, Converter & Validator**

[![Elixir](https://img.shields.io/badge/elixir-%23714A9C.svg?style=for-the-badge&logo=elixir&logoColor=white)](https://elixir-lang.org/)
[![DOCSIS](https://img.shields.io/badge/DOCSIS-3.0%20%7C%203.1-blue?style=for-the-badge)](https://www.cablelabs.com/technologies/docsis)
[![License](https://img.shields.io/badge/license-MIT-green?style=for-the-badge)](LICENSE)

> Transform, analyze, and validate DOCSIS configuration files with ease. Supporting all major formats and DOCSIS versions.

---

## 🚀 **What is Bindocsis?**

Bindocsis is a comprehensive toolkit for working with DOCSIS (Data Over Cable Service Interface Specification) configuration files. Whether you're a network engineer, cable technician, or developer building DOCSIS-related tools, Bindocsis provides the parsing, conversion, and validation capabilities you need.

### **Key Features**

- 🔄 **Multi-Format Support**: Binary (.cm), JSON, YAML, and human-readable config formats
- 📡 **Complete DOCSIS Coverage**: Full support for DOCSIS 1.0, 1.1, 2.0, 3.0, and 3.1 specifications
- 🎯 **141 TLV Types**: Comprehensive support for all standard and vendor-specific TLVs (1-255)
- ⚡ **High Performance**: Lightning-fast parsing and conversion with minimal memory overhead
- 🛡️ **Validation**: Built-in DOCSIS compliance checking and error detection
- 🖥️ **CLI & API**: Both command-line interface and programmatic API
- 🔧 **Developer Friendly**: Clean Elixir APIs with comprehensive documentation

---

## 📋 **Supported TLV Types**

| DOCSIS Version | TLV Range | Count | Description |
|----------------|-----------|-------|-------------|
| **DOCSIS 1.0-2.0** | 1-63 | 63 | Core DOCSIS parameters |
| **DOCSIS 3.0** | 64-76 | +13 | Bonding, L2VPN, PacketCable |
| **DOCSIS 3.1** | 77-85 | +9 | DLS, UNI, Dynamic Bonding |
| **Vendor Specific** | 200-255 | +56 | Vendor-defined extensions |
| **🎯 Total** | **1-255** | **141** | **Complete coverage** |

---

## 🚀 **Quick Start**

### **Installation**

```bash
# Clone the repository
git clone https://github.com/your-org/bindocsis.git
cd bindocsis

# Install dependencies
mix deps.get

# Compile the project
mix compile

# Build CLI executable
mix escript.build
```

### **Basic Usage**

```bash
# Parse a DOCSIS binary file
./bindocsis config.cm

# Convert binary to JSON
./bindocsis -i config.cm -o config.json -t json

# Convert JSON to YAML
./bindocsis -i config.json -o config.yaml -t yaml

# Validate DOCSIS compliance
./bindocsis validate config.cm --docsis-version 3.1

# Parse and convert in one step
./bindocsis -i config.cm -t yaml --validate
```

### **API Usage**

```elixir
# Parse a DOCSIS binary file
{:ok, tlvs} = Bindocsis.parse_file("config.cm")

# Convert to different formats
{:ok, json_data} = Bindocsis.generate(tlvs, format: :json)
{:ok, yaml_data} = Bindocsis.generate(tlvs, format: :yaml)

# Validate DOCSIS compliance
:ok = Bindocsis.Validation.validate_docsis_compliance(tlvs, "3.1")

# Get TLV information
{:ok, info} = Bindocsis.DocsisSpecs.get_tlv_info(68, "3.1")
# => %{name: "Default Upstream Target Buffer", description: "...", ...}
```

---

## 📊 **Supported Formats**

### **Input Formats**

| Format | Extension | Description | Example |
|--------|-----------|-------------|---------|
| **Binary** | `.cm` | Standard DOCSIS binary | `config.cm` |
| **JSON** | `.json` | Structured JSON data | `{"tlvs": [{"type": 3, "value": 1}]}` |
| **YAML** | `.yaml`, `.yml` | Human-readable YAML | `tlvs:\n  - type: 3\n    value: 1` |
| **Config** | `.conf`, `.txt` | Human-readable config | `network_access: enabled` |

### **Output Formats**

| Format | Description | Use Case |
|--------|-------------|----------|
| **Pretty** | Human-readable text | Analysis and debugging |
| **Binary** | DOCSIS binary format | Deployment to cable modems |
| **JSON** | Structured data | API integration, web apps |
| **YAML** | Configuration files | DevOps, version control |
| **Config** | Human-readable | Documentation, templates |

---

## 🖥️ **CLI Reference**

### **Basic Commands**

```bash
# Parse and display
bindocsis [file]                    # Parse and pretty-print
bindocsis --help                    # Show help
bindocsis --version                 # Show version

# Format conversion
bindocsis -i input.cm -o output.json -t json
bindocsis -i input.json -o output.yaml -t yaml
bindocsis -i input.cm -t json       # Output to stdout

# Validation
bindocsis validate config.cm
bindocsis validate config.cm --docsis-version 3.0
bindocsis -i config.cm --validate
```

### **Options**

| Option | Short | Description |
|--------|-------|-------------|
| `--input FILE` | `-i` | Input file or hex string |
| `--output FILE` | `-o` | Output file (default: stdout) |
| `--input-format FORMAT` | `-f` | Input format (auto\|binary\|json\|yaml) |
| `--output-format FORMAT` | `-t` | Output format (pretty\|binary\|json\|yaml) |
| `--docsis-version VER` | `-d` | DOCSIS version (3.0\|3.1) |
| `--validate` | `-V` | Validate DOCSIS compliance |
| `--verbose` | | Verbose output |
| `--quiet` | `-q` | Suppress output |
| `--help` | `-h` | Show help |
| `--version` | `-v` | Show version |

---

## 🏗️ **Architecture**

```
┌─────────────────────────────────────────────────────────────┐
│                        Bindocsis                            │
├─────────────────────────────────────────────────────────────┤
│  Input Parsers           │  Core Engine  │  Output Generators│
│  ┌─────────────────┐    │               │  ┌─────────────── │
│  │ Binary Parser   │    │               │  │ Pretty Print   │
│  │ JSON Parser     │    │               │  │ Binary Writer  │
│  │ YAML Parser     │────┤  TLV Engine   │──┤ JSON Generator │
│  │ Config Parser   │    │               │  │ YAML Generator │
│  └─────────────────┘    │               │  │ Config Writer  │
├─────────────────────────────────────────────────────────────┤
│                    DocsisSpecs Database                     │
│              (141 TLV Types - DOCSIS 1.0-3.1)              │
├─────────────────────────────────────────────────────────────┤
│                 CLI & API Interface                         │
├─────────────────────────────────────────────────────────────┤
│              Validation & Error Handling                    │
└─────────────────────────────────────────────────────────────┘
```

---

## 📖 **Examples**

### **Basic File Parsing**

```bash
# Parse a simple DOCSIS file
$ bindocsis basic_config.cm

Type: 3 (Network Access Control) Length: 1
Value: Enabled

Type: 1 (Downstream Frequency) Length: 4
Value: 93.0 MHz

Type: 24 (Upstream Service Flow Configuration) Length: 7
SubTLVs:
  Type: 1 (Service Flow Ref) Length: 2 Value: 1
  Type: 6 (Min Rsrvd Traffic Rate) Length: 1 Value: 7 bits/second
```

### **DOCSIS 3.1 Advanced TLVs**

```bash
# Parse file with DOCSIS 3.1 extensions
$ bindocsis advanced_3_1.cm

Type: 68 (Default Upstream Target Buffer) Length: 4
Description: Default upstream target buffer size
Value: 1000

Type: 77 (DLS Encoding) Length: 12
Description: Downstream Service (DLS) encoding
SubTLVs:
  Type: 1 (DLS Service Flow ID) Length: 4 Value: 100
  Type: 2 (DLS Application Identifier) Length: 4 Value: 200
```

### **Format Conversion**

```bash
# Convert binary to JSON
$ bindocsis -i config.cm -t json
{
  "docsis_version": "3.1",
  "tlvs": [
    {
      "type": 3,
      "length": 1,
      "value": "01"
    },
    {
      "type": 68,
      "length": 4,
      "value": "000003E8"
    }
  ]
}

# Convert to YAML
$ bindocsis -i config.cm -t yaml
docsis_version: "3.1"
tlvs:
  - type: 3
    length: 1
    value: "01"
  - type: 68
    length: 4
    value: "000003E8"
```

### **Validation**

```bash
# Validate DOCSIS compliance
$ bindocsis validate config.cm -d 3.1
✅ Configuration is valid for DOCSIS 3.1

$ bindocsis validate invalid.cm -d 3.0
❌ Validation failed:
  • TLV 77: Not supported in DOCSIS 3.0 (introduced in 3.1)
  • TLV 25: Missing required SubTLV 1 (Service Flow Reference)
```

---

## 🔧 **API Reference**

### **Core Functions**

```elixir
# File operations
{:ok, tlvs} = Bindocsis.parse_file("config.cm")
{:ok, tlvs} = Bindocsis.parse(binary_data)
:ok = Bindocsis.write_file(tlvs, "output.cm")

# Format conversion
{:ok, binary} = Bindocsis.generate(tlvs, format: :binary)
{:ok, json} = Bindocsis.generate(tlvs, format: :json)
{:ok, yaml} = Bindocsis.generate(tlvs, format: :yaml)

# Validation
:ok = Bindocsis.Validation.validate_docsis_compliance(tlvs, "3.1")
true = Bindocsis.DocsisSpecs.valid_tlv_type?(68, "3.1")
```

### **DocsisSpecs Module**

```elixir
# TLV information
{:ok, info} = Bindocsis.DocsisSpecs.get_tlv_info(68)
# => %{
#   name: "Default Upstream Target Buffer",
#   description: "Default upstream target buffer size",
#   introduced_version: "3.0",
#   subtlv_support: false,
#   value_type: :uint32,
#   max_length: 4
# }

# Version compatibility
types = Bindocsis.DocsisSpecs.get_supported_types("3.1")
# => [1, 2, 3, ..., 85, 200, 201, ..., 255]

true = Bindocsis.DocsisSpecs.supports_subtlvs?(77)
"DLS Encoding" = Bindocsis.DocsisSpecs.get_tlv_name(77)
```

---

## 🧪 **Testing**

```bash
# Run all tests
mix test

# Run specific test categories
mix test test/unit/
mix test test/integration/
mix test test/round_trip/

# Run with coverage
mix test --cover

# Performance benchmarks
mix run test_extended_tlvs.exs
```

---

## 🤝 **Contributing**

We welcome contributions! Please see our [Contributing Guide](CONTRIBUTING.md) for details.

### **Development Setup**

```bash
# Clone and setup
git clone https://github.com/your-org/bindocsis.git
cd bindocsis
mix deps.get

# Run tests
mix test

# Check code quality
mix format
mix credo
mix dialyzer
```

### **Areas for Contribution**

- 📝 **Documentation**: API docs, tutorials, examples
- 🧪 **Testing**: Additional test cases, edge cases
- 🚀 **Performance**: Optimization opportunities
- 🌐 **Formats**: Additional input/output formats
- 🔧 **Features**: New CLI commands, validation rules
- 🐛 **Bug Fixes**: Issue resolution and improvements

---

## 📚 **Documentation**

- **[Installation Guide](docs/INSTALLATION.md)** - Detailed installation instructions
- **[User Guide](docs/USER_GUIDE.md)** - Comprehensive usage guide
- **[API Reference](docs/API_REFERENCE.md)** - Complete API documentation
- **[CLI Reference](docs/CLI_REFERENCE.md)** - Command-line interface guide
- **[Format Specifications](docs/FORMAT_SPECIFICATIONS.md)** - Detailed format specs
- **[Examples](docs/EXAMPLES.md)** - Common use cases and examples
- **[Troubleshooting](docs/TROUBLESHOOTING.md)** - Common issues and solutions
- **[Development Guide](docs/DEVELOPMENT.md)** - Contributor guide

---

## 🏆 **Project Status**

| Phase | Status | Description |
|-------|--------|-------------|
| **Phase 1** | ✅ Complete | Foundation improvements |
| **Phase 2** | ✅ Complete | Multi-format support |
| **Phase 3** | ✅ Complete | Enhanced CLI interface |
| **Phase 4** | ✅ Complete | Comprehensive testing |
| **Phase 6** | ✅ Complete | DOCSIS 3.0/3.1 advanced TLV support |
| **Phase 7** | 🚧 In Progress | Documentation & user experience |

**Current Capabilities:**
- ✅ 141 TLV types supported (complete DOCSIS 1.0-3.1 coverage)
- ✅ Multi-format parsing and generation
- ✅ Professional CLI interface
- ✅ Comprehensive validation
- ✅ Production-ready performance
- ✅ Extensive test coverage

---

## 📄 **License**

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

---

## 📞 **Support & Contact**

- **Issues**: [GitHub Issues](https://github.com/your-org/bindocsis/issues)
- **Discussions**: [GitHub Discussions](https://github.com/your-org/bindocsis/discussions)
- **Documentation**: [Project Docs](docs/)
- **Email**: support@bindocsis.com

---

## 🌟 **Acknowledgments**

- CableLabs for DOCSIS specifications
- Elixir community for excellent tooling
- Contributors and testers
- DOCSIS community feedback

---

**Made with ❤️ in Elixir | Supporting the Cable Industry's Digital Future**

---

*Bindocsis: Because DOCSIS configuration management should be simple, reliable, and powerful.*