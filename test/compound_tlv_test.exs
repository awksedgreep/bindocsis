defmodule Bindocsis.CompoundTlvTest do
  use ExUnit.Case, async: true
  
  @moduledoc """
  Test compound TLV parsing including service flows and classifiers.
  
  Validates that users can create and edit structured TLVs with sub-TLVs
  using human-readable JSON/YAML formats.
  """

  describe "service flow parsing" do
    test "parses downstream service flow with subtlvs array format" do
      service_flow_input = %{
        "subtlvs" => [
          %{
            "type" => 1,
            "value" => 100,
            "value_type" => "uint16"
          },
          %{
            "type" => 4,
            "value" => "Premium",
            "value_type" => "string"
          },
          %{
            "type" => 9,
            "formatted_value" => "100000000",
            "value_type" => "uint32"
          }
        ]
      }
      
      {:ok, binary_result} = Bindocsis.ValueParser.parse_value(:service_flow, service_flow_input)
      
      # Should be concatenated sub-TLVs: 
      # Sub-TLV 1: type(1) + length(2) + value(100 as uint16) = 01 02 00 64
      # Sub-TLV 4: type(4) + length(7) + value("Premium") = 04 07 50726D69756D
      # Sub-TLV 9: type(9) + length(4) + value(100000000 as uint32) = 09 04 05F5E100
      
      assert is_binary(binary_result)
      assert byte_size(binary_result) > 0
      
      # Verify it starts with sub-TLV 1 (type 1, length 2)
      <<first_type::8, first_length::8, _rest::binary>> = binary_result
      assert first_type == 1
      assert first_length == 2
    end
    
    test "parses service flow with human-readable bandwidth values" do
      service_flow_input = %{
        "subtlvs" => [
          %{
            "type" => 1,
            "formatted_value" => "1",
            "value_type" => "uint16"
          },
          %{
            "type" => 9,
            "formatted_value" => "10000000",  # 10 Mbps in bps
            "value_type" => "uint32"
          }
        ]
      }
      
      {:ok, binary_result} = Bindocsis.ValueParser.parse_value(:service_flow, service_flow_input)
      
      # Should contain sub-TLV 9 with 10 Mbps = 10000000 bps = 0x989680
      assert is_binary(binary_result)
      
      # Look for sub-TLV 9 in the result
      hex_result = Base.encode16(binary_result)
      assert String.contains?(hex_result, "090400989680")  # type 9, length 4, value 0x00989680 (10000000)
    end
    
    test "handles compound TLV format (alias for service_flow)" do
      compound_input = %{
        "subtlvs" => [
          %{
            "type" => 1,
            "value" => 200,
            "value_type" => "uint16"
          }
        ]
      }
      
      {:ok, service_flow_result} = Bindocsis.ValueParser.parse_value(:service_flow, compound_input)
      {:ok, compound_result} = Bindocsis.ValueParser.parse_value(:compound, compound_input)
      
      # Both should produce the same result
      assert service_flow_result == compound_result
    end
    
    test "returns error for invalid sub-TLV structure" do
      invalid_input = %{
        "subtlvs" => [
          %{
            "type" => "invalid",
            "value" => 1
          }
        ]
      }
      
      {:error, reason} = Bindocsis.ValueParser.parse_value(:service_flow, invalid_input)
      assert String.contains?(reason, "Invalid sub-TLV type")
    end
    
    test "returns error for missing subtlvs value" do
      invalid_input = %{
        "subtlvs" => [
          %{
            "type" => 1
            # Missing value
          }
        ]
      }
      
      {:error, reason} = Bindocsis.ValueParser.parse_value(:service_flow, invalid_input)
      assert String.contains?(reason, "Missing sub-TLV value")
    end
  end

  describe "compound TLV integration with HumanConfig" do
    test "HumanConfig can convert service flow JSON to binary" do
      test_config = %{
        "docsis_version" => "3.1",
        "tlvs" => [
          %{
            "type" => 24,
            "value_type" => "service_flow",
            "formatted_value" => %{
              "subtlvs" => [
                %{
                  "type" => 1,
                  "formatted_value" => "1",
                  "value_type" => "uint16"
                }
              ]
            }
          }
        ]
      }
      
      json_input = JSON.encode!(test_config)
      
      # Test conversion to binary
      case Bindocsis.HumanConfig.from_json(json_input) do
        {:ok, binary_config} ->
          # Binary should not be empty
          assert byte_size(binary_config) > 0
          
          # Should contain the TLV 24 header and sub-TLV data
          # Expected: type(24) + length + sub-TLV(1,2,0,1)
          # At minimum: 24 + length_byte + 01 02 00 01 = at least 6 bytes
          assert byte_size(binary_config) >= 6
          
          # Should start with type 24
          <<first_byte::8, _rest::binary>> = binary_config
          assert first_byte == 24
          
        {:error, reason} ->
          flunk("Service flow JSON to binary conversion failed: #{reason}")
      end
    end
    
    test "full round-trip: JSON with service flow -> binary -> parsed TLVs" do
      # Test the complete workflow users would use
      test_config = %{
        "docsis_version" => "3.1",
        "tlvs" => [
          %{
            "type" => 24,
            "name" => "Downstream Service Flow",
            "value_type" => "service_flow",
            "formatted_value" => %{
              "subtlvs" => [
                %{
                  "type" => 1,
                  "name" => "Service Flow Reference",
                  "formatted_value" => "1",
                  "value_type" => "uint16"
                },
                %{
                  "type" => 9,
                  "name" => "Maximum Sustained Traffic Rate",
                  "formatted_value" => "100000000",  # 100 Mbps
                  "value_type" => "uint32"
                }
              ]
            }
          }
        ]
      }
      
      json_input = JSON.encode!(test_config)
      
      # Test conversion to binary
      case Bindocsis.HumanConfig.from_json(json_input) do
        {:ok, binary_config} ->
          # Test parsing the binary back to TLVs
          {:ok, parsed_tlvs} = Bindocsis.parse(binary_config)
          
          # Should have one TLV of type 24
          assert length(parsed_tlvs) == 1
          tlv_24 = hd(parsed_tlvs)
          assert tlv_24.type == 24
          assert tlv_24.name == "Downstream Service Flow"
          # Should have non-zero length since it contains sub-TLVs
          assert tlv_24.length > 0
          
        {:error, reason} ->
          flunk("Round-trip test failed: #{reason}")
      end
    end
  end
end