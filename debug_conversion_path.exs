#!/usr/bin/env elixir

# Test which conversion path is taken for compound subtlvs
test_subtlv = %{
  "type" => 1,
  "length" => 4,
  "value_type" => "compound",
  "formatted_value" => nil,
  "subtlvs" => [
    %{
      "type" => 0,
      "length" => 0,
      "value_type" => "marker",
      "formatted_value" => ""
    }
  ]
}

IO.puts("Test subtlv structure:")
IO.puts("  has subtlvs: #{Map.has_key?(test_subtlv, "subtlvs")}")
IO.puts("  subtlvs is list: #{is_list(Map.get(test_subtlv, "subtlvs"))}")
IO.puts("  subtlvs length: #{length(Map.get(test_subtlv, "subtlvs", []))}")

subtlvs = Map.get(test_subtlv, "subtlvs")
IO.puts("  subtlvs check: #{is_list(subtlvs) and length(subtlvs) > 0}")

# This should take the compound TLV path if the condition works correctly
IO.puts("\nCondition evaluation:")
case Map.get(test_subtlv, "subtlvs") do
  subtlvs when is_list(subtlvs) and length(subtlvs) > 0 ->
    IO.puts("✅ Would take compound TLV path")
  _ ->
    IO.puts("❌ Would take simple TLV path")
end

# Test what extract_human_value returns for compound TLV with nil formatted_value
IO.puts("\nTesting extract_human_value:")
try do
  # This is a private function, but let's see what the public interface does
  result = Bindocsis.HumanConfig.from_json(JSON.encode!(%{
    "tlvs" => [test_subtlv]
  }))
  
  case result do
    {:ok, binary} ->
      IO.puts("✅ Conversion succeeded: #{byte_size(binary)} bytes")
      IO.puts("   Binary: #{Base.encode16(binary)}")
      
      # Parse back without terminator
      clean_binary = binary |> :binary.part(0, byte_size(binary) - 1)
      {:ok, parsed} = Bindocsis.parse(clean_binary, enhanced: false)
      if length(parsed) > 0 do
        tlv = hd(parsed)
        IO.puts("   Parsed: type=#{tlv.type}, length=#{tlv.length}")
        IO.puts("   Value: #{Base.encode16(tlv.value)}")
        
        # Check if the value contains the expected TLV 0 structure
        expected_subtlv_binary = <<0, 0>>  # TLV 0 with length 0
        if tlv.value == expected_subtlv_binary do
          IO.puts("   ✅ Correct: Contains TLV 0 marker structure")
        else
          IO.puts("   ❌ Wrong: Expected #{Base.encode16(expected_subtlv_binary)}")
        end
      end
      
    {:error, reason} ->
      IO.puts("❌ Conversion failed: #{reason}")
  end
rescue
  e -> IO.puts("❌ Exception: #{Exception.message(e)}")
end