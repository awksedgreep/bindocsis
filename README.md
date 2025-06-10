# Bindocsis

**TODO: Add description**

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

