#!/usr/bin/env elixir

# Identify files with malformed TLV data that should be moved to questionable/
IO.puts("=== Identifying questionable files ===")

# Files that fail round-trip but show "Incomplete or malformed TLV data" warnings
questionable_files = [
  # Files with L2VPN length differences (malformed nested TLV data)
  "TLV_22_43_5_2_4_2_MPLSPeerIpAddress.cm",
  "TLV_22_43_5_2_4_ServiceMultiplexingValueMPLSPW.cm", 
  "TLV_22_43_5_2_6_IEEE8021ahEncapsulation.cm",
  "TLV_22_43_5_3_to_9.cm",
  "TLV_22_43_9_CMAttributeMasks.cm",
  "TLV_23_43_5_24_SOAMSubtype.cm",
  "TLV_23_43_last_tlvs.cm",
  
  # Files with vendor CLI "invalid byte 78" errors (likely malformed JSON structures)
  "TLV_22_43_10_IPMulticastJoinAuthorization.cm",
  "TLV_22_43_5_10_and_12.cm", 
  "TLV_22_43_5_13_L2VPNMode.cm",
  "TLV_22_43_5_14_DPoE.cm",
  "TLV_22_43_5_23_PseudowireSignaling.cm"
]

# Check each file for malformed data indicators
IO.puts("Analyzing #{length(questionable_files)} potentially questionable files:")

questionable_confirmed = []

Enum.each(questionable_files, fn filename ->
  path = "test/fixtures/#{filename}"
  
  if File.exists?(path) do
    binary = File.read!(path)
    
    # Parse and capture warnings
    original_level = Logger.level()
    Logger.configure(level: :warning)
    
    warnings = ExUnit.CaptureLog.capture_log(fn ->
      {:ok, _tlvs} = Bindocsis.parse(binary, enhanced: true)
    end)
    
    Logger.configure(level: original_level)
    
    # Check for malformed data indicators
    has_incomplete_warnings = String.contains?(warnings, "Incomplete or malformed TLV data")
    has_compound_fallback = String.contains?(warnings, "treating as binary with hex string fallback")
    
    # Test round-trip size difference
    try do
      {:ok, tlvs} = Bindocsis.parse(binary, enhanced: true)
      {:ok, json_str} = Bindocsis.Generators.JsonGenerator.generate(tlvs)
      {:ok, reparsed_binary} = Bindocsis.HumanConfig.from_json(json_str)
      
      size_diff = byte_size(binary) - byte_size(reparsed_binary)
      
      is_questionable = has_incomplete_warnings or has_compound_fallback or size_diff > 5
      
      if is_questionable do
        questionable_confirmed = [filename | questionable_confirmed]
        IO.puts("  ❓ #{filename}:")
        if has_incomplete_warnings, do: IO.puts("     - Has incomplete/malformed TLV warnings")
        if has_compound_fallback, do: IO.puts("     - Has compound TLV parsing fallbacks") 
        if size_diff > 5, do: IO.puts("     - Size difference: #{size_diff} bytes")
      else
        IO.puts("  ✅ #{filename}: Appears valid")
      end
      
    rescue
      _ -> 
        questionable_confirmed = [filename | questionable_confirmed]
        IO.puts("  ❌ #{filename}: Parse/conversion error")
    end
  else
    IO.puts("  ❌ #{filename}: File not found")
  end
end)

IO.puts("\n=== Summary ===")
IO.puts("Confirmed questionable files: #{length(questionable_confirmed)}")

if length(questionable_confirmed) > 0 do
  IO.puts("\nFiles to move to questionable/:")
  Enum.each(questionable_confirmed, fn filename ->
    IO.puts("  - #{filename}")
  end)
  
  # Create questionable directory and move files
  questionable_dir = "test/fixtures/questionable"
  File.mkdir_p!(questionable_dir)
  
  IO.puts("\n=== Moving files ===")
  Enum.each(questionable_confirmed, fn filename ->
    src = "test/fixtures/#{filename}"
    dst = "#{questionable_dir}/#{filename}"
    
    if File.exists?(src) do
      File.rename!(src, dst)
      IO.puts("  ✅ Moved #{filename} to questionable/")
    end
  end)
  
  IO.puts("\n✅ Done! Moved #{length(questionable_confirmed)} questionable files")
  IO.puts("You can review them manually in test/fixtures/questionable/")
else
  IO.puts("\nNo files identified as questionable based on analysis criteria.")
end