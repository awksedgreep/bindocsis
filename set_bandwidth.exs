#!/usr/bin/env elixir

defmodule BandwidthSetter do
  @moduledoc """
  Simple utility to set upstream bandwidth in DOCSIS files
  """

  def main(args) do
    case args do
      [input_file, bandwidth_str, output_file] ->
        set_bandwidth(input_file, bandwidth_str, output_file)
      
      [input_file, bandwidth_str] ->
        output_file = String.replace(input_file, ~r/\.cm$/, "_modified.cm")
        set_bandwidth(input_file, bandwidth_str, output_file)
      
      _ ->
        print_usage()
    end
  end

  defp set_bandwidth(input_file, bandwidth_str, output_file) do
    IO.puts("🔧 Setting upstream bandwidth to #{bandwidth_str}")
    IO.puts("📂 Input:  #{input_file}")
    IO.puts("📂 Output: #{output_file}")
    IO.puts("")

    with {:ok, bandwidth_bps} <- parse_bandwidth(bandwidth_str),
         {:ok, original_binary} <- File.read(input_file) do
      
      IO.puts("✅ Parsed bandwidth: #{bandwidth_bps} bps (#{format_bandwidth(bandwidth_bps)})")
      
      # Create the 4-byte pattern for the new bandwidth
      new_pattern = <<bandwidth_bps::32>>
      
      # Common patterns to replace (these are observed bandwidth values)
      old_patterns = [
        <<55_000_000::32>>,   # 55 Mbps  
        <<100_000_000::32>>,  # 100 Mbps
        <<75_000_000::32>>,   # 75 Mbps (if already set)
        <<50_000_000::32>>,   # 50 Mbps
        <<25_000_000::32>>    # 25 Mbps
      ]
      
      # Try to replace each pattern
      {modified_binary, replaced_count} = 
        old_patterns
        |> Enum.reduce({original_binary, 0}, fn old_pattern, {binary, count} ->
          case :binary.split(binary, old_pattern) do
            [prefix, suffix] ->
              IO.puts("🔄 Replaced bandwidth pattern: #{format_bandwidth(:binary.decode_unsigned(old_pattern, :big))} → #{format_bandwidth(bandwidth_bps)}")
              {prefix <> new_pattern <> suffix, count + 1}
            [_] ->
              {binary, count}
          end
        end)
      
      if replaced_count > 0 do
        File.write!(output_file, modified_binary)
        
        # Verify the new file
        case Bindocsis.parse_file(output_file) do
          {:ok, _tlvs} ->
            IO.puts("✅ Successfully created: #{output_file}")
            IO.puts("🔍 File verified and parses correctly")
          {:error, reason} ->
            IO.puts("❌ Warning: Modified file may have issues: #{reason}")
        end
      else
        IO.puts("⚠️  No bandwidth patterns found to replace")
        IO.puts("💡 The file may use a different bandwidth encoding")
      end
      
    else
      {:error, :invalid_bandwidth} ->
        IO.puts("❌ Invalid bandwidth format: #{bandwidth_str}")
        IO.puts("💡 Use formats like: 75M, 100Mbps, 50000000")
        
      {:error, reason} ->
        IO.puts("❌ Error reading file: #{reason}")
    end
  end

  defp parse_bandwidth(bandwidth_str) do
    bandwidth_str = String.trim(bandwidth_str) |> String.downcase()
    
    cond do
      # Parse formats like "75M", "100Mbps", "50mbps"
      Regex.match?(~r/^\d+\.?\d*m(bps)?$/, bandwidth_str) ->
        {number, _} = Float.parse(bandwidth_str)
        {:ok, trunc(number * 1_000_000)}
      
      # Parse formats like "75K", "500kbps"  
      Regex.match?(~r/^\d+\.?\d*k(bps)?$/, bandwidth_str) ->
        {number, _} = Float.parse(bandwidth_str)
        {:ok, trunc(number * 1_000)}
      
      # Parse raw numbers (assume bps)
      Regex.match?(~r/^\d+$/, bandwidth_str) ->
        {number, _} = Integer.parse(bandwidth_str)
        {:ok, number}
      
      true ->
        {:error, :invalid_bandwidth}
    end
  end

  defp format_bandwidth(bps) when bps >= 1_000_000 do
    mbps = bps / 1_000_000
    if mbps == trunc(mbps) do
      "#{trunc(mbps)} Mbps"
    else
      "#{Float.round(mbps, 1)} Mbps"
    end
  end

  defp format_bandwidth(bps) when bps >= 1_000 do
    kbps = bps / 1_000
    if kbps == trunc(kbps) do
      "#{trunc(kbps)} kbps"
    else
      "#{Float.round(kbps, 1)} kbps"
    end
  end

  defp format_bandwidth(bps), do: "#{bps} bps"

  defp print_usage do
    IO.puts("🔧 DOCSIS Bandwidth Setter")
    IO.puts("")
    IO.puts("Usage:")
    IO.puts("  elixir set_bandwidth.exs <input.cm> <bandwidth> [output.cm]")
    IO.puts("")
    IO.puts("Examples:")
    IO.puts("  elixir set_bandwidth.exs modem.cm 75M")
    IO.puts("  elixir set_bandwidth.exs modem.cm 100Mbps modem_100M.cm")
    IO.puts("  elixir set_bandwidth.exs modem.cm 50000000 modem_50M.cm")
    IO.puts("")
    IO.puts("Bandwidth formats:")
    IO.puts("  75M, 100Mbps, 50K, 1000kbps, 75000000 (raw bps)")
  end
end

# Run the main function with command line arguments
BandwidthSetter.main(System.argv())