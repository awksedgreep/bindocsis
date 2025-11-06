defmodule Bindocsis.ValidationFrameworkTest do
  use ExUnit.Case, async: true

  alias Bindocsis.Validation.{Framework, Result, Rules}

  describe "Result struct" do
    test "creates new result as valid" do
      result = Result.new()

      assert result.valid? == true
      assert result.errors == []
      assert result.warnings == []
      assert result.info == []
    end

    test "adds error and marks invalid" do
      result =
        Result.new()
        |> Result.add_error("Test error")

      assert result.valid? == false
      assert length(result.errors) == 1
      assert hd(result.errors).message == "Test error"
    end

    test "adds warning without marking invalid" do
      result =
        Result.new()
        |> Result.add_warning("Test warning")

      assert result.valid? == true
      assert length(result.warnings) == 1
    end

    test "adds info message" do
      result =
        Result.new()
        |> Result.add_info("Test info")

      assert result.valid? == true
      assert length(result.info) == 1
    end

    test "adds error with context" do
      result =
        Result.new()
        |> Result.add_error("Error", %{tlv: 24})

      error = hd(result.errors)
      assert error.context == %{tlv: 24}
    end

    test "merges two results" do
      r1 = Result.new() |> Result.add_error("Error 1")
      r2 = Result.new() |> Result.add_warning("Warning 1")

      merged = Result.merge(r1, r2)

      # Because r1 has error
      assert merged.valid? == false
      assert length(merged.errors) == 1
      assert length(merged.warnings) == 1
    end

    test "strict mode converts warnings to errors" do
      result =
        Result.new()
        |> Result.add_warning("Warning 1")
        |> Result.add_warning("Warning 2")
        |> Result.strict_mode()

      assert result.valid? == false
      assert length(result.errors) == 2
      assert length(result.warnings) == 0
    end

    test "has_issues? returns true when issues exist" do
      result =
        Result.new()
        |> Result.add_info("Info")

      assert Result.has_issues?(result) == true
    end

    test "has_issues? returns false for clean result" do
      result = Result.new()

      assert Result.has_issues?(result) == false
    end

    test "all_issues returns combined list" do
      result =
        Result.new()
        |> Result.add_error("Error")
        |> Result.add_warning("Warning")
        |> Result.add_info("Info")

      all = Result.all_issues(result)

      assert length(all) == 3
    end

    test "filters issues by severity" do
      result =
        Result.new()
        |> Result.add_error("Error")
        |> Result.add_warning("Warning")

      errors = Result.filter_by_severity(result, :error)
      warnings = Result.filter_by_severity(result, :warning)

      assert length(errors) == 1
      assert length(warnings) == 1
    end

    test "counts issues" do
      result =
        Result.new()
        |> Result.add_error("E1")
        |> Result.add_error("E2")
        |> Result.add_warning("W1")
        |> Result.add_info("I1")

      counts = Result.count(result)

      assert counts.errors == 2
      assert counts.warnings == 1
      assert counts.info == 1
      assert counts.total == 4
    end
  end

  describe "Framework.validate/2" do
    test "validates valid configuration" do
      tlvs = [
        %{type: 1, length: 4, value: <<591_000_000::32>>},
        %{type: 2, length: 1, value: <<3>>},
        %{type: 3, length: 1, value: <<1>>},
        %{type: 6, length: 16, value: <<0::128>>},
        %{type: 7, length: 16, value: <<0::128>>}
      ]

      {:ok, result} = Framework.validate(tlvs)

      assert result.valid? == true
      assert length(result.errors) == 0
    end

    test "detects missing required TLVs" do
      tlvs = [
        %{type: 1, length: 4, value: <<591_000_000::32>>}
        # Missing type 2, 3, 6, 7
      ]

      {:ok, result} = Framework.validate(tlvs)

      assert result.valid? == false
      # At least 2 missing required TLVs
      assert length(result.errors) >= 2
      # Note: Warnings about missing MICs are separate from errors
      assert length(result.errors) + length(result.warnings) >= 4
    end

    test "detects value out of range" do
      tlvs = [
        # Too high
        %{type: 1, length: 4, value: <<2_000_000_000::32>>},
        %{type: 2, length: 1, value: <<3>>},
        %{type: 3, length: 1, value: <<1>>},
        %{type: 6, length: 16, value: <<0::128>>},
        %{type: 7, length: 16, value: <<0::128>>}
      ]

      {:ok, result} = Framework.validate(tlvs)

      assert result.valid? == false
      assert Enum.any?(result.errors, &(&1.message =~ "out of range"))
    end

    test "validates at syntax level only" do
      tlvs = [
        %{type: 1, length: 4, value: <<591_000_000::32>>}
      ]

      {:ok, result} = Framework.validate(tlvs, level: :syntax)

      # Syntax should pass (structure is fine)
      assert result.valid? == true
    end

    test "validates at compliance level" do
      tlvs = [
        # DOCSIS 3.1 TLV
        %{type: 62, length: 10, value: <<0::80>>}
      ]

      {:ok, result} =
        Framework.validate(tlvs,
          level: :compliance,
          # Force 3.0 (should fail)
          docsis_version: "3.0"
        )

      assert result.valid? == false
      assert Enum.any?(result.errors, &(&1.message =~ "3.1"))
    end

    test "strict mode treats warnings as errors" do
      tlvs = [
        %{type: 1, length: 4, value: <<591_000_000::32>>},
        # Duplicate!
        %{type: 1, length: 4, value: <<600_000_000::32>>},
        %{type: 2, length: 1, value: <<3>>},
        %{type: 3, length: 1, value: <<1>>},
        %{type: 6, length: 16, value: <<0::128>>},
        %{type: 7, length: 16, value: <<0::128>>}
      ]

      {:ok, normal} = Framework.validate(tlvs)
      {:ok, strict} = Framework.validate(tlvs, strict: true)

      # Duplicates are warnings
      assert normal.valid? == true
      # Warnings become errors
      assert strict.valid? == false
    end

    test "skips MIC validation when requested" do
      tlvs = [
        %{type: 1, length: 4, value: <<591_000_000::32>>},
        %{type: 2, length: 1, value: <<3>>},
        %{type: 3, length: 1, value: <<1>>}
        # No MIC TLVs
      ]

      {:ok, result} = Framework.validate(tlvs, skip_mic: true)

      # Should not warn about missing MICs
      assert length(result.warnings) == 0
    end
  end

  describe "Framework.valid?/2" do
    test "returns true for valid config" do
      tlvs = [
        %{type: 1, length: 4, value: <<591_000_000::32>>},
        %{type: 2, length: 1, value: <<3>>},
        %{type: 3, length: 1, value: <<1>>},
        %{type: 6, length: 16, value: <<0::128>>},
        %{type: 7, length: 16, value: <<0::128>>}
      ]

      assert Framework.valid?(tlvs) == true
    end

    test "returns false for invalid config" do
      tlvs = [
        # Out of range
        %{type: 1, length: 4, value: <<2_000_000_000::32>>}
      ]

      assert Framework.valid?(tlvs) == false
    end
  end

  describe "Framework.detect_version/1" do
    test "detects DOCSIS 1.0" do
      tlvs = [
        %{type: 1, length: 4, value: <<591_000_000::32>>},
        %{type: 2, length: 1, value: <<3>>}
      ]

      assert Framework.detect_version(tlvs) == "1.0"
    end

    test "detects DOCSIS 1.1 with service flows" do
      tlvs = [
        %{type: 1, length: 4, value: <<591_000_000::32>>},
        # Upstream SF
        %{type: 17, length: 10, value: <<0::80>>}
      ]

      assert Framework.detect_version(tlvs) == "1.1"
    end

    test "detects DOCSIS 3.0 with channel bonding" do
      tlvs = [
        %{type: 1, length: 4, value: <<591_000_000::32>>},
        # Channel descriptor
        %{type: 24, length: 10, value: <<0::80>>}
      ]

      assert Framework.detect_version(tlvs) == "3.0"
    end

    test "detects DOCSIS 3.1 with OFDM" do
      tlvs = [
        %{type: 1, length: 4, value: <<591_000_000::32>>},
        # OFDM profile
        %{type: 62, length: 10, value: <<0::80>>}
      ]

      assert Framework.detect_version(tlvs) == "3.1"
    end
  end

  describe "Framework.stats/1" do
    test "returns statistics" do
      result =
        Result.new()
        |> Result.add_error("E1")
        |> Result.add_error("E2")
        |> Result.add_warning("W1")

      stats = Framework.stats(result)

      assert stats.errors == 2
      assert stats.warnings == 1
      assert stats.total_checks == 3
      assert stats.valid? == false
    end
  end

  describe "Framework.format_result/1" do
    test "formats valid result" do
      result = Result.new()

      formatted = Framework.format_result(result)

      assert formatted =~ "Configuration is valid"
    end

    test "formats result with errors" do
      result =
        Result.new()
        |> Result.add_error("Test error", %{tlv: 1})

      formatted = Framework.format_result(result)

      assert formatted =~ "has errors"
      assert formatted =~ "Test error"
      assert formatted =~ "TLV 1"
    end

    test "formats result with warnings and info" do
      result =
        Result.new()
        |> Result.add_warning("Test warning")
        |> Result.add_info("Test info")

      formatted = Framework.format_result(result)

      assert formatted =~ "Warnings"
      assert formatted =~ "Info"
    end
  end

  describe "Framework.validate_batch/2" do
    test "validates multiple configurations" do
      configs = %{
        "config1" => [
          %{type: 1, length: 4, value: <<591_000_000::32>>},
          %{type: 2, length: 1, value: <<3>>},
          %{type: 3, length: 1, value: <<1>>},
          %{type: 6, length: 16, value: <<0::128>>},
          %{type: 7, length: 16, value: <<0::128>>}
        ],
        "config2" => [
          # Invalid
          %{type: 1, length: 4, value: <<2_000_000_000::32>>}
        ]
      }

      {:ok, results} = Framework.validate_batch(configs)

      assert map_size(results) == 2
      assert results["config1"].valid? == true
      assert results["config2"].valid? == false
    end
  end

  describe "Rules.check_tlv_structure/2" do
    test "passes valid TLV structure" do
      tlvs = [
        %{type: 1, length: 4, value: <<591_000_000::32>>}
      ]

      result = Rules.check_tlv_structure(Result.new(), tlvs)

      assert result.valid? == true
    end

    test "detects missing type field" do
      tlvs = [
        # No type!
        %{length: 4, value: <<0::32>>}
      ]

      result = Rules.check_tlv_structure(Result.new(), tlvs)

      assert result.valid? == false
      assert Enum.any?(result.errors, &(&1.message =~ "type"))
    end

    test "detects missing length and value" do
      tlvs = [
        # No length or value
        %{type: 1}
      ]

      result = Rules.check_tlv_structure(Result.new(), tlvs)

      assert result.valid? == false
    end
  end

  describe "Rules.check_length_consistency/2" do
    test "passes when length matches value size" do
      tlvs = [
        %{type: 1, length: 4, value: <<0::32>>}
      ]

      result = Rules.check_length_consistency(Result.new(), tlvs)

      assert result.valid? == true
    end

    test "detects length mismatch" do
      tlvs = [
        # Says 10, is 4
        %{type: 1, length: 10, value: <<0::32>>}
      ]

      result = Rules.check_length_consistency(Result.new(), tlvs)

      assert result.valid? == false
      assert Enum.any?(result.errors, &(&1.message =~ "mismatch"))
    end
  end

  describe "Rules.check_duplicate_tlvs/2" do
    test "warns on duplicate unique TLVs" do
      tlvs = [
        %{type: 1, length: 4, value: <<591_000_000::32>>},
        # Duplicate
        %{type: 1, length: 4, value: <<600_000_000::32>>}
      ]

      result = Rules.check_duplicate_tlvs(Result.new(), tlvs)

      assert length(result.warnings) > 0
      assert Enum.any?(result.warnings, &(&1.message =~ "appears"))
    end

    test "allows non-unique TLVs to repeat" do
      tlvs = [
        %{type: 100, length: 1, value: <<1>>},
        # OK to repeat
        %{type: 100, length: 1, value: <<2>>}
      ]

      result = Rules.check_duplicate_tlvs(Result.new(), tlvs)

      assert length(result.warnings) == 0
    end
  end

  describe "Rules.check_service_flow_consistency/2" do
    test "detects missing SF reference" do
      tlvs = [
        %{
          type: 17,
          length: 10,
          value: <<0::80>>,
          subtlvs: [
            # Missing sub-TLV 1 (SF Reference)
            %{type: 8, length: 4, value: <<1_000_000::32>>}
          ]
        }
      ]

      result = Rules.check_service_flow_consistency(Result.new(), tlvs)

      assert result.valid? == false
      assert Enum.any?(result.errors, &(&1.message =~ "SF Reference"))
    end

    test "detects QoS inconsistency (min > max)" do
      tlvs = [
        %{
          type: 17,
          length: 20,
          value: <<0::160>>,
          subtlvs: [
            # SF Ref
            %{type: 1, length: 2, value: <<1::16>>},
            # Max rate
            %{type: 8, length: 4, value: <<1000::32>>},
            # Min rate > max!
            %{type: 9, length: 4, value: <<2000::32>>}
          ]
        }
      ]

      result = Rules.check_service_flow_consistency(Result.new(), tlvs)

      assert result.valid? == false
      assert Enum.any?(result.errors, &(&1.message =~ "exceeds maximum"))
    end
  end

  describe "Rules.check_mic_presence/2" do
    test "warns when CM MIC missing" do
      tlvs = [
        %{type: 1, length: 4, value: <<591_000_000::32>>},
        # CMTS MIC only
        %{type: 7, length: 16, value: <<0::128>>}
      ]

      result = Rules.check_mic_presence(Result.new(), tlvs)

      assert Enum.any?(result.warnings, &(&1.message =~ "CM MIC"))
    end

    test "warns when CMTS MIC missing" do
      tlvs = [
        %{type: 1, length: 4, value: <<591_000_000::32>>},
        # CM MIC only
        %{type: 6, length: 16, value: <<0::128>>}
      ]

      result = Rules.check_mic_presence(Result.new(), tlvs)

      assert Enum.any?(result.warnings, &(&1.message =~ "CMTS MIC"))
    end
  end

  describe "Edge cases" do
    test "handles empty TLV list" do
      {:ok, result} = Framework.validate([])

      # Missing required TLVs
      assert result.valid? == false
    end

    test "handles TLVs without subtlvs field" do
      tlvs = [
        # No subtlvs key
        %{type: 17, length: 10, value: <<0::80>>}
      ]

      result = Rules.check_service_flow_consistency(Result.new(), tlvs)

      # Should not crash
      assert is_struct(result, Result)
    end

    test "handles unknown DOCSIS version gracefully" do
      tlvs = [%{type: 1, length: 4, value: <<591_000_000::32>>}]

      {:ok, result} = Framework.validate(tlvs, docsis_version: "99.9")

      # Should not crash
      assert is_struct(result, Result)
    end
  end
end
