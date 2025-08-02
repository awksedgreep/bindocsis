#!/usr/bin/env elixir

defmodule ConfigDescriber do
  @moduledoc """
  Create human-readable descriptions of DOCSIS configuration files
  """

  def main(args) do
    case args do
      [input_file] ->
        output_file = String.replace(input_file, ~r/\.[^.]+$/, "_described.json")
        describe_config(input_file, output_file)
      
      [input_file, output_file] ->
        describe_config(input_file, output_file)
      
      _ ->
        print_usage()
    end
  end

  defp describe_config(input_file, output_file) do
    IO.puts("📋 Creating human-readable description of: #{input_file}")
    IO.puts("📂 Output: #{output_file}")
    IO.puts("")

    case Bindocsis.parse_file(input_file) do
      {:ok, tlvs} ->
        # Generate pretty JSON with enhanced descriptions
        {:ok, pretty_json} = Bindocsis.generate(tlvs, 
          format: :json, 
          pretty: true,
          include_names: true,
          detect_subtlvs: true
        )
        
        # Add summary at the top
        summary = create_summary(tlvs)
        enhanced_json = add_summary_to_json(pretty_json, summary)
        
        File.write!(output_file, enhanced_json)
        
        IO.puts("✅ Created described configuration: #{output_file}")
        IO.puts("📊 File size: #{byte_size(enhanced_json)} bytes")
        IO.puts("")
        IO.puts("📋 Configuration Summary:")
        print_summary(summary)
        
      {:error, reason} ->
        IO.puts("❌ Failed to parse file: #{reason}")
    end
  end

  defp create_summary(tlvs) do
    %{
      total_tlvs: length(tlvs),
      service_flows: count_service_flows(tlvs),
      certificates: count_certificates(tlvs),
      bandwidth_settings: find_bandwidth_settings(tlvs),
      key_settings: find_key_settings(tlvs)
    }
  end

  defp count_service_flows(tlvs) do
    upstream = Enum.count(tlvs, &(&1.type == 24))
    downstream = Enum.count(tlvs, &(&1.type == 25))
    %{upstream: upstream, downstream: downstream}
  end

  defp count_certificates(tlvs) do
    Enum.count(tlvs, &(&1.type == 32))
  end

  defp find_bandwidth_settings(tlvs) do
    tlvs
    |> Enum.filter(&(&1.type in [24, 25]))
    |> Enum.map(fn tlv ->
      # Look for bandwidth patterns in the binary data
      case tlv.value do
        binary when is_binary(binary) ->
          # Scan for 32-bit values that look like bandwidth
          find_bandwidth_in_binary(binary, tlv.type)
        _ -> nil
      end
    end)
    |> Enum.reject(&is_nil/1)
    |> Enum.uniq()
  end

  defp find_bandwidth_in_binary(binary, flow_type) do
    # Look for common bandwidth patterns
    bandwidth_patterns = [
      {<<25_000_000::32>>, "25 Mbps"},
      {<<50_000_000::32>>, "50 Mbps"},
      {<<55_000_000::32>>, "55 Mbps"},
      {<<75_000_000::32>>, "75 Mbps"},
      {<<100_000_000::32>>, "100 Mbps"},
      {<<150_000_000::32>>, "150 Mbps"},
      {<<200_000_000::32>>, "200 Mbps"}
    ]
    
    flow_name = if flow_type == 24, do: "Upstream", else: "Downstream"
    
    Enum.find_value(bandwidth_patterns, fn {pattern, description} ->
      if String.contains?(binary, pattern) do
        "#{flow_name}: #{description}"
      end
    end)
  end

  defp find_key_settings(tlvs) do
    settings = []
    
    # Web Access Control
    settings = case Enum.find(tlvs, &(&1.type == 3)) do
      %{value: <<1>>} -> ["Web Access: Enabled" | settings]
      %{value: <<0>>} -> ["Web Access: Disabled" | settings]
      _ -> settings
    end
    
    # Max CPEs
    settings = case Enum.find(tlvs, &(&1.type == 18)) do
      %{value: <<count>>} -> ["Max CPEs: #{count}" | settings]
      _ -> settings
    end
    
    Enum.reverse(settings)
  end

  defp add_summary_to_json(json_string, summary) do
    # Insert summary at the beginning of the JSON
    summary_json = """
    {
      "_description": "DOCSIS Configuration File Analysis",
      "_summary": {
        "total_tlvs": #{summary.total_tlvs},
        "service_flows": {
          "upstream": #{summary.service_flows.upstream},
          "downstream": #{summary.service_flows.downstream}
        },
        "certificates": #{summary.certificates},
        "bandwidth_settings": #{inspect(summary.bandwidth_settings)},
        "key_settings": #{inspect(summary.key_settings)}
      },
    """
    
    # Replace the opening brace with our summary
    String.replace(json_string, ~r/^\{/, summary_json, global: false)
  end

  defp print_summary(summary) do
    IO.puts("  • Total TLVs: #{summary.total_tlvs}")
    IO.puts("  • Service Flows: #{summary.service_flows.upstream} upstream, #{summary.service_flows.downstream} downstream")
    IO.puts("  • Certificates: #{summary.certificates}")
    
    if length(summary.bandwidth_settings) > 0 do
      IO.puts("  • Bandwidth Settings:")
      Enum.each(summary.bandwidth_settings, fn setting ->
        IO.puts("    - #{setting}")
      end)
    end
    
    if length(summary.key_settings) > 0 do
      IO.puts("  • Key Settings:")
      Enum.each(summary.key_settings, fn setting ->
        IO.puts("    - #{setting}")
      end)
    end
  end

  defp print_usage do
    IO.puts("📋 DOCSIS Configuration Describer")
    IO.puts("")
    IO.puts("Usage:")
    IO.puts("  elixir describe_config.exs <input.cm> [output.json]")
    IO.puts("")
    IO.puts("Examples:")
    IO.puts("  elixir describe_config.exs modem.cm")
    IO.puts("  elixir describe_config.exs modem.cm modem_analysis.json")
    IO.puts("")
    IO.puts("This tool creates a human-readable JSON description of")
    IO.puts("a DOCSIS configuration file with:")
    IO.puts("  • Pretty formatting")
    IO.puts("  • Configuration summary")
    IO.puts("  • Bandwidth analysis")
    IO.puts("  • Key setting identification")
  end
end

# Run the main function with command line arguments
ConfigDescriber.main(System.argv())