#!/usr/bin/env elixir

# Example demonstrating the DOCSIS configuration validation framework

Mix.install([{:bindocsis, path: "../"}])

alias Bindocsis.Validation.{Framework, Result}

IO.puts """
=== DOCSIS Configuration Validation Framework ===

Demonstrates three levels of validation:
1. Syntax - Binary structure and TLV format
2. Semantic - Value correctness and consistency
3. Compliance - DOCSIS version requirements
"""

# Example 1: Valid configuration
IO.puts "\n1. Valid Configuration:"
IO.puts String.duplicate("-", 50)

valid_tlvs = [
  %{type: 1, length: 4, value: <<591_000_000::32>>},  # Downstream Frequency
  %{type: 2, length: 1, value: <<3>>},                 # Upstream Channel ID
  %{type: 3, length: 1, value: <<1>>},                 # Network Access Enabled
  %{type: 6, length: 16, value: <<0::128>>},           # CM MIC (placeholder)
  %{type: 7, length: 16, value: <<0::128>>}            # CMTS MIC (placeholder)
]

{:ok, result} = Framework.validate(valid_tlvs)

IO.puts Framework.format_result(result)
IO.puts "\nStatistics: #{inspect(Framework.stats(result))}"

# Example 2: Configuration with errors
IO.puts "\n\n2. Configuration with Errors:"
IO.puts String.duplicate("-", 50)

invalid_tlvs = [
  %{type: 1, length: 4, value: <<2_000_000_000::32>>},  # Frequency out of range!
  %{type: 2, length: 1, value: <<255>>},                  # Channel ID
  %{type: 3, length: 1, value: <<2>>}                     # Invalid value (should be 0 or 1)
  # Missing required MIC TLVs!
]

{:ok, result2} = Framework.validate(invalid_tlvs)

IO.puts Framework.format_result(result2)

# Example 3: Version detection
IO.puts "\n\n3. DOCSIS Version Detection:"
IO.puts String.duplicate("-", 50)

docsis_10_config = [
  %{type: 1, length: 4, value: <<591_000_000::32>>},
  %{type: 2, length: 1, value: <<3>>}
]

docsis_31_config = [
  %{type: 1, length: 4, value: <<591_000_000::32>>},
  %{type: 62, length: 10, value: <<0::80>>}  # OFDM Profile (3.1 feature)
]

IO.puts "Basic config detected as: #{Framework.detect_version(docsis_10_config)}"
IO.puts "OFDM config detected as: #{Framework.detect_version(docsis_31_config)}"

# Example 4: Compliance validation for wrong version
IO.puts "\n\n4. Version Compliance Checking:"
IO.puts String.duplicate("-", 50)

# Try to use DOCSIS 3.1 TLV in 3.0 config
{:ok, result3} = Framework.validate(docsis_31_config, 
  level: :compliance,
  docsis_version: "3.0"  # Force 3.0 validation
)

IO.puts Framework.format_result(result3)

# Example 5: Strict mode (warnings become errors)
IO.puts "\n\n5. Strict Mode:"
IO.puts String.duplicate("-", 50)

config_with_duplicates = [
  %{type: 1, length: 4, value: <<591_000_000::32>>},
  %{type: 1, length: 4, value: <<600_000_000::32>>},  # Duplicate!
  %{type: 2, length: 1, value: <<3>>},
  %{type: 3, length: 1, value: <<1>>},
  %{type: 6, length: 16, value: <<0::128>>},
  %{type: 7, length: 16, value: <<0::128>>}
]

# Normal mode - duplicate is a warning
{:ok, normal_result} = Framework.validate(config_with_duplicates)
IO.puts "Normal mode: #{if normal_result.valid?, do: "VALID", else: "INVALID"}"
IO.puts "  Errors: #{length(normal_result.errors)}, Warnings: #{length(normal_result.warnings)}"

# Strict mode - warnings become errors
{:ok, strict_result} = Framework.validate(config_with_duplicates, strict: true)
IO.puts "\nStrict mode: #{if strict_result.valid?, do: "VALID", else: "INVALID"}"
IO.puts "  Errors: #{length(strict_result.errors)}, Warnings: #{length(strict_result.warnings)}"

# Example 6: Batch validation
IO.puts "\n\n6. Batch Validation:"
IO.puts String.duplicate("-", 50)

configs = %{
  "config_a" => valid_tlvs,
  "config_b" => invalid_tlvs,
  "config_c" => docsis_31_config
}

{:ok, batch_results} = Framework.validate_batch(configs)

Enum.each(batch_results, fn {name, res} ->
  status = if res.valid?, do: "✓ VALID", else: "✗ INVALID"
  stats = Framework.stats(res)
  IO.puts "  #{name}: #{status} (#{stats.errors} errors, #{stats.warnings} warnings)"
end)

# Example 7: Service Flow validation
IO.puts "\n\n7. Service Flow Validation:"
IO.puts String.duplicate("-", 50)

service_flow_config = [
  %{type: 1, length: 4, value: <<591_000_000::32>>},
  %{type: 2, length: 1, value: <<3>>},
  %{type: 3, length: 1, value: <<1>>},
  %{type: 17, length: 20, value: <<0::160>>,  # Upstream Service Flow
    subtlvs: [
      # Missing SF Reference (sub-TLV 1)!
      %{type: 8, length: 4, value: <<1000000::32>>},  # Max rate
      %{type: 9, length: 4, value: <<2000000::32>>}   # Min rate > max rate!
    ]
  },
  %{type: 6, length: 16, value: <<0::128>>},
  %{type: 7, length: 16, value: <<0::128>>}
]

{:ok, sf_result} = Framework.validate(service_flow_config)

IO.puts Framework.format_result(sf_result)

IO.puts "\n\n=== Summary ==="
IO.puts """
The validation framework provides:
✓ Three-level validation (syntax, semantic, compliance)
✓ Automatic DOCSIS version detection
✓ Required TLV checking
✓ Value range validation
✓ Service flow consistency checks
✓ Duplicate detection
✓ Strict mode option
✓ Batch validation support
✓ Detailed error/warning/info reporting
"""
