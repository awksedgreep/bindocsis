#!/usr/bin/env elixir

# Simple standalone test for Phase 6 Extended TLV Support
# Run with: mix run test_phase6_simple.exs

defmodule Phase6SimpleTest do
  def run do
    IO.puts("🚀 Phase 6 Extended TLV Support - Simple Verification")
    IO.puts("=" <> String.duplicate("=", 55))
    
    test_docsis_specs_module()
    test_extended_tlv_support()
    test_pretty_print_function()
    
    IO.puts("\n✅ Phase 6 Implementation Verified Successfully!")
    IO.puts("🎯 Extended TLV Support (64-255) is Working!")
  end

  defp test_docsis_specs_module do
    IO.puts("\n📋 Testing DocsisSpecs Module...")
    
    # Test DOCSIS 3.0 TLV
    case Bindocsis.DocsisSpecs.get_tlv_info(64) do
      {:ok, tlv_info} ->
        IO.puts("✅ TLV 64: #{tlv_info.name}")
        assert tlv_info.name == "PacketCable Configuration"
        assert tlv_info.introduced_version == "3.0"
      {:error, reason} ->
        IO.puts("❌ TLV 64 failed: #{reason}")
        exit(1)
    end
    
    # Test DOCSIS 3.1 TLV
    case Bindocsis.DocsisSpecs.get_tlv_info(77) do
      {:ok, tlv_info} ->
        IO.puts("✅ TLV 77: #{tlv_info.name}")
        assert tlv_info.name == "DLS Encoding"
        assert tlv_info.introduced_version == "3.1"
      {:error, reason} ->
        IO.puts("❌ TLV 77 failed: #{reason}")
        exit(1)
    end
    
    # Test vendor TLV
    case Bindocsis.DocsisSpecs.get_tlv_info(201) do
      {:ok, tlv_info} ->
        IO.puts("✅ TLV 201: #{tlv_info.name}")
        assert String.contains?(tlv_info.name, "Vendor Specific")
      {:error, reason} ->
        IO.puts("❌ TLV 201 failed: #{reason}")
        exit(1)
    end
    
    # Test version compatibility
    case Bindocsis.DocsisSpecs.get_tlv_info(77, "3.0") do
      {:error, :unsupported_version} ->
        IO.puts("✅ Version compatibility check works")
      {:ok, _} ->
        IO.puts("❌ Version compatibility should prevent 3.1 TLV in 3.0")
        exit(1)
      {:error, reason} ->
        IO.puts("❌ Unexpected error: #{reason}")
        exit(1)
    end
    
    # Test utility functions
    assert Bindocsis.DocsisSpecs.supports_subtlvs?(64) == true
    assert Bindocsis.DocsisSpecs.supports_subtlvs?(68) == false
    assert Bindocsis.DocsisSpecs.get_tlv_value_type(68) == :uint32
    IO.puts("✅ Utility functions work correctly")
  end

  defp test_extended_tlv_support do
    IO.puts("\n🔧 Testing Extended TLV Range Support...")
    
    # Test that all expected TLV ranges are supported
    docsis_30_range = 64..76
    docsis_31_range = 77..85
    vendor_range = 200..255
    
    # Count successful lookups
    docsis_30_count = Enum.count(docsis_30_range, fn type ->
      match?({:ok, _}, Bindocsis.DocsisSpecs.get_tlv_info(type, "3.0"))
    end)
    
    docsis_31_count = Enum.count(docsis_31_range, fn type ->
      match?({:ok, _}, Bindocsis.DocsisSpecs.get_tlv_info(type, "3.1"))
    end)
    
    vendor_count = Enum.count(vendor_range, fn type ->
      match?({:ok, _}, Bindocsis.DocsisSpecs.get_tlv_info(type))
    end)
    
    IO.puts("✅ DOCSIS 3.0 Extensions (64-76): #{docsis_30_count}/13 supported")
    IO.puts("✅ DOCSIS 3.1 Extensions (77-85): #{docsis_31_count}/9 supported")
    IO.puts("✅ Vendor Specific (200-255): #{vendor_count}/56 supported")
    
    # Verify we got the expected counts
    assert docsis_30_count == 13
    assert docsis_31_count == 9
    assert vendor_count == 56
    
    # Test total supported types
    total_types = Bindocsis.DocsisSpecs.get_supported_types("3.1")
    IO.puts("✅ Total TLV types supported in DOCSIS 3.1: #{length(total_types)}")
    assert length(total_types) >= 140  # Should be around 141 types
  end

  defp test_pretty_print_function do
    IO.puts("\n🎨 Testing Pretty Print with Extended TLVs...")
    
    # Capture output for verification
    import ExUnit.CaptureIO
    
    # Test DOCSIS 3.0 TLV (uint32 value)
    output = capture_io(fn ->
      Bindocsis.pretty_print(%{type: 68, length: 4, value: <<0, 0, 0, 100>>})
    end)
    
    assert String.contains?(output, "Type: 68 (Default Upstream Target Buffer)")
    assert String.contains?(output, "Description:")
    assert String.contains?(output, "Value: 100")
    IO.puts("✅ TLV 68 pretty print works")
    
    # Test DOCSIS 3.1 TLV (compound/subtlv)
    output = capture_io(fn ->
      Bindocsis.pretty_print(%{type: 77, length: 8, value: <<1, 2, 3, 4, 5, 6, 7, 8>>})
    end)
    
    assert String.contains?(output, "Type: 77 (DLS Encoding)")
    assert String.contains?(output, "Description:")
    assert String.contains?(output, "SubTLVs:")
    IO.puts("✅ TLV 77 pretty print works")
    
    # Test vendor TLV
    output = capture_io(fn ->
      Bindocsis.pretty_print(%{type: 201, length: 4, value: <<0x12, 0x34, 0x56, 0x78>>})
    end)
    
    assert String.contains?(output, "Type: 201 (Vendor Specific TLV 201)")
    assert String.contains?(output, "Description:")
    IO.puts("✅ TLV 201 pretty print works")
    
    # Test end marker
    output = capture_io(fn ->
      Bindocsis.pretty_print(%{type: 255, length: 0, value: <<>>})
    end)
    
    assert String.contains?(output, "Type: 255 (End-of-Data Marker)")
    assert String.contains?(output, "Value: (end marker)")
    IO.puts("✅ TLV 255 pretty print works")
    
    # Test unknown TLV (should still work gracefully)
    output = capture_io(fn ->
      Bindocsis.pretty_print(%{type: 999, length: 2, value: <<0xAA, 0xBB>>})
    end)
    
    assert String.contains?(output, "Type: 999 (Unknown TLV Type)")
    assert String.contains?(output, "Value (hex):")
    IO.puts("✅ Unknown TLV handling works")
  end

  # Simple assertion helper
  defp assert(true), do: :ok
  defp assert(false) do
    IO.puts("❌ Assertion failed!")
    exit(1)
  end
end

# Run the test
Phase6SimpleTest.run()