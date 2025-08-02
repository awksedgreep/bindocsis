defmodule Bindocsis.ValueParserTest do
  use ExUnit.Case
  doctest Bindocsis.ValueParser

  alias Bindocsis.ValueParser

  describe "frequency parsing" do
    test "parses frequency values in various units" do
      assert {:ok, <<35, 57, 241, 192>>} = ValueParser.parse_value(:frequency, "591 MHz")
      assert {:ok, <<35, 57, 241, 192>>} = ValueParser.parse_value(:frequency, "591MHz")
      assert {:ok, <<35, 57, 241, 192>>} = ValueParser.parse_value(:frequency, "591000000 Hz")
      assert {:ok, <<35, 57, 241, 192>>} = ValueParser.parse_value(:frequency, "591000000")
      
      # 1 GHz = 1,000,000,000 Hz
      assert {:ok, <<59, 154, 202, 0>>} = ValueParser.parse_value(:frequency, "1 GHz")
      assert {:ok, <<59, 154, 202, 0>>} = ValueParser.parse_value(:frequency, "1000 MHz")
      
      # KHz values
      assert {:ok, <<0, 0, 3, 232>>} = ValueParser.parse_value(:frequency, "1 KHz")
      assert {:ok, <<0, 0, 3, 232>>} = ValueParser.parse_value(:frequency, "1000 Hz")
    end

    test "parses decimal frequency values" do
      # 591.25 MHz = 591,250,000 Hz
      assert {:ok, <<35, 61, 194, 80>>} = ValueParser.parse_value(:frequency, "591.25 MHz")
      assert {:ok, <<35, 61, 194, 80>>} = ValueParser.parse_value(:frequency, "591250000 Hz")
      
      # 1.2 GHz = 1,200,000,000 Hz
      assert {:ok, <<71, 134, 140, 0>>} = ValueParser.parse_value(:frequency, "1.2 GHz")
    end

    test "handles numeric frequency inputs" do
      assert {:ok, <<35, 57, 241, 192>>} = ValueParser.parse_value(:frequency, 591_000_000)
      assert {:ok, <<59, 154, 202, 0>>} = ValueParser.parse_value(:frequency, 1_000_000_000)
    end

    test "rejects invalid frequency formats" do
      assert {:error, msg} = ValueParser.parse_value(:frequency, "invalid frequency")
      assert String.contains?(msg, "Invalid frequency format")
      
      assert {:error, msg} = ValueParser.parse_value(:frequency, "591 TB")
      assert String.contains?(msg, "Invalid frequency format")
    end
  end

  describe "bandwidth parsing" do
    test "parses bandwidth values in various units" do
      # 100 Mbps = 100,000,000 bps
      assert {:ok, <<5, 245, 225, 0>>} = ValueParser.parse_value(:bandwidth, "100 Mbps")
      assert {:ok, <<5, 245, 225, 0>>} = ValueParser.parse_value(:bandwidth, "100Mbps")
      assert {:ok, <<5, 245, 225, 0>>} = ValueParser.parse_value(:bandwidth, "100000000 bps")
      assert {:ok, <<5, 245, 225, 0>>} = ValueParser.parse_value(:bandwidth, "100000000")
      
      # 1 Gbps = 1,000,000,000 bps
      assert {:ok, <<59, 154, 202, 0>>} = ValueParser.parse_value(:bandwidth, "1 Gbps")
      assert {:ok, <<59, 154, 202, 0>>} = ValueParser.parse_value(:bandwidth, "1000 Mbps")
      
      # Kbps values
      assert {:ok, <<0, 0, 3, 232>>} = ValueParser.parse_value(:bandwidth, "1 Kbps")
      assert {:ok, <<0, 0, 3, 232>>} = ValueParser.parse_value(:bandwidth, "1000 bps")
    end

    test "parses decimal bandwidth values" do
      # 10.5 Mbps = 10,500,000 bps
      assert {:ok, <<0, 160, 55, 160>>} = ValueParser.parse_value(:bandwidth, "10.5 Mbps")
      
      # 1.5 Gbps = 1,500,000,000 bps
      assert {:ok, <<89, 104, 47, 0>>} = ValueParser.parse_value(:bandwidth, "1.5 Gbps")
    end

    test "handles numeric bandwidth inputs" do
      assert {:ok, <<5, 245, 225, 0>>} = ValueParser.parse_value(:bandwidth, 100_000_000)
      assert {:ok, <<59, 154, 202, 0>>} = ValueParser.parse_value(:bandwidth, 1_000_000_000)
    end

    test "rejects invalid bandwidth formats" do
      assert {:error, msg} = ValueParser.parse_value(:bandwidth, "invalid bandwidth")
      assert String.contains?(msg, "Invalid bandwidth format")
    end
  end

  describe "IPv4 address parsing" do
    test "parses valid IPv4 addresses" do
      assert {:ok, <<192, 168, 1, 100>>} = ValueParser.parse_value(:ipv4, "192.168.1.100")
      assert {:ok, <<10, 0, 0, 1>>} = ValueParser.parse_value(:ipv4, "10.0.0.1")
      assert {:ok, <<255, 255, 255, 255>>} = ValueParser.parse_value(:ipv4, "255.255.255.255")
      assert {:ok, <<0, 0, 0, 0>>} = ValueParser.parse_value(:ipv4, "0.0.0.0")
    end

    test "rejects invalid IPv4 addresses" do
      assert {:error, msg} = ValueParser.parse_value(:ipv4, "192.168.1.256")
      assert String.contains?(msg, "Invalid IPv4")
      
      assert {:error, msg} = ValueParser.parse_value(:ipv4, "192.168.1")
      assert String.contains?(msg, "Invalid IPv4")
      
      assert {:error, msg} = ValueParser.parse_value(:ipv4, "192.168.1.100.1")
      assert String.contains?(msg, "Invalid IPv4")
    end
  end

  describe "IPv6 address parsing" do
    test "parses valid IPv6 addresses" do
      ipv6_result = <<0x20, 0x01, 0x0d, 0xb8, 0x00, 0x00, 0x00, 0x00, 
                      0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x01>>
      assert {:ok, ^ipv6_result} = ValueParser.parse_value(:ipv6, "2001:db8::1")
      
      # Full IPv6 address
      full_ipv6 = <<0x20, 0x01, 0x0d, 0xb8, 0x85, 0xa3, 0x00, 0x00,
                    0x00, 0x00, 0x8a, 0x2e, 0x03, 0x70, 0x73, 0x34>>
      assert {:ok, ^full_ipv6} = ValueParser.parse_value(:ipv6, "2001:db8:85a3::8a2e:370:7334")
    end

    test "rejects invalid IPv6 addresses" do
      assert {:error, msg} = ValueParser.parse_value(:ipv6, "invalid::ipv6")
      assert String.contains?(msg, "Invalid IPv6")
      
      assert {:error, msg} = ValueParser.parse_value(:ipv6, "2001:db8::gg::1")
      assert String.contains?(msg, "Invalid IPv6")
    end
  end

  describe "boolean parsing" do
    test "parses various boolean formats" do
      # True values
      assert {:ok, <<1>>} = ValueParser.parse_value(:boolean, "enabled")
      assert {:ok, <<1>>} = ValueParser.parse_value(:boolean, "enable")
      assert {:ok, <<1>>} = ValueParser.parse_value(:boolean, "on")
      assert {:ok, <<1>>} = ValueParser.parse_value(:boolean, "true")
      assert {:ok, <<1>>} = ValueParser.parse_value(:boolean, "yes")
      assert {:ok, <<1>>} = ValueParser.parse_value(:boolean, "1")
      assert {:ok, <<1>>} = ValueParser.parse_value(:boolean, "ENABLED")
      assert {:ok, <<1>>} = ValueParser.parse_value(:boolean, " enabled ")
      
      # False values
      assert {:ok, <<0>>} = ValueParser.parse_value(:boolean, "disabled")
      assert {:ok, <<0>>} = ValueParser.parse_value(:boolean, "disable")
      assert {:ok, <<0>>} = ValueParser.parse_value(:boolean, "off")
      assert {:ok, <<0>>} = ValueParser.parse_value(:boolean, "false")
      assert {:ok, <<0>>} = ValueParser.parse_value(:boolean, "no")
      assert {:ok, <<0>>} = ValueParser.parse_value(:boolean, "0")
    end

    test "parses boolean literals" do
      assert {:ok, <<1>>} = ValueParser.parse_value(:boolean, true)
      assert {:ok, <<0>>} = ValueParser.parse_value(:boolean, false)
      assert {:ok, <<1>>} = ValueParser.parse_value(:boolean, 1)
      assert {:ok, <<0>>} = ValueParser.parse_value(:boolean, 0)
    end

    test "rejects invalid boolean formats" do
      assert {:error, msg} = ValueParser.parse_value(:boolean, "maybe")
      assert String.contains?(msg, "Invalid boolean value")
      
      assert {:error, msg} = ValueParser.parse_value(:boolean, "2")
      assert String.contains?(msg, "Invalid boolean value")
    end
  end

  describe "MAC address parsing" do
    test "parses various MAC address formats" do
      expected = <<0x00, 0x11, 0x22, 0x33, 0x44, 0x55>>
      
      assert {:ok, ^expected} = ValueParser.parse_value(:mac_address, "00:11:22:33:44:55")
      assert {:ok, ^expected} = ValueParser.parse_value(:mac_address, "00-11-22-33-44-55")
      assert {:ok, ^expected} = ValueParser.parse_value(:mac_address, "001122334455")
      assert {:ok, ^expected} = ValueParser.parse_value(:mac_address, "00:11:22:33:44:55")
    end

    test "handles case insensitive MAC addresses" do
      expected = <<0xAB, 0xCD, 0xEF, 0x12, 0x34, 0x56>>
      
      assert {:ok, ^expected} = ValueParser.parse_value(:mac_address, "ab:cd:ef:12:34:56")
      assert {:ok, ^expected} = ValueParser.parse_value(:mac_address, "AB:CD:EF:12:34:56")
      assert {:ok, ^expected} = ValueParser.parse_value(:mac_address, "abcdef123456")
      assert {:ok, ^expected} = ValueParser.parse_value(:mac_address, "ABCDEF123456")
    end

    test "rejects invalid MAC address formats" do
      assert {:error, msg} = ValueParser.parse_value(:mac_address, "00:11:22:33:44")
      assert String.contains?(msg, "Invalid MAC address")
      
      assert {:error, msg} = ValueParser.parse_value(:mac_address, "00:11:22:33:44:gg")
      assert String.contains?(msg, "Invalid MAC address")
      
      assert {:error, msg} = ValueParser.parse_value(:mac_address, "001122334")
      assert String.contains?(msg, "Invalid MAC address")
    end
  end

  describe "duration parsing" do
    test "parses duration values in various units" do
      assert {:ok, <<0, 0, 0, 30>>} = ValueParser.parse_value(:duration, "30 seconds")
      assert {:ok, <<0, 0, 0, 30>>} = ValueParser.parse_value(:duration, "30 sec")
      assert {:ok, <<0, 0, 0, 30>>} = ValueParser.parse_value(:duration, "30 s")
      assert {:ok, <<0, 0, 0, 30>>} = ValueParser.parse_value(:duration, "30")
      
      # 5 minutes = 300 seconds
      assert {:ok, <<0, 0, 1, 44>>} = ValueParser.parse_value(:duration, "5 minutes")
      assert {:ok, <<0, 0, 1, 44>>} = ValueParser.parse_value(:duration, "5 min")
      assert {:ok, <<0, 0, 1, 44>>} = ValueParser.parse_value(:duration, "5 m")
      
      # 2 hours = 7200 seconds
      assert {:ok, <<0, 0, 28, 32>>} = ValueParser.parse_value(:duration, "2 hours")
      assert {:ok, <<0, 0, 28, 32>>} = ValueParser.parse_value(:duration, "2 h")
      
      # 1 day = 86400 seconds
      assert {:ok, <<0, 1, 81, 128>>} = ValueParser.parse_value(:duration, "1 day")
      assert {:ok, <<0, 1, 81, 128>>} = ValueParser.parse_value(:duration, "1 d")
    end

    test "handles numeric duration inputs" do
      assert {:ok, <<0, 0, 0, 30>>} = ValueParser.parse_value(:duration, 30)
      assert {:ok, <<0, 0, 1, 44>>} = ValueParser.parse_value(:duration, 300)
    end

    test "rejects invalid duration formats" do
      assert {:error, msg} = ValueParser.parse_value(:duration, "invalid duration")
      assert String.contains?(msg, "Invalid duration format")
    end
  end

  describe "percentage parsing" do
    test "parses percentage values in various formats" do
      assert {:ok, <<75>>} = ValueParser.parse_value(:percentage, "75%")
      assert {:ok, <<75>>} = ValueParser.parse_value(:percentage, "75")
      assert {:ok, <<75>>} = ValueParser.parse_value(:percentage, "0.75")
      
      assert {:ok, <<100>>} = ValueParser.parse_value(:percentage, "100%")
      assert {:ok, <<100>>} = ValueParser.parse_value(:percentage, "1.0") 
      assert {:ok, <<0>>} = ValueParser.parse_value(:percentage, "0%")
      assert {:ok, <<0>>} = ValueParser.parse_value(:percentage, "0.0")
    end

    test "handles numeric percentage inputs" do
      assert {:ok, <<75>>} = ValueParser.parse_value(:percentage, 75)
      assert {:ok, <<100>>} = ValueParser.parse_value(:percentage, 100)
      assert {:ok, <<0>>} = ValueParser.parse_value(:percentage, 0)
    end

    test "rejects invalid percentage values" do
      assert {:error, msg} = ValueParser.parse_value(:percentage, "150%")
      assert String.contains?(msg, "must be between 0% and 100%")
      
      assert {:error, msg} = ValueParser.parse_value(:percentage, "1.5")
      assert String.contains?(msg, "Invalid percentage format")
      
      assert {:error, msg} = ValueParser.parse_value(:percentage, "invalid")
      assert String.contains?(msg, "Invalid percentage format")
    end
  end

  describe "integer parsing" do
    test "parses uint8 values" do
      assert {:ok, <<0>>} = ValueParser.parse_value(:uint8, "0")
      assert {:ok, <<255>>} = ValueParser.parse_value(:uint8, "255")
      assert {:ok, <<128>>} = ValueParser.parse_value(:uint8, 128)
    end

    test "parses uint16 values" do
      assert {:ok, <<0, 0>>} = ValueParser.parse_value(:uint16, "0")  
      assert {:ok, <<255, 255>>} = ValueParser.parse_value(:uint16, "65535")
      assert {:ok, <<128, 0>>} = ValueParser.parse_value(:uint16, 32768)
    end

    test "parses uint32 values" do
      assert {:ok, <<0, 0, 0, 0>>} = ValueParser.parse_value(:uint32, "0")
      assert {:ok, <<255, 255, 255, 255>>} = ValueParser.parse_value(:uint32, "4294967295")
      assert {:ok, <<128, 0, 0, 0>>} = ValueParser.parse_value(:uint32, 2147483648)
    end

    test "rejects out-of-range integer values" do
      assert {:error, msg} = ValueParser.parse_value(:uint8, "256")
      assert String.contains?(msg, "out of range for uint8")
      
      assert {:error, msg} = ValueParser.parse_value(:uint16, "65536")
      assert String.contains?(msg, "out of range for uint16")
      
      assert {:error, msg} = ValueParser.parse_value(:uint32, "4294967296")
      assert String.contains?(msg, "out of range for uint32")
    end

    test "rejects invalid integer formats" do
      assert {:error, msg} = ValueParser.parse_value(:uint8, "invalid")
      assert String.contains?(msg, "Invalid integer format")
      
      assert {:error, msg} = ValueParser.parse_value(:uint16, "123.45")
      assert String.contains?(msg, "Invalid integer format")
    end
  end

  describe "string parsing" do
    test "parses string values" do
      assert {:ok, "Hello World\0"} = ValueParser.parse_value(:string, "Hello World")
      assert {:ok, "Test\0"} = ValueParser.parse_value(:string, "Test")
      
      # Preserves existing null terminator
      assert {:ok, "Already Null\0"} = ValueParser.parse_value(:string, "Already Null\0")
    end

    test "handles empty strings" do
      assert {:ok, "\0"} = ValueParser.parse_value(:string, "")
    end
  end

  describe "service flow reference parsing" do
    test "parses service flow references" do
      # Small references (0-255) use 2-byte format with leading zero
      assert {:ok, <<0, 1>>} = ValueParser.parse_value(:service_flow_ref, "1")
      assert {:ok, <<0, 255>>} = ValueParser.parse_value(:service_flow_ref, "255")
      assert {:ok, <<0, 1>>} = ValueParser.parse_value(:service_flow_ref, 1)
      
      # Large references (256+) use 2-byte format
      assert {:ok, <<1, 0>>} = ValueParser.parse_value(:service_flow_ref, "256")
      assert {:ok, <<255, 255>>} = ValueParser.parse_value(:service_flow_ref, "65535")
      assert {:ok, <<1, 0>>} = ValueParser.parse_value(:service_flow_ref, 256)
    end

    test "rejects invalid service flow references" do
      assert {:error, msg} = ValueParser.parse_value(:service_flow_ref, "65536")
      assert String.contains?(msg, "out of range")
      
      assert {:error, msg} = ValueParser.parse_value(:service_flow_ref, "invalid")
      assert String.contains?(msg, "Invalid service flow reference")
    end
  end

  describe "binary/hex parsing" do
    test "parses hex strings" do
      assert {:ok, <<0xDE, 0xAD, 0xBE, 0xEF>>} = ValueParser.parse_value(:binary, "DEADBEEF")
      assert {:ok, <<0xDE, 0xAD, 0xBE, 0xEF>>} = ValueParser.parse_value(:binary, "deadbeef")
      assert {:ok, <<0xDE, 0xAD, 0xBE, 0xEF>>} = ValueParser.parse_value(:binary, "DE:AD:BE:EF")
      assert {:ok, <<0xDE, 0xAD, 0xBE, 0xEF>>} = ValueParser.parse_value(:binary, "DE-AD-BE-EF")
      assert {:ok, <<0xDE, 0xAD, 0xBE, 0xEF>>} = ValueParser.parse_value(:binary, "DE AD BE EF")
    end

    test "handles printable strings as binary" do
      assert {:ok, "Hello World"} = ValueParser.parse_value(:binary, "Hello World")
      assert {:ok, "Test 123"} = ValueParser.parse_value(:binary, "Test 123")
    end

    test "handles mixed strings properly" do
      # "DEADBEE" is odd length hex, so should be treated as string
      assert {:ok, "DEADBEE"} = ValueParser.parse_value(:binary, "DEADBEE")
    end
  end

  describe "vendor OUI parsing" do
    test "parses vendor OUI values" do
      assert {:ok, <<0x00, 0x00, 0x0C>>} = ValueParser.parse_value(:vendor_oui, "00:00:0C")
      assert {:ok, <<0x00, 0x10, 0x95>>} = ValueParser.parse_value(:vendor_oui, "00-10-95")
      assert {:ok, <<0x12, 0x34, 0x56>>} = ValueParser.parse_value(:vendor_oui, "123456")
    end

    test "extracts OUI from full MAC address" do
      assert {:ok, <<0x00, 0x11, 0x22>>} = ValueParser.parse_value(:vendor_oui, "00:11:22:33:44:55")
    end

    test "rejects invalid OUI formats" do
      assert {:error, msg} = ValueParser.parse_value(:vendor_oui, "00:11")
      assert String.contains?(msg, "Invalid OUI format")
    end
  end

  describe "vendor TLV parsing" do
    test "parses vendor TLV maps with hex data" do
      input = %{"oui" => "00:00:0C", "data" => "DEADBEEF"}
      # The data "DEADBEEF" will be parsed as hex since it matches hex pattern
      assert {:ok, <<0x00, 0x00, 0x0C, 0xDE, 0xAD, 0xBE, 0xEF>>} = 
        ValueParser.parse_value(:vendor, input)
    end

    test "parses vendor TLV maps with string data" do
      input = %{"oui" => "00:00:0C", "data" => "Hello"}
      # String data gets treated as binary
      assert {:ok, <<0x00, 0x00, 0x0C, "Hello">>} = 
        ValueParser.parse_value(:vendor, input)
    end

    test "rejects invalid vendor TLV format" do
      assert {:error, msg} = ValueParser.parse_value(:vendor, %{"invalid" => "data"})
      assert String.contains?(msg, "must have 'oui' and 'data' fields")
    end
  end

  describe "error handling and edge cases" do
    test "handles length validation" do
      # Test with max_length option
      assert {:error, msg} = ValueParser.parse_value(:string, "Too long string", max_length: 5)
      assert String.contains?(msg, "Value too long")
    end

    test "handles unsupported types gracefully" do
      # Non-hex string with unknown type should fail
      assert {:error, msg} = ValueParser.parse_value(:unknown_type, "some value")
      assert String.contains?(msg, "Unsupported value type")
      
      # Hex string with unknown type should work (fallback to binary parsing)
      assert {:ok, <<0xDE, 0xAD, 0xBE, 0xEF>>} = ValueParser.parse_value(:unknown_type, "DEADBEEF")
    end

    test "compound TLV parsing returns appropriate error" do
      assert {:error, msg} = ValueParser.parse_value(:compound, %{"test" => "data"})
      assert String.contains?(msg, "not yet implemented")
    end
  end

  describe "round-trip validation" do
    test "validates successful round-trips" do
      # Frequency
      assert {:ok, _} = ValueParser.validate_round_trip(:frequency, "591 MHz")
      
      # IP address
      assert {:ok, _} = ValueParser.validate_round_trip(:ipv4, "192.168.1.100")
      
      # Boolean
      assert {:ok, _} = ValueParser.validate_round_trip(:boolean, "enabled")
      
      # MAC address
      assert {:ok, _} = ValueParser.validate_round_trip(:mac_address, "00:11:22:33:44:55")
    end
  end

  describe "utility functions" do
    test "get_supported_types returns list of supported types" do
      types = ValueParser.get_supported_types()
      assert is_list(types)
      assert :frequency in types
      assert :ipv4 in types
      assert :boolean in types
      assert :bandwidth in types
    end

    test "supported_type? checks if type is supported" do
      assert ValueParser.supported_type?(:frequency) == true
      assert ValueParser.supported_type?(:unknown_type) == false
    end
  end
end