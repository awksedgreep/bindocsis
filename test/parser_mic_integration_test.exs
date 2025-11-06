defmodule Bindocsis.ParserMicIntegrationTest do
  use ExUnit.Case, async: true
  
  alias Bindocsis.Crypto.MIC
  
  @moduledoc """
  Tests for parser-level MIC validation integration.
  
  Tests the validate_mic, shared_secret, and strict options in:
  - Bindocsis.parse/2
  - Bindocsis.parse_file/2
  """
  
  @test_secret "bindocsis_test"
  @wrong_secret "wrong_secret"
  
  describe "Bindocsis.parse/2 with MIC validation" do
    test "parses binary with valid MIC successfully" do
      # Create TLVs with valid MIC
      base_tlvs = [%{type: 3, length: 1, value: <<1>>}]
      {:ok, cm_mic} = MIC.compute_cm_mic(base_tlvs, @test_secret)
      
      # Build binary with MIC
      binary = <<3, 1, 1, 6, 16>> <> cm_mic <> <<0xFF>>
      
      # Parse with validation
      assert {:ok, parsed_tlvs} = Bindocsis.parse(binary, 
        format: :binary,
        validate_mic: true,
        shared_secret: @test_secret,
        enhanced: false
      )
      
      assert length(parsed_tlvs) == 2
      assert Enum.find(parsed_tlvs, fn tlv -> tlv.type == 6 end)
    end
    
    test "fails in strict mode with invalid MIC" do
      # Create TLVs with wrong MIC
      wrong_mic = <<0::128>>
      binary = <<3, 1, 1, 6, 16>> <> wrong_mic <> <<0xFF>>
      
      # Parse with strict validation
      assert {:error, {:mic_validation_failed, msg}} = Bindocsis.parse(binary,
        format: :binary,
        validate_mic: true,
        shared_secret: @test_secret,
        strict: true,
        enhanced: false
      )
      
      assert msg =~ "Invalid MIC"
    end
    
    test "warns in non-strict mode with invalid MIC" do
      wrong_mic = <<0::128>>
      binary = <<3, 1, 1, 6, 16>> <> wrong_mic <> <<0xFF>>
      
      assert {:ok, parsed_tlvs} = Bindocsis.parse(binary,
        format: :binary,
        validate_mic: true,
        shared_secret: @test_secret,
        strict: false,
        enhanced: false
      )
      
      # Should parse successfully but attach metadata
      assert length(parsed_tlvs) == 2
      
      # Check metadata on TLV 6
      tlv6 = Enum.find(parsed_tlvs, fn tlv -> tlv.type == 6 end)
      assert tlv6.mic_validation.status == :invalid
    end
    
    test "skips validation when validate_mic is false" do
      wrong_mic = <<0::128>>
      binary = <<3, 1, 1, 6, 16>> <> wrong_mic <> <<0xFF>>
      
      # Should parse without validation
      assert {:ok, parsed_tlvs} = Bindocsis.parse(binary,
        format: :binary,
        validate_mic: false,
        enhanced: false
      )
      
      assert length(parsed_tlvs) == 2
      
      # No metadata attached
      tlv6 = Enum.find(parsed_tlvs, fn tlv -> tlv.type == 6 end)
      refute Map.has_key?(tlv6, :mic_validation)
    end
    
    test "skips validation when shared_secret is nil" do
      wrong_mic = <<0::128>>
      binary = <<3, 1, 1, 6, 16>> <> wrong_mic <> <<0xFF>>
      
      # Should parse without validation (no secret provided)
      assert {:ok, parsed_tlvs} = Bindocsis.parse(binary,
        format: :binary,
        validate_mic: true,
        shared_secret: nil,
        enhanced: false
      )
      
      assert length(parsed_tlvs) == 2
    end
    
    test "validates both CM and CMTS MIC when both present" do
      base_tlvs = [%{type: 3, length: 1, value: <<1>>}]
      
      {:ok, cm_mic} = MIC.compute_cm_mic(base_tlvs, @test_secret)
      base_with_cm = base_tlvs ++ [%{type: 6, length: 16, value: cm_mic}]
      
      {:ok, cmts_mic} = MIC.compute_cmts_mic(base_with_cm, @test_secret)
      
      # Build binary with both MICs
      binary = <<3, 1, 1, 6, 16>> <> cm_mic <> <<7, 16>> <> cmts_mic <> <<0xFF>>
      
      assert {:ok, parsed_tlvs} = Bindocsis.parse(binary,
        format: :binary,
        validate_mic: true,
        shared_secret: @test_secret,
        enhanced: false
      )
      
      assert length(parsed_tlvs) == 3
    end
    
    test "fails when TLV 7 present without TLV 6" do
      # TLV 7 alone is invalid (requires TLV 6)
      cmts_mic = <<0::128>>
      binary = <<3, 1, 1, 7, 16>> <> cmts_mic <> <<0xFF>>
      
      assert {:error, {:mic_validation_failed, msg}} = Bindocsis.parse(binary,
        format: :binary,
        validate_mic: true,
        shared_secret: @test_secret,
        strict: true,
        enhanced: false
      )
      
      assert msg =~ "TLV 7"
      assert msg =~ "TLV 6"
      assert msg =~ "missing"
    end
    
    test "works with no MIC TLVs present" do
      binary = <<3, 1, 1, 0xFF>>
      
      assert {:ok, parsed_tlvs} = Bindocsis.parse(binary,
        format: :binary,
        validate_mic: true,
        shared_secret: @test_secret,
        enhanced: false
      )
      
      assert length(parsed_tlvs) == 1
    end
  end
  
  describe "Bindocsis.parse/2 with wrong secret" do
    test "fails with wrong secret in strict mode" do
      base_tlvs = [%{type: 3, length: 1, value: <<1>>}]
      {:ok, cm_mic} = MIC.compute_cm_mic(base_tlvs, @test_secret)
      
      binary = <<3, 1, 1, 6, 16>> <> cm_mic <> <<0xFF>>
      
      # Use wrong secret
      assert {:error, {:mic_validation_failed, _msg}} = Bindocsis.parse(binary,
        format: :binary,
        validate_mic: true,
        shared_secret: @wrong_secret,
        strict: true,
        enhanced: false
      )
    end
    
    test "warns with wrong secret in non-strict mode" do
      base_tlvs = [%{type: 3, length: 1, value: <<1>>}]
      {:ok, cm_mic} = MIC.compute_cm_mic(base_tlvs, @test_secret)
      
      binary = <<3, 1, 1, 6, 16>> <> cm_mic <> <<0xFF>>
      
      assert {:ok, _parsed_tlvs} = Bindocsis.parse(binary,
        format: :binary,
        validate_mic: true,
        shared_secret: @wrong_secret,
        strict: false,
        enhanced: false
      )
      
      # Successfully parses in non-strict mode
    end
  end
  
  describe "Bindocsis.parse/2 with enrichment and MIC validation" do
    test "works with enhanced=true (default)" do
      base_tlvs = [%{type: 3, length: 1, value: <<1>>}]
      {:ok, cm_mic} = MIC.compute_cm_mic(base_tlvs, @test_secret)
      
      binary = <<3, 1, 1, 6, 16>> <> cm_mic <> <<0xFF>>
      
      # With enrichment (default)
      assert {:ok, parsed_tlvs} = Bindocsis.parse(binary,
        format: :binary,
        validate_mic: true,
        shared_secret: @test_secret
      )
      
      assert length(parsed_tlvs) == 2
      
      # Check that enrichment happened (tlvs have metadata)
      tlv = List.first(parsed_tlvs)
      assert Map.has_key?(tlv, :name) or Map.has_key?(tlv, :description)
    end
  end
  
  describe "edge cases" do
    test "handles invalid MIC length" do
      # TLV 6 with wrong length (5 instead of 16)
      binary = <<3, 1, 1, 6, 5, 1, 2, 3, 4, 5, 0xFF>>
      
      assert {:error, {:mic_validation_failed, msg}} = Bindocsis.parse(binary,
        format: :binary,
        validate_mic: true,
        shared_secret: @test_secret,
        strict: true,
        enhanced: false
      )
      
      assert msg =~ "length"
    end
    
    test "handles duplicate MIC TLVs" do
      base_tlvs = [%{type: 3, length: 1, value: <<1>>}]
      {:ok, cm_mic} = MIC.compute_cm_mic(base_tlvs, @test_secret)
      wrong_mic = <<0::128>>
      
      # Two TLV 6s: first wrong, second correct (uses last)
      binary = <<3, 1, 1, 6, 16>> <> wrong_mic <> <<6, 16>> <> cm_mic <> <<0xFF>>
      
      assert {:ok, _parsed_tlvs} = Bindocsis.parse(binary,
        format: :binary,
        validate_mic: true,
        shared_secret: @test_secret,
        enhanced: false
      )
      
      # MIC module uses last occurrence and validates successfully
    end
  end
end
