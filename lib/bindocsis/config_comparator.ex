defmodule Bindocsis.ConfigComparator do
  @moduledoc """
  Configuration comparison and diff analysis for DOCSIS configurations.
  
  Provides tools to compare two DOCSIS configurations, identify differences,
  analyze the impact of changes, and generate detailed diff reports for
  troubleshooting, auditing, and configuration management.
  
  ## Features
  
  - **Side-by-side comparison**: Compare two configurations TLV by TLV
  - **Change detection**: Identify added, removed, and modified TLVs
  - **Impact analysis**: Analyze the potential impact of configuration changes
  - **Diff reports**: Generate human-readable reports of configuration differences
  - **Change classification**: Categorize changes by type (critical, minor, cosmetic)
  - **Migration analysis**: Assess compatibility when upgrading configurations
  
  ## Example Usage
  
      # Compare two binary DOCSIS configurations
      config_a = <<1, 4, 35, 57, 241, 192, 3, 1, 1, 255>>
      config_b = <<1, 4, 36, 171, 195, 64, 3, 1, 0, 255>>
      
      {:ok, comparison} = Bindocsis.ConfigComparator.compare(config_a, config_b)
      
      # Generate diff report
      {:ok, report} = Bindocsis.ConfigComparator.generate_diff_report(comparison)
      
      # Analyze change impact
      {:ok, impact} = Bindocsis.ConfigComparator.analyze_impact(comparison)
  """

  alias Bindocsis.ConfigAnalyzer

  @type comparison_result :: %{
    config_a_summary: map(),
    config_b_summary: map(),
    tlv_changes: [tlv_change()],
    summary_changes: [change_summary()],
    impact_analysis: map(),
    compatibility_assessment: map(),
    change_statistics: map()
  }

  @type tlv_change :: %{
    change_type: :added | :removed | :modified | :unchanged,
    tlv_type: non_neg_integer(),
    tlv_name: String.t(),
    old_value: any() | nil,
    new_value: any() | nil,
    old_formatted: String.t() | nil,
    new_formatted: String.t() | nil,
    impact_level: :critical | :high | :medium | :low | :none,
    description: String.t()
  }

  @type change_summary :: %{
    category: atom(),
    change_type: atom(),
    description: String.t(),
    impact_level: atom()
  }

  @type comparison_options :: [
    include_unchanged: boolean(),
    include_impact_analysis: boolean(),
    check_compatibility: boolean(),
    docsis_version: String.t(),
    detailed_analysis: boolean()
  ]

  @doc """
  Compares two DOCSIS configurations and returns a detailed comparison analysis.
  
  ## Parameters
  
  - `config_a` - First binary DOCSIS configuration (baseline)
  - `config_b` - Second binary DOCSIS configuration (comparison target)
  - `opts` - Comparison options
  
  ## Options
  
  - `:include_unchanged` - Include unchanged TLVs in results (default: false)
  - `:include_impact_analysis` - Perform impact analysis (default: true)
  - `:check_compatibility` - Check configuration compatibility (default: true)
  - `:docsis_version` - DOCSIS version for analysis (default: "3.1")
  - `:detailed_analysis` - Include detailed TLV-level analysis (default: true)
  
  ## Returns
  
  - `{:ok, comparison_result}` - Detailed comparison analysis
  - `{:error, reason}` - Comparison error with reason
  
  ## Example
  
      iex> config_a = <<1, 4, 35, 57, 241, 192, 255>>
      iex> config_b = <<1, 4, 36, 171, 195, 64, 255>>
      iex> {:ok, comparison} = Bindocsis.ConfigComparator.compare(config_a, config_b)
      iex> length(comparison.tlv_changes)
      1
  """
  @spec compare(binary(), binary(), comparison_options()) :: {:ok, comparison_result()} | {:error, String.t()}
  def compare(config_a, config_b, opts \\ []) do
    docsis_version = Keyword.get(opts, :docsis_version, "3.1")
    include_unchanged = Keyword.get(opts, :include_unchanged, false)
    include_impact_analysis = Keyword.get(opts, :include_impact_analysis, true)
    check_compatibility = Keyword.get(opts, :check_compatibility, true)
    _detailed_analysis = Keyword.get(opts, :detailed_analysis, true)
    
    with {:ok, analysis_a} <- ConfigAnalyzer.analyze(config_a, docsis_version: docsis_version),
         {:ok, analysis_b} <- ConfigAnalyzer.analyze(config_b, docsis_version: docsis_version),
         {:ok, parsed_a} <- Bindocsis.parse(config_a, format: :binary, enhanced: true, docsis_version: docsis_version),
         {:ok, parsed_b} <- Bindocsis.parse(config_b, format: :binary, enhanced: true, docsis_version: docsis_version) do
      
      # Compare TLVs
      tlv_changes = compare_tlvs(parsed_a, parsed_b, include_unchanged)
      
      # Generate summary-level changes
      summary_changes = compare_summaries(analysis_a, analysis_b)
      
      # Perform impact analysis
      impact_analysis = if include_impact_analysis do
        analyze_change_impact(tlv_changes, analysis_a, analysis_b)
      else
        %{analyzed: false}
      end
      
      # Check compatibility
      compatibility_assessment = if check_compatibility do
        assess_compatibility(analysis_a, analysis_b, tlv_changes)
      else
        %{checked: false}
      end
      
      # Generate statistics
      change_statistics = generate_change_statistics(tlv_changes)
      
      comparison_result = %{
        config_a_summary: extract_comparison_summary(analysis_a),
        config_b_summary: extract_comparison_summary(analysis_b),
        tlv_changes: tlv_changes,
        summary_changes: summary_changes,
        impact_analysis: impact_analysis,
        compatibility_assessment: compatibility_assessment,
        change_statistics: change_statistics
      }
      
      {:ok, comparison_result}
      
    else
      {:error, reason} -> {:error, "Failed to compare configurations: #{reason}"}
    end
  end

  @doc """
  Generates a human-readable diff report from a comparison result.
  
  Creates a detailed report that explains the differences between two
  configurations in terms that network engineers can easily understand.
  """
  @spec generate_diff_report(comparison_result()) :: {:ok, String.t()} | {:error, String.t()}
  def generate_diff_report(comparison) do
    try do
      report = build_diff_report(comparison)
      {:ok, report}
    rescue
      e -> {:error, "Failed to generate diff report: #{Exception.message(e)}"}
    end
  end

  @doc """
  Analyzes the impact of configuration changes.
  
  Determines the potential operational impact of changes between configurations,
  categorizing them by severity and providing recommendations.
  """
  @spec analyze_impact(comparison_result()) :: {:ok, map()} | {:error, String.t()}
  def analyze_impact(%{impact_analysis: impact_analysis}) when impact_analysis != %{analyzed: false} do
    {:ok, impact_analysis}
  end
  def analyze_impact(_comparison) do
    {:error, "Impact analysis not performed - enable with include_impact_analysis: true"}
  end

  @doc """
  Checks if two configurations are compatible.
  
  Determines if the configurations can coexist or if one can be migrated to the other
  without causing service disruption.
  """
  @spec are_compatible?(comparison_result()) :: boolean()
  def are_compatible?(%{compatibility_assessment: %{compatible: compatible}}) do
    compatible
  end
  def are_compatible?(_comparison), do: false

  @doc """
  Gets summary statistics about the configuration changes.
  """
  @spec get_change_statistics(comparison_result()) :: map()
  def get_change_statistics(%{change_statistics: stats}), do: stats
  def get_change_statistics(_), do: %{}

  # Private comparison functions

  defp compare_tlvs(parsed_a, parsed_b, include_unchanged) do
    tlvs_a = Map.new(parsed_a, fn tlv -> {tlv.type, tlv} end)
    tlvs_b = Map.new(parsed_b, fn tlv -> {tlv.type, tlv} end)
    
    all_types = MapSet.union(
      MapSet.new(Map.keys(tlvs_a)),
      MapSet.new(Map.keys(tlvs_b))
    )
    
    changes = Enum.map(all_types, fn type ->
      tlv_a = Map.get(tlvs_a, type)
      tlv_b = Map.get(tlvs_b, type)
      
      create_tlv_change(type, tlv_a, tlv_b)
    end)
    
    if include_unchanged do
      changes
    else
      Enum.filter(changes, &(&1.change_type != :unchanged))
    end
  end

  defp create_tlv_change(type, nil, tlv_b) do
    # Added TLV
    %{
      change_type: :added,
      tlv_type: type,
      tlv_name: tlv_b.name || "TLV #{type}",
      old_value: nil,
      new_value: tlv_b.value,
      old_formatted: nil,
      new_formatted: tlv_b.formatted_value || format_binary_value(tlv_b.value),
      impact_level: assess_tlv_impact_level(type, :added),
      description: "Added #{tlv_b.name || "TLV #{type}"}"
    }
  end

  defp create_tlv_change(type, tlv_a, nil) do
    # Removed TLV
    %{
      change_type: :removed,
      tlv_type: type,
      tlv_name: tlv_a.name || "TLV #{type}",
      old_value: tlv_a.value,
      new_value: nil,
      old_formatted: tlv_a.formatted_value || format_binary_value(tlv_a.value),
      new_formatted: nil,
      impact_level: assess_tlv_impact_level(type, :removed),
      description: "Removed #{tlv_a.name || "TLV #{type}"}"
    }
  end

  defp create_tlv_change(type, tlv_a, tlv_b) do
    # Compare values
    if tlv_a.value == tlv_b.value do
      # Unchanged TLV
      %{
        change_type: :unchanged,
        tlv_type: type,
        tlv_name: tlv_a.name || "TLV #{type}",
        old_value: tlv_a.value,
        new_value: tlv_b.value,
        old_formatted: tlv_a.formatted_value || format_binary_value(tlv_a.value),
        new_formatted: tlv_b.formatted_value || format_binary_value(tlv_b.value),
        impact_level: :none,
        description: "Unchanged #{tlv_a.name || "TLV #{type}"}"
      }
    else
      # Modified TLV
      %{
        change_type: :modified,
        tlv_type: type,
        tlv_name: tlv_a.name || "TLV #{type}",
        old_value: tlv_a.value,
        new_value: tlv_b.value,
        old_formatted: tlv_a.formatted_value || format_binary_value(tlv_a.value),
        new_formatted: tlv_b.formatted_value || format_binary_value(tlv_b.value),
        impact_level: assess_tlv_impact_level(type, :modified),
        description: "Modified #{tlv_a.name || "TLV #{type}"}: #{tlv_a.formatted_value || "?"} → #{tlv_b.formatted_value || "?"}"
      }
    end
  end

  defp compare_summaries(analysis_a, analysis_b) do
    changes = []
    
    # Compare service tiers
    changes = if analysis_a.service_tier != analysis_b.service_tier do
      [%{
        category: :service_tier,
        change_type: :modified,
        description: "Service tier changed from #{analysis_a.service_tier} to #{analysis_b.service_tier}",
        impact_level: :high
      } | changes]
    else
      changes
    end
    
    # Compare configuration types
    changes = if analysis_a.configuration_type != analysis_b.configuration_type do
      [%{
        category: :configuration_type,
        change_type: :modified,
        description: "Configuration type changed from #{analysis_a.configuration_type} to #{analysis_b.configuration_type}",
        impact_level: :high
      } | changes]
    else
      changes
    end
    
    # Compare service flow counts
    sf_a = analysis_a.performance_metrics.total_service_flows
    sf_b = analysis_b.performance_metrics.total_service_flows
    changes = if sf_a != sf_b do
      [%{
        category: :service_flows,
        change_type: :modified,
        description: "Service flows changed from #{sf_a} to #{sf_b}",
        impact_level: if(sf_b > sf_a, do: :medium, else: :high)
      } | changes]
    else
      changes
    end
    
    # Compare security levels
    sec_a = analysis_a.security_assessment.security_level
    sec_b = analysis_b.security_assessment.security_level
    changes = if sec_a != sec_b do
      [%{
        category: :security,
        change_type: :modified,
        description: "Security level changed from #{sec_a} to #{sec_b}",
        impact_level: if(sec_b > sec_a, do: :low, else: :high)
      } | changes]
    else
      changes
    end
    
    changes
  end

  defp analyze_change_impact(tlv_changes, analysis_a, analysis_b) do
    critical_changes = Enum.filter(tlv_changes, &(&1.impact_level == :critical))
    high_changes = Enum.filter(tlv_changes, &(&1.impact_level == :high))
    medium_changes = Enum.filter(tlv_changes, &(&1.impact_level == :medium))
    
    overall_impact = cond do
      length(critical_changes) > 0 -> :critical
      length(high_changes) > 0 -> :high
      length(medium_changes) > 0 -> :medium
      true -> :low
    end
    
    service_disruption_risk = assess_service_disruption_risk(tlv_changes)
    performance_impact = assess_performance_impact(analysis_a, analysis_b)
    security_impact = assess_security_impact(analysis_a, analysis_b)
    
    %{
      overall_impact: overall_impact,
      service_disruption_risk: service_disruption_risk,
      performance_impact: performance_impact,
      security_impact: security_impact,
      critical_changes_count: length(critical_changes),
      high_changes_count: length(high_changes),
      medium_changes_count: length(medium_changes),
      recommendations: generate_change_recommendations(tlv_changes, overall_impact)
    }
  end

  defp assess_compatibility(analysis_a, analysis_b, tlv_changes) do
    incompatible_changes = Enum.filter(tlv_changes, fn change ->
      change.impact_level == :critical or 
      (change.change_type == :removed and change.impact_level == :high)
    end)
    
    version_compatible = analysis_a.compliance_status.docsis_version == 
                        analysis_b.compliance_status.docsis_version
    
    compatible = length(incompatible_changes) == 0 and version_compatible
    
    %{
      compatible: compatible,
      version_compatible: version_compatible,
      incompatible_changes: length(incompatible_changes),
      migration_difficulty: assess_migration_difficulty(tlv_changes),
      compatibility_notes: generate_compatibility_notes(incompatible_changes, version_compatible)
    }
  end

  defp generate_change_statistics(tlv_changes) do
    total = length(tlv_changes)
    added = Enum.count(tlv_changes, &(&1.change_type == :added))
    removed = Enum.count(tlv_changes, &(&1.change_type == :removed))
    modified = Enum.count(tlv_changes, &(&1.change_type == :modified))
    unchanged = Enum.count(tlv_changes, &(&1.change_type == :unchanged))
    
    critical = Enum.count(tlv_changes, &(&1.impact_level == :critical))
    high = Enum.count(tlv_changes, &(&1.impact_level == :high))
    medium = Enum.count(tlv_changes, &(&1.impact_level == :medium))
    low = Enum.count(tlv_changes, &(&1.impact_level == :low))
    
    %{
      total_changes: total,
      added_count: added,
      removed_count: removed,
      modified_count: modified,
      unchanged_count: unchanged,
      critical_impact_count: critical,
      high_impact_count: high,
      medium_impact_count: medium,
      low_impact_count: low,
      change_percentage: if(total > 0, do: Float.round((total - unchanged) / total * 100, 1), else: 0.0)
    }
  end

  defp extract_comparison_summary(analysis) do
    %{
      configuration_type: analysis.configuration_type,
      service_tier: analysis.service_tier,
      total_tlvs: length(analysis.tlv_analysis),
      service_flows: analysis.performance_metrics.total_service_flows,
      security_level: analysis.security_assessment.security_level,
      compliance_status: analysis.compliance_status.compliant
    }
  end

  # Helper functions for impact assessment

  defp assess_tlv_impact_level(type, change_type) do
    case {type, change_type} do
      # Critical TLVs
      {t, _} when t in [1, 2, 3] -> :critical
      
      # High impact TLVs
      {t, :removed} when t in [12, 21, 24, 25, 26] -> :high
      {t, _} when t in [24, 25, 26] -> :high  # Service flows
      
      # Medium impact TLVs
      {t, _} when t in [12, 21, 29, 30] -> :medium
      
      # Low impact for most others
      _ -> :low
    end
  end

  defp assess_service_disruption_risk(tlv_changes) do
    critical_removed = Enum.any?(tlv_changes, fn change ->
      change.change_type == :removed and change.impact_level == :critical
    end)
    
    service_flow_changes = Enum.any?(tlv_changes, fn change ->
      change.tlv_type in [24, 25, 26] and change.change_type in [:removed, :modified]
    end)
    
    cond do
      critical_removed -> :high
      service_flow_changes -> :medium
      true -> :low
    end
  end

  defp assess_performance_impact(analysis_a, analysis_b) do
    sf_a = analysis_a.performance_metrics.total_service_flows
    sf_b = analysis_b.performance_metrics.total_service_flows
    
    complexity_a = analysis_a.performance_metrics.configuration_complexity
    complexity_b = analysis_b.performance_metrics.configuration_complexity
    
    cond do
      sf_b < sf_a -> :negative  # Lost service flows
      complexity_b > complexity_a * 1.5 -> :positive  # Significantly more complex
      complexity_b < complexity_a * 0.5 -> :negative  # Significantly less complex
      true -> :neutral
    end
  end

  defp assess_security_impact(analysis_a, analysis_b) do
    sec_a = analysis_a.security_assessment.security_level
    sec_b = analysis_b.security_assessment.security_level
    
    security_levels = [:low, :low_medium, :medium, :medium_high, :high]
    index_a = Enum.find_index(security_levels, &(&1 == sec_a)) || 0
    index_b = Enum.find_index(security_levels, &(&1 == sec_b)) || 0
    
    cond do
      index_b > index_a -> :improved
      index_b < index_a -> :degraded
      true -> :unchanged
    end
  end

  defp assess_migration_difficulty(tlv_changes) do
    critical_changes = Enum.count(tlv_changes, &(&1.impact_level == :critical))
    high_changes = Enum.count(tlv_changes, &(&1.impact_level == :high))
    removed_changes = Enum.count(tlv_changes, &(&1.change_type == :removed))
    
    cond do
      critical_changes > 2 -> :very_difficult
      critical_changes > 0 or high_changes > 3 -> :difficult
      high_changes > 1 or removed_changes > 2 -> :moderate
      true -> :easy
    end
  end

  defp generate_change_recommendations(tlv_changes, overall_impact) do
    recommendations = []
    
    recommendations = case overall_impact do
      :critical -> ["CRITICAL: Thoroughly test configuration changes before deployment", "Consider staged rollout with rollback plan" | recommendations]
      :high -> ["HIGH IMPACT: Test changes in lab environment first", "Monitor service closely after deployment" | recommendations]
      :medium -> ["MEDIUM IMPACT: Review changes with network team", "Schedule deployment during maintenance window" | recommendations]
      :low -> ["LOW IMPACT: Changes appear safe for deployment" | recommendations]
    end
    
    # Check for specific types of changes
    service_flow_changes = Enum.any?(tlv_changes, &(&1.tlv_type in [24, 25, 26]))
    recommendations = if service_flow_changes do
      ["Service flow changes detected - verify QoS policies are correct" | recommendations]
    else
      recommendations
    end
    
    frequency_changes = Enum.any?(tlv_changes, &(&1.tlv_type == 1))
    recommendations = if frequency_changes do
      ["Frequency changes detected - ensure new frequency is available and licensed" | recommendations]
    else
      recommendations
    end
    
    recommendations
  end

  defp generate_compatibility_notes(incompatible_changes, version_compatible) do
    notes = []
    
    notes = if not version_compatible do
      ["DOCSIS version mismatch - configurations may not be fully compatible" | notes]
    else
      notes
    end
    
    if length(incompatible_changes) > 0 do
      ["#{length(incompatible_changes)} incompatible changes detected" | notes]
    else
      notes
    end
  end

  defp format_binary_value(binary) when is_binary(binary) do
    if String.printable?(binary) do
      "\"#{binary}\""
    else
      Base.encode16(binary)
    end
  end
  defp format_binary_value(value), do: inspect(value)

  defp build_diff_report(comparison) do
    """
    # DOCSIS Configuration Comparison Report
    
    ## Configuration Overview
    
    **Configuration A (Baseline):**
    - Type: #{comparison.config_a_summary.configuration_type}
    - Service Tier: #{comparison.config_a_summary.service_tier}
    - Total TLVs: #{comparison.config_a_summary.total_tlvs}
    - Service Flows: #{comparison.config_a_summary.service_flows}
    - Security Level: #{comparison.config_a_summary.security_level}
    - DOCSIS Compliant: #{comparison.config_a_summary.compliance_status}
    
    **Configuration B (Target):**
    - Type: #{comparison.config_b_summary.configuration_type}
    - Service Tier: #{comparison.config_b_summary.service_tier}
    - Total TLVs: #{comparison.config_b_summary.total_tlvs}
    - Service Flows: #{comparison.config_b_summary.service_flows}
    - Security Level: #{comparison.config_b_summary.security_level}
    - DOCSIS Compliant: #{comparison.config_b_summary.compliance_status}
    
    ## Change Summary
    
    #{build_change_statistics_section(comparison.change_statistics)}
    
    ## Impact Analysis
    
    #{build_impact_analysis_section(comparison.impact_analysis)}
    
    ## Detailed Changes
    
    #{build_detailed_changes_section(comparison.tlv_changes)}
    
    ## Compatibility Assessment
    
    #{build_compatibility_section(comparison.compatibility_assessment)}
    
    ## Summary-Level Changes
    
    #{build_summary_changes_section(comparison.summary_changes)}
    """
  end

  defp build_change_statistics_section(stats) do
    """
    - **Total Changes**: #{stats.total_changes}
    - **Added TLVs**: #{stats.added_count}
    - **Removed TLVs**: #{stats.removed_count}
    - **Modified TLVs**: #{stats.modified_count}
    - **Change Percentage**: #{stats.change_percentage}%
    
    **Impact Distribution:**
    - Critical: #{stats.critical_impact_count}
    - High: #{stats.high_impact_count}
    - Medium: #{stats.medium_impact_count}
    - Low: #{stats.low_impact_count}
    """
  end

  defp build_impact_analysis_section(%{analyzed: false}) do
    "Impact analysis was not performed."
  end
  defp build_impact_analysis_section(impact) do
    """
    - **Overall Impact**: #{String.upcase(to_string(impact.overall_impact))}
    - **Service Disruption Risk**: #{String.upcase(to_string(impact.service_disruption_risk))}
    - **Performance Impact**: #{String.upcase(to_string(impact.performance_impact))}
    - **Security Impact**: #{String.upcase(to_string(impact.security_impact))}
    
    **Recommendations:**
    #{Enum.map(impact.recommendations, &("- #{&1}")) |> Enum.join("\n")}
    """
  end

  defp build_detailed_changes_section(tlv_changes) do
    if length(tlv_changes) == 0 do
      "No TLV changes detected."
    else
      changes_by_type = Enum.group_by(tlv_changes, & &1.change_type)
      
      sections = []
      
      sections = if Map.has_key?(changes_by_type, :added) do
        added_section = """
        ### Added TLVs
        
        #{Enum.map(changes_by_type[:added], &format_tlv_change/1) |> Enum.join("\n")}
        """
        [added_section | sections]
      else
        sections
      end
      
      sections = if Map.has_key?(changes_by_type, :removed) do
        removed_section = """
        ### Removed TLVs
        
        #{Enum.map(changes_by_type[:removed], &format_tlv_change/1) |> Enum.join("\n")}
        """
        [removed_section | sections]
      else
        sections
      end
      
      sections = if Map.has_key?(changes_by_type, :modified) do
        modified_section = """
        ### Modified TLVs
        
        #{Enum.map(changes_by_type[:modified], &format_tlv_change/1) |> Enum.join("\n")}
        """
        [modified_section | sections]
      else
        sections
      end
      
      Enum.join(Enum.reverse(sections), "\n")
    end
  end

  defp build_compatibility_section(%{checked: false}) do
    "Compatibility assessment was not performed."
  end
  defp build_compatibility_section(compatibility) do
    """
    - **Compatible**: #{if compatibility.compatible, do: "Yes", else: "No"}
    - **Version Compatible**: #{if compatibility.version_compatible, do: "Yes", else: "No"}
    - **Migration Difficulty**: #{String.upcase(to_string(compatibility.migration_difficulty))}
    - **Incompatible Changes**: #{compatibility.incompatible_changes}
    
    **Notes:**
    #{Enum.map(compatibility.compatibility_notes, &("- #{&1}")) |> Enum.join("\n")}
    """
  end

  defp build_summary_changes_section(summary_changes) do
    if length(summary_changes) == 0 do
      "No summary-level changes detected."
    else
      Enum.map(summary_changes, fn change ->
        "- **#{String.upcase(to_string(change.impact_level))}**: #{change.description}"
      end) |> Enum.join("\n")
    end
  end

  defp format_tlv_change(change) do
    impact_indicator = case change.impact_level do
      :critical -> "🔴"
      :high -> "🟠"
      :medium -> "🟡"
      :low -> "🟢"
      :none -> "⚪"
    end
    
    case change.change_type do
      :added ->
        "#{impact_indicator} **TLV #{change.tlv_type}** (#{change.tlv_name}): Added with value `#{change.new_formatted}`"
      :removed ->
        "#{impact_indicator} **TLV #{change.tlv_type}** (#{change.tlv_name}): Removed (was `#{change.old_formatted}`)"
      :modified ->
        "#{impact_indicator} **TLV #{change.tlv_type}** (#{change.tlv_name}): Changed from `#{change.old_formatted}` to `#{change.new_formatted}`"
      :unchanged ->
        "#{impact_indicator} **TLV #{change.tlv_type}** (#{change.tlv_name}): Unchanged (`#{change.old_formatted}`)"
    end
  end
end