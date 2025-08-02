defmodule Bindocsis.ConfigAnalyzer do
  @moduledoc """
  Configuration intelligence and analysis for DOCSIS configurations.
  
  Provides automated analysis of DOCSIS configurations to generate human-readable
  summaries, detect configuration patterns, identify potential issues, and suggest
  optimizations for network performance and compliance.
  
  ## Features
  
  - **Configuration summaries**: Generate descriptive overviews of DOCSIS configurations
  - **Service tier detection**: Identify residential vs business vs premium configurations
  - **Performance analysis**: Analyze bandwidth allocations and QoS settings
  - **Compliance checking**: Validate against DOCSIS standards and best practices
  - **Security assessment**: Check for security-related configuration issues
  - **Optimization suggestions**: Recommend improvements for better performance
  
  ## Example Usage
  
      # Analyze a binary DOCSIS configuration
      binary_config = <<1, 4, 35, 57, 241, 192, 3, 1, 1, 255>>
      {:ok, analysis} = Bindocsis.ConfigAnalyzer.analyze(binary_config)
      
      # Generate summary
      {:ok, summary} = Bindocsis.ConfigAnalyzer.generate_summary(analysis)
      
      # Get optimization suggestions
      {:ok, suggestions} = Bindocsis.ConfigAnalyzer.suggest_optimizations(analysis)
  """

  alias Bindocsis.DocsisSpecs

  @type analysis_result :: %{
    configuration_type: atom(),
    service_tier: atom(),
    summary: String.t(),
    key_settings: map(),
    performance_metrics: map(),
    compliance_status: map(),
    security_assessment: map(),
    optimization_suggestions: [String.t()],
    tlv_analysis: [map()]
  }

  @type analysis_options :: [
    include_tlv_details: boolean(),
    check_compliance: boolean(),
    include_security_check: boolean(),
    suggest_optimizations: boolean(),
    docsis_version: String.t()
  ]

  @doc """
  Analyzes a DOCSIS configuration and returns comprehensive analysis results.
  
  ## Parameters
  
  - `binary_config` - Binary DOCSIS configuration data
  - `opts` - Analysis options
  
  ## Options
  
  - `:include_tlv_details` - Include detailed TLV analysis (default: true)
  - `:check_compliance` - Perform DOCSIS compliance checking (default: true)  
  - `:include_security_check` - Include security assessment (default: true)
  - `:suggest_optimizations` - Include optimization suggestions (default: true)
  - `:docsis_version` - Target DOCSIS version (default: "3.1")
  
  ## Returns
  
  - `{:ok, analysis_result}` - Complete configuration analysis
  - `{:error, reason}` - Analysis error with reason
  
  ## Example
  
      iex> binary = <<1, 4, 35, 57, 241, 192, 3, 1, 1, 255>>
      iex> {:ok, analysis} = Bindocsis.ConfigAnalyzer.analyze(binary)
      iex> analysis.service_tier
      :standard
  """
  @spec analyze(binary(), analysis_options()) :: {:ok, analysis_result()} | {:error, String.t()}
  def analyze(binary_config, opts \\ []) do
    # Check for empty or too small binary data
    if byte_size(binary_config) < 3 do
      {:error, "Binary configuration too small to analyze (minimum 3 bytes required)"}
    else
      docsis_version = Keyword.get(opts, :docsis_version, "3.1")
      include_tlv_details = Keyword.get(opts, :include_tlv_details, true)
      check_compliance = Keyword.get(opts, :check_compliance, true)
      include_security_check = Keyword.get(opts, :include_security_check, true)
      suggest_optimizations = Keyword.get(opts, :suggest_optimizations, true)
      
      case Bindocsis.parse(binary_config, format: :binary, enhanced: true, docsis_version: docsis_version) do
        {:ok, enhanced_tlvs} ->
          # Perform various analyses
          configuration_type = detect_configuration_type(enhanced_tlvs)
          service_tier = detect_service_tier(enhanced_tlvs)
          key_settings = extract_key_settings(enhanced_tlvs)
          performance_metrics = analyze_performance(enhanced_tlvs)
          
          compliance_status = if check_compliance do
            check_docsis_compliance(enhanced_tlvs, docsis_version)
          else
            %{checked: false}
          end
          
          security_assessment = if include_security_check do
            assess_security_configuration(enhanced_tlvs)
          else
            %{checked: false}
          end
          
          optimization_suggestions = if suggest_optimizations do
            generate_optimization_suggestions(enhanced_tlvs, key_settings, performance_metrics)
          else
            []
          end
          
          tlv_analysis = if include_tlv_details do
            analyze_individual_tlvs(enhanced_tlvs)
          else
            []
          end
          
          summary = generate_configuration_summary(
            configuration_type, 
            service_tier, 
            key_settings, 
            performance_metrics
          )
          
          analysis_result = %{
            configuration_type: configuration_type,
            service_tier: service_tier,
            summary: summary,
            key_settings: key_settings,
            performance_metrics: performance_metrics,
            compliance_status: compliance_status,
            security_assessment: security_assessment,
            optimization_suggestions: optimization_suggestions,
            tlv_analysis: tlv_analysis
          }
          
          {:ok, analysis_result}
          
        {:error, reason} ->
          {:error, "Failed to parse configuration for analysis: #{reason}"}
      end
    end
  end

  @doc """
  Generates a human-readable summary of the configuration analysis.
  
  Creates a concise, readable summary that explains what the configuration
  does, what type of service it provides, and any notable characteristics.
  """
  @spec generate_summary(analysis_result()) :: {:ok, String.t()} | {:error, String.t()}
  def generate_summary(%{summary: summary}), do: {:ok, summary}
  def generate_summary(_), do: {:error, "Invalid analysis result"}

  @doc """
  Gets optimization suggestions from the analysis.
  """
  @spec get_optimization_suggestions(analysis_result()) :: {:ok, [String.t()]} | {:error, String.t()}
  def get_optimization_suggestions(%{optimization_suggestions: suggestions}), do: {:ok, suggestions}
  def get_optimization_suggestions(_), do: {:error, "Invalid analysis result"}

  @doc """
  Checks if the configuration complies with DOCSIS standards.
  """
  @spec is_compliant?(analysis_result()) :: boolean()
  def is_compliant?(%{compliance_status: %{compliant: compliant}}), do: compliant
  def is_compliant?(_), do: false

  # Private analysis functions

  defp detect_configuration_type(enhanced_tlvs) do
    tlv_types = Enum.map(enhanced_tlvs, & &1.type)
    
    cond do
      # MTA configuration (VoIP)
      Enum.any?(tlv_types, &(&1 in [64, 65, 66, 67])) -> :mta_provisioning
      
      # PacketCable configuration  
      Enum.any?(tlv_types, &(&1 in [43, 122])) -> :packetcable
      
      # Business configuration indicators
      Enum.any?(tlv_types, &(&1 in [28, 29, 30, 31])) -> :business
      
      # Basic cable modem configuration
      Enum.any?(tlv_types, &(&1 in [1, 2, 3])) -> :cable_modem
      
      # Default
      true -> :unknown
    end
  end

  defp detect_service_tier(enhanced_tlvs) do
    # Look for key indicators of service tier
    max_cpe = get_tlv_value(enhanced_tlvs, 21, 1)  # Max CPE IP addresses
    _downstream_freq = get_tlv_value(enhanced_tlvs, 1)  # Downstream frequency
    service_flows = Enum.filter(enhanced_tlvs, &(&1.type in [24, 25, 26]))  # Service flow TLVs
    
    cond do
      # Enterprise/Business indicators
      max_cpe > 32 or length(service_flows) > 4 -> :enterprise
      
      # Business indicators  
      max_cpe > 16 or length(service_flows) > 2 -> :business
      
      # Premium residential
      max_cpe > 8 -> :premium_residential
      
      # Standard residential (explicit CPE limit 1-8)
      max_cpe > 1 and max_cpe <= 8 -> :residential
      
      # Standard if no CPE limit specified or very minimal config
      true -> :standard
    end
  end

  defp extract_key_settings(enhanced_tlvs) do
    %{
      downstream_frequency: get_formatted_value(enhanced_tlvs, 1),
      upstream_channel_id: get_formatted_value(enhanced_tlvs, 2),
      network_access: get_formatted_value(enhanced_tlvs, 3),
      modem_ip: get_formatted_value(enhanced_tlvs, 12),
      max_cpe_count: get_formatted_value(enhanced_tlvs, 21),
      tftp_server: get_formatted_value(enhanced_tlvs, 20),
      config_file_name: get_formatted_value(enhanced_tlvs, 67),
      service_flows: count_service_flows(enhanced_tlvs),
      vendor_extensions: count_vendor_extensions(enhanced_tlvs)
    }
  end

  defp analyze_performance(enhanced_tlvs) do
    service_flows = Enum.filter(enhanced_tlvs, &(&1.type in [24, 25, 26]))
    
    %{
      total_service_flows: length(service_flows),
      has_qos_configuration: length(service_flows) > 0,
      estimated_downstream_capacity: estimate_downstream_capacity(enhanced_tlvs),
      estimated_upstream_capacity: estimate_upstream_capacity(enhanced_tlvs),
      configuration_complexity: calculate_complexity_score(enhanced_tlvs)
    }
  end

  defp check_docsis_compliance(enhanced_tlvs, docsis_version) do
    issues = []
    
    # Check for required TLVs
    required_tlvs = get_required_tlvs(docsis_version)
    present_tlvs = Enum.map(enhanced_tlvs, & &1.type)
    missing_required = required_tlvs -- present_tlvs
    
    issues = if length(missing_required) > 0 do
      ["Missing required TLVs: #{Enum.join(missing_required, ", ")}" | issues]
    else
      issues
    end
    
    # Check for deprecated TLVs
    deprecated_tlvs = get_deprecated_tlvs(docsis_version)
    deprecated_present = present_tlvs -- (present_tlvs -- deprecated_tlvs)
    
    issues = if length(deprecated_present) > 0 do
      ["Deprecated TLVs present: #{Enum.join(deprecated_present, ", ")}" | issues]
    else
      issues
    end
    
    # Check TLV value ranges and formats
    format_issues = check_tlv_formats(enhanced_tlvs, docsis_version)
    issues = issues ++ format_issues
    
    %{
      compliant: length(issues) == 0,
      docsis_version: docsis_version,
      issues: issues,
      warnings: generate_compliance_warnings(enhanced_tlvs, docsis_version)
    }
  end

  defp assess_security_configuration(enhanced_tlvs) do
    security_issues = []
    security_warnings = []
    
    # Check for basic security configurations
    has_bpi = Enum.any?(enhanced_tlvs, &(&1.type == 29))  # BPI configuration
    has_cert = Enum.any?(enhanced_tlvs, &(&1.type == 32))  # Certificate
    
    security_issues = if not has_bpi do
      ["No Baseline Privacy Interface (BPI) configuration found" | security_issues]
    else
      security_issues
    end
    
    security_warnings = if not has_cert do
      ["No security certificate found - may impact authentication" | security_warnings]
    else
      security_warnings
    end
    
    # Check for vendor-specific security extensions
    has_vendor_security = Enum.any?(enhanced_tlvs, fn tlv ->
      case {tlv.type, DocsisSpecs.get_tlv_info(43, "3.1")} do
        {43, {:ok, %{description: desc}}} ->
          String.contains?(String.downcase(desc), "security")
        _ ->
          false
      end
    end)
    
    %{
      has_baseline_privacy: has_bpi,
      has_certificates: has_cert,
      has_vendor_security: has_vendor_security,
      security_level: calculate_security_level(has_bpi, has_cert, has_vendor_security),
      issues: security_issues,
      warnings: security_warnings
    }
  end

  defp generate_optimization_suggestions(_enhanced_tlvs, key_settings, performance_metrics) do
    suggestions = []
    
    # Check for missing QoS configuration
    suggestions = if performance_metrics.total_service_flows == 0 do
      ["Consider adding Quality of Service (QoS) configuration with service flows for better traffic management" | suggestions]
    else
      suggestions
    end
    
    # Check CPE limit optimization
    max_cpe_str = Map.get(key_settings, :max_cpe_count, "Unknown")
    suggestions = case max_cpe_str do
      "Unknown" -> suggestions
      cpe_str when is_binary(cpe_str) ->
        case Integer.parse(cpe_str) do
          {max_cpe, ""} when max_cpe < 4 ->
            ["Consider increasing Max CPE IP addresses (currently #{max_cpe}) to allow more customer devices" | suggestions]
          _ -> suggestions
        end
      max_cpe when is_integer(max_cpe) and max_cpe < 4 ->
        ["Consider increasing Max CPE IP addresses (currently #{max_cpe}) to allow more customer devices" | suggestions]
      _ -> suggestions
    end
    
    # Check for vendor-specific optimizations
    vendor_count = Map.get(key_settings, :vendor_extensions, 0)
    suggestions = if vendor_count == 0 do
      ["Consider adding vendor-specific extensions for enhanced features and performance optimizations" | suggestions]
    else
      suggestions
    end
    
    # Performance suggestions based on complexity
    complexity = performance_metrics.configuration_complexity
    suggestions = if complexity < 3 do
      ["Configuration appears minimal - consider adding more comprehensive settings for production use" | suggestions]
    else
      suggestions
    end
    
    suggestions
  end

  defp analyze_individual_tlvs(enhanced_tlvs) do
    Enum.map(enhanced_tlvs, fn tlv ->
      %{
        type: tlv.type,
        name: tlv.name,
        category: categorize_tlv(tlv.type),
        importance: assess_tlv_importance(tlv.type),
        formatted_value: tlv.formatted_value,
        description: tlv.description,
        compliance_notes: get_tlv_compliance_notes(tlv.type)
      }
    end)
  end

  defp generate_configuration_summary(config_type, service_tier, key_settings, performance_metrics) do
    type_desc = case config_type do
      :cable_modem -> "Cable Modem"
      :business -> "Business Service"
      :mta_provisioning -> "MTA/VoIP Provisioning"
      :packetcable -> "PacketCable"
      _ -> "DOCSIS"
    end
    
    tier_desc = case service_tier do
      :enterprise -> "Enterprise-grade"
      :business -> "Business"
      :premium_residential -> "Premium Residential"
      :residential -> "Residential"
      _ -> "Standard"
    end
    
    qos_desc = if performance_metrics.has_qos_configuration do
      "with QoS traffic management"
    else
      "with basic configuration"
    end
    
    complexity_desc = case performance_metrics.configuration_complexity do
      score when score >= 7 -> "comprehensive"
      score when score >= 4 -> "moderate"
      _ -> "minimal"
    end
    
    # Build summary
    summary = "#{tier_desc} #{type_desc} configuration #{qos_desc}. "
    
    summary = summary <> case key_settings do
      %{downstream_frequency: freq, max_cpe_count: cpe} when freq != nil and cpe != nil ->
        "Operating on #{freq} with support for up to #{cpe} customer devices. "
      %{downstream_frequency: freq} when freq != nil ->
        "Operating on #{freq}. "
      _ ->
        ""
    end
    
    summary <> "This is a #{complexity_desc} configuration with #{performance_metrics.total_service_flows} service flow(s) defined."
  end

  # Helper functions

  defp get_tlv_value(enhanced_tlvs, type, default \\ nil) do
    case Enum.find(enhanced_tlvs, &(&1.type == type)) do
      nil -> default
      %{value: <<value>>} when is_integer(value) -> value
      %{value: <<value::32>>} -> value
      %{value: <<value::16>>} -> value  
      %{value: value} when is_binary(value) -> value
      tlv -> tlv.formatted_value || default
    end
  end

  defp get_formatted_value(enhanced_tlvs, type) do
    case Enum.find(enhanced_tlvs, &(&1.type == type)) do
      nil -> nil
      tlv -> tlv.formatted_value
    end
  end

  defp count_service_flows(enhanced_tlvs) do
    Enum.count(enhanced_tlvs, &(&1.type in [24, 25, 26]))
  end

  defp count_vendor_extensions(enhanced_tlvs) do
    Enum.count(enhanced_tlvs, &(&1.type == 43))
  end

  defp estimate_downstream_capacity(enhanced_tlvs) do
    # This is a simplified estimation - real implementation would analyze service flows
    service_flows = count_service_flows(enhanced_tlvs)
    case service_flows do
      0 -> "Unknown"
      1 -> "Basic (up to 100 Mbps estimated)"
      2 -> "Standard (up to 300 Mbps estimated)"  
      _ -> "High (300+ Mbps estimated)"
    end
  end

  defp estimate_upstream_capacity(enhanced_tlvs) do
    # Simplified estimation
    service_flows = count_service_flows(enhanced_tlvs)
    case service_flows do
      0 -> "Unknown"
      1 -> "Basic (up to 10 Mbps estimated)"
      2 -> "Standard (up to 30 Mbps estimated)"
      _ -> "High (30+ Mbps estimated)"
    end
  end

  defp calculate_complexity_score(enhanced_tlvs) do
    base_score = length(enhanced_tlvs)
    service_flow_bonus = count_service_flows(enhanced_tlvs) * 2
    vendor_bonus = count_vendor_extensions(enhanced_tlvs)
    
    base_score + service_flow_bonus + vendor_bonus
  end

  defp get_required_tlvs("3.1"), do: [1, 2, 3]  # Basic required TLVs for DOCSIS 3.1
  defp get_required_tlvs("3.0"), do: [1, 2, 3]  # Basic required TLVs for DOCSIS 3.0
  defp get_required_tlvs(_), do: [1, 2, 3]      # Default

  defp get_deprecated_tlvs("3.1"), do: []       # No deprecated TLVs in 3.1 yet
  defp get_deprecated_tlvs("3.0"), do: []       # No deprecated TLVs in 3.0
  defp get_deprecated_tlvs(_), do: []           # Default

  defp check_tlv_formats(_enhanced_tlvs, _docsis_version) do
    # Placeholder for format validation - would check value ranges, formats, etc.
    []
  end

  defp generate_compliance_warnings(_enhanced_tlvs, _docsis_version) do
    # Placeholder for compliance warnings
    []
  end

  defp calculate_security_level(has_bpi, has_cert, has_vendor_security) do
    case {has_bpi, has_cert, has_vendor_security} do
      {true, true, true} -> :high
      {true, true, false} -> :medium_high
      {true, false, _} -> :medium
      {false, true, _} -> :low_medium
      {false, false, _} -> :low
    end
  end

  defp categorize_tlv(type) do
    case type do
      t when t in [1, 2] -> :channel_configuration
      t when t in [3, 21] -> :access_control
      t when t in [12, 13, 14, 15] -> :network_configuration
      t when t in [24, 25, 26] -> :quality_of_service
      t when t in [29, 30, 31, 32] -> :security
      43 -> :vendor_specific
      t when t in [64, 65, 66, 67] -> :mta_provisioning
      _ -> :other
    end
  end

  defp assess_tlv_importance(type) do
    case type do
      t when t in [1, 2, 3] -> :critical
      t when t in [12, 21] -> :high
      t when t in [24, 25, 26, 29] -> :high
      t when t in [43, 67] -> :medium
      _ -> :low
    end
  end

  defp get_tlv_compliance_notes(type) do
    case type do
      1 -> "Required for channel configuration"
      2 -> "Required for upstream channel identification"  
      3 -> "Required for network access control"
      21 -> "Recommended to prevent IP address exhaustion"
      24 -> "Required for downstream service flows"
      25 -> "Required for upstream service flows"
      _ -> nil
    end
  end
end