#!/usr/bin/env elixir

binary = File.read!("test/fixtures/TLV_22_43_1_CMLoadBalancingPolicyID.cm")

# Parse and enrich
{:ok, tlvs} = Bindocsis.parse(binary, enhanced: true)

# Now generate JSON map
case Bindocsis.Generators.JsonGenerator.generate(tlvs, []) do
  {:ok, json_string} ->
    # Check if raw_value appears in the JSON string
    if String.contains?(json_string, "raw_value") do
      IO.puts("❌ JSON contains raw_value!")
      
      # Find where it appears
      lines = String.split(json_string, ",")
      Enum.each(lines, fn line ->
        if String.contains?(line, "raw_value") do
          IO.puts("Found: #{String.slice(line, 0, 100)}...")
        end
      end)
    else
      IO.puts("✅ JSON does not contain raw_value")
    end
    
  {:error, reason} ->
    IO.puts("❌ JSON generation failed: #{reason}")
end