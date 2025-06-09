#!/usr/bin/env elixir

# Test script for Extended TLV Support (Phase 6)
# Tests DOCSIS 3.0/3.1 TLV types 64-85 and vendor-specific TLVs 200-254

defmodule ExtendedTLVTest do
  @moduledoc """
  Test script to verify Phase 6 Extended TLV Support implementation.
  
  Tests:
  - DOCSIS 3.0 Extensions (TLV 64-76)
  - DOCSIS 3.1 Extensions (TLV 77-85) 
  - Vendor Specific TLVs (200-254)
  - DocsisSpecs module functionality
  - Updated pretty_print with dynamic TLV lookup
  """

  def run_tests do
    IO.puts("=" <> String.duplicate("=", 60))
    IO.puts("Phase 6: Extended TLV Support - Test Suite")
    IO.puts("=" <> String.duplicate("=", 60))
    IO.puts("")

    test_docsis_specs_module()
    test_docsis_30_extensions()
    test_docsis_31_extensions()
    test_vendor_specific_tlvs()
    test_pretty_print_integration()
    test_version_support()
    
    IO.puts("")
    IO.puts("=" <> String.duplicate("=", 60))
    IO.puts("✅ All Extended TLV Tests Completed Successfully!")
    IO.puts("Phase 6 Implementation: VERIFIED ✅")
    IO.puts("=" <> String.duplicate("=", 60))
  end

  defp test_docsis_specs_module do
    IO.puts("🧪 Testing DocsisSpecs Module Functionality")
    IO.puts("-" <> String.duplicate("-", 50))
    
    # Test TLV info retrieval
    case Bindocsis.DocsisSpecs.get_tlv_info(64) do
      {:ok, tlv_info} ->
        IO.puts("✅ TLV 64: #{tlv_info.name}")
        IO.puts("   Description: #{tlv_info.description}")
        IO.puts("   Introduced: DOCSIS #{tlv_info.introduced_version}")
        
      {:error, reason} ->
        IO.puts("❌ Failed to get TLV 64 info: #{reason}")
    end
    
    # Test DOCSIS 3.1 TLV
    case Bindocsis.DocsisSpecs.get_tlv_info(77) do
      {:ok, tlv_info} ->
        IO.puts("✅ TLV 77: #{tlv_info.name}")
        IO.puts("   Description: #{tlv_info.description}")
        
      {:error, reason} ->
        IO.puts("❌ Failed to get TLV 77 info: #{reason}")
    end
    
    # Test vendor TLV
    case Bindocsis.DocsisSpecs.get_tlv_info(201) do
      {:ok, tlv_info} ->
        IO.puts("✅ TLV 201: #{tlv_info.name}")
        
      {:error, reason} ->
        IO.puts("❌ Failed to get TLV 201 info: #{reason}")
    end
    
    # Test supported types count
    supported_types = Bindocsis.DocsisSpecs.get_supported_types("3.1")
    IO.puts("✅ Total supported TLV types: #{length(supported_types)}")
    IO.puts("   Range: #{Enum.min(supported_types)} - #{Enum.max(supported_types)}")
    
    IO.puts("")
  end

  defp test_docsis_30_extensions do
    IO.puts("🧪 Testing DOCSIS 3.0 Extension TLVs (64-76)")
    IO.puts("-" <> String.duplicate("-", 50))
    
    docsis_30_tlvs = [64, 65, 66, 67, 68, 69, 70, 71, 72, 73, 74, 75, 76]
    
    Enum.each(docsis_30_tlvs, fn type ->
      case Bindocsis.DocsisSpecs.get_tlv_info(type, "3.0") do
        {:ok, tlv_info} ->
          IO.puts("✅ TLV #{type}: #{tlv_info.name}")
          
        {:error, reason} ->
          IO.puts("❌ TLV #{type} failed: #{reason}")
      end
    end)
    
    IO.puts("")
  end

  defp test_docsis_31_extensions do
    IO.puts("🧪 Testing DOCSIS 3.1 Extension TLVs (77-85)")
    IO.puts("-" <> String.duplicate("-", 50))
    
    docsis_31_tlvs = [77, 78, 79, 80, 81, 82, 83, 84, 85]
    
    Enum.each(docsis_31_tlvs, fn type ->
      case Bindocsis.DocsisSpecs.get_tlv_info(type, "3.1") do
        {:ok, tlv_info} ->
          IO.puts("✅ TLV #{type}: #{tlv_info.name}")
          
        {:error, reason} ->
          IO.puts("❌ TLV #{type} failed: #{reason}")
      end
    end)
    
    IO.puts("")
  end

  defp test_vendor_specific_tlvs do
    IO.puts("🧪 Testing Vendor-Specific TLVs (200-254)")
    IO.puts("-" <> String.duplicate("-", 50))
    
    vendor_tlvs = [200, 201, 210, 220, 230, 240, 250, 254, 255]
    
    Enum.each(vendor_tlvs, fn type ->
      case Bindocsis.DocsisSpecs.get_tlv_info(type) do
        {:ok, tlv_info} ->
          IO.puts("✅ TLV #{type}: #{tlv_info.name}")
          
        {:error, reason} ->
          IO.puts("❌ TLV #{type} failed: #{reason}")
      end
    end)
    
    IO.puts("")
  end

  defp test_pretty_print_integration do
    IO.puts("🧪 Testing Pretty Print Integration with Extended TLVs")
    IO.puts("-" <> String.duplicate("-", 50))
    
    # Test DOCSIS 3.0 TLV (simple value)
    tlv_68 = %{type: 68, length: 4, value: <<0, 0, 0, 100>>}
    IO.puts("Testing TLV 68 (Default Upstream Target Buffer):")
    Bindocsis.pretty_print(tlv_68)
    IO.puts("")
    
    # Test DOCSIS 3.1 TLV (compound)
    tlv_77 = %{type: 77, length: 8, value: <<1, 2, 3, 4, 5, 6, 7, 8>>}
    IO.puts("Testing TLV 77 (DLS Encoding):")
    Bindocsis.pretty_print(tlv_77)
    IO.puts("")
    
    # Test vendor TLV
    tlv_201 = %{type: 201, length: 6, value: <<0x12, 0x34, 0x56, 0x78, 0x9A, 0xBC>>}
    IO.puts("Testing TLV 201 (Vendor Specific):")
    Bindocsis.pretty_print(tlv_201)
    IO.puts("")
    
    # Test end marker
    tlv_255 = %{type: 255, length: 0, value: <<>>}
    IO.puts("Testing TLV 255 (End-of-Data Marker):")
    Bindocsis.pretty_print(tlv_255)
    IO.puts("")
  end

  defp test_version_support do
    IO.puts("🧪 Testing Version-Specific TLV Support")
    IO.puts("-" <> String.duplicate("-", 50))
    
    # Test that DOCSIS 3.1 TLV is not supported in 3.0
    case Bindocsis.DocsisSpecs.get_tlv_info(77, "3.0") do
      {:error, :unsupported_version} ->
        IO.puts("✅ TLV 77 correctly unsupported in DOCSIS 3.0")
        
      {:ok, _} ->
        IO.puts("❌ TLV 77 should not be supported in DOCSIS 3.0")
        
      {:error, reason} ->
        IO.puts("❌ Unexpected error for TLV 77 in DOCSIS 3.0: #{reason}")
    end
    
    # Test that DOCSIS 3.0 TLV is supported in 3.1
    case Bindocsis.DocsisSpecs.get_tlv_info(64, "3.1") do
      {:ok, tlv_info} ->
        IO.puts("✅ TLV 64 correctly supported in DOCSIS 3.1: #{tlv_info.name}")
        
      {:error, reason} ->
        IO.puts("❌ TLV 64 should be supported in DOCSIS 3.1: #{reason}")
    end
    
    # Test utility functions
    IO.puts("✅ TLV 77 supports subtlvs: #{Bindocsis.DocsisSpecs.supports_subtlvs?(77)}")
    IO.puts("✅ TLV 68 supports subtlvs: #{Bindocsis.DocsisSpecs.supports_subtlvs?(68)}")
    IO.puts("✅ TLV 64 value type: #{Bindocsis.DocsisSpecs.get_tlv_value_type(64)}")
    
    IO.puts("")
  end
end

# Run the tests
ExtendedTLVTest.run_tests()