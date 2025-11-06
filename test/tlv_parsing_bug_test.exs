defmodule TlvParsingBugTest do
  use ExUnit.Case
  doctest Bindocsis

  @moduletag :tlv_parsing_bug

  describe "compound TLV parsing - CORRECTED understanding" do
    setup do
      {:ok, tlvs} = Bindocsis.parse_file("test/fixtures/tlv_parse_bug_test.cm")
      {:ok, tlvs: tlvs}
    end

    test "service flow sub-TLVs are in a DIFFERENT namespace than global TLVs", %{tlvs: tlvs} do
      # This test documents that TLV type numbers have different meanings in different contexts
      # Service flow sub-TLV 6 = "QoS Parameter Set" (NOT the same as global TLV 6)
      # Service flow sub-TLV 7 = "QoS Parameter Set Type" (NOT the same as global TLV 7)

      service_flows = Enum.filter(tlvs, &(&1.type in [24, 25]))
      assert length(service_flows) > 0, "Expected to find service flow TLVs"

      # Service flows CAN contain sub-TLVs 6 and 7 - these are QoS-related fields
      for sf <- service_flows do
        sub_tlvs = sf.subtlvs || []
        sub_tlv_types = Enum.map(sub_tlvs, & &1.type)

        # Sub-TLV 6 in service flows is "QoS Parameter Set", NOT "CM MIC"
        if 6 in sub_tlv_types do
          sub_tlv_6 = Enum.find(sub_tlvs, &(&1.type == 6))

          assert sub_tlv_6.name == "QoS Parameter Set",
                 "Service flow sub-TLV 6 should be 'QoS Parameter Set', got '#{sub_tlv_6.name}'"
        end

        # Sub-TLV 7 in service flows is "QoS Parameter Set Type", NOT "CMTS MIC"
        if 7 in sub_tlv_types do
          sub_tlv_7 = Enum.find(sub_tlvs, &(&1.type == 7))

          assert sub_tlv_7.name == "QoS Parameter Set Type",
                 "Service flow sub-TLV 7 should be 'QoS Parameter Set Type', got '#{sub_tlv_7.name}'"
        end
      end
    end

    test "SNMP MIB Object TLVs (type 11) should not contain MIC sub-TLVs", %{tlvs: tlvs} do
      # Find SNMP MIB Object TLVs
      snmp_tlvs = Enum.filter(tlvs, &(&1.type == 11))

      # SNMP objects should exist
      assert length(snmp_tlvs) > 0, "Expected to find SNMP MIB Object TLVs"

      # They should NOT contain TLV 6 or 7 as sub-TLVs
      for snmp <- snmp_tlvs do
        sub_tlv_types = Enum.map(snmp.subtlvs || [], & &1.type)

        refute 6 in sub_tlv_types,
               "TLV 11 (SNMP MIB Object) incorrectly contains TLV 6 (CM MIC) as sub-TLV. " <>
                 "Sub-TLVs found: #{inspect(sub_tlv_types)}"

        refute 7 in sub_tlv_types,
               "TLV 11 (SNMP MIB Object) incorrectly contains TLV 7 (CMTS MIC) as sub-TLV. " <>
                 "Sub-TLVs found: #{inspect(sub_tlv_types)}"
      end
    end

    test "MIC TLVs (6 and 7) should appear at global level", %{tlvs: tlvs} do
      # Get all global TLV types
      global_types = Enum.map(tlvs, & &1.type)

      # Should find TLV 6 and 7 at root level
      assert 6 in global_types,
             "TLV 6 (CM Message Integrity Check) should be at global level. " <>
               "Global TLVs found: #{inspect(Enum.sort(global_types))}"

      assert 7 in global_types,
             "TLV 7 (CMTS Message Integrity Check) should be at global level. " <>
               "Global TLVs found: #{inspect(Enum.sort(global_types))}"
    end

    test "MIC TLVs should be 16 bytes each", %{tlvs: tlvs} do
      cm_mic = Enum.find(tlvs, &(&1.type == 6))
      cmts_mic = Enum.find(tlvs, &(&1.type == 7))

      if cm_mic do
        assert cm_mic.length == 16,
               "TLV 6 (CM MIC) should be 16 bytes, got #{cm_mic.length}"
      end

      if cmts_mic do
        assert cmts_mic.length == 16,
               "TLV 7 (CMTS MIC) should be 16 bytes, got #{cmts_mic.length}"
      end
    end

    test "binary structure validation - manual parse", %{tlvs: _tlvs} do
      # Read the raw binary to verify our assumptions
      {:ok, data} = File.read("test/fixtures/tlv_parse_bug_test.cm")

      # Check the end of file for MIC TLVs
      # Last bytes should be: TLV6 (06 10 ...), TLV7 (07 10 ...), FF (terminator)
      tail = binary_part(data, byte_size(data) - 40, 40)

      # Look for the pattern 06 10 (TLV 6, length 16)
      assert String.contains?(tail, <<0x06, 0x10>>),
             "Expected to find TLV 6 marker (06 10) near end of file"

      # Look for the pattern 07 10 (TLV 7, length 16)
      assert String.contains?(tail, <<0x07, 0x10>>),
             "Expected to find TLV 7 marker (07 10) near end of file"

      # Look for FF terminator
      assert String.contains?(tail, <<0xFF>>),
             "Expected to find FF terminator near end of file"
    end
  end

  describe "binary structure analysis" do
    test "parse first few TLVs manually to verify structure" do
      {:ok, data} = File.read("test/fixtures/tlv_parse_bug_test.cm")

      # Parse first TLV
      <<type1, len1, rest1::binary>> = data
      assert type1 == 3, "First TLV should be type 3 (Network Access Control)"
      assert len1 == 1, "First TLV should have length 1"

      # Parse second TLV
      <<_val1::binary-size(len1), type2, len2, _rest2::binary>> = rest1
      assert type2 == 24, "Second TLV should be type 24 (Downstream Service Flow)"
      assert len2 == 16, "Second TLV should have length 16"

      # The value of TLV 24 should NOT start with 01 02 00 01 06 01 07...
      # It should contain service flow sub-TLVs in proper format
    end
  end

  describe "debugging output" do
    test "show parsed structure for manual inspection" do
      {:ok, tlvs} = Bindocsis.parse_file("test/fixtures/tlv_parse_bug_test.cm")

      IO.puts("\n=== Parsed TLV Structure ===")
      IO.puts("Total global TLVs: #{length(tlvs)}")

      global_types = Enum.map(tlvs, & &1.type) |> Enum.frequencies()
      IO.puts("\nGlobal TLV type distribution:")

      Enum.each(global_types, fn {type, count} ->
        IO.puts("  Type #{type}: #{count} occurrence(s)")
      end)

      # Show service flows
      service_flows = Enum.filter(tlvs, &(&1.type in [24, 25]))
      IO.puts("\n=== Service Flows (#{length(service_flows)}) ===")

      Enum.each(service_flows, fn sf ->
        sub_types = Enum.map(sf.subtlvs || [], & &1.type)
        IO.puts("TLV #{sf.type} (#{sf.name}):")
        IO.puts("  Length: #{sf.length}")
        IO.puts("  Sub-TLVs: #{inspect(sub_types)}")
      end)

      # Show SNMP objects
      snmp_tlvs = Enum.filter(tlvs, &(&1.type == 11))
      IO.puts("\n=== SNMP MIB Objects (#{length(snmp_tlvs)}) ===")

      Enum.each(Enum.take(snmp_tlvs, 3), fn snmp ->
        sub_types = Enum.map(snmp.subtlvs || [], & &1.type)
        IO.puts("TLV 11:")
        IO.puts("  Length: #{snmp.length}")
        IO.puts("  Sub-TLVs: #{inspect(sub_types)}")
      end)

      # Show MIC TLVs if found at global level
      cm_mic = Enum.find(tlvs, &(&1.type == 6))
      cmts_mic = Enum.find(tlvs, &(&1.type == 7))

      IO.puts("\n=== Message Integrity Checks ===")

      if cm_mic do
        IO.puts("✓ TLV 6 (CM MIC) found at global level - Length: #{cm_mic.length}")
      else
        IO.puts("✗ TLV 6 (CM MIC) NOT found at global level")
      end

      if cmts_mic do
        IO.puts("✓ TLV 7 (CMTS MIC) found at global level - Length: #{cmts_mic.length}")
      else
        IO.puts("✗ TLV 7 (CMTS MIC) NOT found at global level")
      end
    end
  end
end
