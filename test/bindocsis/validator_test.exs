defmodule Bindocsis.ValidatorTest do
  use ExUnit.Case
  alias Bindocsis.Validator

  describe "validate_configuration/2" do
    test "validates complete valid configuration" do
      valid_tlvs = [
        %{type: 1, length: 4, value: <<35, 57, 241, 192>>},  # Downstream Frequency
        %{type: 2, length: 1, value: <<1>>},                 # Upstream Channel ID
        %{type: 3, length: 1, value: <<1>>}                  # Network Access Control
      ]

      assert {:ok, report} = Validator.validate_configuration(valid_tlvs)
      assert report.status == :valid
      assert length(report.errors) == 0
      assert length(report.warnings) == 0
      assert report.summary.config_completeness == 1.0
    end

    test "detects incomplete configuration" do
      incomplete_tlvs = [
        %{type: 1, length: 4, value: <<35, 57, 241, 192>>}  # Only downstream frequency
      ]

      assert {:ok, report} = Validator.validate_configuration(incomplete_tlvs)
      assert report.status == :warning
      assert length(report.warnings) > 0
      assert report.summary.config_completeness < 1.0
      
      warning = List.first(report.warnings)
      assert warning.type == :incomplete_config
      assert String.contains?(warning.message, "Missing required TLVs")
    end

    test "detects version incompatibility" do
      future_tlvs = [
        %{type: 1, length: 4, value: <<35, 57, 241, 192>>},
        %{type: 121, length: 2, value: <<1, 2>>}  # DOCSIS 4.0 TLV
      ]

      assert {:ok, report} = Validator.validate_configuration(future_tlvs, docsis_version: "1.0")
      assert report.status == :invalid
      assert length(report.errors) > 0
      
      error = Enum.find(report.errors, &(&1.type == :version_incompatible))
      assert error != nil
      assert error.tlv_type == 121
    end
  end

  describe "validate_tlv/3" do
    test "validates correct TLV structure" do
      valid_tlv = %{type: 3, length: 1, value: <<1>>}
      
      assert {:ok, errors} = Validator.validate_tlv(valid_tlv)
      assert length(errors) == 0
    end

    test "detects missing required keys" do
      invalid_tlv = %{type: 3, value: <<1>>}  # Missing length
      
      assert {:ok, errors} = Validator.validate_tlv(invalid_tlv)
      assert length(errors) > 0
      
      error = List.first(errors)
      assert error.type == :invalid_structure
      assert error.severity == :critical
      assert String.contains?(error.message, "length")
    end

    test "detects length mismatch in strict mode" do
      tlv_with_wrong_length = %{type: 1, length: 2, value: <<35, 57, 241, 192>>}
      
      assert {:ok, errors} = Validator.validate_tlv(tlv_with_wrong_length, "3.1", true)
      assert length(errors) > 0
      
      error = Enum.find(errors, &(&1.type == :length_mismatch))
      assert error != nil
      assert error.severity == :error
    end

    test "validates compound TLV with sub-TLVs" do
      compound_tlv = %{
        type: 66,
        length: 3,
        value: <<1, 1, 5>>,
        subtlvs: [%{type: 1, length: 1, value: <<5>>}]
      }
      
      assert {:ok, errors} = Validator.validate_tlv(compound_tlv)
      assert length(errors) == 0
    end
  end

  describe "validate_value/3" do
    test "validates correct frequency value" do
      frequency_value = <<35, 57, 241, 192>>
      
      assert {:ok, []} = Validator.validate_value(:frequency, frequency_value)
    end

    test "validates correct IPv4 value" do
      ipv4_value = <<192, 168, 1, 100>>
      
      assert {:ok, []} = Validator.validate_value(:ipv4, ipv4_value)
    end

    test "detects invalid IPv4 value" do
      invalid_ipv4 = <<192, 168, 1>>  # Too short
      
      assert {:error, reason} = Validator.validate_value(:ipv4, invalid_ipv4)
      assert String.contains?(reason, "length")
    end

    test "validates new value types" do
      # Test OID validation
      oid_value = <<43, 6, 1, 4, 1>>  # 1.3.6.1.4.1
      assert {:ok, []} = Validator.validate_value(:oid, oid_value)
      
      # Test timestamp validation
      timestamp_value = <<96, 150, 129, 0>>  # Some Unix timestamp
      assert {:ok, []} = Validator.validate_value(:timestamp, timestamp_value)
      
      # Test power quarter dB validation
      power_value = <<40>>  # 10.0 dBmV
      assert {:ok, []} = Validator.validate_value(:power_quarter_db, power_value)
    end
  end

  describe "check_minimum_requirements/1" do
    test "passes with all required TLVs present" do
      complete_tlvs = [
        %{type: 1, length: 4, value: <<35, 57, 241, 192>>},
        %{type: 2, length: 1, value: <<1>>},
        %{type: 3, length: 1, value: <<1>>}
      ]
      
      assert {:ok, result} = Validator.check_minimum_requirements(complete_tlvs)
      assert result.complete == true
      assert result.missing == []
      assert length(result.present) == 3
    end

    test "detects missing required TLVs" do
      incomplete_tlvs = [
        %{type: 1, length: 4, value: <<35, 57, 241, 192>>}
      ]
      
      assert {:ok, result} = Validator.check_minimum_requirements(incomplete_tlvs)
      assert result.complete == false
      assert 2 in result.missing
      assert 3 in result.missing
      assert 1 in result.present
    end
  end

  describe "dependency validation" do
    test "detects missing dependencies" do
      # TLV 24 (Downstream Service Flow) without required TLV 1 (Downstream Frequency)
      tlvs_missing_deps = [
        %{type: 24, length: 7, value: <<1, 2, 0, 1, 6, 1, 7>>},
        %{type: 2, length: 1, value: <<1>>}  # Has upstream channel but missing downstream frequency
      ]
      
      assert {:ok, report} = Validator.validate_configuration(tlvs_missing_deps)
      assert report.status == :invalid
      
      dep_error = Enum.find(report.errors, &(&1.type == :missing_dependency))
      assert dep_error != nil
      assert dep_error.tlv_type == 24
      assert String.contains?(dep_error.message, "requires TLV 1")
    end

    test "passes when dependencies are satisfied" do
      tlvs_with_deps = [
        %{type: 1, length: 4, value: <<35, 57, 241, 192>>},  # Downstream Frequency
        %{type: 2, length: 1, value: <<1>>},                 # Upstream Channel ID
        %{type: 24, length: 7, value: <<1, 2, 0, 1, 6, 1, 7>>}  # Downstream Service Flow
      ]
      
      assert {:ok, report} = Validator.validate_configuration(tlvs_with_deps)
      # Should not have dependency errors
      dep_errors = Enum.filter(report.errors, &(&1.type == :missing_dependency))
      assert length(dep_errors) == 0
    end
  end

  describe "sub-TLV validation" do
    test "validates known sub-TLVs" do
      # Create a TLV with valid sub-TLVs
      tlv_with_subtlvs = %{
        type: 5,  # Modem Capabilities
        length: 3,
        value: <<1, 1, 1>>,
        subtlvs: [
          %{type: 1, length: 1, value: <<1>>}  # Concatenation Support
        ]
      }
      
      assert {:ok, errors} = Validator.validate_tlv(tlv_with_subtlvs)
      assert length(errors) == 0
    end

    test "warns about unknown sub-TLVs" do
      tlv_with_unknown_subtlv = %{
        type: 5,
        length: 3,
        value: <<255, 1, 1>>,
        subtlvs: [
          %{type: 255, length: 1, value: <<1>>}  # Unknown sub-TLV
        ]
      }
      
      assert {:ok, errors} = Validator.validate_tlv(tlv_with_unknown_subtlv)
      # Should generate a warning for unknown sub-TLV
      unknown_subtlv_errors = Enum.filter(errors, &(&1.type == :unknown_subtlv_type))
      assert length(unknown_subtlv_errors) > 0
    end
  end

  describe "validation report structure" do
    test "generates comprehensive validation report" do
      mixed_tlvs = [
        %{type: 1, length: 4, value: <<35, 57, 241, 192>>},  # Valid
        %{type: 999, length: 1, value: <<1>>},               # Unknown TLV type (warning)
        %{type: 3, length: 2, value: <<1>>}                  # Length mismatch (error)
      ]
      
      assert {:ok, report} = Validator.validate_configuration(mixed_tlvs, strict: true)
      
      # Check report structure
      assert Map.has_key?(report, :status)
      assert Map.has_key?(report, :errors)
      assert Map.has_key?(report, :warnings)
      assert Map.has_key?(report, :info)
      assert Map.has_key?(report, :summary)
      
      # Check summary structure
      summary = report.summary
      assert Map.has_key?(summary, :total_tlvs)
      assert Map.has_key?(summary, :valid_tlvs)
      assert Map.has_key?(summary, :invalid_tlvs)
      assert Map.has_key?(summary, :docsis_version)
      assert Map.has_key?(summary, :config_completeness)
      
      assert summary.total_tlvs == 3
      assert is_float(summary.config_completeness)
      
      # Should have at least one warning (unknown TLV) and one error (length mismatch)
      assert length(report.warnings) > 0 or length(report.errors) > 0
    end
  end
end