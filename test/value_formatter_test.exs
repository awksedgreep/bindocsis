defmodule Bindocsis.ValueFormatterTest do
  use ExUnit.Case
  doctest Bindocsis.ValueFormatter

  alias Bindocsis.ValueFormatter

  describe "frequency formatting" do
    test "formats frequency values in Hz to MHz/GHz" do
      # 591 MHz frequency
      assert {:ok, "591 MHz"} = ValueFormatter.format_value(:frequency, <<35, 57, 241, 192>>)

      # 1 GHz frequency  
      assert {:ok, "1 GHz"} = ValueFormatter.format_value(:frequency, <<59, 154, 202, 0>>)

      # Low frequency in KHz (1000 Hz actually gets formatted as 1 KHz by auto-formatting)
      assert {:ok, "1 KHz"} = ValueFormatter.format_value(:frequency, <<0, 0, 3, 232>>)
    end

    test "supports custom precision for frequency formatting" do
      # Use a frequency that has decimal places: 591.25 MHz = 591,250,000 Hz
      # 591.25 MHz
      frequency_hz = <<35, 61, 194, 80>>

      assert {:ok, "591 MHz"} =
               ValueFormatter.format_value(:frequency, frequency_hz, precision: 0)

      assert {:ok, "591.25 MHz"} =
               ValueFormatter.format_value(:frequency, frequency_hz, precision: 2)
    end

    test "supports unit preference override" do
      # 591 MHz = 591,000,000 Hz
      frequency_hz = <<35, 57, 241, 192>>

      assert {:ok, "591000000 Hz"} =
               ValueFormatter.format_value(:frequency, frequency_hz, unit_preference: :hz)

      assert {:ok, "0.59 GHz"} =
               ValueFormatter.format_value(:frequency, frequency_hz, unit_preference: :ghz)
    end
  end

  describe "IP address formatting" do
    test "formats IPv4 addresses correctly" do
      assert {:ok, "192.168.1.100"} = ValueFormatter.format_value(:ipv4, <<192, 168, 1, 100>>)
      assert {:ok, "10.0.0.1"} = ValueFormatter.format_value(:ipv4, <<10, 0, 0, 1>>)
      assert {:ok, "255.255.255.255"} = ValueFormatter.format_value(:ipv4, <<255, 255, 255, 255>>)
    end

    test "formats IPv6 addresses correctly" do
      ipv6_binary =
        <<0x20, 0x01, 0x0D, 0xB8, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
          0x00, 0x01>>

      assert {:ok, "2001:db8:0:0:0:0:0:1"} = ValueFormatter.format_value(:ipv6, ipv6_binary)
    end
  end

  describe "bandwidth formatting" do
    test "formats bandwidth values in bps to Mbps/Gbps" do
      # 100 Mbps = 100,000,000 bps 
      assert {:ok, "100 Mbps"} = ValueFormatter.format_value(:bandwidth, <<5, 245, 225, 0>>)

      # 1 Gbps = 1,000,000,000 bps
      assert {:ok, "1 Gbps"} = ValueFormatter.format_value(:bandwidth, <<59, 154, 202, 0>>)

      # Low bandwidth in Kbps (1000 bps gets auto-formatted as 1 Kbps)
      assert {:ok, "1 Kbps"} = ValueFormatter.format_value(:bandwidth, <<0, 0, 3, 232>>)
    end
  end

  describe "boolean formatting" do
    test "formats boolean values correctly" do
      assert {:ok, "Disabled"} = ValueFormatter.format_value(:boolean, <<0>>)
      assert {:ok, "Enabled"} = ValueFormatter.format_value(:boolean, <<1>>)
    end
  end

  describe "MAC address formatting" do
    test "formats MAC addresses correctly" do
      assert {:ok, "00:11:22:33:44:55"} =
               ValueFormatter.format_value(:mac_address, <<0x00, 0x11, 0x22, 0x33, 0x44, 0x55>>)

      assert {:ok, "FF:FF:FF:FF:FF:FF"} =
               ValueFormatter.format_value(:mac_address, <<0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF>>)
    end
  end

  describe "integer formatting" do
    test "formats various integer types" do
      assert {:ok, "255"} = ValueFormatter.format_value(:uint8, <<255>>)
      assert {:ok, "65535"} = ValueFormatter.format_value(:uint16, <<255, 255>>)
      assert {:ok, "4294967295"} = ValueFormatter.format_value(:uint32, <<255, 255, 255, 255>>)
    end
  end

  describe "string formatting" do
    test "formats string values correctly" do
      assert {:ok, "Test String"} = ValueFormatter.format_value(:string, "Test String")
      assert {:ok, "Null Terminated"} = ValueFormatter.format_value(:string, "Null Terminated\0")
    end

    test "handles invalid UTF-8 as binary" do
      invalid_utf8 = <<0xFF, 0xFE, 0xFD>>
      assert {:ok, "FFFEFD"} = ValueFormatter.format_value(:string, invalid_utf8)
    end
  end

  describe "duration formatting" do
    test "formats duration values in human-readable form" do
      assert {:ok, "30 second(s)"} = ValueFormatter.format_value(:duration, <<0, 0, 0, 30>>)
      # 300 seconds
      assert {:ok, "5 minute(s)"} = ValueFormatter.format_value(:duration, <<0, 0, 1, 44>>)
      # 3600 seconds
      assert {:ok, "1 hour(s)"} = ValueFormatter.format_value(:duration, <<0, 0, 14, 16>>)
      # 86400 seconds
      assert {:ok, "1 day(s)"} = ValueFormatter.format_value(:duration, <<0, 1, 81, 128>>)
    end
  end

  describe "percentage formatting" do
    test "formats percentage values correctly" do
      assert {:ok, "75%"} = ValueFormatter.format_value(:percentage, <<75>>)
      assert {:ok, "100%"} = ValueFormatter.format_value(:percentage, <<100>>)
      assert {:ok, "0%"} = ValueFormatter.format_value(:percentage, <<0>>)
    end
  end

  describe "service flow reference formatting" do
    test "formats service flow references correctly" do
      assert {:ok, "Service Flow #1"} = ValueFormatter.format_value(:service_flow_ref, <<0, 1>>)

      assert {:ok, "Service Flow #255"} =
               ValueFormatter.format_value(:service_flow_ref, <<0, 255>>)

      assert {:ok, "Service Flow #1024"} =
               ValueFormatter.format_value(:service_flow_ref, <<4, 0>>)
    end
  end

  describe "vendor OUI formatting" do
    test "formats known vendor OUIs with names" do
      assert {:ok, "Cisco Systems (00:00:0C)"} =
               ValueFormatter.format_value(:vendor_oui, <<0x00, 0x00, 0x0C>>)

      assert {:ok, "Broadcom Corporation (00:10:95)"} =
               ValueFormatter.format_value(:vendor_oui, <<0x00, 0x10, 0x95>>)
    end

    test "formats unknown vendor OUIs as hex" do
      assert {:ok, "12:34:56"} = ValueFormatter.format_value(:vendor_oui, <<0x12, 0x34, 0x56>>)
    end
  end

  describe "binary formatting" do
    test "formats binary data as hex in compact mode" do
      assert {:ok, "DEADBEEF"} = ValueFormatter.format_value(:binary, <<0xDE, 0xAD, 0xBE, 0xEF>>)
    end

    test "formats binary data verbosely with hex dump" do
      binary_data = <<0xDE, 0xAD, 0xBE, 0xEF, 0xCA, 0xFE, 0xBA, 0xBE>>

      assert {:ok, hex_dump} =
               ValueFormatter.format_value(:binary, binary_data, format_style: :verbose)

      assert is_binary(hex_dump)
      assert String.contains?(hex_dump, "0000:")
    end
  end

  describe "compound TLV formatting" do
    test "formats compound TLVs in compact mode" do
      compound_data = <<1, 4, 192, 168, 1, 1, 2, 1, 5>>

      assert {:ok, "<Compound TLV: 9 bytes>"} =
               ValueFormatter.format_value(:compound, compound_data)
    end

    test "formats compound TLVs in verbose mode" do
      compound_data = <<1, 4, 192, 168, 1, 1>>

      assert {:ok, result} =
               ValueFormatter.format_value(:compound, compound_data, format_style: :verbose)

      assert is_map(result)
      assert Map.has_key?(result, "subtlvs")
      assert is_list(result["subtlvs"])
      # Check that the first subtlv has expected structure
      [first_subtlv | _] = result["subtlvs"]
      assert first_subtlv.type == 1
      assert first_subtlv.length == 4
      assert first_subtlv.value == "C0A80101"
    end
  end

  describe "vendor-specific formatting" do
    test "formats vendor TLVs with known OUI as structured data" do
      # Cisco + data
      vendor_data = <<0x00, 0x00, 0x0C, 0x01, 0x02, 0x03, 0x04>>
      assert {:ok, result} = ValueFormatter.format_value(:vendor, vendor_data)

      assert is_map(result)
      assert result["vendor_name"] == "Cisco Systems"
      assert result["oui"] == "00:00:0C"
      assert result["data"] == "01020304"
    end

    test "formats vendor TLVs with unknown OUI as structured data" do
      # Unknown OUI + data
      vendor_data = <<0x12, 0x34, 0x56, 0x01, 0x02>>
      assert {:ok, result} = ValueFormatter.format_value(:vendor, vendor_data)

      assert is_map(result)
      assert result["oui"] == "12:34:56"
      assert result["data"] == "0102"
      # Unknown OUI shouldn't have vendor_name
      refute Map.has_key?(result, "vendor_name")
    end

    test "formats vendor TLVs in verbose mode" do
      # Broadcom + data
      vendor_data = <<0x00, 0x10, 0x95, 0xAB, 0xCD>>

      assert {:ok, result} =
               ValueFormatter.format_value(:vendor, vendor_data, format_style: :verbose)

      assert is_map(result)
      assert result["vendor_name"] == "Broadcom Corporation"
      assert result["oui"] == "00:10:95"
      assert result["data"] == "ABCD"
    end
  end

  describe "raw value formatting" do
    test "formats raw frequency values" do
      assert {:ok, "591 MHz"} = ValueFormatter.format_raw_value(:frequency, 591_000_000)
      assert {:ok, "1 GHz"} = ValueFormatter.format_raw_value(:frequency, 1_000_000_000)
    end

    test "formats raw bandwidth values" do
      assert {:ok, "100 Mbps"} = ValueFormatter.format_raw_value(:bandwidth, 100_000_000)
      assert {:ok, "1 Gbps"} = ValueFormatter.format_raw_value(:bandwidth, 1_000_000_000)
    end

    test "formats raw boolean values" do
      assert {:ok, "Enabled"} = ValueFormatter.format_raw_value(:boolean, 1)
      assert {:ok, "Disabled"} = ValueFormatter.format_raw_value(:boolean, 0)
      assert {:ok, "Enabled"} = ValueFormatter.format_raw_value(:boolean, true)
      assert {:ok, "Disabled"} = ValueFormatter.format_raw_value(:boolean, false)
    end
  end

  describe "error handling" do
    test "handles invalid binary data gracefully" do
      # Wrong size for IPv4
      assert {:error, _} = ValueFormatter.format_value(:ipv4, <<192, 168, 1>>)

      # Wrong size for MAC address
      assert {:error, _} =
               ValueFormatter.format_value(:mac_address, <<0x00, 0x11, 0x22, 0x33, 0x44>>)
    end

    test "falls back to binary formatting for unknown types" do
      assert {:ok, "DEADBEEF"} =
               ValueFormatter.format_value(:unknown_type, <<0xDE, 0xAD, 0xBE, 0xEF>>)
    end
  end

  describe "utility functions" do
    test "get_supported_types returns list of supported types" do
      types = ValueFormatter.get_supported_types()
      assert is_list(types)
      assert :frequency in types
      assert :ipv4 in types
      assert :bandwidth in types
    end

    test "supported_type? checks if type is supported" do
      assert ValueFormatter.supported_type?(:frequency) == true
      assert ValueFormatter.supported_type?(:unknown_type) == false
    end
  end
end
