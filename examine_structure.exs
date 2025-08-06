#!/usr/bin/env elixir

Mix.install([
  {:bindocsis, path: Path.expand(".", __DIR__)},
  {:jason, "~> 1.4"}
])

# Parse a fixture and examine its JSON structure
fixture_file = "test/fixtures/test_mta.bin"
IO.puts("Examining fixture: #{fixture_file}")

case Bindocsis.parse_file(fixture_file) do
  {:ok, tlvs} ->
    case Bindocsis.generate(tlvs, format: :json) do
      {:ok, json_result} ->
        json_data = Jason.decode!(json_result)

        # Look for service flow TLVs (type 24)
        tlvs_data = Map.get(json_data, "tlvs", [])
        service_flows = Enum.filter(tlvs_data, &(Map.get(&1, "type") == 24))

        IO.puts("Total TLVs: #{length(tlvs_data)}")
        IO.puts("Service flow TLVs (type 24): #{length(service_flows)}")

        if length(service_flows) > 0 do
          sf = List.first(service_flows)
          IO.puts("\n=== FIRST SERVICE FLOW STRUCTURE ===")
          IO.puts("Keys: #{inspect(Map.keys(sf))}")

          if Map.has_key?(sf, "subtlvs") do
            IO.puts("Has subtlvs: #{length(sf["subtlvs"])} entries")
            IO.puts("Subtlvs structure:")

            Enum.each(sf["subtlvs"], fn subtlv ->
              IO.puts("  - Type #{subtlv["type"]}: #{subtlv["name"] || "unknown"}")
            end)
          end

          if Map.has_key?(sf, "formatted_value") do
            IO.puts("Has formatted_value: #{inspect(sf["formatted_value"])}")
          end

          # Now test what extract_human_value would return
          IO.puts("\n=== WHAT EXTRACT_HUMAN_VALUE WOULD RETURN ===")

          if Map.has_key?(sf, "subtlvs") do
            IO.puts("✅ Would return subtlvs (the compound TLV structure)")
            IO.puts("This should work with parse_compound_tlv")
          else
            IO.puts("❌ No subtlvs found - would fall back to formatted_value")
          end

          # Save this service flow to examine
          File.write!("/tmp/service_flow_sample.json", Jason.encode!(sf, pretty: true))
          IO.puts("\nService flow saved to /tmp/service_flow_sample.json")
        else
          IO.puts("No service flow TLVs found in this fixture")
        end

      {:error, reason} ->
        IO.puts("JSON generation failed: #{reason}")
    end

  {:error, reason} ->
    IO.puts("Binary parsing failed: #{reason}")
end
