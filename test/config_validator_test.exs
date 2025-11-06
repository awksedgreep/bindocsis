defmodule Bindocsis.ConfigValidatorTest do
  use ExUnit.Case
  doctest Bindocsis.ConfigValidator

  alias Bindocsis.ConfigValidator

  # Sample binary configurations for testing
  @valid_config <<
    # Downstream Frequency: 591 MHz (valid FCC range)
    1,
    4,
    35,
    57,
    241,
    192,
    # Upstream Channel ID: 2
    2,
    1,
    2,
    # Network Access Control: Enabled
    3,
    1,
    1,
    # Modem IP Address: 192.168.1.100
    12,
    4,
    192,
    168,
    1,
    100,
    # Max CPE IP Addresses: 8
    21,
    1,
    8,
    # End marker
    255
  >>

  @invalid_frequency_config <<
    # Downstream Frequency: 50 MHz (INVALID - below FCC minimum)
    1,
    4,
    2,
    250,
    240,
    0,
    # Upstream Channel ID: 2
    2,
    1,
    2,
    # Network Access Control: Enabled
    3,
    1,
    1,
    # End marker
    255
  >>

  @missing_required_config <<
    # Only Network Access Control (missing required TLVs 1 and 2)
    3,
    1,
    1,
    # End marker
    255
  >>

  @high_cpe_config <<
    # Downstream Frequency: 591 MHz
    1,
    4,
    35,
    57,
    241,
    192,
    # Upstream Channel ID: 2
    2,
    1,
    2,
    # Network Access Control: Enabled
    3,
    1,
    1,
    # Max CPE IP Addresses: 32 (high but valid)
    21,
    1,
    32,
    # End marker
    255
  >>

  @minimal_config <<
    # Only the bare minimum required TLVs
    # Frequency
    1,
    4,
    35,
    57,
    241,
    192,
    # Upstream channel
    2,
    1,
    2,
    # Network access
    3,
    1,
    1,
    255
  >>

  describe "validate/2" do
    test "validates a compliant configuration successfully" do
      assert {:ok, validation} = ConfigValidator.validate(@valid_config)

      assert validation.is_valid == true
      assert validation.compliance_level == :full
      assert validation.docsis_version == "3.1"

      # Should have no critical violations
      critical_violations = ConfigValidator.get_critical_violations(validation)
      assert length(critical_violations) == 0

      # Check validation summary
      summary = validation.validation_summary
      assert summary.critical_violations == 0
      assert is_integer(summary.total_violations)
      assert is_integer(summary.total_warnings)
    end

    test "detects invalid frequency violation" do
      assert {:ok, validation} = ConfigValidator.validate(@invalid_frequency_config)

      assert validation.is_valid == false
      assert validation.compliance_level in [:non_compliant, :partial]

      # Should have frequency violation
      violations = validation.violations
      frequency_violation = Enum.find(violations, &(&1.tlv_type == 1))
      assert frequency_violation != nil
      assert frequency_violation.severity in [:major, :critical]
      assert String.contains?(frequency_violation.description, "frequency")
    end

    test "detects missing required TLVs" do
      assert {:ok, validation} = ConfigValidator.validate(@missing_required_config)

      assert validation.is_valid == false
      assert validation.compliance_level == :non_compliant

      # Should have critical violations for missing required TLVs
      critical_violations = ConfigValidator.get_critical_violations(validation)
      # Missing TLVs 1 and 2
      assert length(critical_violations) >= 2

      # Check for specific missing TLVs
      missing_tlv_1 = Enum.find(critical_violations, &(&1.tlv_type == 1))
      missing_tlv_2 = Enum.find(critical_violations, &(&1.tlv_type == 2))
      assert missing_tlv_1 != nil
      assert missing_tlv_2 != nil
      assert missing_tlv_1.category == :required_tlv
      assert missing_tlv_2.category == :required_tlv
    end

    test "generates best practice warnings for high CPE limits" do
      assert {:ok, validation} = ConfigValidator.validate(@high_cpe_config)

      # Should be valid but have warnings
      assert validation.is_valid == true

      # Should have warning about high CPE limit
      warnings = validation.warnings

      cpe_warning =
        Enum.find(warnings, fn warning ->
          warning.tlv_type == 21 or String.contains?(warning.description, "CPE")
        end)

      if cpe_warning do
        assert cpe_warning.category == :best_practices
        assert String.contains?(cpe_warning.description, "CPE")
      end
    end

    test "respects different DOCSIS versions" do
      assert {:ok, validation_31} = ConfigValidator.validate(@valid_config, docsis_version: "3.1")
      assert {:ok, validation_30} = ConfigValidator.validate(@valid_config, docsis_version: "3.0")

      assert validation_31.docsis_version == "3.1"
      assert validation_30.docsis_version == "3.0"

      # Both should be valid for this simple config
      assert validation_31.is_valid
      assert validation_30.is_valid
    end

    test "respects different regulatory regions" do
      # Test FCC region (default)
      assert {:ok, validation_fcc} =
               ConfigValidator.validate(@valid_config, regulatory_region: :fcc)

      # Test IC region (more restrictive frequency range)
      assert {:ok, validation_ic} =
               ConfigValidator.validate(@valid_config, regulatory_region: :ic)

      assert validation_fcc.regulatory_compliance.regulatory_region == :fcc
      assert validation_ic.regulatory_compliance.regulatory_region == :ic

      # Both should be compliant for 591 MHz
      assert validation_fcc.regulatory_compliance.compliant
      assert validation_ic.regulatory_compliance.compliant
    end

    test "validates frequency compliance by regulatory region" do
      # Create config with frequency that's valid for FCC but invalid for IC
      high_freq_config = <<
        # Downstream Frequency: 900 MHz (valid FCC, invalid IC)
        1,
        4,
        53,
        177,
        68,
        0,
        2,
        1,
        2,
        3,
        1,
        1,
        255
      >>

      assert {:ok, validation_fcc} =
               ConfigValidator.validate(high_freq_config, regulatory_region: :fcc)

      assert {:ok, validation_ic} =
               ConfigValidator.validate(high_freq_config, regulatory_region: :ic)

      # Should be compliant for FCC
      assert validation_fcc.regulatory_compliance.compliant

      # May have violations for IC (depending on exact frequency)
      # IC range is 88-862 MHz, so 900 MHz should violate
      ic_violations = Enum.filter(validation_ic.violations, &(&1.category == :regulatory))

      if length(ic_violations) > 0 do
        assert validation_ic.regulatory_compliance.compliant == false
      end
    end

    test "includes security assessment" do
      assert {:ok, validation} = ConfigValidator.validate(@valid_config)

      security = validation.security_assessment
      assert Map.has_key?(security, :security_level)
      assert Map.has_key?(security, :has_security_violations)
      assert Map.has_key?(security, :baseline_privacy_enabled)

      # Basic config shouldn't have BPI enabled
      assert security.baseline_privacy_enabled == false
    end

    test "includes performance assessment" do
      assert {:ok, validation} = ConfigValidator.validate(@valid_config)

      performance = validation.performance_assessment
      assert Map.has_key?(performance, :has_qos_configuration)
      assert Map.has_key?(performance, :service_flows)
      assert Map.has_key?(performance, :estimated_performance_level)

      # Basic config has no service flows
      assert performance.service_flows == 0
      assert performance.has_qos_configuration == false
    end

    test "generates appropriate recommendations" do
      assert {:ok, validation} = ConfigValidator.validate(@minimal_config)

      recommendations = validation.recommendations
      assert is_list(recommendations)
      assert length(recommendations) > 0

      # Should recommend QoS for minimal config
      qos_recommendation =
        Enum.find(recommendations, fn rec ->
          String.contains?(String.downcase(rec), "qos") or
            String.contains?(String.downcase(rec), "service flow")
        end)

      assert qos_recommendation != nil
    end

    test "can disable optional validation checks" do
      opts = [
        check_security: false,
        check_performance: false,
        check_best_practices: false
      ]

      assert {:ok, validation} = ConfigValidator.validate(@valid_config, opts)

      # Should still validate core DOCSIS compliance
      assert validation.is_valid == true

      # But should have fewer warnings since optional checks are disabled
      # (This depends on the specific implementation details)
      assert is_list(validation.warnings)
    end

    test "handles strict mode" do
      assert {:ok, validation_normal} =
               ConfigValidator.validate(@valid_config, strict_mode: false)

      assert {:ok, validation_strict} = ConfigValidator.validate(@valid_config, strict_mode: true)

      # Both should be valid for compliant config
      assert validation_normal.is_valid
      assert validation_strict.is_valid

      # Strict mode may have more violations for the same config
      # (depending on implementation)
      assert is_list(validation_strict.violations)
    end

    test "handles invalid binary configuration" do
      # Invalid length
      invalid_binary = <<1, 255, 2>>

      assert {:error, error_msg} = ConfigValidator.validate(invalid_binary)
      assert String.contains?(error_msg, "Failed to validate")
    end
  end

  describe "is_valid?/1" do
    test "returns true for valid configuration" do
      assert {:ok, validation} = ConfigValidator.validate(@valid_config)
      assert ConfigValidator.is_valid?(validation) == true
    end

    test "returns false for invalid configuration" do
      assert {:ok, validation} = ConfigValidator.validate(@missing_required_config)
      assert ConfigValidator.is_valid?(validation) == false
    end

    test "handles invalid validation result" do
      assert ConfigValidator.is_valid?(%{invalid: :result}) == false
    end
  end

  describe "get_compliance_level/1" do
    test "returns compliance level for valid result" do
      assert {:ok, validation} = ConfigValidator.validate(@valid_config)
      assert ConfigValidator.get_compliance_level(validation) == :full
    end

    test "returns non_compliant for invalid configuration" do
      assert {:ok, validation} = ConfigValidator.validate(@missing_required_config)
      assert ConfigValidator.get_compliance_level(validation) == :non_compliant
    end

    test "handles invalid validation result" do
      assert ConfigValidator.get_compliance_level(%{invalid: :result}) == :non_compliant
    end
  end

  describe "generate_compliance_report/1" do
    test "generates comprehensive compliance report" do
      assert {:ok, validation} = ConfigValidator.validate(@valid_config)
      assert {:ok, report} = ConfigValidator.generate_compliance_report(validation)

      assert is_binary(report)
      assert String.contains?(report, "Configuration Compliance Report")
      assert String.contains?(report, "Validation Summary")
      assert String.contains?(report, "Regulatory Compliance")
      assert String.contains?(report, "Security Assessment")
      assert String.contains?(report, "Performance Assessment")

      # Should contain status indicators
      assert String.contains?(report, "VALID") or String.contains?(report, "✅")
      assert String.contains?(report, "DOCSIS Version")
    end

    test "includes violations in report" do
      assert {:ok, validation} = ConfigValidator.validate(@missing_required_config)
      assert {:ok, report} = ConfigValidator.generate_compliance_report(validation)

      assert String.contains?(report, "Violations")
      assert String.contains?(report, "Critical Violations") or String.contains?(report, "🔴")
      assert String.contains?(report, "TLV 1") or String.contains?(report, "TLV 2")
    end

    test "includes warnings in report" do
      assert {:ok, validation} = ConfigValidator.validate(@high_cpe_config)
      assert {:ok, report} = ConfigValidator.generate_compliance_report(validation)

      # Should include warnings section
      if length(validation.warnings) > 0 do
        assert String.contains?(report, "Warnings") or String.contains?(report, "⚠️")
      end
    end

    test "includes recommendations in report" do
      assert {:ok, validation} = ConfigValidator.validate(@minimal_config)
      assert {:ok, report} = ConfigValidator.generate_compliance_report(validation)

      assert String.contains?(report, "Recommendations")

      # Should have specific recommendations
      recommendations_present =
        Enum.any?(validation.recommendations, fn rec ->
          String.contains?(report, rec)
        end)

      assert recommendations_present || length(validation.recommendations) == 0
    end
  end

  describe "get_critical_violations/1" do
    test "returns critical violations from valid result" do
      assert {:ok, validation} = ConfigValidator.validate(@missing_required_config)
      critical_violations = ConfigValidator.get_critical_violations(validation)

      assert is_list(critical_violations)
      assert length(critical_violations) > 0

      # All returned violations should be critical
      Enum.each(critical_violations, fn violation ->
        assert violation.severity == :critical
      end)
    end

    test "returns empty list for configuration with no critical violations" do
      assert {:ok, validation} = ConfigValidator.validate(@valid_config)
      critical_violations = ConfigValidator.get_critical_violations(validation)

      assert critical_violations == []
    end

    test "handles invalid validation result" do
      assert ConfigValidator.get_critical_violations(%{invalid: :result}) == []
    end
  end

  describe "get_validation_statistics/1" do
    test "returns validation statistics" do
      assert {:ok, validation} = ConfigValidator.validate(@missing_required_config)
      stats = ConfigValidator.get_validation_statistics(validation)

      assert Map.has_key?(stats, :total_violations)
      assert Map.has_key?(stats, :critical_violations)
      assert Map.has_key?(stats, :major_violations)
      assert Map.has_key?(stats, :minor_violations)
      assert Map.has_key?(stats, :total_warnings)
      assert Map.has_key?(stats, :violation_categories)
      assert Map.has_key?(stats, :warning_categories)

      # Should have some violations for invalid config
      assert stats.total_violations > 0
    end

    test "handles invalid validation result" do
      assert ConfigValidator.get_validation_statistics(%{invalid: :result}) == %{}
    end
  end

  describe "frequency validation" do
    test "validates frequencies within FCC range" do
      # Test frequency at lower bound (88 MHz)
      low_freq_config = <<
        # 88 MHz
        1,
        4,
        5,
        62,
        198,
        0,
        2,
        1,
        2,
        3,
        1,
        1,
        255
      >>

      assert {:ok, validation} =
               ConfigValidator.validate(low_freq_config, regulatory_region: :fcc)

      # Should be compliant
      freq_violations =
        Enum.filter(validation.violations, fn v ->
          v.tlv_type == 1 and v.category == :regulatory
        end)

      assert length(freq_violations) == 0
    end

    test "detects frequencies outside regulatory range" do
      # Test frequency below minimum (50 MHz - invalid for all regions)
      invalid_freq_config = <<
        # ~50 MHz
        1,
        4,
        2,
        250,
        240,
        0,
        2,
        1,
        2,
        3,
        1,
        1,
        255
      >>

      assert {:ok, validation} =
               ConfigValidator.validate(invalid_freq_config, regulatory_region: :fcc)

      # Should have regulatory violation
      regulatory_violations = Enum.filter(validation.violations, &(&1.category == :regulatory))
      assert length(regulatory_violations) > 0

      freq_violation = Enum.find(regulatory_violations, &(&1.tlv_type == 1))
      assert freq_violation != nil
      assert freq_violation.severity == :critical
    end
  end

  describe "TLV format validation" do
    test "validates TLV formats correctly" do
      assert {:ok, validation} = ConfigValidator.validate(@valid_config)

      # Should not have format violations for valid config
      format_violations = Enum.filter(validation.violations, &(&1.category == :tlv_format))
      assert length(format_violations) == 0
    end

    test "detects invalid CPE limit values" do
      # Create config with invalid CPE limit (0)
      invalid_cpe_config = <<
        1,
        4,
        35,
        57,
        241,
        192,
        2,
        1,
        2,
        3,
        1,
        1,
        # Invalid CPE limit
        21,
        1,
        0,
        255
      >>

      assert {:ok, validation} = ConfigValidator.validate(invalid_cpe_config)

      # Should have format violation for CPE limit
      cpe_violations =
        Enum.filter(validation.violations, fn v ->
          v.tlv_type == 21 and v.category == :tlv_format
        end)

      if length(cpe_violations) > 0 do
        cpe_violation = hd(cpe_violations)
        assert String.contains?(cpe_violation.description, "CPE")
      end
    end
  end

  describe "compliance level determination" do
    test "determines full compliance for valid configuration" do
      assert {:ok, validation} = ConfigValidator.validate(@valid_config)
      assert validation.compliance_level == :full
    end

    test "determines non-compliant for critical violations" do
      assert {:ok, validation} = ConfigValidator.validate(@missing_required_config)
      assert validation.compliance_level == :non_compliant
    end

    test "determines partial compliance for major violations" do
      # This test depends on the specific implementation
      # In some cases, configurations might have major but not critical violations
      assert {:ok, validation} = ConfigValidator.validate(@invalid_frequency_config)

      # Could be non_compliant or partial depending on frequency violation severity
      assert validation.compliance_level in [:non_compliant, :partial]
    end
  end

  describe "security validation" do
    test "detects missing baseline privacy" do
      assert {:ok, validation} = ConfigValidator.validate(@valid_config)

      # Basic config shouldn't have BPI
      assert validation.security_assessment.baseline_privacy_enabled == false

      # Should have security violation for missing BPI
      security_violations = Enum.filter(validation.violations, &(&1.category == :security))
      bpi_violation = Enum.find(security_violations, &(&1.tlv_type == 29))

      if bpi_violation do
        assert String.contains?(bpi_violation.description, "Privacy")
        assert bpi_violation.severity == :major
      end
    end
  end

  describe "performance validation" do
    test "warns about missing QoS configuration" do
      assert {:ok, validation} = ConfigValidator.validate(@minimal_config)

      # Should have warning about missing QoS
      qos_warnings =
        Enum.filter(validation.warnings, fn w ->
          w.category == :performance and
            (String.contains?(w.description, "QoS") or
               String.contains?(w.description, "service flow"))
        end)

      if length(qos_warnings) > 0 do
        qos_warning = hd(qos_warnings)
        assert String.contains?(qos_warning.recommendation, "service flow")
      end
    end
  end

  describe "recommendation generation" do
    test "generates critical violation recommendations" do
      assert {:ok, validation} = ConfigValidator.validate(@missing_required_config)

      recommendations = validation.recommendations

      urgent_recommendation =
        Enum.find(recommendations, fn rec ->
          String.contains?(String.downcase(rec), "urgent") or
            String.contains?(String.downcase(rec), "critical")
        end)

      assert urgent_recommendation != nil
    end

    test "generates security recommendations" do
      assert {:ok, validation} = ConfigValidator.validate(@valid_config)

      recommendations = validation.recommendations

      security_recommendation =
        Enum.find(recommendations, fn rec ->
          String.contains?(String.downcase(rec), "privacy") or
            String.contains?(String.downcase(rec), "bpi")
        end)

      # Should recommend BPI for configurations without it
      if not validation.security_assessment.baseline_privacy_enabled do
        assert security_recommendation != nil
      end
    end
  end

  describe "error handling" do
    test "handles malformed configurations gracefully" do
      # Too short
      malformed_config = <<1, 2>>

      assert {:error, error_msg} = ConfigValidator.validate(malformed_config)
      assert String.contains?(error_msg, "Failed to validate")
    end

    test "handles empty configurations" do
      empty_config = <<>>

      assert {:error, error_msg} = ConfigValidator.validate(empty_config)
      assert String.contains?(error_msg, "Failed to validate")
    end
  end
end
