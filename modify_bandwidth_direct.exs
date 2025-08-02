#!/usr/bin/env elixir

# Read and parse the JSON
{:ok, json_content} = File.read("17HarvestMoonCW_editable.json")
{:ok, tlvs} = Bindocsis.parse(json_content, format: :json)

IO.puts("Original file has #{length(tlvs)} TLVs")

# For DOCSIS, 75 Mbps upstream might be represented in different ways:
# - 78,643,200 bps (75 * 1024 * 1024)
# - 76,800 kbps (75 * 1024) 
# - Or simply 75 Mbps

# Let's try a direct approach: create new service flow TLVs with 75 Mbps settings
upstream_rate_bps = 75 * 1024 * 1024  # 78,643,200 bps
upstream_rate_kbps = 75 * 1024        # 76,800 kbps

IO.puts("Setting upstream bandwidth to 75 Mbps (#{upstream_rate_bps} bps)")

# Create a modified list of TLVs
modified_tlvs = tlvs
|> Enum.map(fn tlv ->
  case tlv.type do
    # Modify service flow TLVs to include bandwidth information
    24 -> # Upstream Service Flow
      IO.puts("Modifying upstream service flow TLV (Type 24)")
      # Create new subtlvs with bandwidth settings
      new_subtlvs = [
        %{type: 1, value: 1, length: 1, name: "Service Flow Reference", description: "Service flow identifier"},
        %{type: 2, value: 1, length: 1, name: "Service Flow ID", description: "Service flow ID"},
        %{type: 3, value: 7, length: 1, name: "QoS Parameter Set Type", description: "QoS parameter set"},
        %{type: 4, value: upstream_rate_bps, length: 4, name: "Traffic Priority", description: "Upstream max rate"},
        %{type: 8, value: upstream_rate_bps, length: 4, name: "Maximum Sustained Traffic Rate", description: "Max sustained rate"},
        %{type: 9, value: upstream_rate_bps, length: 4, name: "Maximum Traffic Burst", description: "Max burst"},
        %{type: 10, value: upstream_rate_kbps, length: 4, name: "Minimum Reserved Traffic Rate", description: "Min reserved rate"}
      ]
      Map.put(tlv, :subtlvs, new_subtlvs) |> Map.put(:value, nil)
    
    25 -> # Downstream Service Flow  
      IO.puts("Modifying downstream service flow TLV (Type 25)")
      # Keep existing but ensure it doesn't conflict
      new_subtlvs = [
        %{type: 1, value: 2, length: 1, name: "Service Flow Reference", description: "Service flow identifier"},
        %{type: 2, value: 2, length: 1, name: "Service Flow ID", description: "Service flow ID"},
        %{type: 3, value: 7, length: 1, name: "QoS Parameter Set Type", description: "QoS parameter set"},
        %{type: 8, value: 1000 * 1024 * 1024, length: 4, name: "Maximum Sustained Traffic Rate", description: "Downstream max rate (1 Gbps)"}
      ]
      Map.put(tlv, :subtlvs, new_subtlvs) |> Map.put(:value, nil)
    
    _ -> tlv
  end
end)

IO.puts("Generating new DOCSIS file with 75 Mbps upstream...")
{:ok, binary} = Bindocsis.generate(modified_tlvs, format: :binary)
File.write!("17HarvestMoonCW100x75.cm", binary)

IO.puts("✅ Successfully created: 17HarvestMoonCW100x75.cm")
IO.puts("📊 File size: #{byte_size(binary)} bytes")

# Also save the modified JSON for reference
{:ok, modified_json} = Bindocsis.generate(modified_tlvs, format: :json)
File.write!("17HarvestMoonCW100x75.json", modified_json)
IO.puts("📄 Also saved modified JSON: 17HarvestMoonCW100x75.json")

# Verify the new file can be parsed
IO.puts("🔍 Verifying new file...")
case Bindocsis.parse_file("17HarvestMoonCW100x75.cm") do
  {:ok, verified_tlvs} ->
    IO.puts("✅ Verification successful! Parsed #{length(verified_tlvs)} TLVs")
    
    # Show the service flow TLVs in the new file
    verified_tlvs
    |> Enum.with_index()
    |> Enum.each(fn {tlv, index} ->
      if tlv.type in [24, 25] do
        IO.puts("Service Flow TLV #{index} (Type #{tlv.type}):")
        if Map.has_key?(tlv, :subtlvs) and tlv.subtlvs do
          tlv.subtlvs |> Enum.each(fn subtlv ->
            name = Map.get(subtlv, :name, "Type #{subtlv.type}")
            IO.puts("  #{name}: #{subtlv.value}")
          end)
        end
      end
    end)
    
  {:error, reason} ->
    IO.puts("❌ Verification failed: #{reason}")
end