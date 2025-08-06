defmodule TestServiceFlowFix do
  use ExUnit.Case

  test "subtlv value extraction prioritizes value over formatted_value" do
    # Test that our fix works - when parsing a compound TLV with subtlvs,
    # the individual subtlvs should use "value" over "formatted_value"

    subtlv_with_both = %{
      "type" => 1,
      # This should be used
      "value" => 101,
      # This should be ignored
      "formatted_value" => "invalid_hex_format"
    }

    compound_tlv = %{"subtlvs" => [subtlv_with_both]}

    # This should succeed because extract_subtlv_value now prioritizes "value"
    case Bindocsis.ValueParser.parse_value(:compound, compound_tlv, []) do
      {:ok, binary_result} ->
        assert is_binary(binary_result)
        assert byte_size(binary_result) > 0

      {:error, reason} ->
        flunk("Compound TLV parsing should succeed with our fix: #{reason}")
    end
  end

  test "service flow parsing with subtlvs structure" do
    # Test full service flow parsing
    service_flow = %{
      "subtlvs" => [
        %{"type" => 1, "value" => 101},
        %{"type" => 2, "value" => 1}
      ]
    }

    case Bindocsis.ValueParser.parse_value(:service_flow, service_flow, []) do
      {:ok, binary_result} ->
        assert is_binary(binary_result)
        # Should contain encoded subtlvs: type1+length1+value1 + type2+length2+value2
        # At least 2 TLVs with minimal data
        assert byte_size(binary_result) >= 6

      {:error, reason} ->
        flunk("Service flow parsing failed: #{reason}")
    end
  end
end
