defmodule TestServiceFlowFix do
  use ExUnit.Case

  test "service flow TLV parsing with subtlvs prioritization" do
    # Create a service flow TLV structure like what we get from JSON
    service_flow_json = %{
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

    # Test that extract_human_value returns the subtlvs structure
    {:ok, human_value} = Bindocsis.HumanConfig.extract_human_value_for_test(service_flow_json)

    # Should return the whole TLV with subtlvs (not just the formatted_value)
    assert Map.has_key?(human_value, "subtlvs")
    assert is_list(human_value["subtlvs"])
    assert length(human_value["subtlvs"]) == 2

    # Test that we can parse this with ValueParser
    case Bindocsis.ValueParser.parse_value(:service_flow, human_value, []) do
      {:ok, binary_result} ->
        assert is_binary(binary_result)
        assert byte_size(binary_result) > 0

      {:error, reason} ->
        flunk("Service flow parsing failed: #{reason}")
    end
  end

  test "subtlv value extraction uses only formatted_value" do
    subtlv = %{
      "type" => 1,
      "formatted_value" => "101",
      "value_type" => "uint16"
    }

    # This should use the private extract_subtlv_value function from ValueParser
    # Since it's private, we'll test the behavior indirectly through the public API

    # Create a compound TLV with this subtlv
    compound_tlv = %{"subtlvs" => [subtlv]}

    case Bindocsis.ValueParser.parse_value(:compound, compound_tlv, []) do
      {:ok, binary_result} ->
        assert is_binary(binary_result)

      # Should successfully parse using the formatted_value (101)
      {:error, reason} ->
        flunk("Compound TLV parsing failed: #{reason}")
    end
  end
end
