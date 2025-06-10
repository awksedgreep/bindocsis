# Testing Guide

This document provides comprehensive information about testing in the Bindocsis project, including test organization, execution strategies, and best practices.

## Overview

Bindocsis uses a multi-tiered testing approach with different test categories optimized for various development workflows:

- **Quick Tests**: Fast unit and integration tests for rapid development feedback
- **CLI Tests**: Command-line interface integration tests
- **Comprehensive Tests**: Extensive fixture-based tests for thorough validation
- **Performance Tests**: Benchmarking and stress tests (excluded by default for speed)

## Test Organization

### Directory Structure

```
test/
├── fixtures/                    # Test data files
│   ├── BaseConfig.cm           # Binary DOCSIS config
│   ├── sample.json             # JSON test data
│   └── sample.yaml             # YAML test data
├── integration/                # Cross-component tests
│   ├── cli_test.exs           # CLI integration tests (tagged :cli)
│   └── round_trip_test.exs    # Format conversion tests
├── unit/                      # Component-specific tests
│   ├── core/                  # Core parsing logic
│   ├── parsers/               # Format parser tests
│   └── generators/            # Output generator tests
├── support/                   # Test helpers and utilities
│   └── cli_test_helper.ex     # CLI testing utilities
└── test_helper.exs           # Global test configuration
```

### Test Categories and Tags

Tests are organized using ExUnit tags to enable selective execution:

#### `:cli` Tag
- **Purpose**: Command-line interface integration tests
- **Characteristics**: Slower, involves system interactions, file I/O
- **When to run**: Before releases, when modifying CLI functionality
- **Default**: Excluded from regular test runs

#### `:comprehensive_fixtures` Tag
- **Purpose**: Extensive fixture-based testing
- **Characteristics**: Large datasets, thorough edge case coverage
- **When to run**: CI/CD pipelines, comprehensive validation
- **Default**: Excluded from regular test runs

#### `:performance` Tag
- **Purpose**: Performance benchmarks and stress tests
- **Characteristics**: Intentionally slow, large data processing, timing measurements
- **When to run**: Performance analysis, regression testing, optimization work
- **Default**: Excluded from regular test runs

#### Untagged Tests
- **Purpose**: Core functionality, unit tests, fast integration tests
- **Characteristics**: Fast execution, frequent feedback
- **When to run**: During development, every commit
- **Default**: Always included

## Running Tests

### Quick Development Workflow

```bash
# Fast tests for immediate feedback (default)
mix test

# Equivalent to:
# mix test --exclude cli --exclude comprehensive_fixtures --exclude performance
```

**Use case**: Regular development, quick validation of changes
**Execution time**: ~1-2 seconds
**Coverage**: Core functionality, basic integration

### CLI Testing

```bash
# Run CLI tests specifically
mix test --include cli

# Run only CLI tests
mix test --include cli --exclude comprehensive_fixtures test/integration/cli_test.exs
```

**Use case**: Debugging CLI issues, validating command-line behavior
**Execution time**: ~5-10 seconds
**Coverage**: Command parsing, error handling, output formatting

### Comprehensive Testing

```bash
# Run comprehensive fixture tests
mix test --include comprehensive_fixtures

# Full test suite (everything)
mix test --include cli --include comprehensive_fixtures --include performance
```

**Use case**: Pre-release validation, CI/CD pipelines
**Execution time**: ~30-60 seconds
**Coverage**: Edge cases, large datasets, extensive format validation

### Performance Testing

```bash
# Run performance benchmarks only
mix test --include performance

# Performance tests with other categories
mix test --include performance --include cli
```

**Use case**: Performance analysis, optimization work, regression detection
**Execution time**: ~10-30 seconds
**Coverage**: Benchmarks, stress tests, timing validation

### Test Runner Script

The project includes a convenient test runner script with predefined configurations:

