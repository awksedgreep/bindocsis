# Debug the exact type being passed to boolean parser

json_with_boolean = """
{
  "docsis_version": "3.1", 
  "tlvs": [
    {
      "type": 24,
      "length": 4,
      "formatted_value": "Compound TLV with 1 sub-TLVs",
      "value_type": "compound",
      "subtlvs": [
        {
          "type": 1,
          "length": 1,
          "formatted_value": 1,
          "value_type": "boolean"
        }
      ]
    }
  ]
}
"""

IO.puts("=== Testing boolean parsing directly ===")

# Test what happens with integer vs string
IO.puts("Testing integer 1:")
IO.inspect(Bindocsis.ValueParser.parse_value(:boolean, 1, []))

IO.puts("Testing string '1':")
IO.inspect(Bindocsis.ValueParser.parse_value(:boolean, "1", []))

IO.puts("Testing the actual JSON conversion:")
case Bindocsis.convert(json_with_boolean, from: :json, to: :binary) do
  {:ok, _} -> IO.puts("✓ Simple boolean JSON succeeded")
  {:error, reason} -> IO.puts("❌ Simple boolean JSON failed: #{reason}")
end