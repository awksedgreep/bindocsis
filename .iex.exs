# Bindocsis Interactive Testing Helpers
# =====================================
# This file provides convenient functions for testing the recursive parser
# and other Bindocsis functionality in IEx.

defmodule IExHelpers do
  @moduledoc """
  Interactive testing helpers for Bindocsis.

  Available functions:
  - parse_file/1, parse_file/2 - Parse a single file
  - parse_dir/1, parse_dir/2 - Parse all files in a directory
  - test_formats/1 - Test all supported formats on a file
  - perf/1, perf/2 - Performance testing
  - demo/0 - Run demonstration of recursive parsing
  - create_test_config/0 - Create sample config for testing
  """

  require Logger

  @doc """
  Parse a single file and display results.

  ## Examples

      iex> parse_file("test/fixtures/BaseConfig.cm")
      iex> parse_file("test.conf", format: :config)
      iex> parse_file("test/fixtures/BaseConfig.cm", format: :binary, enhanced: true, verbose: true)
  """
  def parse_file(path, opts \\ []) do
    IO.puts("🔄 Parsing file: #{path}")

    case Bindocsis.parse_file(path, opts) do
      {:ok, tlvs} ->
        IO.puts("✅ Successfully parsed #{length(tlvs)} TLVs")

        if Keyword.get(opts, :verbose, false) do
          IO.puts("\n📋 TLV Details:")
          Enum.each(tlvs, &Bindocsis.pretty_print/1)
        else
          IO.puts("💡 Add `verbose: true` to see TLV details")
        end

        tlvs

      {:error, reason} ->
        IO.puts("❌ Parse error: #{reason}")
        nil
    end
  end

  @doc """
  Parse all files in a directory.

  ## Examples

      iex> parse_dir("test/fixtures")
      iex> parse_dir("configs", pattern: "*.conf")
  """
  def parse_dir(dir_path, opts \\ []) do
    pattern = Keyword.get(opts, :pattern, "*")
    full_pattern = Path.join(dir_path, pattern)

    files = Path.wildcard(full_pattern)

    if length(files) == 0 do
      IO.puts("⚠️  No files found matching: #{full_pattern}")
      %{}
    else

    IO.puts("🔍 Found #{length(files)} files in #{dir_path}")
    IO.puts("📁 Pattern: #{pattern}")
    IO.puts("")

      results = %{}

      results = Enum.reduce(files, results, fn file, acc ->
        IO.write("Processing #{Path.basename(file)}... ")

        case Bindocsis.parse_file(file, opts) do
          {:ok, tlvs} ->
            IO.puts("✅ #{length(tlvs)} TLVs")
            Map.put(acc, file, {:ok, tlvs})

          {:error, reason} ->
            IO.puts("❌ Error: #{reason}")
            Map.put(acc, file, {:error, reason})
        end
      end)

      # Summary
      successes = Enum.count(results, fn {_, result} -> match?({:ok, _}, result) end)
      failures = Enum.count(results, fn {_, result} -> match?({:error, _}, result) end)

      IO.puts("")
      IO.puts("📊 Summary: #{successes} successful, #{failures} failed")

      if Keyword.get(opts, :show_errors, false) and failures > 0 do
        IO.puts("\n❌ Failed files:")
        Enum.each(results, fn
          {file, {:error, reason}} ->
            IO.puts("  • #{Path.basename(file)}: #{reason}")
          _ -> :ok
        end)
      end

      results
    end
  end

  @doc """
  Test all supported formats on a file.

  ## Examples

      iex> test_formats("test/fixtures/BaseConfig.cm")
  """
  def test_formats(file_path) do
    formats = [:auto, :binary, :config, :json, :yaml]

    IO.puts("🧪 Testing all formats on: #{Path.basename(file_path)}")
    IO.puts("")

    results =
      Enum.map(formats, fn format ->
        IO.write("Format #{format}... ")

        result = case Bindocsis.parse_file(file_path, format: format) do
          {:ok, tlvs} ->
            IO.puts("✅ #{length(tlvs)} TLVs")
            {:ok, tlvs}

          {:error, reason} ->
            IO.puts("❌ #{reason}")
            {:error, reason}
        end

        {format, result}
      end)

    # Show which formats worked
    working_formats =
      results
      |> Enum.filter(fn {_, result} -> match?({:ok, _}, result) end)
      |> Enum.map(fn {format, _} -> format end)

    IO.puts("")
    IO.puts("✅ Working formats: #{inspect(working_formats)}")

    results
  end

  @doc """
  Performance test for parsing.

  ## Examples

      iex> perf("test/fixtures/BaseConfig.cm")
      iex> perf("test/fixtures/BaseConfig.cm", iterations: 1000)
  """
  def perf(file_path, opts \\ []) do
    iterations = Keyword.get(opts, :iterations, 100)

    IO.puts("⚡ Performance testing: #{Path.basename(file_path)}")
    IO.puts("🔄 Iterations: #{iterations}")

    # Warm up
    Bindocsis.parse_file(file_path)

    {time_microseconds, results} = :timer.tc(fn ->
      Enum.map(1..iterations, fn _ ->
        Bindocsis.parse_file(file_path)
      end)
    end)

    successes = Enum.count(results, &match?({:ok, _}, &1))
    failures = iterations - successes

    avg_time_ms = time_microseconds / iterations / 1000

    IO.puts("")
    IO.puts("📊 Results:")
    IO.puts("  • Total time: #{Float.round(time_microseconds / 1000, 2)}ms")
    IO.puts("  • Average per parse: #{Float.round(avg_time_ms, 3)}ms")
    IO.puts("  • Successes: #{successes}")
    IO.puts("  • Failures: #{failures}")
    IO.puts("  • Rate: #{Float.round(iterations / (time_microseconds / 1_000_000), 1)} parses/sec")

    if failures > 0 do
      IO.puts("⚠️  Some iterations failed - check file and format")
    end

    %{
      avg_time_ms: avg_time_ms,
      total_time_ms: time_microseconds / 1000,
      successes: successes,
      failures: failures,
      rate_per_sec: iterations / (time_microseconds / 1_000_000)
    }
  end

  @doc """
  Demonstrate recursive parsing capabilities.
  """
  def demo() do
    IO.puts("🎬 Bindocsis Recursive Parser Demo")
    IO.puts("==================================")
    IO.puts("")

    # Create a sample config
    sample_config = """
    # Sample DOCSIS Configuration
    NetworkAccessControl enabled
    WebAccessControl disabled
    DownstreamFrequency 591000000
    MaxUpstreamTransmitPower 58
    IPAddress 192.168.1.1

    # This demonstrates recursive compound TLV parsing
    UpstreamServiceFlow {
        ServiceFlowReference 1
        ServiceFlowId 2
        QoSParameterSetType 7
    }

    DownstreamServiceFlow {
        ServiceFlowReference 2
        ServiceFlowId 3
        QoSParameterSetType 7
    }
    """

    IO.puts("📝 Sample Config:")
    IO.puts(sample_config)

    IO.puts("🔄 Parsing with recursive parser...")

    case Bindocsis.Parsers.ConfigParser.parse(sample_config) do
      {:ok, tlvs} ->
        IO.puts("✅ Successfully parsed #{length(tlvs)} TLVs using recursive approach")
        IO.puts("")
        IO.puts("📋 Parsed TLVs:")

        Enum.each(tlvs, fn tlv ->
          IO.puts("  • Type: #{tlv.type}, Length: #{tlv.length}, Value: #{inspect(tlv.value, limit: 20)}")
        end)

        # Test round-trip conversion
        IO.puts("")
        IO.puts("🔄 Testing round-trip conversion...")

        case Bindocsis.generate(tlvs, format: :config) do
          {:ok, generated_config} ->
            IO.puts("✅ Round-trip successful!")
            IO.puts("")
            IO.puts("🔁 Generated config:")
            IO.puts(generated_config)

          {:error, reason} ->
            IO.puts("❌ Round-trip failed: #{reason}")
        end

      {:error, reason} ->
        IO.puts("❌ Parse failed: #{reason}")
    end

    IO.puts("")
    IO.puts("💡 Try these commands:")
    IO.puts("  • parse_file(\"path/to/file.cm\")")
    IO.puts("  • parse_dir(\"test/fixtures\")")
    IO.puts("  • test_formats(\"path/to/file\")")
    IO.puts("  • perf(\"path/to/file.cm\")")
  end

  @doc """
  Create a test config file for experimentation.
  """
  def create_test_config(filename \\ "test_config.conf") do
    config_content = """
    # Test DOCSIS Configuration
    # Generated by Bindocsis IEx helpers
    # Demonstrates recursive TLV parsing

    # Basic TLVs
    NetworkAccessControl enabled
    WebAccessControl disabled
    DownstreamFrequency 591M
    MaxUpstreamTransmitPower 58.5
    UpstreamChannelID 0x05
    IPAddress 192.168.100.1
    SubnetMask 255.255.255.0
    TFTPServer AA:BB:CC:DD:EE:FF

    # Compound TLVs (recursive parsing)
    UpstreamServiceFlow {
        ServiceFlowReference 1
        ServiceFlowId 2
        QoSParameterSetType 7
    }

    DownstreamServiceFlow {
        ServiceFlowReference 2
        ServiceFlowId 3
        QoSParameterSetType 7
    }

    # Nested compound example
    VendorSpecificOptions {
        VendorId 12345
        Option1 "test"
        Option2 0xDEADBEEF
    }
    """

    case File.write(filename, config_content) do
      :ok ->
        IO.puts("✅ Created test config: #{filename}")
        IO.puts("💡 Try: parse_file(\"#{filename}\", format: :config, verbose: true)")
        filename

      {:error, reason} ->
        IO.puts("❌ Failed to create file: #{reason}")
        nil
    end
  end

  @doc """
  Compare binary vs config parsing on the same logical configuration.
  """
  def compare_parsers(binary_file, config_file) do
    IO.puts("⚖️  Comparing Binary vs Config Parser")
    IO.puts("=====================================")

    IO.puts("🔄 Parsing binary file: #{Path.basename(binary_file)}")
    binary_result = Bindocsis.parse_file(binary_file, format: :binary)

    IO.puts("🔄 Parsing config file: #{Path.basename(config_file)}")
    config_result = Bindocsis.parse_file(config_file, format: :config)

    case {binary_result, config_result} do
      {{:ok, binary_tlvs}, {:ok, config_tlvs}} ->
        IO.puts("✅ Both parsers succeeded")
        IO.puts("📊 Binary parser: #{length(binary_tlvs)} TLVs")
        IO.puts("📊 Config parser: #{length(config_tlvs)} TLVs")

        # Compare TLV types
        binary_types = Enum.map(binary_tlvs, & &1.type) |> Enum.sort()
        config_types = Enum.map(config_tlvs, & &1.type) |> Enum.sort()

        IO.puts("🔍 TLV types comparison:")
        IO.puts("  Binary: #{inspect(binary_types)}")
        IO.puts("  Config: #{inspect(config_types)}")

        if binary_types == config_types do
          IO.puts("✅ TLV types match!")
        else
          IO.puts("⚠️  TLV types differ")
        end

      {{:error, binary_error}, {:ok, _}} ->
        IO.puts("❌ Binary parser failed: #{binary_error}")
        IO.puts("✅ Config parser succeeded")

      {{:ok, _}, {:error, config_error}} ->
        IO.puts("✅ Binary parser succeeded")
        IO.puts("❌ Config parser failed: #{config_error}")

      {{:error, binary_error}, {:error, config_error}} ->
        IO.puts("❌ Both parsers failed")
        IO.puts("  Binary: #{binary_error}")
        IO.puts("  Config: #{config_error}")
    end
  end

  @doc """
  Test the recursive nature by parsing a compound TLV and showing its structure.
  """
  def show_recursive_structure(file_path, opts \\ []) do
    IO.puts("🌳 Recursive TLV Structure Analysis")
    IO.puts("===================================")

    case Bindocsis.parse_file(file_path, opts) do
      {:ok, tlvs} ->
        IO.puts("📊 Found #{length(tlvs)} top-level TLVs")
        IO.puts("")

        Enum.each(tlvs, fn tlv ->
          IO.puts("📦 TLV #{tlv.type} (#{tlv.length} bytes)")

          # Try to parse as compound TLV
          if tlv.length > 2 do
            case Bindocsis.parse_tlv(tlv.value, []) do
              sub_tlvs when is_list(sub_tlvs) and length(sub_tlvs) > 0 ->
                IO.puts("  ├─ Contains #{length(sub_tlvs)} sub-TLVs:")
                Enum.each(sub_tlvs, fn sub_tlv ->
                  IO.puts("  │  ├─ Sub-TLV #{sub_tlv.type} (#{sub_tlv.length} bytes)")
                end)

              _ ->
                IO.puts("  ├─ Simple TLV (no sub-structure)")
            end
          else
            IO.puts("  ├─ Simple TLV (#{tlv.length} bytes)")
          end

          IO.puts("")
        end)

      {:error, reason} ->
        IO.puts("❌ Failed to parse: #{reason}")
    end
  end
