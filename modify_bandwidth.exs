#!/usr/bin/env elixir

# Read and parse the JSON
IO.puts("Reading original JSON file...")
{:ok, json_content} = File.read("17HarvestMoonCW_editable.json")
{:ok, tlvs} = Bindocsis.parse(json_content, format: :json)

IO.puts("Looking for bandwidth-related TLVs...")

# 75 Mbps in bits per second = 75 * 1024 * 1024 = 78,643,200 bps
# For DOCSIS, upstream rates are often in different units, let's try common values
upstream_bandwidth_bps = 75 * 1024 * 1024  # 78,643,200 bps
upstream_bandwidth_kbps = 75 * 1024        # 76,800 kbps

IO.puts("Target upstream bandwidth: #{upstream_bandwidth_bps} bps (#{upstream_bandwidth_kbps} kbps)")

# Modify TLVs - looking for service flow TLVs that might contain bandwidth settings
modified_tlvs = tlvs
|> Enum.with_index()
|> Enum.map(fn {tlv, index} ->
  cond do
    # Type 24 is Upstream Service Flow - modify its subtlvs
    tlv.type == 24 and Map.has_key?(tlv, :subtlvs) and tlv.subtlvs ->
      IO.puts("Modifying Upstream Service Flow at index #{index}")
      updated_subtlvs = tlv.subtlvs
      |> Enum.with_index()
      |> Enum.map(fn {subtlv, _sub_index} ->
        case subtlv.type do
          8 -> # Upstream Channel ID - might represent bandwidth
            IO.puts("  Updating Upstream Channel ID from #{subtlv.value} to #{upstream_bandwidth_kbps}")
            %{subtlv | value: upstream_bandwidth_kbps}
          9 -> # Network Time Protocol Server - might be bandwidth related
            IO.puts("  Updating NTP Server value from #{subtlv.value} to #{upstream_bandwidth_kbps}")
            %{subtlv | value: upstream_bandwidth_kbps}
          _ -> subtlv
        end
      end)
      %{tlv | subtlvs: updated_subtlvs}
    
    # Type 25 is Downstream Service Flow - check if it has upstream bandwidth settings
    tlv.type == 25 and Map.has_key?(tlv, :subtlvs) and tlv.subtlvs ->
      IO.puts("Checking Downstream Service Flow at index #{index}")
      updated_subtlvs = tlv.subtlvs
      |> Enum.map(fn subtlv ->
        case subtlv.type do
          8 when subtlv.value > 50000000 -> # Large values might be bandwidth
            IO.puts("  Updating large Channel ID value from #{subtlv.value} to #{upstream_bandwidth_bps}")
            %{subtlv | value: upstream_bandwidth_bps}
          _ -> subtlv
        end
      end)
      %{tlv | subtlvs: updated_subtlvs}
    
    true -> tlv
  end
end)

IO.puts("Generating new DOCSIS file...")
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
  {:error, reason} ->
    IO.puts("❌ Verification failed: #{reason}")
end