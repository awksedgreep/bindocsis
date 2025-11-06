defmodule Bindocsis.SubTlv6263Test do
  use ExUnit.Case
  alias Bindocsis.SubTlvSpecs

  describe "TLV 62 (Downstream OFDM Profile) sub-TLV specifications" do
    test "retrieves sub-TLV specifications for TLV 62" do
      assert {:ok, subtlvs} = SubTlvSpecs.get_subtlv_specs(62)
      assert is_map(subtlvs)
      assert map_size(subtlvs) == 12
    end

    test "TLV 62 has all expected sub-TLV types" do
      {:ok, subtlvs} = SubTlvSpecs.get_subtlv_specs(62)

      # Verify all 12 sub-TLV types are present
      for type <- 1..12 do
        assert Map.has_key?(subtlvs, type), "Sub-TLV #{type} should exist"
      end
    end

    test "TLV 62 Sub-TLV 1 (Profile ID) has correct specification" do
      {:ok, subtlvs} = SubTlvSpecs.get_subtlv_specs(62)
      profile_id = subtlvs[1]

      assert profile_id.name == "Profile ID"
      assert profile_id.description == "OFDM profile identifier"
      assert profile_id.value_type == :uint8
      assert profile_id.max_length == 1
      assert profile_id.enum_values == nil
    end

    test "TLV 62 Sub-TLV 2 (Channel ID) has correct specification" do
      {:ok, subtlvs} = SubTlvSpecs.get_subtlv_specs(62)
      channel_id = subtlvs[2]

      assert channel_id.name == "Channel ID"
      assert channel_id.description == "OFDM channel identifier"
      assert channel_id.value_type == :uint8
      assert channel_id.max_length == 1
    end

    test "TLV 62 Sub-TLV 3 (Configuration Change Count) has correct specification" do
      {:ok, subtlvs} = SubTlvSpecs.get_subtlv_specs(62)
      change_count = subtlvs[3]

      assert change_count.name == "Configuration Change Count"
      assert change_count.value_type == :uint8
      assert change_count.max_length == 1
    end

    test "TLV 62 Sub-TLV 4 (Subcarrier Spacing) has correct enum values" do
      {:ok, subtlvs} = SubTlvSpecs.get_subtlv_specs(62)
      spacing = subtlvs[4]

      assert spacing.name == "Subcarrier Spacing"
      assert spacing.value_type == :uint8
      assert spacing.max_length == 1

      assert spacing.enum_values == %{
               0 => "25 kHz",
               1 => "50 kHz"
             }
    end

    test "TLV 62 Sub-TLV 5 (Cyclic Prefix) has 8 enum options" do
      {:ok, subtlvs} = SubTlvSpecs.get_subtlv_specs(62)
      cyclic_prefix = subtlvs[5]

      assert cyclic_prefix.name == "Cyclic Prefix"
      assert cyclic_prefix.value_type == :uint8
      assert cyclic_prefix.max_length == 1
      assert map_size(cyclic_prefix.enum_values) == 8

      # Verify all 8 options are present
      for i <- 0..7 do
        assert Map.has_key?(cyclic_prefix.enum_values, i), "Option #{i} should exist"
      end

      # Verify specific values
      assert cyclic_prefix.enum_values[0] == "192 samples"
      assert cyclic_prefix.enum_values[7] == "1024 samples"
    end

    test "TLV 62 Sub-TLV 6 (Roll-off Period) has correct enum values" do
      {:ok, subtlvs} = SubTlvSpecs.get_subtlv_specs(62)
      rolloff = subtlvs[6]

      assert rolloff.name == "Roll-off Period"
      assert rolloff.value_type == :uint8
      assert rolloff.max_length == 1
      assert map_size(rolloff.enum_values) == 5
      assert rolloff.enum_values[0] == "0 samples"
      assert rolloff.enum_values[4] == "256 samples"
    end

    test "TLV 62 Sub-TLV 7 (Interleaver Depth) has correct enum values" do
      {:ok, subtlvs} = SubTlvSpecs.get_subtlv_specs(62)
      interleaver = subtlvs[7]

      assert interleaver.name == "Interleaver Depth"
      assert interleaver.value_type == :uint8
      assert interleaver.max_length == 1
      assert map_size(interleaver.enum_values) == 6
      assert interleaver.enum_values[0] == "1 (no interleaving)"
      assert interleaver.enum_values[5] == "32"
    end

    test "TLV 62 Sub-TLV 8 (Modulation Profile) is compound type" do
      {:ok, subtlvs} = SubTlvSpecs.get_subtlv_specs(62)
      modulation = subtlvs[8]

      assert modulation.name == "Modulation Profile"
      assert modulation.value_type == :compound
      assert modulation.max_length == :unlimited
      assert modulation.enum_values == nil
    end

    test "TLV 62 Sub-TLV 9 (Start Frequency) has correct specification" do
      {:ok, subtlvs} = SubTlvSpecs.get_subtlv_specs(62)
      start_freq = subtlvs[9]

      assert start_freq.name == "Start Frequency"
      assert start_freq.value_type == :uint32
      assert start_freq.max_length == 4
    end

    test "TLV 62 Sub-TLV 10 (End Frequency) has correct specification" do
      {:ok, subtlvs} = SubTlvSpecs.get_subtlv_specs(62)
      end_freq = subtlvs[10]

      assert end_freq.name == "End Frequency"
      assert end_freq.value_type == :uint32
      assert end_freq.max_length == 4
    end

    test "TLV 62 Sub-TLV 11 (Number of Subcarriers) has correct specification" do
      {:ok, subtlvs} = SubTlvSpecs.get_subtlv_specs(62)
      num_subcarriers = subtlvs[11]

      assert num_subcarriers.name == "Number of Subcarriers"
      assert num_subcarriers.value_type == :uint16
      assert num_subcarriers.max_length == 2
    end

    test "TLV 62 Sub-TLV 12 (Pilot Pattern) has correct enum values" do
      {:ok, subtlvs} = SubTlvSpecs.get_subtlv_specs(62)
      pilot = subtlvs[12]

      assert pilot.name == "Pilot Pattern"
      assert pilot.value_type == :uint8
      assert pilot.max_length == 1
      assert map_size(pilot.enum_values) == 3
      assert pilot.enum_values[0] == "Scattered pilots"
      assert pilot.enum_values[1] == "Continuous pilots"
      assert pilot.enum_values[2] == "Mixed pattern"
    end

    test "all TLV 62 sub-TLVs have required fields" do
      {:ok, subtlvs} = SubTlvSpecs.get_subtlv_specs(62)

      for {type, subtlv} <- subtlvs do
        assert Map.has_key?(subtlv, :name), "Sub-TLV #{type} missing :name"
        assert Map.has_key?(subtlv, :description), "Sub-TLV #{type} missing :description"
        assert Map.has_key?(subtlv, :value_type), "Sub-TLV #{type} missing :value_type"
        assert Map.has_key?(subtlv, :max_length), "Sub-TLV #{type} missing :max_length"
        assert Map.has_key?(subtlv, :enum_values), "Sub-TLV #{type} missing :enum_values"
      end
    end
  end

  describe "TLV 63 (Downstream OFDMA Profile) sub-TLV specifications" do
    test "retrieves sub-TLV specifications for TLV 63" do
      assert {:ok, subtlvs} = SubTlvSpecs.get_subtlv_specs(63)
      assert is_map(subtlvs)
      assert map_size(subtlvs) == 13
    end

    test "TLV 63 has all expected sub-TLV types" do
      {:ok, subtlvs} = SubTlvSpecs.get_subtlv_specs(63)

      # Verify all 13 sub-TLV types are present
      for type <- 1..13 do
        assert Map.has_key?(subtlvs, type), "Sub-TLV #{type} should exist"
      end
    end

    test "TLV 63 Sub-TLV 1 (Profile ID) has correct specification" do
      {:ok, subtlvs} = SubTlvSpecs.get_subtlv_specs(63)
      profile_id = subtlvs[1]

      assert profile_id.name == "Profile ID"
      assert profile_id.description == "OFDMA profile identifier"
      assert profile_id.value_type == :uint8
      assert profile_id.max_length == 1
    end

    test "TLV 63 Sub-TLV 4 (Subcarrier Spacing) matches TLV 62" do
      {:ok, subtlvs_62} = SubTlvSpecs.get_subtlv_specs(62)
      {:ok, subtlvs_63} = SubTlvSpecs.get_subtlv_specs(63)

      # Both should have identical subcarrier spacing enums
      assert subtlvs_63[4].enum_values == subtlvs_62[4].enum_values
    end

    test "TLV 63 Sub-TLV 5 (Cyclic Prefix) matches TLV 62" do
      {:ok, subtlvs_62} = SubTlvSpecs.get_subtlv_specs(62)
      {:ok, subtlvs_63} = SubTlvSpecs.get_subtlv_specs(63)

      # Both should have identical cyclic prefix enums
      assert subtlvs_63[5].enum_values == subtlvs_62[5].enum_values
    end

    test "TLV 63 Sub-TLV 11 (Mini-slot Size) is unique to OFDMA" do
      {:ok, subtlvs} = SubTlvSpecs.get_subtlv_specs(63)
      minislot = subtlvs[11]

      assert minislot.name == "Mini-slot Size"
      assert minislot.description == "Upstream mini-slot size in OFDMA symbols"
      assert minislot.value_type == :uint8
      assert minislot.max_length == 1
    end

    test "TLV 63 Sub-TLV 12 (Pilot Pattern) has correct enum values" do
      {:ok, subtlvs} = SubTlvSpecs.get_subtlv_specs(63)
      pilot = subtlvs[12]

      assert pilot.name == "Pilot Pattern"
      assert pilot.value_type == :uint8
      assert pilot.max_length == 1
      assert map_size(pilot.enum_values) == 3
    end

    test "TLV 63 Sub-TLV 13 (Power Control) is unique to OFDMA" do
      {:ok, subtlvs} = SubTlvSpecs.get_subtlv_specs(63)
      power_control = subtlvs[13]

      assert power_control.name == "Power Control"
      assert power_control.description == "Upstream power control parameter"
      assert power_control.value_type == :int8
      assert power_control.max_length == 1
    end

    test "all TLV 63 sub-TLVs have required fields" do
      {:ok, subtlvs} = SubTlvSpecs.get_subtlv_specs(63)

      for {type, subtlv} <- subtlvs do
        assert Map.has_key?(subtlv, :name), "Sub-TLV #{type} missing :name"
        assert Map.has_key?(subtlv, :description), "Sub-TLV #{type} missing :description"
        assert Map.has_key?(subtlv, :value_type), "Sub-TLV #{type} missing :value_type"
        assert Map.has_key?(subtlv, :max_length), "Sub-TLV #{type} missing :max_length"
        assert Map.has_key?(subtlv, :enum_values), "Sub-TLV #{type} missing :enum_values"
      end
    end
  end

  describe "TLV 62/63 integration with SubTlvSpecs module" do
    test "supports_subtlvs?/1 returns true for TLV 62" do
      assert SubTlvSpecs.supports_subtlvs?(62) == true
    end

    test "supports_subtlvs?/1 returns true for TLV 63" do
      assert SubTlvSpecs.supports_subtlvs?(63) == true
    end

    test "get_subtlv_info/2 retrieves individual sub-TLV for TLV 62" do
      assert {:ok, subtlv} = SubTlvSpecs.get_subtlv_info(62, 1)
      assert subtlv.name == "Profile ID"
    end

    test "get_subtlv_info/2 retrieves individual sub-TLV for TLV 63" do
      assert {:ok, subtlv} = SubTlvSpecs.get_subtlv_info(63, 13)
      assert subtlv.name == "Power Control"
    end

    test "get_subtlv_info/2 returns error for unknown sub-TLV" do
      assert {:error, :unknown_subtlv} = SubTlvSpecs.get_subtlv_info(62, 99)
      assert {:error, :unknown_subtlv} = SubTlvSpecs.get_subtlv_info(63, 99)
    end
  end

  describe "TLV 62/63 consistency checks" do
    test "common sub-TLVs have consistent types between OFDM and OFDMA" do
      {:ok, ofdm} = SubTlvSpecs.get_subtlv_specs(62)
      {:ok, ofdma} = SubTlvSpecs.get_subtlv_specs(63)

      # Check common sub-TLVs (1-10) have same value_type and max_length
      common_types = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10]

      for type <- common_types do
        assert ofdm[type].value_type == ofdma[type].value_type,
               "Sub-TLV #{type} value_type mismatch"

        assert ofdm[type].max_length == ofdma[type].max_length,
               "Sub-TLV #{type} max_length mismatch"
      end
    end

    test "frequency sub-TLVs use uint32 for Hz precision" do
      {:ok, ofdm} = SubTlvSpecs.get_subtlv_specs(62)
      {:ok, ofdma} = SubTlvSpecs.get_subtlv_specs(63)

      # Start and End Frequency should be uint32
      assert ofdm[9].value_type == :uint32
      assert ofdm[10].value_type == :uint32
      assert ofdma[9].value_type == :uint32
      assert ofdma[10].value_type == :uint32
    end

    test "all enum-based sub-TLVs use uint8 value_type" do
      {:ok, ofdm} = SubTlvSpecs.get_subtlv_specs(62)

      enum_subtlvs = [4, 5, 6, 7, 12]

      for type <- enum_subtlvs do
        assert ofdm[type].value_type == :uint8, "Sub-TLV #{type} should be uint8"
        assert is_map(ofdm[type].enum_values), "Sub-TLV #{type} should have enum_values"
      end
    end
  end

  describe "value type validation" do
    test "uint8 types have max_length of 1" do
      {:ok, ofdm} = SubTlvSpecs.get_subtlv_specs(62)

      for {type, subtlv} <- ofdm do
        if subtlv.value_type == :uint8 do
          assert subtlv.max_length == 1,
                 "Sub-TLV #{type} is uint8 but max_length is not 1"
        end
      end
    end

    test "uint16 types have max_length of 2" do
      {:ok, ofdm} = SubTlvSpecs.get_subtlv_specs(62)

      for {type, subtlv} <- ofdm do
        if subtlv.value_type == :uint16 do
          assert subtlv.max_length == 2,
                 "Sub-TLV #{type} is uint16 but max_length is not 2"
        end
      end
    end

    test "uint32 types have max_length of 4" do
      {:ok, ofdm} = SubTlvSpecs.get_subtlv_specs(62)

      for {type, subtlv} <- ofdm do
        if subtlv.value_type == :uint32 do
          assert subtlv.max_length == 4,
                 "Sub-TLV #{type} is uint32 but max_length is not 4"
        end
      end
    end

    test "compound types have max_length of :unlimited" do
      {:ok, ofdm} = SubTlvSpecs.get_subtlv_specs(62)

      for {type, subtlv} <- ofdm do
        if subtlv.value_type == :compound do
          assert subtlv.max_length == :unlimited,
                 "Sub-TLV #{type} is compound but max_length is not :unlimited"
        end
      end
    end
  end
end
