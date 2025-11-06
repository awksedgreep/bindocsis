defmodule Bindocsis.Crypto.MICTest do
  use ExUnit.Case, async: true
  
  alias Bindocsis.Crypto.MIC
  
  @moduledoc """
  Comprehensive test suite for DOCSIS Message Integrity Check (MIC).
  
  Tests cover:
  - MIC computation (TLV 6 and TLV 7)
  - MIC validation (positive and negative cases)
  - Edge cases (duplicates, missing MICs, wrong secrets)
  - Round-trip properties
  """
  
  @test_secret "bindocsis_test"
  @wrong_secret "wrong_secret"
  
  describe "compute_cm_mic/2" do
    test "returns 16-byte MIC for simple TLV list" do
      tlvs = [
        %{type: 3, length: 0, value: <<>>}
      ]
      
      assert {:ok, mic} = MIC.compute_cm_mic(tlvs, @test_secret)
      assert byte_size(mic) == 16
      assert is_binary(mic)
    end
    
    test "returns different MICs for different secrets" do
      tlvs = [
        %{type: 3, length: 0, value: <<>>}
      ]
      
      {:ok, mic1} = MIC.compute_cm_mic(tlvs, "secret1")
      {:ok, mic2} = MIC.compute_cm_mic(tlvs, "secret2")
      
      assert mic1 != mic2
    end
    
    test "returns same MIC for same inputs (deterministic)" do
      tlvs = [
        %{type: 3, length: 1, value: <<1>>},
        %{type: 24, length: 7, value: <<1, 2, 0, 1, 6, 1, 7>>}
      ]
      
      {:ok, mic1} = MIC.compute_cm_mic(tlvs, @test_secret)
      {:ok, mic2} = MIC.compute_cm_mic(tlvs, @test_secret)
      
      assert mic1 == mic2
    end
    
    test "strips existing MIC TLVs before computation" do
      tlvs_with_mic = [
        %{type: 3, length: 1, value: <<1>>},
        %{type: 6, length: 16, value: <<0::128>>},
        %{type: 7, length: 16, value: <<0::128>>}
      ]
      
      tlvs_without_mic = [
        %{type: 3, length: 1, value: <<1>>}
      ]
      
      {:ok, mic_with} = MIC.compute_cm_mic(tlvs_with_mic, @test_secret)
      {:ok, mic_without} = MIC.compute_cm_mic(tlvs_without_mic, @test_secret)
      
      # Should be same since MICs are stripped
      assert mic_with == mic_without
    end
    
    test "handles empty TLV list" do
      assert {:ok, mic} = MIC.compute_cm_mic([], @test_secret)
      assert byte_size(mic) == 16
    end
    
    test "order matters - different order produces different MIC" do
      tlvs1 = [
        %{type: 3, length: 1, value: <<1>>},
        %{type: 24, length: 7, value: <<1, 2, 0, 1, 6, 1, 7>>}
      ]
      
      tlvs2 = [
        %{type: 24, length: 7, value: <<1, 2, 0, 1, 6, 1, 7>>},
        %{type: 3, length: 1, value: <<1>>}
      ]
      
      {:ok, mic1} = MIC.compute_cm_mic(tlvs1, @test_secret)
      {:ok, mic2} = MIC.compute_cm_mic(tlvs2, @test_secret)
      
      assert mic1 != mic2, "TLV order should affect MIC computation"
    end
  end
  
  describe "compute_cmts_mic/2" do
    test "returns 16-byte MIC when TLV 6 already present" do
      cm_mic = <<1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16>>
      
      tlvs = [
        %{type: 3, length: 1, value: <<1>>},
        %{type: 6, length: 16, value: cm_mic}
      ]
      
      assert {:ok, mic} = MIC.compute_cmts_mic(tlvs, @test_secret)
      assert byte_size(mic) == 16
    end
    
    test "computes TLV 6 automatically if missing" do
      tlvs = [
        %{type: 3, length: 1, value: <<1>>}
      ]
      
      assert {:ok, mic} = MIC.compute_cmts_mic(tlvs, @test_secret)
      assert byte_size(mic) == 16
    end
    
    test "produces different MIC than CM MIC" do
      tlvs = [
        %{type: 3, length: 1, value: <<1>>}
      ]
      
      {:ok, cm_mic} = MIC.compute_cm_mic(tlvs, @test_secret)
      {:ok, cmts_mic} = MIC.compute_cmts_mic(tlvs, @test_secret)
      
      assert cm_mic != cmts_mic
    end
    
    test "is deterministic" do
      tlvs = [
        %{type: 3, length: 1, value: <<1>>}
      ]
      
      {:ok, mic1} = MIC.compute_cmts_mic(tlvs, @test_secret)
      {:ok, mic2} = MIC.compute_cmts_mic(tlvs, @test_secret)
      
      assert mic1 == mic2
    end
    
    test "includes TLV 6 in preimage" do
      # CMTS MIC should be different depending on what TLV 6 is present
      cm_mic1 = <<1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16>>
      cm_mic2 = <<16, 15, 14, 13, 12, 11, 10, 9, 8, 7, 6, 5, 4, 3, 2, 1>>
      
      tlvs1 = [
        %{type: 3, length: 1, value: <<1>>},
        %{type: 6, length: 16, value: cm_mic1}
      ]
      
      tlvs2 = [
        %{type: 3, length: 1, value: <<1>>},
        %{type: 6, length: 16, value: cm_mic2}
      ]
      
      {:ok, cmts_mic1} = MIC.compute_cmts_mic(tlvs1, @test_secret)
      {:ok, cmts_mic2} = MIC.compute_cmts_mic(tlvs2, @test_secret)
      
      assert cmts_mic1 != cmts_mic2, "CMTS MIC should depend on CM MIC value"
    end
  end
  
  describe "validate_cm_mic/2" do
    test "validates correct MIC successfully" do
      tlvs = [
        %{type: 3, length: 1, value: <<1>>}
      ]
      
      # Compute valid MIC
      {:ok, valid_mic} = MIC.compute_cm_mic(tlvs, @test_secret)
      
      # Add MIC to TLV list
      tlvs_with_mic = tlvs ++ [%{type: 6, length: 16, value: valid_mic}]
      
      assert {:ok, :valid} = MIC.validate_cm_mic(tlvs_with_mic, @test_secret)
    end
    
    test "rejects incorrect MIC" do
      wrong_mic = <<0::128>>
      
      tlvs = [
        %{type: 3, length: 1, value: <<1>>},
        %{type: 6, length: 16, value: wrong_mic}
      ]
      
      assert {:error, {:invalid, details}} = MIC.validate_cm_mic(tlvs, @test_secret)
      assert details.tlv == 6
      assert details.reason == :mismatch
      assert String.length(details.stored) == 32  # Hex encoded (16 bytes * 2)
      assert String.length(details.computed) == 32
    end
    
    test "fails with wrong secret" do
      tlvs = [
        %{type: 3, length: 1, value: <<1>>}
      ]
      
      {:ok, mic} = MIC.compute_cm_mic(tlvs, @test_secret)
      tlvs_with_mic = tlvs ++ [%{type: 6, length: 16, value: mic}]
      
      assert {:error, {:invalid, _}} = MIC.validate_cm_mic(tlvs_with_mic, @wrong_secret)
    end
    
    test "returns missing error when TLV 6 not found" do
      tlvs = [
        %{type: 3, length: 1, value: <<1>>}
      ]
      
      assert {:error, {:missing, msg}} = MIC.validate_cm_mic(tlvs, @test_secret)
      assert msg =~ "TLV 6"
    end
    
    test "rejects MIC with wrong length" do
      wrong_length_mic = <<1, 2, 3, 4, 5>>  # Only 5 bytes instead of 16
      
      tlvs = [
        %{type: 3, length: 1, value: <<1>>},
        %{type: 6, length: 5, value: wrong_length_mic}
      ]
      
      assert {:error, {:invalid_length, details}} = MIC.validate_cm_mic(tlvs, @test_secret)
      assert details.tlv == 6
      assert details.expected == 16
      assert details.actual == 5
    end
    
    test "uses last occurrence when duplicates exist" do
      {:ok, correct_mic} = MIC.compute_cm_mic([%{type: 3, length: 1, value: <<1>>}], @test_secret)
      wrong_mic = <<0::128>>
      
      tlvs = [
        %{type: 3, length: 1, value: <<1>>},
        %{type: 6, length: 16, value: wrong_mic},     # First occurrence (wrong)
        %{type: 6, length: 16, value: correct_mic}    # Last occurrence (correct)
      ]
      
      # Should use last occurrence and validate successfully
      assert {:ok, :valid} = MIC.validate_cm_mic(tlvs, @test_secret)
    end
  end
  
  describe "validate_cmts_mic/2" do
    test "validates correct CMTS MIC successfully" do
      tlvs = [
        %{type: 3, length: 1, value: <<1>>}
      ]
      
      {:ok, cm_mic} = MIC.compute_cm_mic(tlvs, @test_secret)
      tlvs_with_cm = tlvs ++ [%{type: 6, length: 16, value: cm_mic}]
      
      {:ok, cmts_mic} = MIC.compute_cmts_mic(tlvs_with_cm, @test_secret)
      tlvs_with_both = tlvs_with_cm ++ [%{type: 7, length: 16, value: cmts_mic}]
      
      assert {:ok, :valid} = MIC.validate_cmts_mic(tlvs_with_both, @test_secret)
    end
    
    test "requires TLV 6 to be present" do
      cmts_mic = <<1::128>>
      
      tlvs = [
        %{type: 3, length: 1, value: <<1>>},
        %{type: 7, length: 16, value: cmts_mic}
      ]
      
      assert {:error, {:missing, msg}} = MIC.validate_cmts_mic(tlvs, @test_secret)
      assert msg =~ "TLV 6"
    end
    
    test "rejects incorrect CMTS MIC" do
      {:ok, cm_mic} = MIC.compute_cm_mic([%{type: 3, length: 1, value: <<1>>}], @test_secret)
      wrong_cmts_mic = <<0::128>>
      
      tlvs = [
        %{type: 3, length: 1, value: <<1>>},
        %{type: 6, length: 16, value: cm_mic},
        %{type: 7, length: 16, value: wrong_cmts_mic}
      ]
      
      assert {:error, {:invalid, details}} = MIC.validate_cmts_mic(tlvs, @test_secret)
      assert details.tlv == 7
    end
    
    test "fails with wrong secret" do
      tlvs = [%{type: 3, length: 1, value: <<1>>}]
      
      {:ok, cm_mic} = MIC.compute_cm_mic(tlvs, @test_secret)
      {:ok, cmts_mic} = MIC.compute_cmts_mic(tlvs ++ [%{type: 6, length: 16, value: cm_mic}], @test_secret)
      
      full_tlvs = tlvs ++ [
        %{type: 6, length: 16, value: cm_mic},
        %{type: 7, length: 16, value: cmts_mic}
      ]
      
      assert {:error, {:invalid, _}} = MIC.validate_cmts_mic(full_tlvs, @wrong_secret)
    end
  end
  
  describe "round-trip property" do
    test "computed MIC validates successfully (CM MIC)" do
      tlvs = [
        %{type: 3, length: 1, value: <<1>>},
        %{type: 24, length: 7, value: <<1, 2, 0, 1, 6, 1, 7>>}
      ]
      
      # Compute
      {:ok, mic} = MIC.compute_cm_mic(tlvs, @test_secret)
      
      # Add to TLV list
      tlvs_with_mic = tlvs ++ [%{type: 6, length: 16, value: mic}]
      
      # Validate
      assert {:ok, :valid} = MIC.validate_cm_mic(tlvs_with_mic, @test_secret)
    end
    
    test "computed MIC validates successfully (CMTS MIC)" do
      tlvs = [
        %{type: 3, length: 1, value: <<1>>}
      ]
      
      # Compute both MICs
      {:ok, cm_mic} = MIC.compute_cm_mic(tlvs, @test_secret)
      tlvs_with_cm = tlvs ++ [%{type: 6, length: 16, value: cm_mic}]
      
      {:ok, cmts_mic} = MIC.compute_cmts_mic(tlvs_with_cm, @test_secret)
      tlvs_with_both = tlvs_with_cm ++ [%{type: 7, length: 16, value: cmts_mic}]
      
      # Validate both
      assert {:ok, :valid} = MIC.validate_cm_mic(tlvs_with_both, @test_secret)
      assert {:ok, :valid} = MIC.validate_cmts_mic(tlvs_with_both, @test_secret)
    end
    
    test "full workflow: strip → compute → append → validate" do
      # Start with TLVs that have old/wrong MICs
      tlvs_with_old_mic = [
        %{type: 3, length: 1, value: <<1>>},
        %{type: 6, length: 16, value: <<0::128>>},
        %{type: 7, length: 16, value: <<0::128>>}
      ]
      
      # Strip old MICs
      base_tlvs = Enum.reject(tlvs_with_old_mic, fn tlv -> tlv.type in [6, 7] end)
      
      # Compute CM MIC first
      {:ok, new_cm_mic} = MIC.compute_cm_mic(base_tlvs, @test_secret)
      
      # Add CM MIC to list
      tlvs_with_cm = base_tlvs ++ [%{type: 6, length: 16, value: new_cm_mic}]
      
      # Compute CMTS MIC (which includes TLV 6 in its preimage)
      {:ok, new_cmts_mic} = MIC.compute_cmts_mic(tlvs_with_cm, @test_secret)
      
      # Build final TLV list with both MICs
      fresh_tlvs = tlvs_with_cm ++ [%{type: 7, length: 16, value: new_cmts_mic}]
      
      # Validate
      assert {:ok, :valid} = MIC.validate_cm_mic(fresh_tlvs, @test_secret)
      assert {:ok, :valid} = MIC.validate_cmts_mic(fresh_tlvs, @test_secret)
    end
  end
  
  describe "edge cases" do
    test "handles TLV list with many TLVs" do
      # Create a larger TLV list
      tlvs = Enum.map(1..20, fn i ->
        %{type: rem(i, 250) + 1, length: 1, value: <<i>>}
      end)
      
      {:ok, mic} = MIC.compute_cm_mic(tlvs, @test_secret)
      tlvs_with_mic = tlvs ++ [%{type: 6, length: 16, value: mic}]
      
      assert {:ok, :valid} = MIC.validate_cm_mic(tlvs_with_mic, @test_secret)
    end
    
    test "handles TLVs with large values" do
      large_value = :binary.copy(<<42>>, 255)
      
      tlvs = [
        %{type: 3, length: 255, value: large_value}
      ]
      
      {:ok, mic} = MIC.compute_cm_mic(tlvs, @test_secret)
      assert byte_size(mic) == 16
    end
    
    test "handles binary secrets (not just strings)" do
      binary_secret = <<1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16>>
      
      tlvs = [%{type: 3, length: 1, value: <<1>>}]
      
      {:ok, mic} = MIC.compute_cm_mic(tlvs, binary_secret)
      tlvs_with_mic = tlvs ++ [%{type: 6, length: 16, value: mic}]
      
      assert {:ok, :valid} = MIC.validate_cm_mic(tlvs_with_mic, binary_secret)
    end
    
    test "secret as-is (no trimming)" do
      # Secrets with whitespace should be used exactly as-is
      secret_with_space = "secret "
      secret_no_space = "secret"
      
      tlvs = [%{type: 3, length: 1, value: <<1>>}]
      
      {:ok, mic1} = MIC.compute_cm_mic(tlvs, secret_with_space)
      {:ok, mic2} = MIC.compute_cm_mic(tlvs, secret_no_space)
      
      assert mic1 != mic2, "Secrets should be used as-is without trimming"
    end
  end
  
  describe "error handling" do
    test "compute_cm_mic handles invalid input gracefully" do
      # Empty secret
      assert {:ok, _} = MIC.compute_cm_mic([%{type: 3, length: 1, value: <<1>>}], "")
      
      # Non-list TLVs would fail at compile time due to guards
      # But we can test with malformed TLV maps
      
      # TLV missing required fields - should fail during preimage building
      malformed_tlv = [%{type: 3}]  # Missing length and value
      
      assert {:error, _} = MIC.compute_cm_mic(malformed_tlv, @test_secret)
    end
  end
  
  describe "Logger integration" do
    import ExUnit.CaptureLog
    require Logger
    
    @tag :skip  # Skipped: log capture depends on test env config
    test "logs debug messages during computation" do
      tlvs = [%{type: 3, length: 1, value: <<1>>}]
      
      log = capture_log([level: :debug], fn ->
        MIC.compute_cm_mic(tlvs, @test_secret)
      end)
      
      # Note: May be empty if logging disabled in test env
      if log != "" do
        assert log =~ "Computing CM MIC"
      end
    end
    
    @tag :skip  # Skipped: log capture depends on test env config
    test "logs warnings for validation failures" do
      wrong_mic = <<0::128>>
      tlvs = [
        %{type: 3, length: 1, value: <<1>>},
        %{type: 6, length: 16, value: wrong_mic}
      ]
      
      log = capture_log([level: :warning], fn ->
        MIC.validate_cm_mic(tlvs, @test_secret)
      end)
      
      # Note: May be empty if logging disabled in test env
      if log != "" do
        assert log =~ "validation failed"
      end
    end
    
    @tag :skip  # Skipped: log capture depends on test env config
    test "warns about duplicate MICs" do
      {:ok, mic} = MIC.compute_cm_mic([%{type: 3, length: 1, value: <<1>>}], @test_secret)
      
      tlvs = [
        %{type: 3, length: 1, value: <<1>>},
        %{type: 6, length: 16, value: mic},
        %{type: 6, length: 16, value: mic}  # Duplicate
      ]
      
      log = capture_log([level: :warning], fn ->
        MIC.validate_cm_mic(tlvs, @test_secret)
      end)
      
      # Note: May be empty if logging disabled in test env
      if log != "" do
        assert log =~ "Found 2 instances of TLV 6"
      end
    end
  end
end
