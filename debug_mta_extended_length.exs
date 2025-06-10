#!/usr/bin/env elixir

# Debug script for MTA binary length parsing issues
# Usage: elixir debug_mta_extended_length.exs

defmodule MTALengthDebugger do
  @moduledoc """
  Debug script to investigate the PacketCable MTA binary length parsing issue.
  
  The problem: Files consistently show lengths of 134414357 bytes but only have ~254 bytes.
  Pattern: <<TLV_TYPE, 0x84, 0x08, 0x03, 0x00, 0x15, ...>>
  """

  def run do
    IO.puts("🔍 MTA Binary Length Debugging Tool")
    IO.puts("=" <> String.duplicate("=", 50))
    
    # Find MTA binary files
    mta_files = find_mta_files()
    
    if Enum.empty?(mta_files) do
      IO.puts("❌ No MTA binary files found. Looking in:")
      IO.puts("  - test/fixtures/")
      IO.puts("  - *.bin files in current directory")
      System.halt(1)
    end
    
    IO.puts("📁 Found #{length(mta_files)} MTA binary files")
    IO.puts("")
    
    # Debug each file
    Enum.each(mta_files, &debug_file/1)
    
    # Show summary analysis
    show_summary_analysis()
  end
  
  defp find_mta_files do
    # Look for binary files in common locations
    patterns = [
      "test/fixtures/*.bin",
      "*.bin", 
      "test/fixtures/**/*.bin"
    ]
    
    patterns
    |> Enum.flat_map(&Path.wildcard/1)
    |> Enum.filter(&File.exists?/1)
    |> Enum.uniq()
  end
  
  defp debug_file(filepath) do
    IO.puts("🔍 Debugging: #{Path.basename(filepath)}")
    IO.puts("   Full path: #{filepath}")
    
    case File.read(filepath) do
      {:ok, data} ->
        analyze_binary_data(data, filepath)
      {:error, reason} ->
        IO.puts("   ❌ Failed to read: #{reason}")
    end
    
    IO.puts("")
  end
  
  defp analyze_binary_data(data, filepath) do
    file_size = byte_size(data)
    IO.puts("   📊 File size: #{file_size} bytes")
    
    # Show hex dump of first 32 bytes
    show_hex_dump(data, 32)
    
    # Look for the problematic 0x84 pattern
    find_extended_length_patterns(data)
    
    # Try to parse with different strategies
    try_parsing_strategies(data, filepath)
  end
  
  defp show_hex_dump(data, max_bytes) do
    bytes_to_show = min(byte_size(data), max_bytes)
    <<chunk::binary-size(bytes_to_show), _rest::binary>> = data
    
    hex_string = chunk
    |> :binary.bin_to_list()
    |> Enum.map(&Integer.to_string(&1, 16))
    |> Enum.map(&String.pad_leading(&1, 2, "0"))
    |> Enum.join(" ")
    
    IO.puts("   🔢 Hex dump (first #{bytes_to_show} bytes):")
    IO.puts("      #{hex_string}")
  end
  
  defp find_extended_length_patterns(data) do
    IO.puts("   🔍 Looking for extended length patterns (0x8X)...")
    
    # Find all positions where 0x8X appears as potential length indicators
    find_pattern_positions(data, 0)
  end
  
  defp find_pattern_positions(<<>>, _pos), do: nil
  
  defp find_pattern_positions(<<byte::8, rest::binary>>, pos) do
    if byte >= 0x80 and byte <= 0x84 do
      analyze_extended_length_at_position(<<byte::8, rest::binary>>, pos)
    end
    find_pattern_positions(rest, pos + 1)
  end
  
  defp analyze_extended_length_at_position(data, pos) do
    case data do
      <<length_indicator::8, b1::8, b2::8, b3::8, b4::8, _rest::binary>> when length_indicator == 0x84 ->
        IO.puts("   🎯 Found 0x84 pattern at position #{pos}")
        
        # Calculate different interpretations
        big_endian = b1 * 0x1000000 + b2 * 0x10000 + b3 * 0x100 + b4
        little_endian = b4 * 0x1000000 + b3 * 0x10000 + b2 * 0x100 + b1
        
        # Network byte order (big endian 16-bit pairs)
        pair1 = b1 * 0x100 + b2
        pair2 = b3 * 0x100 + b4
        
        IO.puts("      Length bytes: [#{b1}, #{b2}, #{b3}, #{b4}] (0x#{format_hex([b1, b2, b3, b4])})")
        IO.puts("      Big-endian:    #{big_endian} bytes")
        IO.puts("      Little-endian: #{little_endian} bytes")
        IO.puts("      As two shorts:  #{pair1} + #{pair2} = #{pair1 + pair2}")
        IO.puts("      Just last byte: #{b4} bytes")
        
        # Check if any interpretation makes sense for file size
        remaining_data = byte_size(data) - 5  # subtract 5 bytes for type + 0x84 + 4 length bytes
        IO.puts("      Remaining data after this TLV header: #{remaining_data} bytes")
        
        interpretations = [
          {"big-endian", big_endian},
          {"little-endian", little_endian}, 
          {"sum of pairs", pair1 + pair2},
          {"first pair only", pair1},
          {"second pair only", pair2},
          {"last byte only", b4}
        ]
        
        reasonable = Enum.filter(interpretations, fn {_name, length} -> 
          length > 0 and length <= remaining_data 
        end)
        
        if Enum.empty?(reasonable) do
          IO.puts("      ❌ No reasonable length interpretation found!")
        else
          IO.puts("      ✅ Reasonable interpretations:")
          Enum.each(reasonable, fn {name, length} ->
            IO.puts("         - #{name}: #{length} bytes")
          end)
        end
        
      <<length_indicator::8, _rest::binary>> when length_indicator >= 0x81 and length_indicator <= 0x83 ->
        num_length_bytes = length_indicator - 0x80
        IO.puts("   📏 Found 0x#{Integer.to_string(length_indicator, 16)} pattern at position #{pos} (#{num_length_bytes} length bytes)")
        
      _ ->
        nil
    end
  end
  
  defp format_hex(bytes) do
    bytes
    |> Enum.map(&Integer.to_string(&1, 16))
    |> Enum.map(&String.pad_leading(&1, 2, "0"))
    |> Enum.join(" ")
  end
  
  defp try_parsing_strategies(data, filepath) do
    IO.puts("   🧪 Trying different parsing strategies...")
    
    # Strategy 1: Standard TLV parsing
    try_standard_tlv(data)
    
    # Strategy 2: Assume 0x84 means something else
    try_alternative_0x84_meanings(data)
    
    # Strategy 3: Skip problematic bytes and continue
    try_skip_and_continue(data)
    
    # Strategy 4: Look for recognizable patterns
    look_for_ascii_strings(data)
  end
  
  defp try_standard_tlv(data) do
    IO.puts("      Strategy 1: Standard TLV parsing")
    case parse_first_tlv_standard(data) do
      {:ok, tlv} ->
        IO.puts("         ✅ Parsed TLV: Type=#{tlv.type}, Length=#{tlv.length}")
      {:error, reason} ->
        IO.puts("         ❌ Failed: #{reason}")
    end
  end
  
  defp try_alternative_0x84_meanings(data) do
    IO.puts("      Strategy 2: Alternative 0x84 interpretations")
    
    case data do
      <<type::8, 0x84, b1::8, b2::8, b3::8, b4::8, rest::binary>> ->
        # Maybe 0x84 is not a length indicator but part of the value?
        IO.puts("         Hypothesis: 0x84 is not length indicator")
        IO.puts("         Type=#{type}, Value starts with [0x84, #{b1}, #{b2}, #{b3}, #{b4}]")
        
        # Try parsing as if the length is just the next byte
        case rest do
          <<actual_length::8, value_data::binary>> ->
            if byte_size(value_data) >= actual_length do
              <<value::binary-size(actual_length), _::binary>> = value_data
              IO.puts("         ✅ Could be: Type=#{type}, Length=#{actual_length}, Value=#{inspect(value)}")
            else
              IO.puts("         ❌ Not enough data for length #{actual_length}")
            end
          _ ->
            IO.puts("         ❌ No additional length byte found")
        end
        
      _ ->
        IO.puts("         ❌ No 0x84 pattern found")
    end
  end
  
  defp try_skip_and_continue(data) do
    IO.puts("      Strategy 3: Skip problematic bytes")
    
    # Try skipping different amounts and see if we can parse TLVs
    skip_amounts = [1, 2, 3, 4, 5, 6, 7, 8]
    
    Enum.each(skip_amounts, fn skip ->
      if byte_size(data) > skip do
        <<_skip::binary-size(skip), remaining::binary>> = data
        case parse_first_tlv_standard(remaining) do
          {:ok, tlv} ->
            IO.puts("         ✅ After skipping #{skip} bytes: Type=#{tlv.type}, Length=#{tlv.length}")
          {:error, _} ->
            nil  # Don't spam with errors
        end
      end
    end)
  end
  
  defp look_for_ascii_strings(data) do
    IO.puts("      Strategy 4: Look for ASCII strings")
    
    # Look for sequences of printable ASCII
    ascii_sequences = find_ascii_sequences(data)
    
    if Enum.empty?(ascii_sequences) do
      IO.puts("         ❌ No ASCII strings found")
    else
      IO.puts("         ✅ Found ASCII sequences:")
      Enum.each(ascii_sequences, fn {pos, str} ->
        IO.puts("            Position #{pos}: \"#{str}\"")
      end)
    end
  end
  
  defp find_ascii_sequences(data, pos \\ 0, acc \\ [])
  defp find_ascii_sequences(<<>>, _pos, acc), do: Enum.reverse(acc)
  
  defp find_ascii_sequences(data, pos, acc) do
    case extract_ascii_sequence(data) do
      {sequence, rest} when byte_size(sequence) >= 3 ->
        # Found a sequence of at least 3 printable characters
        string = String.trim(sequence)
        find_ascii_sequences(rest, pos + byte_size(sequence), [{pos, string} | acc])
      {_sequence, rest} ->
        # Skip one byte and continue
        <<_::8, remaining::binary>> = data
        find_ascii_sequences(remaining, pos + 1, acc)
    end
  end
  
  defp extract_ascii_sequence(data, acc \\ <<>>)
  defp extract_ascii_sequence(<<>>, acc), do: {acc, <<>>}
  
  defp extract_ascii_sequence(<<byte::8, rest::binary>>, acc) do
    if byte >= 32 and byte <= 126 do
      # Printable ASCII
      extract_ascii_sequence(rest, acc <> <<byte>>)
    else
      # Non-printable, stop sequence
      {acc, <<byte::8, rest::binary>>}
    end
  end
  
  defp parse_first_tlv_standard(<<type::8, length::8, rest::binary>>) when length <= 127 do
    if byte_size(rest) >= length do
      <<value::binary-size(length), _remaining::binary>> = rest
      {:ok, %{type: type, length: length, value: value}}
    else
      {:error, "Not enough data for value (need #{length}, have #{byte_size(rest)})"}
    end
  end
  
  defp parse_first_tlv_standard(<<_type::8, length::8, _rest::binary>>) when length > 127 do
    {:error, "Extended length encoding (0x#{Integer.to_string(length, 16)}) - not handling in standard parse"}
  end
  
  defp parse_first_tlv_standard(_data) do
    {:error, "Insufficient data for TLV header"}
  end
  
  defp show_summary_analysis do
    IO.puts("📊 SUMMARY ANALYSIS")
    IO.puts("=" <> String.duplicate("=", 30))
    IO.puts("")
    IO.puts("🔍 Key Findings:")
    IO.puts("• The 0x84 byte indicates 4-byte extended length encoding")
    IO.puts("• Length bytes [8, 3, 0, 21] = 134,414,357 in big-endian")
    IO.puts("• This length exceeds file sizes by millions of bytes")
    IO.puts("")
    IO.puts("💡 Hypotheses:")
    IO.puts("1. PacketCable uses different length encoding than DOCSIS")
    IO.puts("2. The 0x84 byte has a different meaning in PacketCable context") 
    IO.puts("3. Files are corrupted or truncated")
    IO.puts("4. Length should be interpreted as little-endian or in pairs")
    IO.puts("")
    IO.puts("🎯 Recommended Actions:")
    IO.puts("1. Find PacketCable binary format specification")
    IO.puts("2. Compare with working PacketCable parser implementations")
    IO.puts("3. Test with known-good MTA files from different sources")
    IO.puts("4. Contact vendors for format documentation")
  end
end

# Run the debugger
MTALengthDebugger.run()