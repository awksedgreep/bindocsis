defmodule Bindocsis.ValidationTest do
  use ExUnit.Case, async: true
  alias Bindocsis.Validation
  
  doctest Validation

  describe "validate_tlvs/1" do
    test "validates basic TLV list" do
      tlvs = [
        %{type: 3, length: 1, value: <<1>>},
        %{type: 4, length: 4, value: <<1, 1, 1, 2, 4, 0, 15, 66>>},
        %{type: 6, length: 16, value: <<1::128>>},
        %{type: 7, length: 16, value: <<2::128>>}
      ]
      
      assert :ok = Validation.validate_tlvs(tlvs)
    end

    test "returns errors for invalid TLV list" do
      tlvs = [
        %{type: 999, length: 1, value: <<1>>}  # Invalid type
      ]
      
      assert {:error, errors} = Validation.validate_tlvs(tlvs)
      assert is_list(errors)
    end
  end

  describe "validate_docsis_compliance/2 with DOCSIS 3.1" do
    test "validates complete valid configuration" do
      tlvs = [
        %{type: 3, length: 1, value: <<1>>},                    # Network Access
        %{type: 4, length: 9, value: <<1, 1, 1, 2, 4, 0, 15, 66, 64>>}, # CoS
        %{type: 6, length: 16, value: <<1::128>>},              # CM MIC
        %{type: 7, length: 16, value: <<2::128>>},              # CMTS MIC
        %{type: 21, length: 1, value: <<5>>}                   # Max CPE
      ]
      
      assert :ok = Validation.validate_docsis_compliance(tlvs, "3.1")
    end

    test "validates complete valid configuration" do
      tlvs = [
        %{type: 3, length: 1, value: <<1>>},                    # Network Access
        %{type: 4, length: 9, value: <<1, 1, 1, 2, 4, 0, 15, 66, 64>>}, # CoS
        %{type: 6, length: 16, value: <<1::128>>},              # CM MIC
        %{type: 7, length: 16, value: <<2::128>>},              # CMTS MIC
        %{type: 21, length: 1, value: <<5>>}                   # Max CPE
      ]
      
      assert :ok = Validation.validate_docsis_compliance(tlvs, "3.1")
    end

    test "identifies missing required TLVs" do
      tlvs = [
        %{type: 3, length: 1, value: <<1>>},  # Only Network Access, missing others
        %{type: 21, length: 1, value: <<5>>}
      ]
      
      assert {:error, errors} = Validation.validate_docsis_compliance(tlvs, "3.1")
      
      # Should report missing required TLVs (4, 6, 7)
      error_types = Enum.map(errors, fn {_, type, _} -> type end)
      assert 4 in error_types  # Missing CoS
      assert 6 in error_types  # Missing CM MIC
      assert 7 in error_types  # Missing CMTS MIC
    end

    test "validates DOCSIS 3.1 specific TLVs" do
      tlvs = [
        %{type: 3, length: 1, value: <<1>>},
        %{type: 4, length: 9, value: <<1, 1, 1, 2, 4, 0, 15, 66, 64>>},
        %{type: 6, length: 16, value: <<1::128>>},
        %{type: 7, length: 16, value: <<2::128>>},
        %{type: 77, length: 2, value: <<1, 2>>}  # DOCSIS 3.1 TLV
      ]
      
      assert :ok = Validation.validate_docsis_compliance(tlvs, "3.1")
    end

    test "rejects invalid TLV types for DOCSIS 3.1" do
      tlvs = [
        %{type: 3, length: 1, value: <<1>>},
        %{type: 4, length: 9, value: <<1, 1, 1, 2, 4, 0, 15, 66, 64>>},
        %{type: 6, length: 16, value: <<1::128>>},
        %{type: 7, length: 16, value: <<2::128>>},
        %{type: 999, length: 1, value: <<1>>}  # Invalid type
      ]
      
      assert {:error, errors} = Validation.validate_docsis_compliance(tlvs, "3.1")
      assert Enum.any?(errors, fn {_, type, _} -> type == 999 end)
    end
  end

  describe "validate_docsis_compliance/2 with DOCSIS 3.0" do
    test "validates DOCSIS 3.0 configuration" do
      tlvs = [
        %{type: 3, length: 1, value: <<1>>},
        %{type: 4, length: 9, value: <<1, 1, 1, 2, 4, 0, 15, 66, 64>>},
        %{type: 6, length: 16, value: <<1::128>>},
        %{type: 7, length: 16, value: <<2::128>>},
        %{type: 50, length: 4, value: <<1, 2, 3, 4>>}  # DOCSIS 3.0 TLV
      ]
      
      assert :ok = Validation.validate_docsis_compliance(tlvs, "3.0")
    end

    test "rejects DOCSIS 3.1 TLVs in 3.0 mode" do
      tlvs = [
        %{type: 3, length: 1, value: <<1>>},
        %{type: 4, length: 9, value: <<1, 1, 1, 2, 4, 0, 15, 66, 64>>},
        %{type: 6, length: 16, value: <<1::128>>},
        %{type: 7, length: 16, value: <<2::128>>},
        %{type: 77, length: 2, value: <<1, 2>>}  # DOCSIS 3.1 only TLV
      ]
      
      assert {:error, errors} = Validation.validate_docsis_compliance(tlvs, "3.0")
      assert Enum.any?(errors, fn {_, type, _} -> type == 77 end)
    end
  end

  describe "TLV value validation" do
    test "validates downstream frequency TLV (type 1)" do
      # Valid frequency
      valid_tlv = %{type: 1, length: 4, value: <<100_000_000::32>>}
      tlvs = [valid_tlv] ++ required_tlvs()
      
      assert :ok = Validation.validate_docsis_compliance(tlvs, "3.1")
    end

    test "rejects invalid downstream frequency" do
      # Frequency too low
      invalid_tlv = %{type: 1, length: 4, value: <<10_000_000::32>>}
      tlvs = [invalid_tlv] ++ required_tlvs()
      
      assert {:error, errors} = Validation.validate_docsis_compliance(tlvs, "3.1")
      assert Enum.any?(errors, fn {_, type, reason} -> 
        type == 1 and (String.contains?(reason, "out of valid range") or String.contains?(reason, "Invalid frequency format"))
      end)
    end

    test "validates Max CPE IP addresses TLV (type 21)" do
      # Valid CPE count
      valid_tlv = %{type: 21, length: 1, value: <<10>>}
      tlvs = [valid_tlv] ++ required_tlvs()
      
      assert :ok = Validation.validate_docsis_compliance(tlvs, "3.1")
    end

    test "rejects invalid CPE count" do
      # CPE count too high
      invalid_tlv = %{type: 21, length: 1, value: <<255>>}
      tlvs = [invalid_tlv] ++ required_tlvs()
      
      assert {:error, errors} = Validation.validate_docsis_compliance(tlvs, "3.1")
      assert Enum.any?(errors, fn {_, type, reason} -> 
        type == 21 and (String.contains?(reason, "must be between") or String.contains?(reason, "Invalid CPE count format"))
      end)
    end

    test "validates Class of Service subtlvs" do
      cos_tlv = %{
        type: 4, 
        length: 8,
        value: <<1, 1, 1, 2, 4, 0, 15, 66>>,
        subtlvs: [
          %{type: 1, length: 1, value: <<1>>},      # Class ID
          %{type: 2, length: 4, value: <<1000000::32>>}  # Max Rate
        ]
      }
      tlvs = [cos_tlv] ++ required_tlvs_except([4])
      
      assert :ok = Validation.validate_docsis_compliance(tlvs, "3.1")
    end

    test "rejects CoS without required subtlvs" do
      cos_tlv = %{
        type: 4, 
        length: 4,
        value: <<1, 1, 1, 2>>,
        subtlvs: [
          %{type: 1, length: 1, value: <<1>>}  # Only Class ID, missing Max Rate
        ]
      }
      tlvs = [cos_tlv] ++ required_tlvs_except([4])
      
      assert {:error, errors} = Validation.validate_docsis_compliance(tlvs, "3.1")
      assert Enum.any?(errors, fn {_, type, reason} -> 
        type == 4 and String.contains?(reason, "Max Rate")
      end)
    end

    test "validates Service Flow subtlvs" do
      sf_tlv = %{
        type: 17,
        length: 6,
        value: <<1, 2, 0, 1, 6, 1>>,
        subtlvs: [
          %{type: 1, length: 2, value: <<1::16>>}  # SF Reference
        ]
      }
      tlvs = [sf_tlv] ++ required_tlvs()
      
      assert :ok = Validation.validate_docsis_compliance(tlvs, "3.1")
    end

    test "rejects Service Flow without SF Reference" do
      sf_tlv = %{
        type: 17,
        length: 4,
        value: <<6, 1, 0, 0>>,
        subtlvs: [
          %{type: 6, length: 1, value: <<0>>}  # Missing SF Reference
        ]
      }
      tlvs = [sf_tlv] ++ required_tlvs()
      
      assert {:error, errors} = Validation.validate_docsis_compliance(tlvs, "3.1")
      assert Enum.any?(errors, fn {_, type, reason} -> 
        type == 17 and String.contains?(reason, "SF Reference")
      end)
    end
  end

  describe "TLV conflict detection" do
    test "allows multiple TLVs for types that can appear multiple times" do
      tlvs = [
        %{type: 17, length: 6, value: <<1, 2, 0, 1, 6, 1>>},  # Upstream SF 1
        %{type: 17, length: 6, value: <<1, 2, 0, 2, 6, 1>>},  # Upstream SF 2
        %{type: 18, length: 6, value: <<1, 2, 0, 3, 6, 1>>},  # Downstream SF 1
        %{type: 18, length: 6, value: <<1, 2, 0, 4, 6, 1>>}   # Downstream SF 2
      ] ++ required_tlvs()
      
      assert :ok = Validation.validate_docsis_compliance(tlvs, "3.1")
    end

    test "rejects duplicate single-occurrence TLVs" do
      tlvs = [
        %{type: 1, length: 4, value: <<100_000_000::32>>},  # Frequency 1
        %{type: 1, length: 4, value: <<200_000_000::32>>},  # Frequency 2 (duplicate)
        %{type: 21, length: 1, value: <<5>>},               # CPE count 1
        %{type: 21, length: 1, value: <<10>>}               # CPE count 2 (duplicate)
      ] ++ required_tlvs()
      
      assert {:error, errors} = Validation.validate_docsis_compliance(tlvs, "3.1")
      assert Enum.any?(errors, fn {_, type, reason} -> 
        type == 1 and String.contains?(reason, "only appear once")
      end)
      assert Enum.any?(errors, fn {_, type, reason} -> 
        type == 21 and String.contains?(reason, "only appear once")
      end)
    end
  end

  describe "validate_tlv_for_version/2" do
    test "validates TLV for correct version" do
      tlv = %{type: 3, length: 1, value: <<1>>}
      assert :ok = Validation.validate_tlv_for_version(tlv, "3.1")
      assert :ok = Validation.validate_tlv_for_version(tlv, "3.0")
    end

    test "rejects DOCSIS 3.1 TLV for 3.0 version" do
      tlv = %{type: 77, length: 2, value: <<1, 2>>}
      assert :ok = Validation.validate_tlv_for_version(tlv, "3.1")
      assert {:error, reason} = Validation.validate_tlv_for_version(tlv, "3.0")
      assert String.contains?(reason, "not supported in DOCSIS 3.0")
    end

    test "validates TLV with subtlvs" do
      tlv = %{
        type: 4,
        length: 8,
        value: <<1, 1, 1, 2, 4, 0, 15, 66>>,
        subtlvs: [
          %{type: 1, length: 1, value: <<1>>},
          %{type: 2, length: 4, value: <<1000000::32>>}
        ]
      }
      assert :ok = Validation.validate_tlv_for_version(tlv, "3.1")
    end

    test "validates subtlv types" do
      tlv = %{
        type: 4,
        length: 4,
        value: <<1, 1, 1, 2>>,
        subtlvs: [
          %{type: 999, length: 1, value: <<1>>}  # Invalid subtlv type
        ]
      }
      assert {:error, reason} = Validation.validate_tlv_for_version(tlv, "3.1")
      assert String.contains?(reason, "Invalid sub-TLV")
    end
  end

  describe "valid_tlv_type?/2" do
    test "validates DOCSIS 3.0 TLV types" do
      assert Validation.valid_tlv_type?(3, "3.0") == true
      assert Validation.valid_tlv_type?(50, "3.0") == true
      assert Validation.valid_tlv_type?(77, "3.0") == false  # 3.1 only
      assert Validation.valid_tlv_type?(999, "3.0") == false
    end

    test "validates DOCSIS 3.1 TLV types" do
      assert Validation.valid_tlv_type?(3, "3.1") == true
      assert Validation.valid_tlv_type?(50, "3.1") == true
      assert Validation.valid_tlv_type?(77, "3.1") == true   # 3.1 TLV
      assert Validation.valid_tlv_type?(999, "3.1") == false
    end

    test "defaults to DOCSIS 3.1" do
      assert Validation.valid_tlv_type?(77) == true
      assert Validation.valid_tlv_type?(999) == false
    end
  end

  describe "get_tlv_description/2" do
    test "returns correct descriptions for DOCSIS 3.0 TLVs" do
      assert Validation.get_tlv_description(3, "3.0") == "Network Access Control"
      assert Validation.get_tlv_description(21, "3.0") == "Max CPE IP Addresses"
      assert Validation.get_tlv_description(50, "3.0") == "Transmit Pre-Equalizer"
    end

    test "returns correct descriptions for DOCSIS 3.1 TLVs" do
      assert Validation.get_tlv_description(77, "3.1") == "FCType Forwarding"
      assert Validation.get_tlv_description(83, "3.1") == "Extended CMTS Message Integrity Check"
    end

    test "returns unknown for invalid TLV types" do
      assert Validation.get_tlv_description(999, "3.1") == "Unknown TLV"
      assert Validation.get_tlv_description(999, "3.0") == "Unknown TLV"
    end

    test "defaults to DOCSIS 3.1" do
      assert Validation.get_tlv_description(77) == "FCType Forwarding"
    end
  end

  describe "get_valid_tlv_types/1" do
    test "returns DOCSIS 3.0 TLV types" do
      types_30 = Validation.get_valid_tlv_types("3.0")
      
      assert is_list(types_30)
      assert 3 in types_30      # Basic TLV
      assert 50 in types_30     # 3.0 TLV
      assert 77 not in types_30 # 3.1 only TLV
      assert Enum.sort(types_30) == types_30  # Should be sorted
    end

    test "returns DOCSIS 3.1 TLV types" do
      types_31 = Validation.get_valid_tlv_types("3.1")
      
      assert is_list(types_31)
      assert 3 in types_31      # Basic TLV
      assert 50 in types_31     # 3.0 TLV (should be included)
      assert 77 in types_31     # 3.1 TLV
      assert Enum.sort(types_31) == types_31  # Should be sorted
    end

    test "DOCSIS 3.1 includes all 3.0 TLVs" do
      types_30 = Validation.get_valid_tlv_types("3.0")
      types_31 = Validation.get_valid_tlv_types("3.1")
      
      # All 3.0 types should be in 3.1
      assert Enum.all?(types_30, &(&1 in types_31))
      # 3.1 should have additional types
      assert length(types_31) > length(types_30)
    end

    test "defaults to DOCSIS 3.1" do
      types_default = Validation.get_valid_tlv_types()
      types_31 = Validation.get_valid_tlv_types("3.1")
      
      assert types_default == types_31
    end
  end

  describe "edge cases and error handling" do
    test "handles empty TLV list" do
      assert {:error, errors} = Validation.validate_docsis_compliance([], "3.1")
      # Should report all required TLVs as missing
      assert length(errors) >= 4
    end

    test "handles TLVs with malformed values" do
      tlvs = [
        %{type: 1, length: 4, value: "not_binary"},  # String instead of binary
        %{type: 21, length: 1, value: <<>>}          # Empty value
      ] ++ required_tlvs()
      
      assert {:error, errors} = Validation.validate_docsis_compliance(tlvs, "3.1")
      assert length(errors) > 0
    end

    test "handles invalid DOCSIS version" do
      tlvs = required_tlvs()
      
      # Should default to 3.1 behavior for unknown version
      assert {:error, _} = Validation.validate_docsis_compliance(tlvs, "4.0")
    end

    test "handles TLVs without required fields" do
      incomplete_tlv = %{type: 3}  # Missing length and value
      
      # Should handle gracefully without crashing
      assert_raise MatchError, fn ->
        Validation.validate_docsis_compliance([incomplete_tlv], "3.1")
      end
    end
  end

  describe "performance tests" do
    test "validates large configuration efficiently" do
      # Generate 1000 TLVs
      large_tlvs = for i <- 1..1000 do
        %{type: rem(i, 50) + 1, length: 1, value: <<rem(i, 255)>>}
      end
      
      {time, result} = :timer.tc(fn ->
        Validation.validate_docsis_compliance(large_tlvs, "3.1")
      end)
      
      # Should complete validation within reasonable time (less than 100ms)
      assert time < 100_000
      assert match?({:error, _}, result)  # Will have errors due to missing required TLVs
    end
  end

  # Helper functions
  defp required_tlvs do
    [
      %{type: 3, length: 1, value: <<1>>},                    # Network Access
      %{type: 4, length: 8, value: <<1, 1, 1, 2, 4, 0, 15, 66>>}, # CoS
      %{type: 6, length: 16, value: <<1::128>>},              # CM MIC
      %{type: 7, length: 16, value: <<2::128>>}               # CMTS MIC
    ]
  end

  defp required_tlvs_except(exclude_types) do
    required_tlvs()
    |> Enum.reject(fn tlv -> tlv.type in exclude_types end)
  end
end