#!/usr/bin/env elixir

# Creates a synthetic DOCSIS file that reproduces the 0xFE length edge case
# without any sensitive production data

defmodule SyntheticEdgeCase do
  def create_file do
    # Reproduce the key edge case: 0xFE as a single-byte length (254 bytes)
    # This was the bug that caused production parsing to fail
    
    # Build the binary data piece by piece to avoid structural issues
    binary_data = 
      # Standard TLVs
      <<3, 1, 1>> <>                    # WebAccessControl enabled
      <<1, 4, 35, 57, 241, 192>> <>    # DownstreamFrequency 591MHz
      <<4, 4, 192, 168, 1, 100>> <>    # IPAddress
      <<5, 4, 255, 255, 255, 0>> <>    # SubnetMask
      
      # The critical edge case: TLV with 0xFE (254) length
      # This should be treated as a single-byte length, NOT as extended length indicator
      create_tlv_with_fe_length() <>
      
      # Service flows to make it more realistic
      <<24, 12,                      # DownstreamServiceFlow
        1, 2, 0, 1,                  # ServiceFlowReference 1
        6, 1, 7,                     # QoSParameterSetType 7  
        7, 4, 0, 0, 39, 16>> <>      # MaxTrafficRate 10000 kbps
        
      <<25, 9,                       # UpstreamServiceFlow
        1, 2, 0, 2,                  # ServiceFlowReference 2
        6, 1, 7,                     # QoSParameterSetType 7
        7, 2, 0, 100>> <>            # MaxTrafficRate 100 kbps
      
      # Terminator
      <<255>>
    
    File.write!("test/fixtures/synthetic_edge_case.cm", binary_data)
    
    IO.puts("✅ Created synthetic edge case file: test/fixtures/synthetic_edge_case.cm")
    IO.puts("📊 File size: #{byte_size(binary_data)} bytes")
    IO.puts("🔍 Contains 0xFE length edge case that caused production failure")
  end
  
  defp create_tlv_with_fe_length do
    # Create a TLV with exactly 254 bytes of data (0xFE length)
    # This reproduces the edge case where 0xFE should be treated as 
    # single-byte length, not as extended length indicator
    
    type = 43  # VendorSpecific TLV
    length = 0xFE  # 254 bytes - the critical edge case
    
    # Create 254 bytes of synthetic vendor data (non-sensitive)
    vendor_id = <<0x00, 0x00, 0x0B, 0xBE>>  # Synthetic vendor ID (4 bytes)
    vendor_data = :binary.copy(<<0x42>>, 250)  # Deterministic padding "B" repeated (250 bytes)
    
    value = vendor_id <> vendor_data  # Total: 254 bytes
    
    # Verify we have exactly 254 bytes
    if byte_size(value) != 254 do
      raise "Value size mismatch: expected 254, got #{byte_size(value)}"
    end
    
    <<type, length>> <> value
  end
end

SyntheticEdgeCase.create_file()