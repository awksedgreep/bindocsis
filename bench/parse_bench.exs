# Bindocsis Performance Benchmarks
#
# Run with: mix run bench/parse_bench.exs
#
# This benchmark suite measures:
# - Parse performance for different file sizes
# - JSON/YAML/Binary format conversion
# - Round-trip conversion efficiency
# - Memory usage

# Generate test data
defmodule BenchmarkData do
  def small_config do
    # ~500 bytes
    [
      %{type: 1, length: 4, value: <<591_000_000::32>>},
      %{type: 2, length: 1, value: <<3>>},
      %{type: 3, length: 1, value: <<1>>},
      %{type: 21, length: 1, value: <<5>>},
      %{type: 6, length: 16, value: <<0::128>>},
      %{type: 7, length: 16, value: <<0::128>>}
    ]
  end
  
  def medium_config do
    # ~5KB with service flows
    small_config() ++ [
      %{type: 17, length: 50, value: <<0::400>>,
        subtlvs: [
          %{type: 1, length: 2, value: <<1::16>>},
          %{type: 8, length: 4, value: <<10_000_000::32>>},
          %{type: 9, length: 4, value: <<1_000_000::32>>}
        ]
      },
      %{type: 18, length: 50, value: <<0::400>>,
        subtlvs: [
          %{type: 1, length: 2, value: <<2::16>>},
          %{type: 8, length: 4, value: <<100_000_000::32>>},
          %{type: 9, length: 4, value: <<10_000_000::32>>}
        ]
      }
    ]
  end
  
  def large_config do
    # ~50KB with multiple service flows
    base = medium_config()
    
    # Add 20 more service flows
    service_flows = for i <- 1..20 do
      %{type: 17, length: 50, value: <<0::400>>,
        subtlvs: [
          %{type: 1, length: 2, value: <<i::16>>},
          %{type: 8, length: 4, value: <<10_000_000::32>>},
          %{type: 9, length: 4, value: <<1_000_000::32>>}
        ]
      }
    end
    
    base ++ service_flows
  end
  
  def generate_binary(tlvs) do
    {:ok, binary} = Bindocsis.generate(tlvs, format: :binary)
    binary
  end
end

IO.puts """
=== Bindocsis Performance Benchmarks ===

Testing parse and generation performance across different
file sizes and formats.

Generating test data...
"""

# Prepare test data
small_tlvs = BenchmarkData.small_config()
medium_tlvs = BenchmarkData.medium_config()
large_tlvs = BenchmarkData.large_config()

small_binary = BenchmarkData.generate_binary(small_tlvs)
medium_binary = BenchmarkData.generate_binary(medium_tlvs)
large_binary = BenchmarkData.generate_binary(large_tlvs)

{:ok, small_json} = Bindocsis.generate(small_tlvs, format: :json)
{:ok, medium_json} = Bindocsis.generate(medium_tlvs, format: :json)

IO.puts """
Test data sizes:
  Small:  #{byte_size(small_binary)} bytes (#{length(small_tlvs)} TLVs)
  Medium: #{byte_size(medium_binary)} bytes (#{length(medium_tlvs)} TLVs)
  Large:  #{byte_size(large_binary)} bytes (#{length(large_tlvs)} TLVs)

Running benchmarks...
"""

Benchee.run(
  %{
    # Parse benchmarks
    "parse_small_binary" => fn ->
      Bindocsis.parse(small_binary, format: :binary)
    end,
    
    "parse_medium_binary" => fn ->
      Bindocsis.parse(medium_binary, format: :binary)
    end,
    
    "parse_large_binary" => fn ->
      Bindocsis.parse(large_binary, format: :binary)
    end,
    
    "parse_small_json" => fn ->
      Bindocsis.parse(small_json, format: :json)
    end,
    
    "parse_medium_json" => fn ->
      Bindocsis.parse(medium_json, format: :json)
    end,
    
    # Generation benchmarks
    "generate_small_binary" => fn ->
      Bindocsis.generate(small_tlvs, format: :binary)
    end,
    
    "generate_medium_binary" => fn ->
      Bindocsis.generate(medium_tlvs, format: :binary)
    end,
    
    "generate_small_json" => fn ->
      Bindocsis.generate(small_tlvs, format: :json)
    end,
    
    "generate_medium_json" => fn ->
      Bindocsis.generate(medium_tlvs, format: :json)
    end,
    
    # Round-trip benchmarks
    "round_trip_small" => fn ->
      {:ok, tlvs} = Bindocsis.parse(small_binary, format: :binary)
      {:ok, _binary} = Bindocsis.generate(tlvs, format: :binary)
    end,
    
    "round_trip_medium" => fn ->
      {:ok, tlvs} = Bindocsis.parse(medium_binary, format: :binary)
      {:ok, _binary} = Bindocsis.generate(tlvs, format: :binary)
    end,
    
    # Format conversion benchmarks
    "binary_to_json_small" => fn ->
      {:ok, tlvs} = Bindocsis.parse(small_binary, format: :binary)
      {:ok, _json} = Bindocsis.generate(tlvs, format: :json)
    end,
    
    "json_to_binary_small" => fn ->
      {:ok, tlvs} = Bindocsis.parse(small_json, format: :json)
      {:ok, _binary} = Bindocsis.generate(tlvs, format: :binary)
    end,
    
    # Validation benchmarks
    "validate_small" => fn ->
      Bindocsis.Validation.Framework.validate(small_tlvs)
    end,
    
    "validate_medium" => fn ->
      Bindocsis.Validation.Framework.validate(medium_tlvs)
    end,
    
    "validate_large" => fn ->
      Bindocsis.Validation.Framework.validate(large_tlvs)
    end
  },
  time: 3,
  memory_time: 2,
  reduction_time: 1,
  formatters: [
    Benchee.Formatters.Console,
    {Benchee.Formatters.HTML, file: "bench/results.html"}
  ],
  print: [
    fast_warning: false
  ]
)

IO.puts """

Benchmark complete!
Results saved to: bench/results.html
"""