```bash
# Quick tests (default)
./test_runner.sh quick

# CLI tests only
./test_runner.sh cli

# Comprehensive fixture tests
./test_runner.sh comprehensive

# Integration tests (includes CLI)
./test_runner.sh integration

# Performance benchmarks
./test_runner.sh performance

# Full test suite
./test_runner.sh full

# Unit tests only
./test_runner.sh unit

# Coverage report
./test_runner.sh coverage

# Watch mode (requires mix_test_watch)
./test_runner.sh watch
```

#### Script Options

```bash
# Verbose output
./test_runner.sh quick --verbose

# Specific seed for reproducibility
./test_runner.sh unit --seed 12345

# Limit concurrent test cases
./test_runner.sh full --maxcases 4

# Generate coverage report
./test_runner.sh full --coverage

# Run performance tests with timing
./test_runner.sh performance --verbose
```

## Test Types

### Unit Tests

**Location**: `test/unit/`
**Purpose**: Test individual components in isolation
**Characteristics**:
- Fast execution (< 1ms per test)
- No external dependencies
- Focused on single functions/modules
- Mock external interactions

**Example**:
```elixir
defmodule Bindocsis.ParserTest do
  use ExUnit.Case
  
  test "parses basic TLV structure" do
    binary = <<1, 4, 192, 168, 1, 1>>
    assert {:ok, [%{type: 1, length: 4, value: <<192, 168, 1, 1>>}]} = 
           Bindocsis.parse(binary)
  end
end
```

### Integration Tests

**Location**: `test/integration/`
**Purpose**: Test component interactions and data flow
**Characteristics**:
- Moderate execution time (1-100ms per test)
- Multiple components working together
- Real data flows
- File system interactions

**Example**:
```elixir
defmodule Bindocsis.Integration.RoundTripTest do
  use ExUnit.Case
  
  test "binary to JSON to binary preserves data" do
    {:ok, original_tlvs} = Bindocsis.parse(binary_data)
    {:ok, json_data} = Bindocsis.Generators.JsonGenerator.generate(original_tlvs)
    {:ok, parsed_tlvs} = Bindocsis.Parsers.JsonParser.parse(json_data)
    {:ok, result_binary} = Bindocsis.Generators.BinaryGenerator.generate(parsed_tlvs)
    
    assert binary_data == result_binary
  end
end
```

### CLI Tests

**Location**: `test/integration/cli_test.exs`
**Tag**: `:cli`
**Purpose**: Test command-line interface functionality
**Characteristics**:
- System-level interactions
- File I/O operations
- Process spawning
- Error condition handling

**Example**:
```elixir
defmodule Bindocsis.Integration.CLITest do
  use ExUnit.Case
  @moduletag :cli
  
  test "converts binary to JSON via CLI" do
    result = CliTestHelper.run_cli([
      "--input", "test/fixtures/BaseConfig.cm",
      "--output-format", "json"
    ])
    
    assert result == :ok
  end
end
```

### Performance Tests

**Purpose**: Validate performance characteristics
**Characteristics**:
- Benchmark execution times
- Memory usage validation
- Scalability testing
- Regression detection

**Example**:
```elixir
@tag :performance
test "processes large configurations efficiently" do
  large_config = generate_large_test_config(1000)
  
  {time_us, {:ok, _result}} = :timer.tc(fn ->
    Bindocsis.parse(large_config)
  end)
  
  # Should process 1000 TLVs in under 100ms
  assert time_us < 100_000
end
```

## Best Practices

### Test Naming

```elixir
# Good: Descriptive, indicates expected behavior
test "parses downstream frequency TLV with valid 4-byte value"
test "rejects invalid DOCSIS version in CLI arguments"
test "converts binary config to JSON preserving all TLV types"

# Avoid: Vague or implementation-focused
test "test_parser"
test "check_tlv_function"
test "binary_to_json"
```

### Test Organization

