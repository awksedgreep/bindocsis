#!/usr/bin/env elixir

# Creates a minimal synthetic DOCSIS file that reproduces the 0xFE length edge case

defmodule SimpleEdgeCase do
  def create_file do
    # Simple file with just the critical 0xFE edge case
    binary_data = 
      # Standard TLV
      <<3, 1, 1>> <>                    # WebAccessControl enabled
      
      # The critical edge case: TLV with 0xFE (254) length
      create_tlv_with_fe_length() <>
      
      # Another simple TLV
      <<1, 4, 35, 57, 241, 192>> <>    # DownstreamFrequency 591MHz
      
      # Terminator
      <<255>>
    
    File.write!("test/fixtures/simple_edge_case.cm", binary_data)
    
    IO.puts("✅ Created simple edge case file: test/fixtures/simple_edge_case.cm")
    IO.puts("📊 File size: #{byte_size(binary_data)} bytes")
    IO.puts("🔍 Contains 0xFE length edge case that caused production failure")
  end
  
  defp create_tlv_with_fe_length do
    # Create a TLV with exactly 254 bytes of data (0xFE length)
    type = 43  # VendorSpecific TLV
    length = 0xFE  # 254 bytes - the critical edge case
    
    # Create exactly 254 bytes of data
    value = :binary.copy(<<0x42>>, 254)  # "B" repeated 254 times
    
    <<type, length>> <> value
  end
end

SimpleEdgeCase.create_file()