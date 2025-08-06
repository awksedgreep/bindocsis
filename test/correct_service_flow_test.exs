defmodule CorrectServiceFlowTest do
  use ExUnit.Case

  test "service flow parsing with subtlvs only (no formatted_value parsing)" do
    # This is what we expect from JSON - service flow with subtlvs structure
    service_flow_tlv = %{
      "type" => 24,
      "name" => "Downstream Service Flow",
      "subtlvs" => [
        %{
          "type" => 1,
          "name" => "Service Flow Reference",
          "formatted_value" => "101",
          "value_type" => "uint16"
        },
        %{
          "type" => 2,
          "name" => "Service Flow ID",
          "formatted_value" => "1",
          "value_type" => "uint32"
        }
      ],
      "formatted_value" => "0000: 01 01 65 02 01 01                               |..e...|"
    }

    # Test that HumanConfig.extract_human_value returns the subtlvs structure
    # (We can't call the private function directly, so we'll test the full flow)

    # Convert this TLV structure using the flow that would happen in from_json
    case Bindocsis.ValueParser.parse_value(:service_flow, service_flow_tlv, []) do
      {:ok, binary_result} ->
        assert is_binary(binary_result)
        assert byte_size(binary_result) > 0
        # Should contain 2 encoded subtlvs
        assert byte_size(binary_result) >= 6

      {:error, reason} ->
        flunk("Service flow parsing should work with subtlvs structure: #{reason}")
    end
  end

  test "subtlv with formatted_value works" do
    # Individual subtlv with formatted_value
    subtlv = %{"type" => 1, "formatted_value" => "101", "value_type" => "uint16"}
    compound_tlv = %{"subtlvs" => [subtlv]}

    case Bindocsis.ValueParser.parse_value(:compound, compound_tlv, []) do
      {:ok, binary_result} ->
        assert is_binary(binary_result)
        assert byte_size(binary_result) > 0

      {:error, reason} ->
        flunk("Subtlv with only value should parse: #{reason}")
    end
  end

  test "subtlv with formatted_value hex dump fails appropriately" do
    # Individual subtlv with hex dump in formatted_value and no value
    subtlv = %{"type" => 1, "formatted_value" => "0000: 65 |e|"}
    compound_tlv = %{"subtlvs" => [subtlv]}

    case Bindocsis.ValueParser.parse_value(:compound, compound_tlv, []) do
      {:ok, _binary_result} ->
        flunk("Should not successfully parse hex dump from formatted_value")

      {:error, reason} ->
        # This should fail because hex dump format is not parseable as traffic priority (type 1 default)
        assert String.contains?(reason, "Invalid traffic priority format")
    end
  end
end
