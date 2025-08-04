defmodule Bindocsis.ComprehensiveHumanInputTest do
  use ExUnit.Case, async: true
  require Logger

  @moduledoc """
  Comprehensive test suite for ALL primitive DOCSIS value types to ensure
  users can edit formatted_value strings and have them parse correctly.
  
  Tests every value type that appears in DOCSIS specs to ensure the complete
  editing workflow works: export → user edits formatted_value → import.
  """

  describe "uint8 human input parsing" do
    test "parses various uint8 formatted values" do
      # Basic integers
      assert {:ok, <<0>>} = Bindocsis.ValueParser.parse_value(:uint8, "0")
      assert {:ok, <<42>>} = Bindocsis.ValueParser.parse_value(:uint8, "42")
      assert {:ok, <<255>>} = Bindocsis.ValueParser.parse_value(:uint8, "255")
      
      # Edge cases
      assert {:error, _} = Bindocsis.ValueParser.parse_value(:uint8, "256")
      assert {:error, _} = Bindocsis.ValueParser.parse_value(:uint8, "-1")
      assert {:error, _} = Bindocsis.ValueParser.parse_value(:uint8, "invalid")
    end
  end

  describe "uint16 human input parsing" do
    test "parses various uint16 formatted values" do
      assert {:ok, <<0, 0>>} = Bindocsis.ValueParser.parse_value(:uint16, "0")
      assert {:ok, <<1, 44>>} = Bindocsis.ValueParser.parse_value(:uint16, "300")
      assert {:ok, <<255, 255>>} = Bindocsis.ValueParser.parse_value(:uint16, "65535")
      
      # Edge cases
      assert {:error, _} = Bindocsis.ValueParser.parse_value(:uint16, "65536")
      assert {:error, _} = Bindocsis.ValueParser.parse_value(:uint16, "-1")
    end
  end

  describe "uint32 human input parsing" do
    test "parses various uint32 formatted values" do
      assert {:ok, <<0, 0, 0, 0>>} = Bindocsis.ValueParser.parse_value(:uint32, "0")
      assert {:ok, <<0, 0, 1, 44>>} = Bindocsis.ValueParser.parse_value(:uint32, "300")
      assert {:ok, <<255, 255, 255, 255>>} = Bindocsis.ValueParser.parse_value(:uint32, "4294967295")
      
      # Edge cases
      assert {:error, _} = Bindocsis.ValueParser.parse_value(:uint32, "4294967296")
      assert {:error, _} = Bindocsis.ValueParser.parse_value(:uint32, "-1")
    end
  end

  describe "frequency human input parsing" do
    test "parses frequency values with units" do
      # MHz formats
      assert {:ok, <<35, 57, 241, 192>>} = Bindocsis.ValueParser.parse_value(:frequency, "591 MHz")
      assert {:ok, <<35, 57, 241, 192>>} = Bindocsis.ValueParser.parse_value(:frequency, "591MHz")
      assert {:ok, <<35, 57, 241, 192>>} = Bindocsis.ValueParser.parse_value(:frequency, "591 mhz")
      
      # GHz formats
      assert {:ok, <<59, 154, 202, 0>>} = Bindocsis.ValueParser.parse_value(:frequency, "1 GHz")
      assert {:ok, <<59, 154, 202, 0>>} = Bindocsis.ValueParser.parse_value(:frequency, "1GHz")
      assert {:ok, <<59, 154, 202, 0>>} = Bindocsis.ValueParser.parse_value(:frequency, "1000 MHz")
      
      # Hz formats
      assert {:ok, <<35, 57, 241, 192>>} = Bindocsis.ValueParser.parse_value(:frequency, "591000000 Hz")
      assert {:ok, <<35, 57, 241, 192>>} = Bindocsis.ValueParser.parse_value(:frequency, "591000000")
      
      # Decimal values
      assert {:ok, <<35, 61, 194, 80>>} = Bindocsis.ValueParser.parse_value(:frequency, "591.25 MHz")
    end

    test "rejects invalid frequency formats" do
      assert {:error, _} = Bindocsis.ValueParser.parse_value(:frequency, "invalid")
      assert {:error, _} = Bindocsis.ValueParser.parse_value(:frequency, "591 TB")
      assert {:error, _} = Bindocsis.ValueParser.parse_value(:frequency, "")
    end
  end

  describe "boolean human input parsing" do
    test "parses various boolean formatted values" do
      # True values
      assert {:ok, <<1>>} = Bindocsis.ValueParser.parse_value(:boolean, "enabled")
      assert {:ok, <<1>>} = Bindocsis.ValueParser.parse_value(:boolean, "Enabled")
      assert {:ok, <<1>>} = Bindocsis.ValueParser.parse_value(:boolean, "ENABLED")
      assert {:ok, <<1>>} = Bindocsis.ValueParser.parse_value(:boolean, "true")
      assert {:ok, <<1>>} = Bindocsis.ValueParser.parse_value(:boolean, "True")
      assert {:ok, <<1>>} = Bindocsis.ValueParser.parse_value(:boolean, "1")
      assert {:ok, <<1>>} = Bindocsis.ValueParser.parse_value(:boolean, "yes")
      assert {:ok, <<1>>} = Bindocsis.ValueParser.parse_value(:boolean, "on")
      
      # False values
      assert {:ok, <<0>>} = Bindocsis.ValueParser.parse_value(:boolean, "disabled")
      assert {:ok, <<0>>} = Bindocsis.ValueParser.parse_value(:boolean, "Disabled")
      assert {:ok, <<0>>} = Bindocsis.ValueParser.parse_value(:boolean, "false")
      assert {:ok, <<0>>} = Bindocsis.ValueParser.parse_value(:boolean, "0")
      assert {:ok, <<0>>} = Bindocsis.ValueParser.parse_value(:boolean, "no")
      assert {:ok, <<0>>} = Bindocsis.ValueParser.parse_value(:boolean, "off")
    end

    test "rejects invalid boolean formats" do
      assert {:error, _} = Bindocsis.ValueParser.parse_value(:boolean, "maybe")
      assert {:error, _} = Bindocsis.ValueParser.parse_value(:boolean, "2")
      assert {:error, _} = Bindocsis.ValueParser.parse_value(:boolean, "")
    end
  end

  describe "ipv4 human input parsing" do
    test "parses IPv4 addresses" do
      assert {:ok, <<192, 168, 1, 1>>} = Bindocsis.ValueParser.parse_value(:ipv4, "192.168.1.1")
      assert {:ok, <<10, 0, 0, 1>>} = Bindocsis.ValueParser.parse_value(:ipv4, "10.0.0.1")
      assert {:ok, <<255, 255, 255, 255>>} = Bindocsis.ValueParser.parse_value(:ipv4, "255.255.255.255")
      assert {:ok, <<0, 0, 0, 0>>} = Bindocsis.ValueParser.parse_value(:ipv4, "0.0.0.0")
    end

    test "rejects invalid IPv4 formats" do
      assert {:error, _} = Bindocsis.ValueParser.parse_value(:ipv4, "256.1.1.1")
      assert {:error, _} = Bindocsis.ValueParser.parse_value(:ipv4, "192.168.1")
      assert {:error, _} = Bindocsis.ValueParser.parse_value(:ipv4, "not.an.ip.address")
      assert {:error, _} = Bindocsis.ValueParser.parse_value(:ipv4, "")
    end
  end

  describe "ipv6 human input parsing" do
    test "parses IPv6 addresses" do
      # Full format
      {:ok, result} = Bindocsis.ValueParser.parse_value(:ipv6, "2001:0db8:85a3:0000:0000:8a2e:0370:7334")
      assert byte_size(result) == 16
      
      # Compressed format
      {:ok, result} = Bindocsis.ValueParser.parse_value(:ipv6, "2001:db8:85a3::8a2e:370:7334")
      assert byte_size(result) == 16
      
      # Loopback
      {:ok, result} = Bindocsis.ValueParser.parse_value(:ipv6, "::1")
      assert byte_size(result) == 16
    end

    test "rejects invalid IPv6 formats" do
      assert {:error, _} = Bindocsis.ValueParser.parse_value(:ipv6, "invalid:ipv6")
      assert {:error, _} = Bindocsis.ValueParser.parse_value(:ipv6, "192.168.1.1")
      assert {:error, _} = Bindocsis.ValueParser.parse_value(:ipv6, "")
    end
  end

  describe "string human input parsing" do
    test "parses string values" do
      assert {:ok, "hello"} = Bindocsis.ValueParser.parse_value(:string, "hello")
      assert {:ok, "DOCSIS Config"} = Bindocsis.ValueParser.parse_value(:string, "DOCSIS Config")
      assert {:ok, ""} = Bindocsis.ValueParser.parse_value(:string, "")
      assert {:ok, "123"} = Bindocsis.ValueParser.parse_value(:string, "123")
    end
  end

  describe "binary human input parsing" do
    test "parses hex string values" do
      assert {:ok, <<0x01, 0x02, 0x03>>} = Bindocsis.ValueParser.parse_value(:binary, "010203")
      assert {:ok, <<0x01, 0x02, 0x03>>} = Bindocsis.ValueParser.parse_value(:binary, "01 02 03")
      assert {:ok, <<0xDE, 0xAD, 0xBE, 0xEF>>} = Bindocsis.ValueParser.parse_value(:binary, "DEADBEEF")
      assert {:ok, <<0xde, 0xad, 0xbe, 0xef>>} = Bindocsis.ValueParser.parse_value(:binary, "deadbeef")
      assert {:ok, <<>>} = Bindocsis.ValueParser.parse_value(:binary, "")
    end

    test "rejects invalid hex formats" do
      assert {:error, _} = Bindocsis.ValueParser.parse_value(:binary, "GG")
      assert {:error, _} = Bindocsis.ValueParser.parse_value(:binary, "1")  # Odd length
      assert {:error, _} = Bindocsis.ValueParser.parse_value(:binary, "not hex")
    end
  end

  describe "power_quarter_db human input parsing" do
    test "parses power values in dBmV" do
      # Test if this value type is implemented
      case Bindocsis.ValueParser.parse_value(:power_quarter_db, "6.5 dBmV") do
        {:ok, _} -> 
          assert {:ok, _} = Bindocsis.ValueParser.parse_value(:power_quarter_db, "6.5 dBmV")
          assert {:ok, _} = Bindocsis.ValueParser.parse_value(:power_quarter_db, "-10 dBmV")
          assert {:ok, _} = Bindocsis.ValueParser.parse_value(:power_quarter_db, "0 dBmV")
        {:error, _} ->
          # If not implemented, mark as pending
          flunk("power_quarter_db human input parsing not implemented")
      end
    end
  end

  describe "service_flow_ref human input parsing" do
    test "parses service flow references" do
      case Bindocsis.ValueParser.parse_value(:service_flow_ref, "Service Flow #1") do
        {:ok, _} ->
          assert {:ok, _} = Bindocsis.ValueParser.parse_value(:service_flow_ref, "Service Flow #1")
          assert {:ok, _} = Bindocsis.ValueParser.parse_value(:service_flow_ref, "Service Flow #255")
          assert {:ok, _} = Bindocsis.ValueParser.parse_value(:service_flow_ref, "1")
        {:error, _} ->
          flunk("service_flow_ref human input parsing not implemented")
      end
    end
  end

  describe "vendor human input parsing with structured data" do
    test "parses vendor TLV structured format" do
      # Test the structured vendor format we implemented
      vendor_input = %{
        "oui" => "00:10:95",
        "data" => "01020304"
      }
      
      case Bindocsis.ValueParser.parse_value(:vendor, vendor_input) do
        {:ok, binary} ->
          # Should produce OUI bytes + data bytes
          assert <<0x00, 0x10, 0x95, 0x01, 0x02, 0x03, 0x04>> = binary
          
          # Test other formats
          vendor_input2 = %{
            "oui" => "00:20:A6", 
            "data" => "DEADBEEF"
          }
          assert {:ok, <<0x00, 0x20, 0xA6, 0xDE, 0xAD, 0xBE, 0xEF>>} = 
                 Bindocsis.ValueParser.parse_value(:vendor, vendor_input2)
        {:error, _} ->
          flunk("vendor structured input parsing not implemented")
      end
    end
  end

  describe "bandwidth human input parsing" do
    test "parses bandwidth values with units" do
      case Bindocsis.ValueParser.parse_value(:bandwidth, "100 Mbps") do
        {:ok, _} ->
          assert {:ok, _} = Bindocsis.ValueParser.parse_value(:bandwidth, "100 Mbps")
          assert {:ok, _} = Bindocsis.ValueParser.parse_value(:bandwidth, "1 Gbps") 
          assert {:ok, _} = Bindocsis.ValueParser.parse_value(:bandwidth, "500 Kbps")
          assert {:ok, _} = Bindocsis.ValueParser.parse_value(:bandwidth, "1000000 bps")
        {:error, _} ->
          flunk("bandwidth human input parsing not implemented")
      end
    end
  end

  describe "mac_address human input parsing" do
    test "parses MAC addresses" do
      case Bindocsis.ValueParser.parse_value(:mac_address, "00:11:22:33:44:55") do
        {:ok, binary} ->
          assert <<0x00, 0x11, 0x22, 0x33, 0x44, 0x55>> = binary
          assert {:ok, _} = Bindocsis.ValueParser.parse_value(:mac_address, "AA:BB:CC:DD:EE:FF")
          assert {:ok, _} = Bindocsis.ValueParser.parse_value(:mac_address, "aa:bb:cc:dd:ee:ff")
        {:error, _} ->
          flunk("mac_address human input parsing not implemented")
      end
    end
  end

  describe "comprehensive round-trip testing" do
    test "all primitive types can round-trip through human editing" do
      test_cases = [
        {:uint8, "42"},
        {:uint16, "300"}, 
        {:uint32, "1000000"},
        {:frequency, "591 MHz"},
        {:boolean, "enabled"},
        {:ipv4, "192.168.1.100"},
        {:string, "Test Config"},
        {:binary, "DEADBEEF"}
      ]
      
      Enum.each(test_cases, fn {value_type, human_input} ->
        # Parse human input to binary
        {:ok, binary} = Bindocsis.ValueParser.parse_value(value_type, human_input)
        
        # Format binary back to human readable
        {:ok, formatted} = Bindocsis.ValueFormatter.format_value(value_type, binary)
        
        # Parse the formatted value back to binary
        {:ok, round_trip_binary} = Bindocsis.ValueParser.parse_value(value_type, formatted)
        
        # Should be identical
        assert binary == round_trip_binary, 
               "Round-trip failed for #{value_type}: #{human_input} -> #{inspect(binary)} -> #{formatted} -> #{inspect(round_trip_binary)}"
      end)
    end
  end

  describe "real-world DOCSIS TLV editing simulation" do
    test "user can edit a complete DOCSIS configuration" do
      # Simulate a user editing multiple TLV types in a real configuration
      test_config = %{ 
        "docsis_version" => "3.1",
        "tlvs" => [
          %{
            "type" => 1,
            "name" => "Downstream Frequency",
            "formatted_value" => "600 MHz",  # User edited from 591 MHz
            "value_type" => "frequency"
          },
          %{
            "type" => 3,
            "name" => "Network Access Control", 
            "formatted_value" => "enabled",   # User edited from disabled
            "value_type" => "boolean"
          },
          %{
            "type" => 23,
            "name" => "TFTP Server Address",
            "formatted_value" => "10.0.0.100", # User changed IP
            "value_type" => "ipv4"
          }
        ]
      }
      
      json_input = JSON.encode!(test_config)
      
      # Test the complete workflow: JSON -> binary -> parsed TLVs
      case Bindocsis.HumanConfig.from_json(json_input) do
        {:ok, binary_config} ->
          {:ok, parsed_tlvs} = Bindocsis.parse(binary_config)
          
          # Verify the user's edits were preserved
          freq_tlv = Enum.find(parsed_tlvs, &(&1.type == 1))
          assert String.contains?(freq_tlv.formatted_value, "600")
          
          bool_tlv = Enum.find(parsed_tlvs, &(&1.type == 3))
          assert bool_tlv.formatted_value == "Enabled"
          
          ip_tlv = Enum.find(parsed_tlvs, &(&1.type == 23))
          assert ip_tlv.formatted_value == "10.0.0.100"
          
        {:error, reason} ->
          flunk("Real-world editing simulation failed: #{reason}")
      end
    end
  end
end