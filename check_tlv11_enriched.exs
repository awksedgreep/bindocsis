Mix.install([{:bindocsis, path: "."}])

# Parse and enrich, then check TLV 11
{:ok, config} = Bindocsis.parse_file("25ccatv-base-v2.cm")

# Find first TLV 11
tlv11 = Enum.find(config.tlvs, fn tlv -> tlv[:type] == 11 end)

if tlv11 do
  IO.puts("TLV 11 after enrichment:")
  IO.puts("  Type: #{tlv11[:type]}")
  IO.puts("  Name: #{tlv11[:name]}")
  IO.puts("  value_type: #{inspect(tlv11[:value_type])}")
  IO.puts("  has subtlvs key: #{Map.has_key?(tlv11, :subtlvs)}")

  if Map.has_key?(tlv11, :subtlvs) do
    IO.puts("  number of subtlvs: #{length(tlv11[:subtlvs])}")
    Enum.each(tlv11[:subtlvs], fn sub ->
      IO.puts("    - Type #{sub[:type]}: #{sub[:name]}")
      IO.puts("      value_type: #{inspect(sub[:value_type])}")
      if Map.has_key?(sub, :subtlvs) do
        IO.puts("      has nested subtlvs: #{length(sub[:subtlvs])}")
      end
    end)
  else
    IO.puts("  NO SUBTLVS (correct!)")
  end
else
  IO.puts("No TLV 11 found")
end
