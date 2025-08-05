#!/usr/bin/env elixir

Mix.install([
  {:bindocsis, path: "."}
])

# Find service flow fixtures that might be producing TLVs 0, 9, 24
service_flow_fixtures = [
  "test/fixtures/TLV_24_43_6_ExtendedCMTSMICConfiguration.cm",
  "test/fixtures/TLV_24_43_1_to_4_CMLoadBalancingPolicyID.cm", 
  "test/fixtures/TLV_24_43_5_14_DPoE.cm",
  "test/fixtures/TLV_24_43_5_24_SOAMSubtype.cm",
  "test/fixtures/TLV_24_43_5_10_and_12.cm",
  "test/fixtures/TLV_24_43_last_tlvs.cm",
  "test/fixtures/TLV_24_last_before_43.cm",
  "test/fixtures/TLV_24_43_5_13_L2VPNMode.cm",
  "test/fixtures/TLV_24_3_ServiceIdentifier.cm",
  "test/fixtures/TLV_25_43_last_tlvs.cm",
  "test/fixtures/TLV_25_remaining.cm",
  "test/fixtures/TLV_25_43_5_10_and_12.cm",
  "test/fixtures/TLV_25_43_1_to_4_CMLoadBalancingPolicyID.cm",
  "test/fixtures/TLV_25_43_6_ExtendedCMTSMICConfiguration.cm",
  "test/fixtures/TLV_25_43_5_24_SOAMSubtype.cm",
  "test/fixtures/TLV_25_43_5_14_DPoE.cm",
  "test/fixtures/TLV_25_43_5_13_L2VPNMode.cm"
]

IO.puts("Testing service flow fixtures for TLV 0, 9, 24 issue...")
IO.puts("=" <> String.duplicate("=", 50))

for fixture <- service_flow_fixtures do
  if File.exists?(fixture) do
    IO.puts("\nTesting: #{fixture}")
    
    case Bindocsis.parse_file(fixture) do
      {:ok, tlvs} ->
        tlv_types = tlvs |> Enum.map(&(&1.type)) |> Enum.sort() |> Enum.uniq()
        IO.puts("  TLV types found: #{inspect(tlv_types)}")
        
        # Check if this produces the problematic pattern
        if Enum.sort([0, 9, 24]) == Enum.sort(tlv_types) do
          IO.puts("  🚨 FOUND IT! This fixture produces TLVs 0, 9, 24")
          IO.puts("  File size: #{File.stat!(fixture).size} bytes")
          
          # Show the binary content
          binary_content = File.read!(fixture)
          hex_dump = binary_content |> :binary.bin_to_list() |> Enum.map(&Integer.to_string(&1, 16) |> String.pad_leading(2, "0")) |> Enum.join(" ")
          IO.puts("  Binary content: #{hex_dump}")
          
          # Show the parsed TLVs
          IO.puts("  Parsed TLVs:")
          for tlv <- tlvs do
            IO.puts("    TLV #{tlv.type}: length=#{tlv.length}, value=#{inspect(tlv.value)}")
          end
        elsif 0 in tlv_types do
          IO.puts("  ⚠️  Contains TLV 0, checking...")
          
          tlv_0 = Enum.find(tlvs, &(&1.type == 0))
          IO.puts("    TLV 0: length=#{tlv_0.length}, value=#{inspect(tlv_0.value)}")
          
          if tlv_0.length == 2 do
            IO.puts("    🔍 TLV 0 has invalid 2-byte length (should be 1 byte)")
          end
        end
        
      {:error, reason} ->
        IO.puts("  ❌ Parse error: #{reason}")
    end
  else
    IO.puts("  ⚠️  File does not exist: #{fixture}")
  end
end

IO.puts("\n" <> String.duplicate("=", 50))
IO.puts("Search complete.")
