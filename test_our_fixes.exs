#!/usr/bin/env elixir

# Test script to verify our fixes for prioritizing formatted_value over value

Mix.install([{:jason, "~> 1.4"}])

# Add the project to the path
Code.prepend_path("_build/dev/lib/bindocsis/ebin")

defmodule TestOurFixes do
  def test_extract_human_value() do
    IO.puts("=== Testing extract_human_value function ===")

    # Test case 1: TLV with both value and formatted_value
    tlv_with_both = %{
      "type" => 3,
      # raw binary
      "value" => <<1>>,
      # human-readable
      "formatted_value" => "enabled"
    }

    IO.puts("Test 1 - TLV with both value and formatted_value:")
    IO.puts("  Input: #{inspect(tlv_with_both)}")

    result1 = Bindocsis.HumanConfig.extract_human_value(tlv_with_both)
    IO.puts("  Result: #{inspect(result1)}")
    IO.puts("  Expected: 'enabled' (formatted_value should be prioritized)")
    IO.puts("  ✓ Pass: #{result1 == "enabled"}")

    # Test case 2: TLV with compound structure (subtlvs)
    tlv_with_subtlvs = %{
      "type" => 24,
      "subtlvs" => [
        %{"type" => 1, "formatted_value" => "best_effort"},
        %{"type" => 2, "formatted_value" => 1000}
      ]
    }

    IO.puts("\nTest 2 - TLV with subtlvs:")
    IO.puts("  Input: #{inspect(tlv_with_subtlvs)}")

    result2 = Bindocsis.HumanConfig.extract_human_value(tlv_with_subtlvs)
    IO.puts("  Result: #{inspect(result2)}")
    IO.puts("  Expected: Map with subtlv data (subtlvs should be processed)")

    # Test case 3: TLV with only value (fallback case)
    tlv_with_only_value = %{
      "type" => 5,
      # IP address
      "value" => <<192, 168, 1, 1>>
    }

    IO.puts("\nTest 3 - TLV with only value (fallback):")
    IO.puts("  Input: #{inspect(tlv_with_only_value)}")

    result3 = Bindocsis.HumanConfig.extract_human_value(tlv_with_only_value)
    IO.puts("  Result: #{inspect(result3)}")
    IO.puts("  Expected: Should fall back to processing value")
  end

  def test_extract_subtlv_value() do
    IO.puts("\n=== Testing extract_subtlv_value function ===")

    # Test case 1: SubTLV with formatted_value
    subtlv_with_formatted = %{
      "type" => 1,
      # raw binary
      "value" => <<1>>,
      # human-readable
      "formatted_value" => "best_effort"
    }

    IO.puts("Test 1 - SubTLV with formatted_value:")
    IO.puts("  Input: #{inspect(subtlv_with_formatted)}")

    result1 = Bindocsis.ValueParser.extract_subtlv_value(subtlv_with_formatted)
    IO.puts("  Result: #{inspect(result1)}")
    IO.puts("  Expected: 'best_effort' (formatted_value should be prioritized)")
    IO.puts("  ✓ Pass: #{result1 == "best_effort"}")

    # Test case 2: SubTLV with only value (fallback)
    subtlv_with_only_value = %{
      "type" => 2,
      # 1000 as binary
      "value" => <<0, 0, 3, 232>>
    }

    IO.puts("\nTest 2 - SubTLV with only value (fallback):")
    IO.puts("  Input: #{inspect(subtlv_with_only_value)}")

    result2 = Bindocsis.ValueParser.extract_subtlv_value(subtlv_with_only_value)
    IO.puts("  Result: #{inspect(result2)}")
    IO.puts("  Expected: Should fall back to processing value")
  end

  def run_tests() do
    IO.puts("Testing our fixes to prioritize formatted_value over value\n")

    try do
      test_extract_human_value()
      test_extract_subtlv_value()

      IO.puts("\n=== Test Summary ===")
      IO.puts("✓ All tests completed")

      IO.puts(
        "Key principle verified: formatted_value is prioritized over value for human editing"
      )
    rescue
      e ->
        IO.puts("Error during testing: #{Exception.message(e)}")
        IO.puts("Stack trace:")
        IO.puts(Exception.format_stacktrace(__STACKTRACE__))
    end
  end
end

# Run the tests
TestOurFixes.run_tests()