end

# Import the helpers into the global namespace
import IExHelpers

# Display welcome message
IO.puts("""

🎉 Bindocsis Interactive Testing Environment
===========================================

Your recursive parser integration is ready! Here are some helpful commands:

📁 File Operations:
  • parse_file("path/to/file.cm")                    - Parse a single file
  • parse_file("config.conf", format: :config)       - Parse with specific format
  • parse_file("file.cm", verbose: true)             - Show detailed TLV info
  • parse_file("file.cm", format: :binary, enhanced: true) - Enriched, human-readable TLVs
  • parse_dir("test/fixtures")                       - Parse all files in directory
  • parse_dir("configs", pattern: "*.conf")          - Parse with file pattern

🧪 Testing & Analysis:
  • test_formats("file.cm")                          - Test all supported formats
  • show_recursive_structure("file.cm")              - Analyze TLV structure
  • compare_parsers("file.cm", "config.conf")        - Compare binary vs config

⚡ Performance:
  • perf("file.cm")                                  - Basic performance test
  • perf("file.cm", iterations: 1000)               - Custom iteration count

🎬 Demos:
  • demo()                                           - Run interactive demo
  • create_test_config()                             - Create sample config file
  • create_test_config("my_test.conf")               - Create with custom name

💡 Example workflow:
  1. create_test_config("sample.conf")
  2. parse_file("sample.conf", format: :config, verbose: true, enhanced: true)
  3. test_formats("sample.conf")
  4. perf("sample.conf")

Happy testing! Your recursive parser handles multi-byte lengths, multi-line configs,
and nested TLVs beautifully. 🚀

""")
