#!/usr/bin/env elixir

# Analyze L2VPN nested structures to understand spec issues
fixtures = [
  "TLV_22_43_5_2_4_2_MPLSPeerIpAddress.cm",
  "TLV_22_43_5_2_4_ServiceMultiplexingValueMPLSPW.cm", 
  "TLV_22_43_5_2_6_IEEE8021ahEncapsulation.cm"
]

defmodule L2VPNAnalyzer do
  def analyze_fixture(filename) do
    path = "test/fixtures/#{filename}"
    if File.exists?(path) do
      binary = File.read!(path)
      {:ok, tlvs} = Bindocsis.parse(binary, enhanced: true)
      
      IO.puts("\n=== #{filename} ===")
      
      # Find TLV 22 or 23
      main_tlv = Enum.find(tlvs, &(&1.type in [22, 23]))
      if main_tlv do
        find_and_analyze_l2vpn_path(main_tlv, [main_tlv.type])
      end
    end
  end
  
  def find_and_analyze_l2vpn_path(tlv, path) do
    if tlv.subtlvs do
      Enum.each(tlv.subtlvs, fn subtlv ->
        new_path = path ++ [subtlv.type]
        
        # Check for L2VPN encoding contexts (TLV 43.5.x)
        cond do
          path == [22, 43, 5] or path == [23, 43, 5] ->
            IO.puts("L2VPN context: #{inspect(new_path)}")
            IO.puts("  Type: #{subtlv.type}, Length: #{subtlv.length}")
            IO.puts("  Value type: #{inspect(subtlv.value_type)}")
            IO.puts("  Formatted value: #{inspect(subtlv.formatted_value, limit: 50)}")
            
            # Check current spec
            current_spec = get_subtlv_spec_for_context(new_path, subtlv.type)
            IO.puts("  Current spec: #{inspect(current_spec)}")
            
          length(new_path) >= 4 and Enum.at(new_path, 1) == 43 and Enum.at(new_path, 2) == 5 ->
            IO.puts("Deep L2VPN: #{inspect(new_path)}")
            IO.puts("  Type: #{subtlv.type}, Length: #{subtlv.length}")
            IO.puts("  Value type: #{inspect(subtlv.value_type)}")
            IO.puts("  Has subtlvs: #{!!subtlv.subtlvs and length(subtlv.subtlvs) > 0}")
            
          true ->
            nil
        end
        
        # Recurse into subtlvs
        find_and_analyze_l2vpn_path(subtlv, new_path)
      end)
    end
  end
  
  def get_subtlv_spec_for_context(path, type) do
    try do
      Bindocsis.SubTlvSpecs.get_subtlv_specs_for_context(path) |> Map.get(type)
    rescue
      _ -> :no_spec
    end
  end
end

# Analyze the failing fixtures
Enum.each(fixtures, &L2VPNAnalyzer.analyze_fixture/1)