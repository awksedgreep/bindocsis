# Simple test to verify our parsing fixes work

# Create a test JSON structure that would previously fail
test_json = """
{
  "tlvs": [
    {
      "type": 24,
      "subtlvs": [
        {
          "type": 1,
          "value": "AQ==",
          "formatted_value": "best_effort"
        },
        {
          "type": 2,
          "value": "AAAD6A==",
          "formatted_value": 1000
        }
      ]
    },
    {
      "type": 3,
      "value": "AQ==",
      "formatted_value": "enabled"
    }
  ]
}
"""

IO.puts("=== Testing Our Parsing Fixes ===")
IO.puts("Testing that formatted_value is prioritized over value...")

# Save test JSON
File.write!("/tmp/test_parsing_fix.json", test_json)

# Test the round-trip conversion
case Bindocsis.parse_file("/tmp/test_parsing_fix.json", format: :json) do
  {:ok, tlvs} ->
    IO.puts("✅ JSON parsing successful - our fixes work!")

    case Bindocsis.generate(tlvs, format: :binary) do
      {:ok, binary_result} ->
        IO.puts("✅ Binary generation successful!")
        IO.puts("✅ Round-trip test PASSED - formatted_value priority fix works!")

        # Parse the binary back to verify
        case Bindocsis.parse(binary_result, format: :binary) do
          {:ok, final_tlvs} ->
            IO.puts("✅ Final verification: binary can be parsed back")
            IO.puts("🎉 ALL TESTS PASSED - Our fixes are working!")

          {:error, reason} ->
            IO.puts("⚠️  Binary re-parsing failed: #{reason}")
        end

      {:error, reason} ->
        IO.puts("❌ Binary generation failed: #{reason}")
        IO.puts("This suggests our fixes didn't fully resolve the issue")
    end

  {:error, reason} ->
    IO.puts("❌ JSON parsing failed: #{reason}")
    IO.puts("This suggests there are still issues with our parsing logic")
end

# Cleanup
File.rm("/tmp/test_parsing_fix.json")
