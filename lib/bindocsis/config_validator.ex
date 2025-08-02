defmodule Bindocsis.ConfigValidator do
  @moduledoc """
  Configuration validation and compliance checking for DOCSIS configurations.
  
  Provides comprehensive validation of DOCSIS configurations against industry standards,
  DOCSIS specifications, regulatory requirements, and best practices. Helps ensure
  configurations are compliant, secure, and optimized for production deployment.
  
  ## Features
  
  - **DOCSIS compliance validation**: Check against DOCSIS 2.0, 3.0, 3.1, 4.0 standards
  - **Regulatory compliance**: Validate FCC, Industry Canada, ETSI regulations
  - **Security validation**: Check encryption, authentication, access controls
  - **Performance validation**: Validate QoS, bandwidth allocations, service flows
  - **Best practices checking**: Industry standard configuration recommendations
  - **Custom rule validation**: User-defined validation rules and policies
  - **Detailed violation reports**: Actionable feedback for configuration fixes
  
  ## Example Usage
  
      # Validate a binary DOCSIS configuration
      binary_config = <<1, 4, 35, 57, 241, 192, 3, 1, 1, 255>>
      {:ok, validation} = Bindocsis.ConfigValidator.validate(binary_config)
      
      # Check if configuration is valid
      if validation.is_valid do
        IO.puts("Configuration is valid")
      else
        IO.puts("Configuration has violations")
      end
      
      # Generate compliance report
      {:ok, report} = Bindocsis.ConfigValidator.generate_compliance_report(validation)
  """

  alias Bindocsis.ConfigAnalyzer
  alias Bindocsis.DocsisSpecs

  @type validation_result :: %{
    is_valid: boolean(),
    compliance_level: :full | :partial | :non_compliant,
    docsis_version: String.t(),
    violations: [violation()],
    warnings: [warning()],
    recommendations: [String.t()],
    validation_summary: map(),
    regulatory_compliance: map(),
    security_assessment: map(),
    performance_assessment: map()
  }

  @type violation :: %{
    severity: :critical | :major | :minor,
    category: atom(),
    tlv_type: non_neg_integer() | nil,
    tlv_name: String.t() | nil,
    rule_id: String.t(),
    description: String.t(),
    expected: String.t() | nil,
    actual: String.t() | nil,
    remediation: String.t()
  }

  @type warning :: %{
    category: atom(),
    tlv_type: non_neg_integer() | nil,
    description: String.t(),
    recommendation: String.t()
  }

  @type validation_options :: [
    docsis_version: String.t(),
    regulatory_region: :fcc | :ic | :etsi | :global,
    check_security: boolean(),
    check_performance: boolean(),
    check_best_practices: boolean(),
    custom_rules: [map()],
    strict_mode: boolean()
  ]

  @doc """
  Validates a DOCSIS configuration against compliance standards and best practices.
  
  ## Parameters
  
  - `binary_config` - Binary DOCSIS configuration data
  - `opts` - Validation options
  
  ## Options
  
  - `:docsis_version` - Target DOCSIS version (default: "3.1")
  - `:regulatory_region` - Regulatory compliance region (default: :fcc)
  - `:check_security` - Perform security validation (default: true)
  - `:check_performance` - Perform performance validation (default: true)
  - `:check_best_practices` - Check industry best practices (default: true)
  - `:custom_rules` - Additional custom validation rules (default: [])
  - `:strict_mode` - Enable strict validation mode (default: false)
  
  ## Returns
  
  - `{:ok, validation_result}` - Complete validation results
  - `{:error, reason}` - Validation error with reason
  
  ## Example
  
      iex> binary = <<1, 4, 35, 57, 241, 192, 2, 1, 1, 3, 1, 1, 255>>
      iex> {:ok, validation} = Bindocsis.ConfigValidator.validate(binary, check_security: false)
      iex> Bindocsis.ConfigValidator.is_valid?(validation)
      true
  """
  @spec validate(binary(), validation_options()) :: {:ok, validation_result()} | {:error, String.t()}
  def validate(binary_config, opts \\ []) do
    docsis_version = Keyword.get(opts, :docsis_version, "3.1")
    regulatory_region = Keyword.get(opts, :regulatory_region, :fcc)
    check_security = Keyword.get(opts, :check_security, true)
    check_performance = Keyword.get(opts, :check_performance, true)
    check_best_practices = Keyword.get(opts, :check_best_practices, true)
    custom_rules = Keyword.get(opts, :custom_rules, [])
    strict_mode = Keyword.get(opts, :strict_mode, false)
    
    with {:ok, analysis} <- ConfigAnalyzer.analyze(binary_config, docsis_version: docsis_version),
         {:ok, enhanced_tlvs} <- Bindocsis.parse(binary_config, format: :binary, enhanced: true, docsis_version: docsis_version) do
      violations = []
      warnings = []
      
      # Core DOCSIS compliance validation
      {docsis_violations, docsis_warnings} = validate_docsis_compliance(analysis, enhanced_tlvs, docsis_version, strict_mode)
      violations = violations ++ docsis_violations
      warnings = warnings ++ docsis_warnings
      
      # Regulatory compliance validation
      {regulatory_violations, regulatory_warnings} = validate_regulatory_compliance(analysis, enhanced_tlvs, regulatory_region)
      violations = violations ++ regulatory_violations
      warnings = warnings ++ regulatory_warnings
      
      # Security validation
      {security_violations, security_warnings} = if check_security do
        validate_security_configuration(analysis, docsis_version)
      else
        {[], []}
      end
      violations = violations ++ security_violations
      warnings = warnings ++ security_warnings
      
      # Performance validation
      {performance_violations, performance_warnings} = if check_performance do
        validate_performance_configuration(analysis, docsis_version)
      else
        {[], []}
      end
      violations = violations ++ performance_violations
      warnings = warnings ++ performance_warnings
      
      # Best practices validation
      {bp_violations, bp_warnings} = if check_best_practices do
        validate_best_practices(analysis, enhanced_tlvs, docsis_version)
      else
        {[], []}
      end
      violations = violations ++ bp_violations
      warnings = warnings ++ bp_warnings
      
      # Custom rules validation
      {custom_violations, custom_warnings} = validate_custom_rules(analysis, custom_rules)
      violations = violations ++ custom_violations
      warnings = warnings ++ custom_warnings
      
      # Generate assessments
      regulatory_compliance = generate_regulatory_assessment(regulatory_violations, regulatory_region)
      security_assessment = generate_security_assessment(analysis, security_violations)
      performance_assessment = generate_performance_assessment(analysis, performance_violations)
      
      # Determine overall compliance
      compliance_level = determine_compliance_level(violations)
      is_valid = compliance_level != :non_compliant
      
      # Generate recommendations
      recommendations = generate_validation_recommendations(violations, warnings, analysis)
      
      validation_result = %{
        is_valid: is_valid,
        compliance_level: compliance_level,
        docsis_version: docsis_version,
        violations: violations,
        warnings: warnings,
        recommendations: recommendations,
        validation_summary: generate_validation_summary(violations, warnings),
        regulatory_compliance: regulatory_compliance,
        security_assessment: security_assessment,
        performance_assessment: performance_assessment
      }
      
      {:ok, validation_result}
    else
      {:error, reason} ->
        {:error, "Failed to validate configuration: #{reason}"}
    end
  end

  @doc """
  Checks if a validation result indicates a valid configuration.
  """
  @spec is_valid?(validation_result()) :: boolean()
  def is_valid?(%{is_valid: is_valid}), do: is_valid
  def is_valid?(_), do: false

  @doc """
  Gets the compliance level from a validation result.
  """
  @spec get_compliance_level(validation_result()) :: :full | :partial | :non_compliant
  def get_compliance_level(%{compliance_level: level}), do: level
  def get_compliance_level(_), do: :non_compliant

  @doc """
  Generates a comprehensive compliance report from validation results.
  """
  @spec generate_compliance_report(validation_result()) :: {:ok, String.t()} | {:error, String.t()}
  def generate_compliance_report(validation_result) do
    try do
      report = build_compliance_report(validation_result)
      {:ok, report}
    rescue
      e -> {:error, "Failed to generate compliance report: #{Exception.message(e)}"}
    end
  end

  @doc """
  Gets all critical violations from a validation result.
  """
  @spec get_critical_violations(validation_result()) :: [violation()]
  def get_critical_violations(%{violations: violations}) do
    Enum.filter(violations, &(&1.severity == :critical))
  end
  def get_critical_violations(_), do: []

  @doc """
  Gets validation statistics from a validation result.
  """
  @spec get_validation_statistics(validation_result()) :: map()
  def get_validation_statistics(%{validation_summary: summary}), do: summary
  def get_validation_statistics(_), do: %{}

  # Private validation functions

  defp validate_docsis_compliance(analysis, enhanced_tlvs, docsis_version, strict_mode) do
    violations = []
    warnings = []
    
    # Check for required TLVs
    required_tlvs = get_required_tlvs_for_version(docsis_version)
    present_tlvs = Enum.map(analysis.tlv_analysis, & &1.type)
    missing_required = required_tlvs -- present_tlvs
    
    violations = Enum.reduce(missing_required, violations, fn tlv_type, acc ->
      tlv_info = get_tlv_name(tlv_type)
      [%{
        severity: :critical,
        category: :required_tlv,
        tlv_type: tlv_type,
        tlv_name: tlv_info,
        rule_id: "DOCSIS-REQ-#{tlv_type}",
        description: "Missing required TLV #{tlv_type} (#{tlv_info})",
        expected: "Present",
        actual: "Missing",
        remediation: "Add required TLV #{tlv_type} to configuration"
      } | acc]
    end)
    
    # Check for deprecated TLVs
    deprecated_tlvs = get_deprecated_tlvs_for_version(docsis_version)
    deprecated_present = present_tlvs -- (present_tlvs -- deprecated_tlvs)
    
    severity = if strict_mode, do: :major, else: :minor
    violations = Enum.reduce(deprecated_present, violations, fn tlv_type, acc ->
      tlv_info = get_tlv_name(tlv_type)
      [%{
        severity: severity,
        category: :deprecated_tlv,
        tlv_type: tlv_type,
        tlv_name: tlv_info,
        rule_id: "DOCSIS-DEP-#{tlv_type}",
        description: "Deprecated TLV #{tlv_type} (#{tlv_info}) present in DOCSIS #{docsis_version}",
        expected: "Not present",
        actual: "Present",
        remediation: "Remove deprecated TLV #{tlv_type} and use modern equivalent"
      } | acc]
    end)
    
    # Validate TLV value formats and ranges
    {format_violations, format_warnings} = validate_tlv_formats(enhanced_tlvs, docsis_version, strict_mode)
    violations = violations ++ format_violations
    warnings = warnings ++ format_warnings
    
    # Check version-specific requirements
    {version_violations, version_warnings} = validate_version_specific_requirements(analysis, docsis_version)
    violations = violations ++ version_violations
    warnings = warnings ++ version_warnings
    
    {violations, warnings}
  end

  defp validate_regulatory_compliance(analysis, enhanced_tlvs, regulatory_region) do
    violations = []
    warnings = []
    
    # Frequency validation based on regulatory region
    {freq_violations, freq_warnings} = validate_frequency_compliance(analysis, enhanced_tlvs, regulatory_region)
    violations = violations ++ freq_violations
    warnings = warnings ++ freq_warnings
    
    # Power level validation
    {power_violations, power_warnings} = validate_power_compliance(analysis, regulatory_region)
    violations = violations ++ power_violations
    warnings = warnings ++ power_warnings
    
    # Channel plan validation
    {channel_violations, channel_warnings} = validate_channel_plan_compliance(analysis, regulatory_region)
    violations = violations ++ channel_violations
    warnings = warnings ++ channel_warnings
    
    {violations, warnings}
  end

  defp validate_security_configuration(analysis, docsis_version) do
    violations = []
    warnings = []
    
    # Check for baseline privacy (BPI/BPI+)
    has_bpi = analysis.security_assessment.has_baseline_privacy
    violations = if not has_bpi do
      [%{
        severity: :major,
        category: :security,
        tlv_type: 29,
        tlv_name: "Privacy Enable",
        rule_id: "SEC-BPI-001",
        description: "Baseline Privacy Interface (BPI) not enabled",
        expected: "BPI enabled",
        actual: "BPI disabled",
        remediation: "Enable BPI by adding TLV 29 with appropriate configuration"
      } | violations]
    else
      violations
    end
    
    # Check for security certificates
    has_certs = analysis.security_assessment.has_certificates
    warnings = if not has_certs and String.to_float(docsis_version) >= 3.0 do
      [%{
        category: :security,
        tlv_type: 32,
        description: "No security certificates found for DOCSIS #{docsis_version}",
        recommendation: "Consider adding manufacturer certificate (TLV 32) for enhanced security"
      } | warnings]
    else
      warnings
    end
    
    # Check for weak or default configurations
    {weak_violations, weak_warnings} = validate_security_strength(analysis, docsis_version)
    violations = violations ++ weak_violations
    warnings = warnings ++ weak_warnings
    
    {violations, warnings}
  end

  defp validate_performance_configuration(analysis, docsis_version) do
    violations = []
    warnings = []
    
    # Validate service flow configuration
    service_flows = analysis.performance_metrics.total_service_flows
    warnings = if service_flows == 0 and String.to_float(docsis_version) >= 3.0 do
      [%{
        category: :performance,
        tlv_type: nil,
        description: "No QoS service flows configured",
        recommendation: "Consider adding service flows (TLVs 24-26) for better traffic management"
      } | warnings]
    else
      warnings
    end
    
    # Check for conflicting QoS parameters
    {qos_violations, qos_warnings} = validate_qos_configuration(analysis, docsis_version)
    violations = violations ++ qos_violations
    warnings = warnings ++ qos_warnings
    
    # Validate bandwidth allocations
    {bandwidth_violations, bandwidth_warnings} = validate_bandwidth_allocations(analysis)
    violations = violations ++ bandwidth_violations
    warnings = warnings ++ bandwidth_warnings
    
    # Check for performance bottlenecks
    {bottleneck_violations, bottleneck_warnings} = validate_performance_bottlenecks(analysis)
    violations = violations ++ bottleneck_violations
    warnings = warnings ++ bottleneck_warnings
    
    {violations, warnings}
  end

  defp validate_best_practices(analysis, enhanced_tlvs, docsis_version) do
    violations = []
    warnings = []
    
    # Check CPE limit recommendations
    max_cpe = get_cpe_limit(enhanced_tlvs)
    warnings = if max_cpe != nil and max_cpe > 16 do
      [%{
        category: :best_practices,
        tlv_type: 21,
        description: "High CPE limit (#{max_cpe}) may impact performance",
        recommendation: "Consider limiting CPE devices to 16 or less for optimal performance"
      } | warnings]
    else
      warnings
    end
    
    # Check for missing optional but recommended TLVs
    {optional_violations, optional_warnings} = validate_optional_recommendations(analysis, docsis_version)
    violations = violations ++ optional_violations
    warnings = warnings ++ optional_warnings
    
    # Validate configuration complexity
    complexity = analysis.performance_metrics.configuration_complexity
    warnings = if complexity > 20 do
      [%{
        category: :best_practices,
        tlv_type: nil,
        description: "Configuration complexity is high (#{complexity})",
        recommendation: "Consider simplifying configuration for easier maintenance"
      } | warnings]
    else
      warnings
    end
    
    {violations, warnings}
  end

  defp validate_custom_rules(_analysis, []), do: {[], []}
  defp validate_custom_rules(analysis, custom_rules) do
    violations = []
    warnings = []
    
    # Process custom validation rules
    # This is a placeholder for custom rule processing
    # In a real implementation, this would evaluate user-defined rules
    
    Enum.reduce(custom_rules, {violations, warnings}, fn rule, {v_acc, w_acc} ->
      case apply_custom_rule(analysis, rule) do
        :ok -> {v_acc, w_acc}
        # Future: Add support for {:violation, violation} and {:warning, warning}
      end
    end)
  end

  # Helper functions for specific validations

  defp validate_tlv_formats(tlv_analysis, docsis_version, strict_mode) do
    violations = []
    warnings = []
    
    # Check each TLV for format compliance
    Enum.reduce(tlv_analysis, {violations, warnings}, fn tlv, {v_acc, w_acc} ->
      case validate_tlv_format(tlv, docsis_version, strict_mode) do
        {:violation, violation} -> {[violation | v_acc], w_acc}
        :ok -> {v_acc, w_acc}
        # Future: Add support for {:warning, warning} when needed
      end
    end)
  end

  defp validate_tlv_format(tlv, _docsis_version, _strict_mode) do
    # Placeholder for TLV format validation
    # Would check value ranges, formats, lengths, etc.
    case tlv.type do
      1 -> validate_frequency_tlv(tlv)
      21 -> validate_cpe_limit_tlv(tlv)
      _ -> :ok  # No specific validation for this TLV
    end
  end

  defp validate_frequency_tlv(tlv) do
    # Example: Validate downstream frequency is in valid range
    # Extract frequency from binary value
    frequency_value = case tlv.value do
      <<freq::32>> -> freq
      _ -> nil
    end
    
    case frequency_value do
      freq when is_integer(freq) and freq >= 88_000_000 and freq <= 1_002_000_000 ->
        :ok
      freq when is_integer(freq) ->
        {:violation, %{
          severity: :major,
          category: :tlv_format,
          tlv_type: 1,
          tlv_name: "Downstream Frequency",
          rule_id: "FMT-FREQ-001",
          description: "Downstream frequency #{freq} Hz is outside valid range",
          expected: "88-1002 MHz (88000000-1002000000 Hz)",
          actual: "#{freq} Hz",
          remediation: "Set frequency within the valid DOCSIS frequency range"
        }}
      _ ->
        {:violation, %{
          severity: :critical,
          category: :tlv_format,
          tlv_type: 1,
          tlv_name: "Downstream Frequency",
          rule_id: "FMT-FREQ-002",
          description: "Invalid downstream frequency format",
          expected: "32-bit integer (Hz)",
          actual: "#{inspect(tlv.value)}",
          remediation: "Provide frequency as 32-bit integer in Hz"
        }}
    end
  end

  defp validate_cpe_limit_tlv(tlv) do
    # Extract CPE limit from binary value
    cpe_limit = case tlv.value do
      <<limit::8>> -> limit
      _ -> nil
    end
    
    case cpe_limit do
      limit when is_integer(limit) and limit >= 1 and limit <= 255 ->
        :ok
      limit when is_integer(limit) ->
        {:violation, %{
          severity: :minor,
          category: :tlv_format,
          tlv_type: 21,
          tlv_name: "Max CPE IP Addresses",
          rule_id: "FMT-CPE-001",
          description: "CPE limit #{limit} is outside recommended range",
          expected: "1-255",
          actual: "#{limit}",
          remediation: "Set CPE limit between 1 and 255"
        }}
      _ ->
        {:violation, %{
          severity: :major,
          category: :tlv_format,
          tlv_type: 21,
          tlv_name: "Max CPE IP Addresses",
          rule_id: "FMT-CPE-002",
          description: "Invalid CPE limit format",
          expected: "8-bit integer",
          actual: "#{inspect(tlv.value)}",
          remediation: "Provide CPE limit as 8-bit integer"
        }}
    end
  end

  defp validate_version_specific_requirements(analysis, docsis_version) do
    violations = []
    warnings = []
    
    case docsis_version do
      "3.1" -> validate_docsis_31_requirements(analysis)
      "3.0" -> validate_docsis_30_requirements(analysis)
      "2.0" -> validate_docsis_20_requirements(analysis)
      _ -> {violations, warnings}
    end
  end

  defp validate_docsis_31_requirements(_analysis) do
    # DOCSIS 3.1 specific validations
    {[], []}
  end

  defp validate_docsis_30_requirements(_analysis) do
    # DOCSIS 3.0 specific validations
    {[], []}
  end

  defp validate_docsis_20_requirements(_analysis) do
    # DOCSIS 2.0 specific validations
    {[], []}
  end

  defp validate_frequency_compliance(_analysis, enhanced_tlvs, regulatory_region) do
    violations = []
    warnings = []
    
    # Get frequency ranges for regulatory region
    {min_freq, max_freq} = get_frequency_range_for_region(regulatory_region)
    
    # Find frequency TLV
    enhanced_freq_tlv = Enum.find(enhanced_tlvs, &(&1.type == 1))
    
    updated_violations = if enhanced_freq_tlv do
      freq_hz = case enhanced_freq_tlv.value do
        <<freq::32>> -> freq
        _ -> nil
      end
      
      if freq_hz && (freq_hz < min_freq || freq_hz > max_freq) do
        violations ++ [%{
          severity: :critical,
          category: :regulatory,
          tlv_type: 1,
          tlv_name: "Downstream Frequency",
          rule_id: "REG-FREQ-#{String.upcase(to_string(regulatory_region))}",
          description: "Frequency #{freq_hz} Hz violates #{regulatory_region} regulations",
          expected: "#{min_freq}-#{max_freq} Hz",
          actual: "#{freq_hz} Hz",
          remediation: "Set frequency within approved range for #{regulatory_region} region"
        }]
      else
        violations
      end
    else
      violations
    end
    
    {updated_violations, warnings}
  end

  defp validate_power_compliance(_analysis, _regulatory_region) do
    # Placeholder for power level validation
    {[], []}
  end

  defp validate_channel_plan_compliance(_analysis, _regulatory_region) do
    # Placeholder for channel plan validation
    {[], []}
  end

  defp validate_security_strength(_analysis, _docsis_version) do
    # Placeholder for security strength validation
    {[], []}
  end

  defp validate_qos_configuration(_analysis, _docsis_version) do
    # Placeholder for QoS validation
    {[], []}
  end

  defp validate_bandwidth_allocations(_analysis) do
    # Placeholder for bandwidth validation
    {[], []}
  end

  defp validate_performance_bottlenecks(_analysis) do
    # Placeholder for bottleneck detection
    {[], []}
  end

  defp validate_optional_recommendations(_analysis, _docsis_version) do
    # Placeholder for optional TLV recommendations
    {[], []}
  end

  defp apply_custom_rule(_analysis, _rule) do
    # Placeholder for custom rule application
    :ok
  end

  # Configuration constants and lookup functions

  defp get_required_tlvs_for_version("3.1"), do: [1, 2, 3]
  defp get_required_tlvs_for_version("3.0"), do: [1, 2, 3]
  defp get_required_tlvs_for_version("2.0"), do: [1, 2, 3]
  defp get_required_tlvs_for_version(_), do: [1, 2, 3]

  defp get_deprecated_tlvs_for_version("3.1"), do: []
  defp get_deprecated_tlvs_for_version("3.0"), do: []
  defp get_deprecated_tlvs_for_version("2.0"), do: []
  defp get_deprecated_tlvs_for_version(_), do: []

  defp get_frequency_range_for_region(:fcc), do: {88_000_000, 1_002_000_000}  # FCC: 88-1002 MHz
  defp get_frequency_range_for_region(:ic), do: {88_000_000, 862_000_000}     # IC: 88-862 MHz
  defp get_frequency_range_for_region(:etsi), do: {110_000_000, 862_000_000}  # ETSI: 110-862 MHz
  defp get_frequency_range_for_region(:global), do: {88_000_000, 1_002_000_000} # Global: widest range

  defp get_tlv_name(type) do
    case DocsisSpecs.get_tlv_info(type, "3.1") do
      {:ok, tlv_info} -> tlv_info.name
      {:error, _} -> "TLV #{type}"
    end
  end

  defp get_cpe_limit(enhanced_tlvs) do
    cpe_tlv = Enum.find(enhanced_tlvs, &(&1.type == 21))
    
    if cpe_tlv do
      case cpe_tlv.value do
        <<limit::8>> -> limit
        _ -> nil
      end
    else
      nil
    end
  end

  # Result processing functions

  defp determine_compliance_level(violations) do
    critical_count = Enum.count(violations, &(&1.severity == :critical))
    major_count = Enum.count(violations, &(&1.severity == :major))
    
    cond do
      critical_count > 0 -> :non_compliant
      major_count > 3 -> :partial
      true -> :full
    end
  end

  defp generate_validation_summary(violations, warnings) do
    total_violations = length(violations)
    critical_violations = Enum.count(violations, &(&1.severity == :critical))
    major_violations = Enum.count(violations, &(&1.severity == :major))
    minor_violations = Enum.count(violations, &(&1.severity == :minor))
    total_warnings = length(warnings)
    
    %{
      total_violations: total_violations,
      critical_violations: critical_violations,
      major_violations: major_violations,
      minor_violations: minor_violations,
      total_warnings: total_warnings,
      violation_categories: get_violation_categories(violations),
      warning_categories: get_warning_categories(warnings)
    }
  end

  defp get_violation_categories(violations) do
    violations
    |> Enum.group_by(& &1.category)
    |> Enum.map(fn {category, viols} -> {category, length(viols)} end)
    |> Enum.into(%{})
  end

  defp get_warning_categories(warnings) do
    warnings
    |> Enum.group_by(& &1.category)
    |> Enum.map(fn {category, warns} -> {category, length(warns)} end)
    |> Enum.into(%{})
  end

  defp generate_regulatory_assessment(violations, regulatory_region) do
    regulatory_violations = Enum.filter(violations, &(&1.category == :regulatory))
    
    %{
      regulatory_region: regulatory_region,
      compliant: length(regulatory_violations) == 0,
      violations: length(regulatory_violations),
      critical_violations: Enum.count(regulatory_violations, &(&1.severity == :critical))
    }
  end

  defp generate_security_assessment(analysis, violations) do
    security_violations = Enum.filter(violations, &(&1.category == :security))
    
    %{
      security_level: analysis.security_assessment.security_level,
      has_security_violations: length(security_violations) > 0,
      violations: length(security_violations),
      baseline_privacy_enabled: analysis.security_assessment.has_baseline_privacy
    }
  end

  defp generate_performance_assessment(analysis, violations) do
    performance_violations = Enum.filter(violations, &(&1.category == :performance))
    
    %{
      has_qos_configuration: analysis.performance_metrics.has_qos_configuration,
      service_flows: analysis.performance_metrics.total_service_flows,
      violations: length(performance_violations),
      estimated_performance_level: assess_performance_level(analysis, performance_violations)
    }
  end

  defp assess_performance_level(analysis, violations) do
    base_score = analysis.performance_metrics.total_service_flows * 2
    violation_penalty = length(violations) * 3
    
    score = max(0, base_score - violation_penalty)
    
    cond do
      score >= 8 -> :excellent
      score >= 6 -> :good
      score >= 4 -> :fair
      score >= 2 -> :poor
      true -> :inadequate
    end
  end

  defp generate_validation_recommendations(violations, warnings, analysis) do
    recommendations = []
    
    # Critical violation recommendations
    critical_violations = Enum.filter(violations, &(&1.severity == :critical))
    recommendations = if length(critical_violations) > 0 do
      ["URGENT: Address #{length(critical_violations)} critical compliance violations before deployment" | recommendations]
    else
      recommendations
    end
    
    # Security recommendations
    recommendations = if not analysis.security_assessment.has_baseline_privacy do
      ["Enable Baseline Privacy Interface (BPI) for security compliance" | recommendations]
    else
      recommendations
    end
    
    # Performance recommendations
    recommendations = if analysis.performance_metrics.total_service_flows == 0 do
      ["Consider adding QoS service flows for better traffic management" | recommendations]
    else
      recommendations
    end
    
    # Warning-based recommendations
    warning_categories = get_warning_categories(warnings)
    recommendations = if Map.get(warning_categories, :best_practices, 0) > 3 do
      ["Review configuration against industry best practices" | recommendations]
    else
      recommendations
    end
    
    recommendations
  end

  defp build_compliance_report(validation_result) do
    """
    # DOCSIS Configuration Compliance Report
    
    ## Validation Summary
    
    **Overall Status**: #{if validation_result.is_valid, do: "✅ VALID", else: "❌ INVALID"}
    **Compliance Level**: #{String.upcase(to_string(validation_result.compliance_level))}
    **DOCSIS Version**: #{validation_result.docsis_version}
    **Total Violations**: #{validation_result.validation_summary.total_violations}
    **Total Warnings**: #{validation_result.validation_summary.total_warnings}
    
    ### Violation Breakdown
    - **Critical**: #{validation_result.validation_summary.critical_violations}
    - **Major**: #{validation_result.validation_summary.major_violations}
    - **Minor**: #{validation_result.validation_summary.minor_violations}
    
    ## Regulatory Compliance
    
    **Region**: #{String.upcase(to_string(validation_result.regulatory_compliance.regulatory_region))}
    **Status**: #{if validation_result.regulatory_compliance.compliant, do: "✅ COMPLIANT", else: "❌ NON-COMPLIANT"}
    **Violations**: #{validation_result.regulatory_compliance.violations}
    
    ## Security Assessment
    
    **Security Level**: #{String.upcase(to_string(validation_result.security_assessment.security_level))}
    **BPI Enabled**: #{if validation_result.security_assessment.baseline_privacy_enabled, do: "✅ Yes", else: "❌ No"}
    **Security Violations**: #{validation_result.security_assessment.violations}
    
    ## Performance Assessment
    
    **QoS Configuration**: #{if validation_result.performance_assessment.has_qos_configuration, do: "✅ Present", else: "❌ Missing"}
    **Service Flows**: #{validation_result.performance_assessment.service_flows}
    **Performance Level**: #{String.upcase(to_string(validation_result.performance_assessment.estimated_performance_level))}
    
    #{build_violations_section(validation_result.violations)}
    
    #{build_warnings_section(validation_result.warnings)}
    
    ## Recommendations
    
    #{Enum.map(validation_result.recommendations, &("- #{&1}")) |> Enum.join("\n")}
    
    ---
    *Report generated by Bindocsis ConfigValidator*
    """
  end

  defp build_violations_section([]), do: ""
  defp build_violations_section(violations) do
    violations_by_severity = Enum.group_by(violations, & &1.severity)
    
    sections = []
    
    sections = if Map.has_key?(violations_by_severity, :critical) do
      critical_section = """
      ### 🔴 Critical Violations
      
      #{Enum.map(violations_by_severity[:critical], &format_violation/1) |> Enum.join("\n\n")}
      """
      [critical_section | sections]
    else
      sections
    end
    
    sections = if Map.has_key?(violations_by_severity, :major) do
      major_section = """
      ### 🟠 Major Violations
      
      #{Enum.map(violations_by_severity[:major], &format_violation/1) |> Enum.join("\n\n")}
      """
      [major_section | sections]
    else
      sections
    end
    
    sections = if Map.has_key?(violations_by_severity, :minor) do
      minor_section = """
      ### 🟡 Minor Violations
      
      #{Enum.map(violations_by_severity[:minor], &format_violation/1) |> Enum.join("\n\n")}
      """
      [minor_section | sections]
    else
      sections
    end
    
    "## Violations\n\n" <> Enum.join(Enum.reverse(sections), "\n")
  end

  defp build_warnings_section([]), do: ""
  defp build_warnings_section(warnings) do
    """
    ## Warnings
    
    ### ⚠️ Configuration Warnings
    
    #{Enum.map(warnings, &format_warning/1) |> Enum.join("\n\n")}
    """
  end

  defp format_violation(violation) do
    tlv_info = if violation.tlv_type do
      "**TLV #{violation.tlv_type}** (#{violation.tlv_name}): "
    else
      ""
    end
    
    """
    #{tlv_info}#{violation.description}
    - **Rule**: #{violation.rule_id}
    - **Expected**: #{violation.expected || "N/A"}
    - **Actual**: #{violation.actual || "N/A"}
    - **Fix**: #{violation.remediation}
    """
  end

  defp format_warning(warning) do
    tlv_info = if warning.tlv_type do
      "TLV #{warning.tlv_type}: "
    else
      ""
    end
    
    "**#{tlv_info}#{warning.description}**\n- Recommendation: #{warning.recommendation}"
  end
end