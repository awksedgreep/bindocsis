#!/usr/bin/env elixir

# Debug how TLV 26 subtlvs are formatted differently in JSON vs YAML
IO.puts("=== TLV 26 Subtlv Format Comparison ===")

filename = "PHS_last_tlvs.cm"
path = "test/fixtures/#{filename}"

if File.exists?(path) do
  binary = File.read!(path)
  
  # Parse with enhanced mode
  {:ok, tlvs} = Bindocsis.parse(binary, enhanced: true)
  
  # Find TLV 26
  tlv26 = Enum.find(tlvs, &(&1.type == 26))
  
  if tlv26 && Map.has_key?(tlv26, :subtlvs) do
    IO.puts("TLV 26 has #{length(tlv26.subtlvs)} subtlvs:")
    
    Enum.each(tlv26.subtlvs, fn subtlv ->
      IO.puts("  Subtlv #{subtlv.type}: length=#{subtlv.length}, value=#{inspect(subtlv.value, base: :hex)}")
      if Map.has_key?(subtlv, :formatted_value) do
        IO.puts("    formatted_value: #{inspect(subtlv.formatted_value)}")
      end
      if Map.has_key?(subtlv, :value_type) do
        IO.puts("    value_type: #{inspect(subtlv.value_type)}")
      end
    end)
    
    # Generate JSON
    {:ok, json_str} = Bindocsis.Generators.JsonGenerator.generate(tlvs)
    
    # Extract TLV 26 from JSON string
    json_lines = String.split(json_str, "\n")
    in_tlv26 = false
    tlv26_json_lines = []
    brace_count = 0
    
    Enum.each(json_lines, fn line ->
      cond do
        String.contains?(line, "\"type\": 26") ->
          in_tlv26 = true
          tlv26_json_lines = [line | tlv26_json_lines]
          brace_count = if String.contains?(line, "{"), do: 1, else: 0
          
        in_tlv26 ->
          tlv26_json_lines = [line | tlv26_json_lines]
          brace_count = brace_count + 
            (String.length(line) - String.length(String.replace(line, "{", ""))) -
            (String.length(line) - String.length(String.replace(line, "}", "")))
          
          if brace_count <= 0 and String.contains?(line, "}") do
            in_tlv26 = false
          end
          
        true -> nil
      end
    end)
    
    IO.puts("\n--- JSON TLV 26 ---")
    tlv26_json_lines |> Enum.reverse() |> Enum.each(&IO.puts(&1))
    
    # Generate YAML
    {:ok, yaml_str} = Bindocsis.Generators.YamlGenerator.generate(tlvs)
    
    # Extract TLV 26 from YAML string
    yaml_lines = String.split(yaml_str, "\n")
    in_tlv26 = false
    tlv26_yaml_lines = []
    current_indent = 0
    
    Enum.each(yaml_lines, fn line ->
      line_indent = String.length(line) - String.length(String.trim_leading(line))
      
      cond do
        String.contains?(line, "type: 26") ->
          in_tlv26 = true
          current_indent = line_indent
          tlv26_yaml_lines = [line | tlv26_yaml_lines]
          
        in_tlv26 and line_indent > current_indent ->
          tlv26_yaml_lines = [line | tlv26_yaml_lines]
          
        in_tlv26 and line_indent <= current_indent and String.trim(line) != "" ->
          in_tlv26 = false
          
        in_tlv26 ->
          tlv26_yaml_lines = [line | tlv26_yaml_lines]
          
        true -> nil
      end
    end)
    
    IO.puts("\n--- YAML TLV 26 ---")
    tlv26_yaml_lines |> Enum.reverse() |> Enum.each(&IO.puts(&1))
    
  else
    IO.puts("TLV 26 has no subtlvs or not found")
  end
else
  IO.puts("File #{path} not found")
end