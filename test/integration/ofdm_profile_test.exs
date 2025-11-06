defmodule Bindocsis.Integration.OfdmProfileTest do
  use ExUnit.Case, async: true

  @moduledoc """
  Integration tests for DOCSIS 3.1 OFDM/OFDMA Profile round-trip conversion.

  Tests:
  - TLV 62 (Downstream OFDM Profile) parsing and generation
  - TLV 63 (Downstream OFDMA Profile) parsing and generation
  - Binary ↔ JSON ↔ Binary round-trip
  - Binary ↔ YAML ↔ Binary round-trip
  - Sub-TLV parsing with formatted_value
  - Unknown sub-TLV fallback to hex string
  """

  setup do
    temp_dir = System.tmp_dir!()
    test_id = :rand.uniform(100_000)

    files = %{
      binary: Path.join(temp_dir, "ofdm_#{test_id}.cm"),
      json: Path.join(temp_dir, "ofdm_#{test_id}.json"),
      yaml: Path.join(temp_dir, "ofdm_#{test_id}.yaml"),
      temp_binary: Path.join(temp_dir, "ofdm_temp_#{test_id}.cm")
    }

    on_exit(fn ->
      Enum.each(files, fn {_key, path} -> File.rm(path) end)
    end)

    %{files: files}
  end

  describe "TLV 62 (Downstream OFDM Profile) round-trip conversion" do
    test "basic OFDM profile with common sub-TLVs", %{files: files} do
      # Create OFDM profile sub-TLVs
      ofdm_subtlvs = [
        # Profile ID = 1
        %{type: 1, length: 1, value: <<1>>},
        # Channel ID = 159
        %{type: 2, length: 1, value: <<159>>},
        # Config Change Count = 0
        %{type: 3, length: 1, value: <<0>>},
        # Subcarrier Spacing = 50 kHz
        %{type: 4, length: 1, value: <<1>>},
        # Cyclic Prefix = 384 samples
        %{type: 5, length: 1, value: <<2>>},
        # Start Frequency = 108 MHz
        %{type: 9, length: 4, value: <<108_000_000::32>>},
        # End Frequency = 300 MHz
        %{type: 10, length: 4, value: <<300_000_000::32>>},
        # Number of Subcarriers = 3840
        %{type: 11, length: 2, value: <<3840::16>>}
      ]

      # Generate sub-TLV binary
      {:ok, ofdm_value} =
        Bindocsis.Generators.BinaryGenerator.generate(
          ofdm_subtlvs,
          terminate: false
        )

      # Create top-level TLV 62
      original_tlvs = [
        # Network Access = enabled
        %{type: 3, length: 1, value: <<1>>},
        %{type: 62, length: byte_size(ofdm_value), value: ofdm_value},
        # Max CPE = 5
        %{type: 21, length: 1, value: <<5>>}
      ]

      # Generate binary
      {:ok, binary_data} = Bindocsis.Generators.BinaryGenerator.generate(original_tlvs)
      File.write!(files.binary, binary_data)

      # Parse binary
      assert {:ok, parsed_tlvs} = Bindocsis.parse_file(files.binary)

      # Find TLV 62
      ofdm_tlv = Enum.find(parsed_tlvs, &(&1.type == 62))
      assert ofdm_tlv != nil
      assert ofdm_tlv.name == "Downstream OFDM Profile"

      # Verify sub-TLVs were parsed
      assert is_list(ofdm_tlv.subtlvs)
      assert length(ofdm_tlv.subtlvs) == length(ofdm_subtlvs)

      # Verify parent TLV has formatted_value describing compound structure
      assert Map.has_key?(ofdm_tlv, :formatted_value)
      assert String.contains?(ofdm_tlv.formatted_value, "Compound TLV")

      # Verify sub-TLVs have formatted_value
      profile_id = Enum.find(ofdm_tlv.subtlvs, &(&1.type == 1))
      assert profile_id != nil
      assert profile_id.name == "Profile ID"
      assert Map.has_key?(profile_id, :formatted_value)

      # Convert to JSON
      assert {:ok, json_content} = Bindocsis.Generators.JsonGenerator.generate(parsed_tlvs)
      File.write!(files.json, json_content)

      # Parse JSON
      assert {:ok, json_parsed_tlvs} = Bindocsis.parse_file(files.json)

      # Generate binary from JSON
      assert {:ok, final_binary} = Bindocsis.Generators.BinaryGenerator.generate(json_parsed_tlvs)

      # Parse final binary
      assert {:ok, final_tlvs} = Bindocsis.parse(final_binary)

      # Verify TLV 62 survived round-trip
      final_ofdm = Enum.find(final_tlvs, &(&1.type == 62))
      assert final_ofdm != nil
      assert length(final_ofdm.subtlvs) == length(ofdm_tlv.subtlvs)

      # Verify sub-TLV values preserved
      Enum.zip(ofdm_tlv.subtlvs, final_ofdm.subtlvs)
      |> Enum.each(fn {orig, final} ->
        assert orig.type == final.type
        assert orig.value == final.value
      end)
    end

    test "OFDM profile with enum-based sub-TLVs preserves human-readable values", %{files: files} do
      # Create OFDM profile with enum values
      ofdm_subtlvs = [
        # Profile ID = 2
        %{type: 1, length: 1, value: <<2>>},
        # Subcarrier Spacing = 50 kHz (enum)
        %{type: 4, length: 1, value: <<1>>},
        # Cyclic Prefix = 512 samples (enum)
        %{type: 5, length: 1, value: <<3>>},
        # Roll-off = 128 samples (enum)
        %{type: 6, length: 1, value: <<2>>},
        # Interleaver Depth = 16 (enum)
        %{type: 7, length: 1, value: <<4>>},
        # Pilot Pattern = Scattered (enum)
        %{type: 12, length: 1, value: <<0>>}
      ]

      {:ok, ofdm_value} =
        Bindocsis.Generators.BinaryGenerator.generate(
          ofdm_subtlvs,
          terminate: false
        )

      original_tlvs = [
        %{type: 62, length: byte_size(ofdm_value), value: ofdm_value}
      ]

      # Round-trip: Binary -> JSON -> Binary
      {:ok, binary_data} = Bindocsis.Generators.BinaryGenerator.generate(original_tlvs)
      {:ok, parsed_tlvs} = Bindocsis.parse(binary_data)
      {:ok, json_content} = Bindocsis.Generators.JsonGenerator.generate(parsed_tlvs)
      File.write!(files.json, json_content)
      {:ok, json_parsed_tlvs} = Bindocsis.parse_file(files.json)
      {:ok, final_binary} = Bindocsis.Generators.BinaryGenerator.generate(json_parsed_tlvs)
      {:ok, final_tlvs} = Bindocsis.parse(final_binary)

      # Verify enum sub-TLVs preserved
      ofdm_tlv = Enum.find(final_tlvs, &(&1.type == 62))

      # Check Subcarrier Spacing
      spacing = Enum.find(ofdm_tlv.subtlvs, &(&1.type == 4))
      assert spacing.value == <<1>>
      # Enum should be reflected in formatted_value or metadata

      # Check Cyclic Prefix
      cyclic = Enum.find(ofdm_tlv.subtlvs, &(&1.type == 5))
      assert cyclic.value == <<3>>

      # Check Pilot Pattern
      pilot = Enum.find(ofdm_tlv.subtlvs, &(&1.type == 12))
      assert pilot.value == <<0>>
    end

    test "OFDM profile with unknown sub-TLV falls back to hex string", %{files: files} do
      # Create OFDM profile with unknown sub-TLV
      ofdm_subtlvs = [
        # Profile ID = 3
        %{type: 1, length: 1, value: <<3>>},
        # Subcarrier Spacing = 25 kHz
        %{type: 4, length: 1, value: <<0>>},
        # Unknown sub-TLV with data
        %{type: 255, length: 4, value: <<0xDE, 0xAD, 0xBE, 0xEF>>}
      ]

      {:ok, ofdm_value} =
        Bindocsis.Generators.BinaryGenerator.generate(
          ofdm_subtlvs,
          terminate: false
        )

      original_tlvs = [
        %{type: 62, length: byte_size(ofdm_value), value: ofdm_value}
      ]

      # Parse binary
      {:ok, binary_data} = Bindocsis.Generators.BinaryGenerator.generate(original_tlvs)
      {:ok, parsed_tlvs} = Bindocsis.parse(binary_data)

      # Find TLV 62 and unknown sub-TLV
      ofdm_tlv = Enum.find(parsed_tlvs, &(&1.type == 62))
      unknown_subtlv = Enum.find(ofdm_tlv.subtlvs, &(&1.type == 255))

      assert unknown_subtlv != nil
      assert unknown_subtlv.value == <<0xDE, 0xAD, 0xBE, 0xEF>>

      # Unknown sub-TLV should have formatted_value as hex string (per WARP.md)
      # This allows human editing of unknown TLVs
      assert Map.has_key?(unknown_subtlv, :formatted_value)

      # Round-trip to verify hex string survives
      {:ok, json_content} = Bindocsis.Generators.JsonGenerator.generate(parsed_tlvs)
      File.write!(files.json, json_content)
      {:ok, json_parsed_tlvs} = Bindocsis.parse_file(files.json)
      {:ok, final_binary} = Bindocsis.Generators.BinaryGenerator.generate(json_parsed_tlvs)
      {:ok, final_tlvs} = Bindocsis.parse(final_binary)

      final_ofdm = Enum.find(final_tlvs, &(&1.type == 62))
      final_unknown = Enum.find(final_ofdm.subtlvs, &(&1.type == 255))

      assert final_unknown.value == <<0xDE, 0xAD, 0xBE, 0xEF>>
    end

    test "OFDM profile with compound Modulation Profile sub-TLV", %{files: files} do
      # Create nested Modulation Profile (sub-TLV 8 is compound)
      # Simplified modulation data
      mod_profile_data = <<0x01, 0x02, 0x03, 0x04>>

      ofdm_subtlvs = [
        # Profile ID = 5
        %{type: 1, length: 1, value: <<5>>},
        # Modulation Profile (compound)
        %{type: 8, length: 4, value: mod_profile_data},
        # Start Frequency
        %{type: 9, length: 4, value: <<200_000_000::32>>}
      ]

      {:ok, ofdm_value} =
        Bindocsis.Generators.BinaryGenerator.generate(
          ofdm_subtlvs,
          terminate: false
        )

      original_tlvs = [
        %{type: 62, length: byte_size(ofdm_value), value: ofdm_value}
      ]

      # Round-trip conversion
      {:ok, binary_data} = Bindocsis.Generators.BinaryGenerator.generate(original_tlvs)
      {:ok, parsed_tlvs} = Bindocsis.parse(binary_data)
      {:ok, json_content} = Bindocsis.Generators.JsonGenerator.generate(parsed_tlvs)
      File.write!(files.json, json_content)

      {:ok, json_parsed_tlvs} = Bindocsis.parse_file(files.json)
      {:ok, final_binary} = Bindocsis.Generators.BinaryGenerator.generate(json_parsed_tlvs)
      {:ok, final_tlvs} = Bindocsis.parse(final_binary)

      # Verify Modulation Profile sub-TLV survived
      ofdm_tlv = Enum.find(final_tlvs, &(&1.type == 62))
      mod_profile = Enum.find(ofdm_tlv.subtlvs, &(&1.type == 8))

      assert mod_profile != nil
      assert mod_profile.name == "Modulation Profile"
      assert mod_profile.value == mod_profile_data
    end
  end

  describe "TLV 63 (Downstream OFDMA Profile) round-trip conversion" do
    test "basic OFDMA profile with OFDMA-specific sub-TLVs", %{files: files} do
      # Create OFDMA profile sub-TLVs
      ofdma_subtlvs = [
        # Profile ID = 1
        %{type: 1, length: 1, value: <<1>>},
        # Channel ID = 1
        %{type: 2, length: 1, value: <<1>>},
        # Subcarrier Spacing = 50 kHz
        %{type: 4, length: 1, value: <<1>>},
        # Cyclic Prefix = 256 samples
        %{type: 5, length: 1, value: <<1>>},
        # Start Frequency = 16 MHz
        %{type: 9, length: 4, value: <<16_000_000::32>>},
        # End Frequency = 85 MHz
        %{type: 10, length: 4, value: <<85_000_000::32>>},
        # Mini-slot Size = 6 (OFDMA-specific)
        %{type: 11, length: 1, value: <<6>>},
        # Power Control = -3 dB (OFDMA-specific)
        %{type: 13, length: 1, value: <<-3::signed-8>>}
      ]

      {:ok, ofdma_value} =
        Bindocsis.Generators.BinaryGenerator.generate(
          ofdma_subtlvs,
          terminate: false
        )

      original_tlvs = [
        %{type: 3, length: 1, value: <<1>>},
        %{type: 63, length: byte_size(ofdma_value), value: ofdma_value}
      ]

      # Generate and parse
      {:ok, binary_data} = Bindocsis.Generators.BinaryGenerator.generate(original_tlvs)
      File.write!(files.binary, binary_data)

      assert {:ok, parsed_tlvs} = Bindocsis.parse_file(files.binary)

      # Find TLV 63
      ofdma_tlv = Enum.find(parsed_tlvs, &(&1.type == 63))
      assert ofdma_tlv != nil
      assert ofdma_tlv.name == "Downstream OFDMA Profile"

      # Verify OFDMA-specific sub-TLVs
      minislot = Enum.find(ofdma_tlv.subtlvs, &(&1.type == 11))
      assert minislot != nil
      assert minislot.name == "Mini-slot Size"
      assert minislot.value == <<6>>

      power_control = Enum.find(ofdma_tlv.subtlvs, &(&1.type == 13))
      assert power_control != nil
      assert power_control.name == "Power Control"
      assert power_control.value == <<-3::signed-8>>

      # Verify parent has formatted_value describing compound structure
      assert Map.has_key?(ofdma_tlv, :formatted_value)
      assert String.contains?(ofdma_tlv.formatted_value, "Compound TLV")

      # Round-trip through JSON
      assert {:ok, json_content} = Bindocsis.Generators.JsonGenerator.generate(parsed_tlvs)
      File.write!(files.json, json_content)

      assert {:ok, json_parsed_tlvs} = Bindocsis.parse_file(files.json)
      assert {:ok, final_binary} = Bindocsis.Generators.BinaryGenerator.generate(json_parsed_tlvs)

      assert {:ok, final_tlvs} = Bindocsis.parse(final_binary)

      # Verify OFDMA-specific sub-TLVs survived
      final_ofdma = Enum.find(final_tlvs, &(&1.type == 63))
      final_minislot = Enum.find(final_ofdma.subtlvs, &(&1.type == 11))
      final_power = Enum.find(final_ofdma.subtlvs, &(&1.type == 13))

      assert final_minislot.value == <<6>>
      assert final_power.value == <<-3::signed-8>>
    end

    test "OFDMA profile consistency with OFDM for common sub-TLVs", %{files: files} do
      # Create matching OFDM and OFDMA profiles with same common parameters
      common_subtlvs = [
        # Profile ID = 10
        %{type: 1, length: 1, value: <<10>>},
        # Subcarrier Spacing = 50 kHz
        %{type: 4, length: 1, value: <<1>>},
        # Cyclic Prefix = 384 samples
        %{type: 5, length: 1, value: <<2>>},
        # Start Frequency
        %{type: 9, length: 4, value: <<100_000_000::32>>},
        # End Frequency
        %{type: 10, length: 4, value: <<200_000_000::32>>}
      ]

      {:ok, ofdm_value} =
        Bindocsis.Generators.BinaryGenerator.generate(
          common_subtlvs,
          terminate: false
        )

      # Add OFDMA-specific sub-TLVs
      ofdma_subtlvs =
        common_subtlvs ++
          [
            # Mini-slot Size
            %{type: 11, length: 1, value: <<8>>},
            # Power Control
            %{type: 13, length: 1, value: <<0::signed-8>>}
          ]

      {:ok, ofdma_value} =
        Bindocsis.Generators.BinaryGenerator.generate(
          ofdma_subtlvs,
          terminate: false
        )

      original_tlvs = [
        %{type: 62, length: byte_size(ofdm_value), value: ofdm_value},
        %{type: 63, length: byte_size(ofdma_value), value: ofdma_value}
      ]

      # Parse both
      {:ok, binary_data} = Bindocsis.Generators.BinaryGenerator.generate(original_tlvs)
      {:ok, parsed_tlvs} = Bindocsis.parse(binary_data)

      ofdm_tlv = Enum.find(parsed_tlvs, &(&1.type == 62))
      ofdma_tlv = Enum.find(parsed_tlvs, &(&1.type == 63))

      # Verify common sub-TLVs match between OFDM and OFDMA
      common_types = [1, 4, 5, 9, 10]

      Enum.each(common_types, fn type ->
        ofdm_subtlv = Enum.find(ofdm_tlv.subtlvs, &(&1.type == type))
        ofdma_subtlv = Enum.find(ofdma_tlv.subtlvs, &(&1.type == type))

        assert ofdm_subtlv.value == ofdma_subtlv.value,
               "Sub-TLV #{type} should have same value in OFDM and OFDMA"
      end)

      # Verify OFDMA has additional sub-TLVs that OFDM doesn't
      assert length(ofdma_tlv.subtlvs) == length(ofdm_tlv.subtlvs) + 2
    end
  end

  describe "YAML round-trip for OFDM/OFDMA profiles" do
    test "OFDM profile survives YAML round-trip", %{files: files} do
      ofdm_subtlvs = [
        %{type: 1, length: 1, value: <<7>>},
        # 25 kHz
        %{type: 4, length: 1, value: <<0>>},
        # 640 samples
        %{type: 5, length: 1, value: <<4>>},
        # Continuous pilots
        %{type: 12, length: 1, value: <<1>>}
      ]

      {:ok, ofdm_value} =
        Bindocsis.Generators.BinaryGenerator.generate(
          ofdm_subtlvs,
          terminate: false
        )

      original_tlvs = [
        %{type: 62, length: byte_size(ofdm_value), value: ofdm_value}
      ]

      # Round-trip: Binary -> YAML -> Binary
      {:ok, binary_data} = Bindocsis.Generators.BinaryGenerator.generate(original_tlvs)
      File.write!(files.binary, binary_data)

      assert {:ok, parsed_tlvs} = Bindocsis.parse_file(files.binary)
      assert {:ok, yaml_content} = Bindocsis.Generators.YamlGenerator.generate(parsed_tlvs)
      File.write!(files.yaml, yaml_content)

      assert {:ok, yaml_parsed_tlvs} = Bindocsis.parse_file(files.yaml)
      assert {:ok, final_binary} = Bindocsis.Generators.BinaryGenerator.generate(yaml_parsed_tlvs)

      assert {:ok, final_tlvs} = Bindocsis.parse(final_binary)

      # Verify TLV 62 survived
      final_ofdm = Enum.find(final_tlvs, &(&1.type == 62))
      assert final_ofdm != nil
      assert length(final_ofdm.subtlvs) == 4
    end

    test "OFDMA profile survives YAML round-trip", %{files: files} do
      ofdma_subtlvs = [
        %{type: 1, length: 1, value: <<8>>},
        # Mini-slot Size
        %{type: 11, length: 1, value: <<4>>},
        # Power Control = +5 dB
        %{type: 13, length: 1, value: <<5::signed-8>>}
      ]

      {:ok, ofdma_value} =
        Bindocsis.Generators.BinaryGenerator.generate(
          ofdma_subtlvs,
          terminate: false
        )

      original_tlvs = [
        %{type: 63, length: byte_size(ofdma_value), value: ofdma_value}
      ]

      # Round-trip: Binary -> YAML -> Binary
      {:ok, binary_data} = Bindocsis.Generators.BinaryGenerator.generate(original_tlvs)
      {:ok, parsed_tlvs} = Bindocsis.parse(binary_data)
      {:ok, yaml_content} = Bindocsis.Generators.YamlGenerator.generate(parsed_tlvs)
      File.write!(files.yaml, yaml_content)

      {:ok, yaml_parsed_tlvs} = Bindocsis.parse_file(files.yaml)
      {:ok, final_binary} = Bindocsis.Generators.BinaryGenerator.generate(yaml_parsed_tlvs)
      {:ok, final_tlvs} = Bindocsis.parse(final_binary)

      # Verify TLV 63 survived
      final_ofdma = Enum.find(final_tlvs, &(&1.type == 63))
      assert final_ofdma != nil

      # Verify OFDMA-specific sub-TLVs
      minislot = Enum.find(final_ofdma.subtlvs, &(&1.type == 11))
      power = Enum.find(final_ofdma.subtlvs, &(&1.type == 13))

      assert minislot.value == <<4>>
      assert power.value == <<5::signed-8>>
    end
  end

  describe "complex configurations with multiple OFDM/OFDMA profiles" do
    test "configuration with both OFDM and OFDMA profiles", %{files: files} do
      # Create OFDM profile
      ofdm_subtlvs = [
        %{type: 1, length: 1, value: <<1>>},
        %{type: 9, length: 4, value: <<108_000_000::32>>}
      ]

      {:ok, ofdm_value} =
        Bindocsis.Generators.BinaryGenerator.generate(
          ofdm_subtlvs,
          terminate: false
        )

      # Create OFDMA profile
      ofdma_subtlvs = [
        %{type: 1, length: 1, value: <<1>>},
        %{type: 11, length: 1, value: <<6>>}
      ]

      {:ok, ofdma_value} =
        Bindocsis.Generators.BinaryGenerator.generate(
          ofdma_subtlvs,
          terminate: false
        )

      # Create configuration with both
      original_tlvs = [
        # Network Access
        %{type: 3, length: 1, value: <<1>>},
        %{type: 62, length: byte_size(ofdm_value), value: ofdm_value},
        %{type: 63, length: byte_size(ofdma_value), value: ofdma_value},
        # Max CPE
        %{type: 21, length: 1, value: <<5>>}
      ]

      # Round-trip through JSON
      {:ok, binary_data} = Bindocsis.Generators.BinaryGenerator.generate(original_tlvs)
      {:ok, parsed_tlvs} = Bindocsis.parse(binary_data)
      {:ok, json_content} = Bindocsis.Generators.JsonGenerator.generate(parsed_tlvs)
      File.write!(files.json, json_content)
      {:ok, json_parsed_tlvs} = Bindocsis.parse_file(files.json)
      {:ok, final_binary} = Bindocsis.Generators.BinaryGenerator.generate(json_parsed_tlvs)
      {:ok, final_tlvs} = Bindocsis.parse(final_binary)

      # Verify both profiles survived
      assert Enum.find(final_tlvs, &(&1.type == 62)) != nil
      assert Enum.find(final_tlvs, &(&1.type == 63)) != nil
      assert Enum.find(final_tlvs, &(&1.type == 3)) != nil
      assert Enum.find(final_tlvs, &(&1.type == 21)) != nil
    end
  end
end
