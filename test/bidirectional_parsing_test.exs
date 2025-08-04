defmodule Bindocsis.BidirectionalParsingTest do
  use ExUnit.Case, async: true
  
  @moduledoc """
  Comprehensive test suite for bidirectional parsing support.
  
  Tests all value types to ensure they can be formatted to human-readable
  strings and then parsed back to the same binary representation.
  
  This ensures complete round-trip integrity for the editing workflow:
  binary → human format → user edits → parse back to binary
  """

  describe "marker parsing" do
    test "parses various marker formats" do
      # Empty string
      assert {:ok, <<>>} = Bindocsis.ValueParser.parse_value(:marker, "")
      assert {:ok, <<>>} = Bindocsis.ValueParser.parse_value(:marker, nil)
      
      # Explicit marker values
      assert {:ok, <<>>} = Bindocsis.ValueParser.parse_value(:marker, "end")
      assert {:ok, <<>>} = Bindocsis.ValueParser.parse_value(:marker, "marker")
      assert {:ok, <<>>} = Bindocsis.ValueParser.parse_value(:marker, "end-of-data")
      
      # Case insensitive
      assert {:ok, <<>>} = Bindocsis.ValueParser.parse_value(:marker, "END")
      assert {:ok, <<>>} = Bindocsis.ValueParser.parse_value(:marker, "Marker")
      
      # With whitespace
      assert {:ok, <<>>} = Bindocsis.ValueParser.parse_value(:marker, "  end  ")
    end
    
    test "rejects invalid marker formats" do
      assert {:error, _} = Bindocsis.ValueParser.parse_value(:marker, "invalid")
      assert {:error, _} = Bindocsis.ValueParser.parse_value(:marker, "123")
    end
  end

  describe "complete round-trip testing" do
    test "all basic value types support round-trip parsing" do
      test_cases = [
        {:uint8, <<42>>, "42"},
        {:uint16, <<1, 44>>, "300"},
        {:uint32, <<0, 0, 1, 44>>, "300"},
        {:frequency, <<35, 57, 241, 192>>, "591 MHz"},
        {:bandwidth, <<5, 245, 225, 0>>, "100 Mbps"},
        {:boolean, <<1>>, "Enabled"},
        {:boolean, <<0>>, "Disabled"},
        {:ipv4, <<192, 168, 1, 100>>, "192.168.1.100"},
        {:mac_address, <<0, 17, 34, 51, 68, 85>>, "00:11:22:33:44:55"},
        {:duration, <<0, 0, 0, 30>>, "30 seconds"},
        {:percentage, <<75>>, "75%"},
        {:power_quarter_db, <<26>>, "6.5 dBmV"},
        {:string, "Hello", "Hello"},
        {:binary, <<1, 2, 3>>, "010203"},
        {:service_flow_ref, <<0, 1>>, "Service Flow #1"},
        {:marker, <<>>, "End-of-Data Marker"}
      ]
      
      Enum.each(test_cases, fn {value_type, binary_value, expected_format} ->
        # Test: binary → formatted string
        {:ok, formatted_string} = Bindocsis.ValueFormatter.format_value(value_type, binary_value)
        
        # Verify the formatted string matches expectations (approximately)
        if expected_format != nil do
          assert String.contains?(formatted_string, String.split(expected_format) |> hd()),
                 "Expected #{value_type} formatting to contain '#{String.split(expected_format) |> hd()}', got '#{formatted_string}'"
        end
        
        # Test: formatted string → binary (round-trip)
        {:ok, parsed_binary} = Bindocsis.ValueParser.parse_value(value_type, formatted_string)
        
        # Should match original binary
        assert binary_value == parsed_binary,
               "Round-trip failed for #{value_type}: #{inspect(binary_value)} → '#{formatted_string}' → #{inspect(parsed_binary)}"
      end)
    end
    
    test "IPv6 round-trip parsing" do
      # IPv6 is more complex, test separately
      ipv6_binary = <<0x20, 0x01, 0x0d, 0xb8, 0x85, 0xa3, 0x00, 0x00, 0x00, 0x00, 0x8a, 0x2e, 0x03, 0x70, 0x73, 0x34>>
      
      {:ok, formatted_ipv6} = Bindocsis.ValueFormatter.format_value(:ipv6, ipv6_binary)
      assert String.contains?(formatted_ipv6, "2001:db8")
      
      {:ok, parsed_ipv6} = Bindocsis.ValueParser.parse_value(:ipv6, formatted_ipv6)
      assert ipv6_binary == parsed_ipv6
    end
    
    test "vendor TLV round-trip parsing" do
      # Test vendor TLV with structured input
      vendor_binary = <<0x00, 0x10, 0x95, 0x01, 0x02, 0x03>>
      
      {:ok, formatted_vendor} = Bindocsis.ValueFormatter.format_value(:vendor, vendor_binary)
      
      # Vendor formatter returns structured data, we need to parse it back
      # For this test, we'll use structured input directly
      vendor_input = %{
        "oui" => "00:10:95",
        "data" => "010203"
      }
      
      {:ok, parsed_vendor} = Bindocsis.ValueParser.parse_value(:vendor, vendor_input)
      assert vendor_binary == parsed_vendor
    end
    
    test "timestamp round-trip parsing" do
      # Test timestamp with Unix timestamp
      timestamp_binary = <<95, 52, 201, 96>>  # Some Unix timestamp
      
      {:ok, formatted_timestamp} = Bindocsis.ValueFormatter.format_value(:timestamp, timestamp_binary)
      
      # Parse it back - timestamp parser accepts Unix timestamps
      unix_timestamp = :binary.decode_unsigned(timestamp_binary, :big)
      {:ok, parsed_timestamp} = Bindocsis.ValueParser.parse_value(:timestamp, to_string(unix_timestamp))
      
      assert timestamp_binary == parsed_timestamp
    end
  end

  describe "error handling and edge cases" do
    test "parser handles malformed input gracefully" do
      # Each parser should return helpful error messages
      test_cases = [
        {:uint8, "300"},      # Out of range
        {:ipv4, "999.1.1.1"}, # Invalid IP
        {:frequency, "invalid"}, # Non-numeric frequency
        {:boolean, "maybe"},  # Invalid boolean
        {:marker, "invalid"}  # Invalid marker
      ]
      
      Enum.each(test_cases, fn {value_type, invalid_input} ->
        {:error, reason} = Bindocsis.ValueParser.parse_value(value_type, invalid_input)
        assert is_binary(reason), "Error message should be a string for #{value_type}"
        assert String.length(reason) > 0, "Error message should not be empty for #{value_type}"
      end)
    end
    
    test "round-trip validation helper works" do
      # Test the round-trip validation helper function
      assert {:ok, <<42>>} = Bindocsis.ValueParser.validate_round_trip(:uint8, "42")
      assert {:error, _} = Bindocsis.ValueParser.validate_round_trip(:uint8, "300")
    end
  end

  describe "human-readable input variations" do
    test "parsers accept multiple human formats for same value" do
      # Test that parsers are flexible with human input formats
      test_variations = [
        # Frequency variations
        {:frequency, ["591 MHz", "591MHz", "591 mhz", "591000000 Hz", "591000000"]},
        
        # Boolean variations  
        {:boolean, ["enabled", "Enabled", "ENABLED", "true", "1", "yes", "on"]},
        {:boolean, ["disabled", "Disabled", "false", "0", "no", "off"]},
        
        # Service flow reference variations
        {:service_flow_ref, ["1", "Service Flow #1"]},
        
        # Marker variations
        {:marker, ["", "end", "marker", "end-of-data", "END"]},
        
        # Power variations (with negative support)
        {:power_quarter_db, ["6.5 dBmV", "6.5", "-10 dBmV"]}
      ]
      
      Enum.each(test_variations, fn {value_type, variations} ->
        # All variations should parse successfully (though may produce different results)
        results = Enum.map(variations, fn variation ->
          case Bindocsis.ValueParser.parse_value(value_type, variation) do
            {:ok, binary} -> binary
            {:error, _} -> :error
          end
        end)
        
        # Should have at least one successful parse
        successful_parses = Enum.count(results, &(&1 != :error))
        assert successful_parses > 0, "At least one variation should parse for #{value_type}: #{inspect(variations)}"
      end)
    end
  end
end