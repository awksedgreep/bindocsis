#!/usr/bin/env elixir

defmodule AnalysisHelper do
  def check_nested_43(tlvs) do
    Enum.any?(tlvs, fn tlv ->
      subtlvs = Map.get(tlv, :subtlvs, [])
      if subtlvs != [] do
        Enum.any?(subtlvs, &(&1.type == 43)) or check_nested_43(subtlvs)
      else
        false
      end
    end) |> then(fn x -> if x, do: "Y", else: "N" end)
  end
end

failing_files = [
  "StaticMulticastSession.cm",
  "TLV41_DsChannelList.cm", 
  "TLV_22_43_12_DEMARCAutoConfiguration.cm",
  "TLV_22_43_5_2_4_2_MPLSPeerIpAddress.cm",
  "TLV_22_43_5_2_4_ServiceMultiplexingValueMPLSPW.cm",
  "TLV_22_43_5_2_6_IEEE8021ahEncapsulation.cm",
  "TLV_22_43_5_3_to_9.cm",
  "TLV_22_43_9_CMAttributeMasks.cm",
  "TLV_23_43_5_24_SOAMSubtype.cm",
  "TLV_23_43_last_tlvs.cm",
  "PHS_last_tlvs.cm",
  "TLV_22_43_4.cm"
]

IO.puts("File,Size,TLVs,Has22/23,Has41,Has43nested,JSON,YAML")

Enum.each(failing_files, fn filename ->
  path = "test/fixtures/#{filename}"
  if File.exists?(path) do
    binary = File.read!(path)
    
    case Bindocsis.parse(binary, enhanced: true) do
      {:ok, tlvs} ->
        size = byte_size(binary)
        tlv_count = length(tlvs)
        has_22_23 = if Enum.any?(tlvs, &(&1.type in [22, 23])), do: "Y", else: "N"
        has_41 = if Enum.any?(tlvs, &(&1.type == 41)), do: "Y", else: "N"
        
        # Check for nested 43
        has_nested_43 = AnalysisHelper.check_nested_43(tlvs)
        
        # Test JSON
        json_result = try do
          {:ok, json} = Bindocsis.Generators.JsonGenerator.generate(tlvs)
          {:ok, binary} = Bindocsis.HumanConfig.from_json(json)
          {:ok, final} = Bindocsis.parse(binary, enhanced: true)
          if length(tlvs) == length(final) and 
             Enum.zip(tlvs, final) |> Enum.all?(fn {t1, t2} -> 
               t1.type == t2.type and t1.length == t2.length 
             end) do
            "OK"
          else
            "FAIL"
          end
        rescue
          _ -> "ERROR"
        end
        
        # Test YAML
        yaml_result = try do
          {:ok, yaml} = Bindocsis.Generators.YamlGenerator.generate(tlvs)
          {:ok, binary} = Bindocsis.HumanConfig.from_yaml(yaml)
          {:ok, final} = Bindocsis.parse(binary, enhanced: true)
          if length(tlvs) == length(final) and 
             Enum.zip(tlvs, final) |> Enum.all?(fn {t1, t2} -> 
               t1.type == t2.type and t1.length == t2.length 
             end) do
            "OK"
          else
            "FAIL"
          end
        rescue
          _ -> "ERROR"
        end
        
        IO.puts("#{filename},#{size},#{tlv_count},#{has_22_23},#{has_41},#{has_nested_43},#{json_result},#{yaml_result}")
      
      {:error, _} ->
        IO.puts("#{filename},ERROR,,,,,")
    end
  end
end)