```elixir
describe "TLV parsing" do
  test "handles valid single TLV" do
    # Test implementation
  end
  
  test "handles multiple TLVs" do
    # Test implementation
  end
  
  test "rejects malformed TLV" do
    # Test implementation
  end
end

describe "error conditions" do
  test "returns error for truncated data" do
    # Test implementation
  end
end
```

### Fixture Management

```elixir
# Use module attributes for reusable test data
@valid_tlv_binary <<1, 4, 192, 168, 1, 1>>
@invalid_tlv_binary <<1, 255>>  # Length exceeds available data

# Use setup callbacks for complex fixtures
setup do
  config_file = create_temp_config()
  on_exit(fn -> File.rm!(config_file) end)
  {:ok, config_file: config_file}
end
```

### Assertion Best Practices

```elixir
# Good: Specific assertions
assert {:ok, [%{type: 1, length: 4}]} = result
assert_in_delta 42.0, result, 0.001
assert String.contains?(output, "Error: Invalid TLV")

# Good: Pattern matching for complex structures
assert {:ok, [
  %{type: 1, value: value1},
  %{type: 2, value: value2}
]} = result

# Avoid: Generic assertions
assert result != nil
assert length(result) > 0
```

## Continuous Integration

### CI Configuration

```yaml
# .github/workflows/test.yml example
test:
  runs-on: ubuntu-latest
  steps:
    - uses: actions/checkout@v2
    - uses: erlef/setup-beam@v1
      with:
        elixir-version: '1.14'
        otp-version: '25'
    
    - name: Install dependencies
      run: mix deps.get
    
    - name: Run quick tests
      run: mix test
    
    - name: Run full test suite
      run: mix test --include cli --include comprehensive_fixtures
    
    - name: Generate coverage report
      run: mix test --cover --include cli --include comprehensive_fixtures
```

### Test Stages

1. **Quick Tests**: Run on every commit/PR (~1.4s)
2. **CLI Tests**: Run on CLI-related changes and releases (~30s)
3. **Comprehensive Tests**: Run on release candidates and main branch (~60s)
4. **Performance Tests**: Run nightly, on performance-related changes, or before releases (~30s)

## Debugging Tests

### Common Issues

#### CLI Tests Failing
```bash
# Run CLI tests with verbose output
./test_runner.sh cli --verbose

# Run specific CLI test
mix test test/integration/cli_test.exs:123 --include cli
```

#### Performance Test Variability
```bash
# Use fixed seed for reproducible results
mix test --seed 12345

# Run with single process to avoid timing variations
mix test --max-cases 1
```

#### Fixture-Related Issues
```bash
# Check fixture files exist
ls test/fixtures/

# Verify fixture content
file test/fixtures/BaseConfig.cm
hexdump -C test/fixtures/BaseConfig.cm | head
```

### Test Utilities

The project provides test utilities in `test/support/`:

- `CliTestHelper`: CLI testing without system halts
- Fixture generators for different data types
- Assertion helpers for complex data structures

## Coverage Reports

Generate coverage reports to identify untested code:

```bash
# Basic coverage
mix test --cover

# Detailed HTML coverage report
mix test --cover --include cli --include comprehensive_fixtures

# Coverage report location
open cover/excoveralls.html
```

Target coverage goals:
- **Unit tests**: > 95% line coverage
- **Integration paths**: > 90% line coverage
- **CLI commands**: > 85% line coverage

## Performance Monitoring

Track test execution times to detect performance regressions:

```bash
# Time individual test suites
time mix test test/unit/
time mix test test/integration/ --include cli

# Profile specific tests
mix test --trace test/integration/round_trip_test.exs
```

Expected benchmarks:
- Quick tests (default): < 2 seconds total
- Unit tests: < 5 seconds total
- Integration tests (no CLI): < 10 seconds total
- CLI tests: < 30 seconds total
- Performance tests: < 30 seconds total
- Full suite: < 90 seconds total

---

For questions about testing or to report testing issues, please refer to the project's issue tracker or development documentation.