# Debug uint32 value parsing

IO.puts("=== Testing uint32 parsing directly ===")

# Test what happens with various inputs
IO.puts("Testing integer 1:")
IO.inspect(Bindocsis.ValueParser.parse_value(:uint32, 1, []))

IO.puts("Testing string '1':")
IO.inspect(Bindocsis.ValueParser.parse_value(:uint32, "1", []))

IO.puts("Testing large number:")
IO.inspect(Bindocsis.ValueParser.parse_value(:uint32, "4294967295", []))

# Test a simple JSON with uint32
json_with_uint32 = """
{
  "docsis_version": "3.1", 
  "tlvs": [
    {
      "type": 22,
      "length": 4,
      "formatted_value": "Compound TLV with 1 sub-TLVs",
      "value_type": "compound",
      "subtlvs": [
        {
          "type": 1,
          "length": 4,
          "formatted_value": "12345",
          "value_type": "uint32"
        }
      ]
    }
  ]
}
"""

IO.puts("\\nTesting uint32 JSON conversion:")
case Bindocsis.convert(json_with_uint32, from: :json, to: :binary) do
  {:ok, _} -> IO.puts("✓ uint32 JSON succeeded")
  {:error, reason} -> IO.puts("❌ uint32 JSON failed: #{reason}")
end