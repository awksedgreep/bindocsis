#!/usr/bin/env elixir

# Direct test of our fixes to verify they work correctly

defmodule DirectTestOurFixes do
  def test_extract_functions() do
    IO.puts("=== Testing Our Fixed Functions Directly ===")

    # Test extract_human_value with formatted_value priority
    test_tlv = %{
      "type" => 24,
      # This should be ignored
      "value" => "base64encodedrawbinary",
      # This should be prioritized
      "formatted_value" => "this_should_be_used",
      "subtlvs" => [
        %{"type" => 1, "formatted_value" => "best_effort"},
        %{"type" => 2, "formatted_value" => 1000}
      ]
    }

    IO.puts("\n1. Testing extract_human_value with formatted_value priority:")
    IO.puts("  Input TLV: #{inspect(test_tlv)}")

    result = Bindocsis.HumanConfig.extract_human_value(test_tlv)
    IO.puts("  Result: #{inspect(result)}")
    IO.puts("  Expected: Should use subtlvs structure, not formatted_value for compound TLVs")

    # Test extract_subtlv_value with formatted_value priority
    test_subtlv = %{
      "type" => 1,
      # This should be ignored
      "value" => "shouldnotbeused",
      # This should be used
      "formatted_value" => "best_effort"
    }

    IO.puts("\n2. Testing extract_subtlv_value with formatted_value priority:")
    IO.puts("  Input SubTLV: #{inspect(test_subtlv)}")

    {:ok, subtlv_result} = Bindocsis.ValueParser.extract_subtlv_value(test_subtlv)
    IO.puts("  Result: #{inspect(subtlv_result)}")
    IO.puts("  Expected: 'best_effort' (formatted_value should be used)")

    success = subtlv_result == "best_effort"
    IO.puts("  ✓ Test passes: #{success}")

    if success do
      IO.puts("\n🎉 Our fixes are working correctly!")
      IO.puts("The issue must be elsewhere in the round-trip process.")
    else
      IO.puts("\n❌ Our fixes are not working as expected.")
    end
  end
end

# Run the test
DirectTestOurFixes.test_extract_functions()
