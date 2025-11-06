defmodule Bindocsis.GeneratorMicIntegrationTest do
  use ExUnit.Case, async: true
  
  alias Bindocsis.Crypto.MIC
  
  @moduledoc """
  Tests for generator-level MIC computation integration.
  
  Tests the add_mic and shared_secret options in:
  - Bindocsis.generate/2
  - Bindocsis.Generators.BinaryGenerator.generate/2
  """
  
  @test_secret "bindocsis_test"
  
  describe "Bindocsis.Generators.BinaryGenerator.generate/2 with MIC" do
    test "generates binary with valid MIC TLVs when add_mic is true" do
      tlvs = [%{type: 3, length: 1, value: <<1>>}]
      
      assert {:ok, binary} = Bindocsis.Generators.BinaryGenerator.generate(tlvs,
        add_mic: true,
        shared_secret: @test_secret
      )
      
      # Parse the binary back to verify MIC TLVs were added
      assert {:ok, parsed_tlvs} = Bindocsis.parse(binary, format: :binary, enhanced: false)
      
      # Should have original TLV + TLV 6 + TLV 7
      assert length(parsed_tlvs) == 3
      
      # Verify TLV 6 exists
      tlv6 = Enum.find(parsed_tlvs, fn tlv -> tlv.type == 6 end)
      assert tlv6
      assert tlv6.length == 16
      
      # Verify TLV 7 exists
      tlv7 = Enum.find(parsed_tlvs, fn tlv -> tlv.type == 7 end)
      assert tlv7
      assert tlv7.length == 16
    end
    
    test "generated MICs validate correctly" do
      tlvs = [%{type: 3, length: 1, value: <<1>>}]
      
      {:ok, binary} = Bindocsis.Generators.BinaryGenerator.generate(tlvs,
        add_mic: true,
        shared_secret: @test_secret
      )
      
      # Parse and validate
      {:ok, parsed_tlvs} = Bindocsis.parse(binary, format: :binary, enhanced: false)
      
      # Validate CM MIC
      assert {:ok, :valid} = MIC.validate_cm_mic(parsed_tlvs, @test_secret)
      
      # Validate CMTS MIC
      assert {:ok, :valid} = MIC.validate_cmts_mic(parsed_tlvs, @test_secret)
    end
    
    test "strips existing MIC TLVs before adding new ones" do
      # Start with TLVs that have old MIC values
      old_mic = <<0::128>>
      tlvs = [
        %{type: 3, length: 1, value: <<1>>},
        %{type: 6, length: 16, value: old_mic},
        %{type: 7, length: 16, value: old_mic}
      ]
      
      {:ok, binary} = Bindocsis.Generators.BinaryGenerator.generate(tlvs,
        add_mic: true,
        shared_secret: @test_secret
      )
      
      {:ok, parsed_tlvs} = Bindocsis.parse(binary, format: :binary, enhanced: false)
      
      # Should still have 3 TLVs (base + new TLV 6 + new TLV 7)
      assert length(parsed_tlvs) == 3
      
      # New MICs should validate
      assert {:ok, :valid} = MIC.validate_cm_mic(parsed_tlvs, @test_secret)
      assert {:ok, :valid} = MIC.validate_cmts_mic(parsed_tlvs, @test_secret)
    end
    
    test "does not add MIC when add_mic is false" do
      tlvs = [%{type: 3, length: 1, value: <<1>>}]
      
      {:ok, binary} = Bindocsis.Generators.BinaryGenerator.generate(tlvs,
        add_mic: false
      )
      
      {:ok, parsed_tlvs} = Bindocsis.parse(binary, format: :binary, enhanced: false)
      
      # Should only have the original TLV
      assert length(parsed_tlvs) == 1
      assert hd(parsed_tlvs).type == 3
    end
    
    test "does not add MIC when shared_secret is nil" do
      tlvs = [%{type: 3, length: 1, value: <<1>>}]
      
      {:ok, binary} = Bindocsis.Generators.BinaryGenerator.generate(tlvs,
        add_mic: true,
        shared_secret: nil
      )
      
      {:ok, parsed_tlvs} = Bindocsis.parse(binary, format: :binary, enhanced: false)
      
      # Should only have the original TLV
      assert length(parsed_tlvs) == 1
    end
    
    test "works with multiple TLVs" do
      tlvs = [
        %{type: 3, length: 1, value: <<1>>},
        %{type: 24, length: 7, value: <<1, 2, 0, 1, 6, 1, 7>>},
        %{type: 43, length: 254, value: :binary.copy(<<42>>, 254)}
      ]
      
      {:ok, binary} = Bindocsis.Generators.BinaryGenerator.generate(tlvs,
        add_mic: true,
        shared_secret: @test_secret
      )
      
      {:ok, parsed_tlvs} = Bindocsis.parse(binary, format: :binary, enhanced: false)
      
      # Should have 3 original + 2 MIC TLVs
      assert length(parsed_tlvs) == 5
      
      # Validate MICs
      assert {:ok, :valid} = MIC.validate_cm_mic(parsed_tlvs, @test_secret)
      assert {:ok, :valid} = MIC.validate_cmts_mic(parsed_tlvs, @test_secret)
    end
  end
  
  describe "Bindocsis.generate/2 with MIC" do
    test "generates binary with MIC via main API" do
      tlvs = [%{type: 3, length: 1, value: <<1>>}]
      
      assert {:ok, binary} = Bindocsis.generate(tlvs,
        format: :binary,
        add_mic: true,
        shared_secret: @test_secret
      )
      
      {:ok, parsed_tlvs} = Bindocsis.parse(binary, format: :binary, enhanced: false)
      
      assert length(parsed_tlvs) == 3
      assert {:ok, :valid} = MIC.validate_cm_mic(parsed_tlvs, @test_secret)
      assert {:ok, :valid} = MIC.validate_cmts_mic(parsed_tlvs, @test_secret)
    end
    
    test "MIC generation only works with binary format" do
      tlvs = [%{type: 3, length: 1, value: <<1>>}]
      
      # JSON format - add_mic option is ignored
      {:ok, json} = Bindocsis.generate(tlvs,
        format: :json,
        add_mic: true,
        shared_secret: @test_secret
      )
      
      # JSON should not contain MIC TLVs
      assert is_binary(json)
      refute String.contains?(json, "\"type\":6")
      refute String.contains?(json, "\"type\":7")
    end
  end
  
  describe "end-to-end workflows" do
    test "parse JSON → generate binary with MIC → validate" do
      json_input = ~s({
        "tlvs": [
          {"type": 3, "length": 1, "formatted_value": "1"}
        ]
      })
      
      # Parse JSON
      {:ok, tlvs} = Bindocsis.parse(json_input, format: :json, enhanced: false)
      
      # Generate binary with MIC
      {:ok, binary} = Bindocsis.generate(tlvs,
        format: :binary,
        add_mic: true,
        shared_secret: @test_secret
      )
      
      # Parse binary and validate
      {:ok, parsed_tlvs} = Bindocsis.parse(binary, format: :binary, enhanced: false)
      
      assert {:ok, :valid} = MIC.validate_cm_mic(parsed_tlvs, @test_secret)
      assert {:ok, :valid} = MIC.validate_cmts_mic(parsed_tlvs, @test_secret)
    end
    
    test "parse binary → modify → regenerate with MIC → validate" do
      # Start with a simple binary
      original_binary = <<3, 1, 1, 0xFF>>
      
      # Parse
      {:ok, tlvs} = Bindocsis.parse(original_binary, format: :binary, enhanced: false)
      
      # Modify (add a TLV)
      modified_tlvs = tlvs ++ [%{type: 24, length: 7, value: <<1, 2, 0, 1, 6, 1, 7>>}]
      
      # Regenerate with MIC
      {:ok, new_binary} = Bindocsis.generate(modified_tlvs,
        format: :binary,
        add_mic: true,
        shared_secret: @test_secret
      )
      
      # Parse and validate
      {:ok, final_tlvs} = Bindocsis.parse(new_binary, format: :binary, enhanced: false)
      
      assert length(final_tlvs) == 4  # 2 original + 2 MIC
      assert {:ok, :valid} = MIC.validate_cm_mic(final_tlvs, @test_secret)
      assert {:ok, :valid} = MIC.validate_cmts_mic(final_tlvs, @test_secret)
    end
    
    test "round-trip: parse with validation → regenerate with MIC → validate again" do
      tlvs = [%{type: 3, length: 1, value: <<1>>}]
      
      # Generate with MIC
      {:ok, binary1} = Bindocsis.generate(tlvs,
        format: :binary,
        add_mic: true,
        shared_secret: @test_secret
      )
      
      # Parse with validation
      {:ok, parsed_tlvs} = Bindocsis.parse(binary1,
        format: :binary,
        validate_mic: true,
        shared_secret: @test_secret,
        enhanced: false
      )
      
      # Strip MICs and regenerate
      base_tlvs = Enum.reject(parsed_tlvs, fn tlv -> tlv.type in [6, 7] end)
      
      {:ok, binary2} = Bindocsis.generate(base_tlvs,
        format: :binary,
        add_mic: true,
        shared_secret: @test_secret
      )
      
      # Parse and validate again
      {:ok, final_tlvs} = Bindocsis.parse(binary2,
        format: :binary,
        validate_mic: true,
        shared_secret: @test_secret,
        strict: true,
        enhanced: false
      )
      
      assert length(final_tlvs) == 3
    end
  end
  
  describe "error handling" do
    test "returns error when MIC computation fails" do
      # Malformed TLV that will cause MIC computation to fail
      malformed_tlv = [%{type: 3}]  # Missing length and value
      
      assert {:error, msg} = Bindocsis.Generators.BinaryGenerator.generate(malformed_tlv,
        add_mic: true,
        shared_secret: @test_secret,
        validate: false  # Skip validation to reach MIC computation
      )
      
      assert msg =~ "MIC generation error"
    end
  end
end
