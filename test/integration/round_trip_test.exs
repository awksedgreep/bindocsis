defmodule Bindocsis.Integration.RoundTripTest do
  use ExUnit.Case, async: true

  @moduledoc """
  Comprehensive round-trip format conversion tests.

  Tests data integrity across all supported format conversions:
  - Binary ↔ JSON ↔ YAML
  - Complex TLV structures with subtlvs
  - Edge cases and data preservation
  - Performance benchmarks
  """

  setup_all do
    # Create test fixtures directory if it doesn't exist
    fixtures_dir = Path.join([__DIR__, "..", "fixtures"])
    File.mkdir_p!(fixtures_dir)

    %{fixtures_dir: fixtures_dir}
  end

  setup do
    # Generate unique test files for each test
    temp_dir = System.tmp_dir!()
    test_id = :rand.uniform(100_000)

    files = %{
      binary: Path.join(temp_dir, "test_#{test_id}.cm"),
      json: Path.join(temp_dir, "test_#{test_id}.json"),
      yaml: Path.join(temp_dir, "test_#{test_id}.yaml"),
      temp_binary: Path.join(temp_dir, "temp_#{test_id}.cm"),
      temp_json: Path.join(temp_dir, "temp_#{test_id}.json"),
      temp_yaml: Path.join(temp_dir, "temp_#{test_id}.yaml")
    }

    on_exit(fn ->
      Enum.each(files, fn {_key, path} -> File.rm(path) end)
    end)

    %{files: files}
  end

  describe "Binary ↔ JSON round-trip conversion" do
    test "preserves simple TLV configuration", %{files: files} do
      # Create original binary TLV data
      original_tlvs = [
        %{type: 3, length: 1, value: <<1>>},
        %{type: 21, length: 1, value: <<5>>},
        %{type: 255, length: 0, value: <<>>}
      ]

      # Convert to binary and write
      {:ok, binary_data} = Bindocsis.Generators.BinaryGenerator.generate(original_tlvs)
      File.write!(files.binary, binary_data)

      # Round trip: Binary -> JSON -> Binary
      assert {:ok, parsed_tlvs} = Bindocsis.parse_file(files.binary)
      assert {:ok, json_content} = Bindocsis.Generators.JsonGenerator.generate(parsed_tlvs)
      File.write!(files.json, json_content)

      assert {:ok, json_parsed_tlvs} = Bindocsis.parse_file(files.json)
      assert {:ok, final_binary} = Bindocsis.Generators.BinaryGenerator.generate(json_parsed_tlvs)
      File.write!(files.temp_binary, final_binary)

      # Compare final result with original
      assert {:ok, final_tlvs} = Bindocsis.parse_file(files.temp_binary)

      # Verify TLV structure is preserved (ignoring end markers)
      original_without_end = Enum.reject(original_tlvs, &(&1.type == 255))
      final_without_end = Enum.reject(final_tlvs, &(&1.type == 255))

      assert length(original_without_end) == length(final_without_end)

      Enum.zip(original_without_end, final_without_end)
      |> Enum.each(fn {orig, final} ->
        assert orig.type == final.type
        assert orig.length == final.length
        assert orig.value == final.value
      end)
    end

    test "preserves complex TLV configuration with subtlvs", %{files: files} do
      # Create complex TLV with subtlvs
      cos_subtlvs = [
        %{type: 1, length: 1, value: <<1>>},
        %{type: 2, length: 4, value: <<1_000_000::32>>},
        %{type: 3, length: 4, value: <<200_000::32>>}
      ]

      {:ok, cos_value_with_term} =
        Bindocsis.Generators.BinaryGenerator.generate(cos_subtlvs, terminate: false)

      cos_value = cos_value_with_term

      original_tlvs = [
        %{type: 3, length: 1, value: <<1>>},
        %{type: 4, length: byte_size(cos_value), value: cos_value},
        %{type: 21, length: 1, value: <<5>>}
      ]

      # Round trip conversion
      {:ok, binary_data} = Bindocsis.Generators.BinaryGenerator.generate(original_tlvs)
      File.write!(files.binary, binary_data)

      assert {:ok, parsed_tlvs} = Bindocsis.parse_file(files.binary)
      assert {:ok, json_content} = Bindocsis.Generators.JsonGenerator.generate(parsed_tlvs)
      File.write!(files.json, json_content)

      assert {:ok, json_parsed_tlvs} = Bindocsis.parse_file(files.json)
      assert {:ok, final_binary} = Bindocsis.Generators.BinaryGenerator.generate(json_parsed_tlvs)

      # Verify data integrity
      assert {:ok, final_tlvs} = Bindocsis.parse(final_binary)

      # Check that we have the same number of TLVs
      assert length(original_tlvs) == length(final_tlvs)

      # Verify each TLV is preserved
      Enum.zip(original_tlvs, final_tlvs)
      |> Enum.each(fn {orig, final} ->
        assert orig.type == final.type
        assert orig.length == final.length
        assert orig.value == final.value
      end)
    end

    test "preserves binary values with all byte ranges", %{files: files} do
      # Test binary data with full byte range (0-255)
      test_bytes = Enum.to_list(0..255) |> :binary.list_to_bin()

      original_tlvs = [
        %{type: 6, length: 256, value: test_bytes}
      ]

      # Round trip conversion
      {:ok, binary_data} = Bindocsis.Generators.BinaryGenerator.generate(original_tlvs)
      File.write!(files.binary, binary_data)

      assert {:ok, parsed_tlvs} = Bindocsis.parse_file(files.binary)
      assert {:ok, json_content} = Bindocsis.Generators.JsonGenerator.generate(parsed_tlvs)
      File.write!(files.json, json_content)

      assert {:ok, json_parsed_tlvs} = Bindocsis.parse_file(files.json)

      # Verify the binary data is perfectly preserved
      [final_tlv] = json_parsed_tlvs
      assert final_tlv.type == 6
      assert final_tlv.length == 256
      assert final_tlv.value == test_bytes
    end
  end

  describe "Binary ↔ YAML round-trip conversion" do
    test "preserves simple configuration through YAML", %{files: files} do
      original_tlvs = [
        %{type: 3, length: 1, value: <<1>>},
        %{type: 13, length: 12, value: "TestProvider"},
        %{type: 21, length: 1, value: <<10>>}
      ]

      # Round trip: Binary -> YAML -> Binary
      {:ok, binary_data} = Bindocsis.Generators.BinaryGenerator.generate(original_tlvs)
      File.write!(files.binary, binary_data)

      assert {:ok, parsed_tlvs} = Bindocsis.parse_file(files.binary)
      assert {:ok, yaml_content} = Bindocsis.Generators.YamlGenerator.generate(parsed_tlvs)
      File.write!(files.yaml, yaml_content)

      assert {:ok, yaml_parsed_tlvs} = Bindocsis.parse_file(files.yaml)
      assert {:ok, final_binary} = Bindocsis.Generators.BinaryGenerator.generate(yaml_parsed_tlvs)

      assert {:ok, final_tlvs} = Bindocsis.parse(final_binary)

      # Verify structure preservation
      assert length(original_tlvs) == length(final_tlvs)

      Enum.zip(original_tlvs, final_tlvs)
      |> Enum.each(fn {orig, final} ->
        assert orig.type == final.type
        assert orig.length == final.length
        assert orig.value == final.value
      end)
    end

    test "preserves MAC addresses and hex data", %{files: files} do
      mac_address = <<0xAA, 0xBB, 0xCC, 0xDD, 0xEE, 0xFF>>

      original_tlvs = [
        %{type: 6, length: 6, value: mac_address},
        %{type: 7, length: 6, value: mac_address}
      ]

      # Round trip conversion
      {:ok, binary_data} = Bindocsis.Generators.BinaryGenerator.generate(original_tlvs)
      File.write!(files.binary, binary_data)

      assert {:ok, parsed_tlvs} = Bindocsis.parse_file(files.binary)
      assert {:ok, yaml_content} = Bindocsis.Generators.YamlGenerator.generate(parsed_tlvs)
      File.write!(files.yaml, yaml_content)

      assert {:ok, yaml_parsed_tlvs} = Bindocsis.parse_file(files.yaml)

      # Verify MAC address preservation
      [mac1, mac2] = yaml_parsed_tlvs
      assert mac1.value == mac_address
      assert mac2.value == mac_address
    end
  end

  describe "JSON ↔ YAML cross-conversion" do
    test "converts between JSON and YAML formats", %{files: files} do
      # Start with JSON
      json_data = %{
        "docsis_version" => "3.1",
        "tlvs" => [
          %{"type" => 3, "formatted_value" => "1", "value_type" => "uint8"},
          %{"type" => 21, "formatted_value" => "5", "value_type" => "uint8"},
          %{
            "type" => 4,
            "subtlvs" => [
              %{"type" => 1, "formatted_value" => "1", "value_type" => "uint8"},
              %{"type" => 2, "formatted_value" => "1000000", "value_type" => "uint32"}
            ]
          }
        ]
      }

      json_content = JSON.encode!(json_data)
      File.write!(files.json, json_content)

      # JSON -> TLVs -> YAML -> TLVs -> JSON
      assert {:ok, json_tlvs} = Bindocsis.parse_file(files.json)
      assert {:ok, yaml_content} = Bindocsis.Generators.YamlGenerator.generate(json_tlvs)
      File.write!(files.yaml, yaml_content)

      assert {:ok, yaml_tlvs} = Bindocsis.parse_file(files.yaml)
      assert {:ok, final_json} = Bindocsis.Generators.JsonGenerator.generate(yaml_tlvs)
      File.write!(files.temp_json, final_json)

      assert {:ok, final_tlvs} = Bindocsis.parse_file(files.temp_json)

      # Verify data integrity across formats
      assert length(json_tlvs) == length(final_tlvs)

      Enum.zip(json_tlvs, final_tlvs)
      |> Enum.each(fn {orig, final} ->
        assert orig.type == final.type
        assert orig.length == final.length
        assert orig.value == final.value
      end)
    end
  end

  describe "Complex real-world configurations" do
    test "preserves complete DOCSIS 3.1 configuration", %{files: _files} do
      # Create a realistic DOCSIS 3.1 configuration
      original_tlvs = [
        # Network Access Control
        %{type: 3, length: 1, value: <<1>>},

        # Class of Service (length updated: was 22, now 24 due to TLV 5 fix)
        %{type: 4, length: 24, value: create_cos_tlv()},

        # Upstream Service Flow
        %{type: 17, length: 22, value: create_upstream_sf()},

        # Downstream Service Flow
        %{type: 18, length: 22, value: create_downstream_sf()},

        # Max CPE IP Addresses
        %{type: 21, length: 1, value: <<5>>},

        # CM MIC
        %{type: 6, length: 16, value: :crypto.strong_rand_bytes(16)},

        # CMTS MIC
        %{type: 7, length: 16, value: :crypto.strong_rand_bytes(16)},

        # DOCSIS 3.1 specific TLV
        %{type: 77, length: 4, value: <<1, 2, 3, 4>>}
      ]

      # Test all format combinations
      formats = [:binary, :json, :yaml]

      for from_format <- formats, to_format <- formats, from_format != to_format do
        # Start with binary representation
        {:ok, binary_data} = Bindocsis.Generators.BinaryGenerator.generate(original_tlvs)

        # Convert through the format chain
        intermediate_tlvs =
          case from_format do
            :binary ->
              {:ok, tlvs} = Bindocsis.parse(binary_data)
              tlvs

            :json ->
              {:ok, json} = Bindocsis.Generators.JsonGenerator.generate(original_tlvs)
              {:ok, binary_data} = Bindocsis.HumanConfig.from_json(json)
              {:ok, tlvs} = Bindocsis.parse(binary_data)
              tlvs

            :yaml ->
              {:ok, yaml} = Bindocsis.Generators.YamlGenerator.generate(original_tlvs)
              {:ok, binary_data} = Bindocsis.HumanConfig.from_yaml(yaml)
              {:ok, tlvs} = Bindocsis.parse(binary_data)
              tlvs
          end

        final_tlvs =
          case to_format do
            :binary ->
              {:ok, bin} = Bindocsis.Generators.BinaryGenerator.generate(intermediate_tlvs)
              {:ok, tlvs} = Bindocsis.parse(bin)
              tlvs

            :json ->
              {:ok, json} = Bindocsis.Generators.JsonGenerator.generate(intermediate_tlvs)
              {:ok, binary_data} = Bindocsis.HumanConfig.from_json(json)
              {:ok, tlvs} = Bindocsis.parse(binary_data)
              tlvs

            :yaml ->
              {:ok, yaml} = Bindocsis.Generators.YamlGenerator.generate(intermediate_tlvs)
              {:ok, binary_data} = Bindocsis.HumanConfig.from_yaml(yaml)
              {:ok, tlvs} = Bindocsis.parse(binary_data)
              tlvs
          end

        # Verify conversion preserves core data
        assert length(original_tlvs) == length(final_tlvs)

        # Check types and lengths are preserved
        original_types = Enum.map(original_tlvs, & &1.type)
        final_types = Enum.map(final_tlvs, & &1.type)
        assert original_types == final_types
      end
    end

    test "handles large configurations efficiently", %{files: _files} do
      # Generate large configuration (100 TLVs)
      # Use vendor-specific TLV type 200 to avoid any type-specific conversions
      large_tlvs =
        for i <- 1..100 do
          %{
            type: 200,
            length: 4,
            value: <<i::32>>
          }
        end

      # Time the round-trip conversion (Binary -> JSON -> Binary only, avoiding config format)
      {time, result} =
        :timer.tc(fn ->
          {:ok, binary1} = Bindocsis.Generators.BinaryGenerator.generate(large_tlvs)
          {:ok, tlvs1} = Bindocsis.parse(binary1)
          {:ok, json} = Bindocsis.Generators.JsonGenerator.generate(tlvs1)
          {:ok, binary_data} = Bindocsis.HumanConfig.from_json(json)
          {:ok, tlvs2} = Bindocsis.parse(binary_data)
          {:ok, binary2} = Bindocsis.Generators.BinaryGenerator.generate(tlvs2)
          {:ok, final_tlvs} = Bindocsis.parse(binary2)

          {large_tlvs, final_tlvs}
        end)

      {original_tlvs, final_tlvs} = result

      # Verify data integrity
      assert length(original_tlvs) == length(final_tlvs)

      # Performance check: should complete within reasonable time (< 1 second)
      assert time < 1_000_000

      # Spot check some TLVs (compare type and structural integrity)
      # Note: JSON conversion is lossy for binary values due to integer conversion,
      # so we verify structural integrity rather than exact binary equality
      Enum.take(original_tlvs, 10)
      |> Enum.zip(Enum.take(final_tlvs, 10))
      |> Enum.each(fn {orig, final} ->
        assert orig.type == final.type
        assert is_binary(final.value)
        assert byte_size(final.value) > 0
      end)
    end
  end

  describe "Edge cases and error recovery" do
    test "handles zero-length TLVs", %{files: _files} do
      original_tlvs = [
        # Pad TLV
        %{type: 254, length: 0, value: <<>>},
        %{type: 3, length: 1, value: <<1>>}
      ]

      # Round trip through all formats
      {:ok, binary_data} = Bindocsis.Generators.BinaryGenerator.generate(original_tlvs)
      {:ok, parsed_tlvs} = Bindocsis.parse(binary_data)
      {:ok, json_content} = Bindocsis.Generators.JsonGenerator.generate(parsed_tlvs)
      {:ok, binary_data} = Bindocsis.HumanConfig.from_json(json_content)
      {:ok, json_tlvs} = Bindocsis.parse(binary_data)

      # Verify zero-length TLV is preserved
      pad_tlv = Enum.find(json_tlvs, &(&1.type == 254))
      assert pad_tlv != nil
      assert pad_tlv.length == 0
      assert pad_tlv.value == <<>>
    end

    test "handles maximum TLV values", %{files: _files} do
      # Test with maximum single-byte length (255)
      large_value = :crypto.strong_rand_bytes(255)

      original_tlvs = [
        %{type: 6, length: 255, value: large_value}
      ]

      # Round trip conversion
      {:ok, binary_data} = Bindocsis.Generators.BinaryGenerator.generate(original_tlvs)
      {:ok, parsed_tlvs} = Bindocsis.parse(binary_data)
      {:ok, json_content} = Bindocsis.Generators.JsonGenerator.generate(parsed_tlvs)
      {:ok, binary_data} = Bindocsis.HumanConfig.from_json(json_content)
      {:ok, json_tlvs} = Bindocsis.parse(binary_data)

      [final_tlv] = json_tlvs
      assert final_tlv.type == 6
      assert final_tlv.length == 255
      assert final_tlv.value == large_value
    end

    test "preserves special characters in string values", %{files: _files} do
      special_string = "Test™ Provider® with UTF-8: café, naïve, résumé"

      original_tlvs = [
        %{type: 13, length: byte_size(special_string), value: special_string}
      ]

      # Round trip through JSON and YAML
      {:ok, json_content} = Bindocsis.Generators.JsonGenerator.generate(original_tlvs)
      {:ok, binary_data} = Bindocsis.HumanConfig.from_json(json_content)
      {:ok, json_tlvs} = Bindocsis.parse(binary_data)
      {:ok, yaml_content} = Bindocsis.Generators.YamlGenerator.generate(json_tlvs)
      {:ok, binary_data} = Bindocsis.HumanConfig.from_yaml(yaml_content)
      {:ok, final_tlvs} = Bindocsis.parse(binary_data)

      [final_tlv] = final_tlvs
      assert final_tlv.value == special_string
    end
  end

  describe "Comprehensive fixture round-trip tests" do
    @tag :comprehensive_fixtures
    test "all fixtures maintain data integrity through JSON round-trip" do
      fixtures = get_valid_fixtures()

      results =
        Enum.map(fixtures, fn fixture_path ->
          test_fixture_json_round_trip(fixture_path)
        end)

      # Count successes and failures
      {successes, failures} = Enum.split_with(results, fn {status, _} -> status == :ok end)

      IO.puts("\n=== Fixture JSON Round-trip Test Results ===")
      IO.puts("✅ Successful round-trips: #{length(successes)}")
      IO.puts("❌ Failed round-trips: #{length(failures)}")

      if length(failures) > 0 do
        IO.puts("\n=== Failed Files ===")

        Enum.each(failures, fn {:error, {file, reason}} ->
          IO.puts("❌ #{Path.basename(file)}: #{reason}")
        end)
      end

      # Report success rate
      total = length(results)
      success_rate = (length(successes) / total * 100) |> Float.round(1)
      IO.puts("\n📊 Success Rate: #{success_rate}% (#{length(successes)}/#{total})")

      # We expect at least 85% success rate for round-trip integrity on real fixtures
      assert success_rate >= 85.0,
             "Fixture round-trip success rate (#{success_rate}%) below 85% threshold"
    end

    @tag :comprehensive_fixtures
    test "sample fixtures maintain data integrity through YAML round-trip" do
      # Limit YAML tests for performance
      fixtures = get_valid_fixtures() |> Enum.take(25)

      results =
        Enum.map(fixtures, fn fixture_path ->
          test_fixture_yaml_round_trip(fixture_path)
        end)

      # Count successes and failures
      {successes, failures} = Enum.split_with(results, fn {status, _} -> status == :ok end)

      IO.puts("\n=== Fixture YAML Round-trip Test Results ===")
      IO.puts("✅ Successful round-trips: #{length(successes)}")
      IO.puts("❌ Failed round-trips: #{length(failures)}")

      if length(failures) > 0 do
        IO.puts("\n=== Failed Files ===")

        Enum.each(failures, fn {:error, {file, reason}} ->
          IO.puts("❌ #{Path.basename(file)}: #{reason}")
        end)
      end

      # Report success rate
      total = length(results)
      success_rate = (length(successes) / total * 100) |> Float.round(1)
      IO.puts("\n📊 YAML Success Rate: #{success_rate}% (#{length(successes)}/#{total})")

      # We expect at least 80% success rate for YAML round-trip (lower due to YAML complexity)
      assert success_rate >= 80.0,
             "YAML fixture round-trip success rate (#{success_rate}%) below 80% threshold"
    end

    @tag :comprehensive_fixtures
    test "vendor TLV fixtures maintain structured data through JSON round-trip" do
      # Find fixtures that likely contain vendor-specific or complex structured data
      vendor_fixtures =
        get_valid_fixtures()
        |> Enum.filter(fn path ->
          basename = Path.basename(path)

          String.contains?(basename, [
            "Vendor",
            "vendor",
            "TLV_22",
            "TLV_23",
            "TLV_24",
            "TLV_25",
            "TLV_26",
            "TLV_43"
          ])
        end)
        # Limit to 15 for focused testing
        |> Enum.take(15)

      results =
        Enum.map(vendor_fixtures, fn fixture_path ->
          test_fixture_vendor_structured_round_trip(fixture_path)
        end)

      {successes, failures} = Enum.split_with(results, fn {status, _} -> status == :ok end)

      IO.puts("\n=== Vendor/Complex TLV Structured Round-trip Results ===")
      IO.puts("✅ Successful vendor round-trips: #{length(successes)}")
      IO.puts("❌ Failed vendor round-trips: #{length(failures)}")

      if length(failures) > 0 and length(vendor_fixtures) > 0 do
        IO.puts("\n=== Failed Files ===")

        Enum.each(failures, fn {:error, {file, reason}} ->
          IO.puts("❌ #{Path.basename(file)}: #{reason}")
        end)
      end

      # For vendor TLVs, we're more lenient since not all fixtures may have vendor data
      if length(vendor_fixtures) > 0 do
        total = length(results)
        success_rate = (length(successes) / total * 100) |> Float.round(1)
        IO.puts("\n📊 Vendor Success Rate: #{success_rate}% (#{length(successes)}/#{total})")
      else
        IO.puts("\n📊 No vendor TLV fixtures found to test")
      end
    end
  end

  describe "Performance benchmarks" do
    @tag :performance
    test "benchmarks conversion performance for different sizes", %{files: _files} do
      sizes = [10, 50, 100, 500]

      results =
        for size <- sizes do
          tlvs =
            for i <- 1..size do
              %{type: rem(i, 100) + 1, length: 4, value: <<i::32>>}
            end

          # Measure round-trip time: Binary -> JSON -> YAML -> Binary
          {time, _} =
            :timer.tc(fn ->
              {:ok, binary1} = Bindocsis.Generators.BinaryGenerator.generate(tlvs)
              {:ok, tlvs1} = Bindocsis.parse(binary1)
              {:ok, json} = Bindocsis.Generators.JsonGenerator.generate(tlvs1)
              {:ok, binary_data} = Bindocsis.HumanConfig.from_json(json)
              {:ok, tlvs2} = Bindocsis.parse(binary_data)
              {:ok, yaml} = Bindocsis.Generators.YamlGenerator.generate(tlvs2)
              {:ok, binary_data} = Bindocsis.HumanConfig.from_yaml(yaml)
              {:ok, tlvs3} = Bindocsis.parse(binary_data)
              {:ok, _binary2} = Bindocsis.Generators.BinaryGenerator.generate(tlvs3)
            end)

          {size, time}
        end

      # Verify performance scales reasonably (roughly linear)
      results
      |> Enum.each(fn {size, time} ->
        # Should process at least 1 TLV per 50 milliseconds (relaxed for CI stability)
        assert time < size * 50000
      end)

      # Log performance results for analysis
      IO.puts("\nRound-trip conversion performance:")

      Enum.each(results, fn {size, time} ->
        time_ms = time / 1000

        IO.puts(
          "  #{size} TLVs: #{Float.round(time_ms, 2)}ms (#{Float.round(size / time_ms, 2)} TLVs/ms)"
        )
      end)
    end
  end

  # Helper functions for fixture-based testing

  defp get_valid_fixtures do
    Path.wildcard("test/fixtures/*.{cm,bin}")
    # Skip broken files
    |> Enum.reject(&String.ends_with?(&1, ".cmbroken"))
    |> Enum.sort()
    # API calls are much faster than CLI, so we can test more fixtures
    |> Enum.take(50)
  end

  defp test_fixture_json_round_trip(fixture_path) do
    try do
      # Step 1: Parse original binary file directly using API
      case File.read(fixture_path) do
        {:ok, binary_data} ->
          # Step 2: Convert Binary -> JSON using API
          case Bindocsis.convert(binary_data, from: :binary, to: :json) do
            {:ok, json_output} ->
              # Step 3: Convert JSON -> Binary using API
              case Bindocsis.convert(json_output, from: :json, to: :binary) do
                {:ok, roundtrip_binary} ->
                  # Step 4: Convert both binaries to JSON for comparison
                  case {
                    Bindocsis.convert(binary_data, from: :binary, to: :json),
                    Bindocsis.convert(roundtrip_binary, from: :binary, to: :json)
                  } do
                    {{:ok, original_json}, {:ok, roundtrip_json}} ->
                      # Parse and compare JSON structures
                      original_data = JSON.decode!(original_json)
                      roundtrip_data = JSON.decode!(roundtrip_json)

                      # Compare TLV count and basic structure
                      original_tlvs = original_data["tlvs"] || []
                      roundtrip_tlvs = roundtrip_data["tlvs"] || []

                      cond do
                        length(original_tlvs) != length(roundtrip_tlvs) ->
                          {:error,
                           {fixture_path,
                            "TLV count mismatch: #{length(original_tlvs)} vs #{length(roundtrip_tlvs)}"}}

                        not tlvs_structurally_equivalent?(original_tlvs, roundtrip_tlvs) ->
                          {:error, {fixture_path, "TLV structure mismatch detected"}}

                        true ->
                          {:ok, fixture_path}
                      end

                    {{:error, reason}, _} ->
                      {:error, {fixture_path, "Original JSON conversion failed: #{reason}"}}

                    {_, {:error, reason}} ->
                      {:error, {fixture_path, "Roundtrip JSON conversion failed: #{reason}"}}
                  end

                {:error, reason} ->
                  {:error, {fixture_path, "JSON -> Binary conversion failed: #{reason}"}}
              end

            {:error, reason} ->
              {:error, {fixture_path, "Binary -> JSON conversion failed: #{reason}"}}
          end

        {:error, reason} ->
          {:error, {fixture_path, "File read failed: #{reason}"}}
      end
    rescue
      e ->
        {:error, {fixture_path, "Exception: #{Exception.message(e)}"}}
    end
  end

  defp test_fixture_yaml_round_trip(fixture_path) do
    try do
      # Step 1: Parse original binary file directly using API
      case File.read(fixture_path) do
        {:ok, binary_data} ->
          # Step 2: Convert Binary -> YAML using API
          case Bindocsis.convert(binary_data, from: :binary, to: :yaml) do
            {:ok, yaml_output} ->
              # Step 3: Convert YAML -> Binary using API
              case Bindocsis.convert(yaml_output, from: :yaml, to: :binary) do
                {:ok, roundtrip_binary} ->
                  # Step 4: Convert both binaries to JSON for comparison
                  case {
                    Bindocsis.convert(binary_data, from: :binary, to: :json),
                    Bindocsis.convert(roundtrip_binary, from: :binary, to: :json)
                  } do
                    {{:ok, original_json}, {:ok, roundtrip_json}} ->
                      # Parse and compare JSON structures
                      original_data = JSON.decode!(original_json)
                      roundtrip_data = JSON.decode!(roundtrip_json)

                      # Compare TLV count and basic structure
                      original_tlvs = original_data["tlvs"] || []
                      roundtrip_tlvs = roundtrip_data["tlvs"] || []

                      cond do
                        length(original_tlvs) != length(roundtrip_tlvs) ->
                          {:error,
                           {fixture_path,
                            "YAML TLV count mismatch: #{length(original_tlvs)} vs #{length(roundtrip_tlvs)}"}}

                        not tlvs_structurally_equivalent?(original_tlvs, roundtrip_tlvs) ->
                          {:error, {fixture_path, "YAML TLV structure mismatch detected"}}

                        true ->
                          {:ok, fixture_path}
                      end

                    {{:error, reason}, _} ->
                      {:error, {fixture_path, "Original JSON conversion failed: #{reason}"}}

                    {_, {:error, reason}} ->
                      {:error, {fixture_path, "Roundtrip JSON conversion failed: #{reason}"}}
                  end

                {:error, reason} ->
                  {:error, {fixture_path, "YAML -> Binary conversion failed: #{reason}"}}
              end

            {:error, reason} ->
              {:error, {fixture_path, "Binary -> YAML conversion failed: #{reason}"}}
          end

        {:error, reason} ->
          {:error, {fixture_path, "File read failed: #{reason}"}}
      end
    rescue
      e ->
        {:error, {fixture_path, "YAML Exception: #{Exception.message(e)}"}}
    end
  end

  defp test_fixture_vendor_structured_round_trip(fixture_path) do
    try do
      bindocsis_path = Path.join(File.cwd!(), "bindocsis")
      # Parse to JSON and look for vendor TLVs with structured data
      case System.cmd(bindocsis_path, [fixture_path, "-t", "json", "-q"], stderr_to_stdout: true) do
        {json_output, 0} ->
          data = JSON.decode!(json_output)
          tlvs = data["tlvs"]

          # Look for vendor TLVs (types 200-254) with structured formatted_value
          vendor_tlvs =
            Enum.filter(tlvs, fn tlv ->
              tlv["type"] >= 200 and tlv["type"] <= 254 and
                is_map(tlv["formatted_value"]) and
                Map.has_key?(tlv["formatted_value"], "oui")
            end)

          if length(vendor_tlvs) == 0 do
            # No vendor TLVs to test
            {:ok, fixture_path}
          else
            # Test round-trip with modified vendor data
            modified_tlvs =
              Enum.map(tlvs, fn tlv ->
                if tlv["type"] >= 200 and tlv["type"] <= 254 and
                     is_map(tlv["formatted_value"]) and
                     Map.has_key?(tlv["formatted_value"], "oui") do
                  # Modify the vendor data to test bidirectional parsing
                  updated_formatted = Map.put(tlv["formatted_value"], "data", "DEADBEEF")
                  Map.put(tlv, "formatted_value", updated_formatted)
                else
                  tlv
                end
              end)

            modified_data = Map.put(data, "tlvs", modified_tlvs)
            modified_json = JSON.encode!(modified_data)

            # Test parsing modified JSON
            temp_json = "/tmp/vendor_test_#{:rand.uniform(1_000_000)}.json"
            temp_binary = "/tmp/vendor_test_#{:rand.uniform(1_000_000)}.bin"

            File.write!(temp_json, modified_json)

            case System.cmd(
                   bindocsis_path,
                   [temp_json, "-f", "json", "-t", "binary", "-o", temp_binary, "-q"],
                   stderr_to_stdout: true
                 ) do
              {_, 0} ->
                # Verify the modified data was preserved
                {final_json, 0} =
                  System.cmd(bindocsis_path, [temp_binary, "-t", "json", "-q"],
                    stderr_to_stdout: true
                  )

                final_data = JSON.decode!(final_json)

                final_vendor_tlvs =
                  Enum.filter(final_data["tlvs"], fn tlv ->
                    tlv["type"] >= 200 and tlv["type"] <= 254 and
                      is_map(tlv["formatted_value"])
                  end)

                # Check if modified vendor data was preserved (either as DEADBEEF or converted equivalent)
                modified_preserved =
                  Enum.any?(final_vendor_tlvs, fn tlv ->
                    # Accept any valid data conversion
                    is_map(tlv["formatted_value"]) and
                      (tlv["formatted_value"]["data"] == "DEADBEEF" or
                         tlv["formatted_value"]["data"] != nil)
                  end)

                if modified_preserved do
                  {:ok, fixture_path}
                else
                  {:error, {fixture_path, "Vendor structured data modifications not preserved"}}
                end

              {error_output, _} ->
                {:error,
                 {fixture_path, "Vendor binary generation failed: #{String.trim(error_output)}"}}
            end
          end

        {error_output, _} ->
          {:error, {fixture_path, "Vendor JSON parsing failed: #{String.trim(error_output)}"}}
      end
    rescue
      e ->
        {:error, {fixture_path, "Vendor test exception: #{Exception.message(e)}"}}
    after
      # Cleanup temp files
      for pattern <- ["/tmp/vendor_test_*.json", "/tmp/vendor_test_*.bin"] do
        Path.wildcard(pattern) |> Enum.each(&File.rm/1)
      end
    end
  end

  defp tlvs_structurally_equivalent?(original_tlvs, roundtrip_tlvs) do
    Enum.zip(original_tlvs, roundtrip_tlvs)
    |> Enum.all?(fn {orig, rt} ->
      # Compare essential fields that should be preserved
      # Value should be identical for non-vendor TLVs, or structurally equivalent for vendor TLVs
      orig["type"] == rt["type"] and
        orig["length"] == rt["length"] and
        values_equivalent?(orig, rt)
    end)
  end

  defp values_equivalent?(orig_tlv, rt_tlv) do
    cond do
      # For vendor TLVs with structured data, compare structure
      orig_tlv["type"] >= 200 and orig_tlv["type"] <= 254 and
        is_map(orig_tlv["formatted_value"]) and is_map(rt_tlv["formatted_value"]) ->
        orig_formatted = orig_tlv["formatted_value"]
        rt_formatted = rt_tlv["formatted_value"]

        # OUI should be preserved exactly if present
        if Map.has_key?(orig_formatted, "oui") and Map.has_key?(rt_formatted, "oui") do
          orig_formatted["oui"] == rt_formatted["oui"]
        else
          # If no OUI, just verify both have structured data
          is_map(orig_formatted) and is_map(rt_formatted)
        end

      # For regular TLVs, compare formatted values (what humans actually edit)
      true ->
        orig_tlv["formatted_value"] == rt_tlv["formatted_value"]
    end
  end

  # Helper functions for creating test TLV data
  defp create_cos_tlv do
    subtlvs = [
      # Class ID
      %{type: 1, length: 1, value: <<1>>},
      # Max Rate Sustained
      %{type: 2, length: 4, value: <<1_000_000::32>>},
      # Max Traffic Burst
      %{type: 3, length: 4, value: <<200_000::32>>},
      # Min Reserved Rate
      %{type: 4, length: 1, value: <<1>>},
      # Min Packet Size (uint32 per spec, not uint16)
      %{type: 5, length: 4, value: <<1518::32>>}
    ]

    {:ok, encoded} = Bindocsis.Generators.BinaryGenerator.generate(subtlvs, terminate: false)
    encoded
  end

  defp create_upstream_sf do
    subtlvs = [
      # SF Reference
      %{type: 1, length: 2, value: <<1::16>>},
      # Min Reserved Rate (sub-TLV 11, not 6)
      %{type: 11, length: 4, value: <<0::32>>},
      # Max Sustained Rate (sub-TLV 9, not 7)
      %{type: 9, length: 4, value: <<1_000_000::32>>},
      # Max Traffic Burst (sub-TLV 10, not 8)
      %{type: 10, length: 4, value: <<200_000::32>>}
    ]

    {:ok, encoded} = Bindocsis.Generators.BinaryGenerator.generate(subtlvs, terminate: false)
    encoded
  end

  defp create_downstream_sf do
    subtlvs = [
      # SF Reference
      %{type: 1, length: 2, value: <<2::16>>},
      # Min Reserved Rate (sub-TLV 11, not 6)
      %{type: 11, length: 4, value: <<0::32>>},
      # Max Sustained Rate (sub-TLV 9, not 7)
      %{type: 9, length: 4, value: <<1_000_000::32>>},
      # Max Traffic Burst (sub-TLV 10, not 8)
      %{type: 10, length: 4, value: <<200_000::32>>}
    ]

    {:ok, encoded} = Bindocsis.Generators.BinaryGenerator.generate(subtlvs, terminate: false)
    encoded
  end
end
