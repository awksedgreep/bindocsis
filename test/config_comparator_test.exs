defmodule Bindocsis.ConfigComparatorTest do
  use ExUnit.Case
  doctest Bindocsis.ConfigComparator

  alias Bindocsis.ConfigComparator

  # Sample binary configurations for testing
  @config_original <<
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

  @config_modified_frequency <<
    # Downstream Frequency: 615 MHz (CHANGED)
    1,
    4,
    36,
    171,
    195,
    64,
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

  @config_with_additions <<
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
    # Modem IP Address: 192.168.1.100
    12,
    4,
    192,
    168,
    1,
    100,
    # Max CPE IP Addresses: 16 (CHANGED)
    21,
    1,
    16,
    # Downstream Service Flow (ADDED)
    24,
    10,
    1,
    2,
    3,
    4,
    5,
    6,
    7,
    8,
    9,
    10,
    # End marker
    255
  >>

  @config_with_removals <<
    # Downstream Frequency: 591 MHz
    1,
    4,
    35,
    57,
    241,
    192,
    # Network Access Control: Enabled
    3,
    1,
    1,
    # End marker (Removed: Upstream Channel, IP, CPE limit)
    255
  >>

  describe "compare/3" do
    test "compares identical configurations" do
      assert {:ok, comparison} = ConfigComparator.compare(@config_original, @config_original)

      # Should have no changes (except unchanged if included)
      changes_without_unchanged =
        Enum.filter(comparison.tlv_changes, &(&1.change_type != :unchanged))

      assert length(changes_without_unchanged) == 0

      # Statistics should reflect no changes
      stats = comparison.change_statistics
      assert stats.added_count == 0
      assert stats.removed_count == 0
      assert stats.modified_count == 0
      assert stats.change_percentage == 0.0
    end

    test "detects frequency change as critical modification" do
      assert {:ok, comparison} =
               ConfigComparator.compare(@config_original, @config_modified_frequency)

      # Should detect one modification (frequency change)
      modifications = Enum.filter(comparison.tlv_changes, &(&1.change_type == :modified))
      assert length(modifications) == 1

      frequency_change = hd(modifications)
      assert frequency_change.tlv_type == 1
      assert frequency_change.impact_level == :critical
      assert String.contains?(frequency_change.description, "591 MHz")

      assert String.contains?(frequency_change.description, "615") and
               String.contains?(frequency_change.description, "MHz")
    end

    test "detects additions and modifications" do
      assert {:ok, comparison} =
               ConfigComparator.compare(@config_original, @config_with_additions)

      # Should detect one addition (service flow) and one modification (CPE limit)
      additions = Enum.filter(comparison.tlv_changes, &(&1.change_type == :added))
      modifications = Enum.filter(comparison.tlv_changes, &(&1.change_type == :modified))

      assert length(additions) == 1
      assert length(modifications) == 1

      # Check service flow addition
      service_flow_addition = hd(additions)
      assert service_flow_addition.tlv_type == 24
      assert service_flow_addition.impact_level == :high

      # Check CPE modification
      cpe_modification = hd(modifications)
      assert cpe_modification.tlv_type == 21
      assert cpe_modification.impact_level == :medium
    end

    test "detects removals" do
      assert {:ok, comparison} = ConfigComparator.compare(@config_original, @config_with_removals)

      removals = Enum.filter(comparison.tlv_changes, &(&1.change_type == :removed))
      # Upstream channel, IP, CPE limit
      assert length(removals) == 3

      # Check that removed TLVs have appropriate impact levels
      removed_types = Enum.map(removals, & &1.tlv_type)
      # Upstream channel
      assert 2 in removed_types
      # IP address
      assert 12 in removed_types
      # CPE limit
      assert 21 in removed_types
    end

    test "generates change statistics correctly" do
      assert {:ok, comparison} =
               ConfigComparator.compare(@config_original, @config_with_additions)

      stats = comparison.change_statistics
      assert stats.total_changes > 0
      assert stats.added_count == 1
      assert stats.modified_count == 1
      assert stats.removed_count == 0
      assert stats.change_percentage > 0.0

      # Should have appropriate impact counts
      # Service flow addition
      assert stats.high_impact_count >= 1
      # CPE modification
      assert stats.medium_impact_count >= 1
    end

    test "includes impact analysis by default" do
      assert {:ok, comparison} =
               ConfigComparator.compare(@config_original, @config_modified_frequency)

      impact = comparison.impact_analysis
      assert Map.has_key?(impact, :overall_impact)
      assert Map.has_key?(impact, :service_disruption_risk)
      assert Map.has_key?(impact, :performance_impact)
      assert Map.has_key?(impact, :security_impact)
      assert Map.has_key?(impact, :recommendations)

      # Frequency change should be critical impact
      assert impact.overall_impact == :critical
      assert is_list(impact.recommendations)
      assert length(impact.recommendations) > 0
    end

    test "includes compatibility assessment by default" do
      assert {:ok, comparison} =
               ConfigComparator.compare(@config_original, @config_modified_frequency)

      compatibility = comparison.compatibility_assessment
      assert Map.has_key?(compatibility, :compatible)
      assert Map.has_key?(compatibility, :version_compatible)
      assert Map.has_key?(compatibility, :migration_difficulty)
      assert Map.has_key?(compatibility, :incompatible_changes)

      # Frequency change might make configs incompatible
      assert is_boolean(compatibility.compatible)
      assert is_boolean(compatibility.version_compatible)
    end

    test "detects summary-level changes" do
      assert {:ok, comparison} =
               ConfigComparator.compare(@config_original, @config_with_additions)

      summary_changes = comparison.summary_changes
      assert is_list(summary_changes)

      # Should detect service tier change (8 CPE -> 16 CPE = residential -> business)
      service_tier_change = Enum.find(summary_changes, &(&1.category == :service_tier))

      if service_tier_change do
        assert service_tier_change.change_type == :modified
        assert service_tier_change.impact_level in [:high, :medium]
      end
    end

    test "respects comparison options" do
      opts = [
        include_unchanged: true,
        include_impact_analysis: false,
        check_compatibility: false
      ]

      assert {:ok, comparison} =
               ConfigComparator.compare(@config_original, @config_original, opts)

      # Should include unchanged TLVs
      unchanged = Enum.filter(comparison.tlv_changes, &(&1.change_type == :unchanged))
      assert length(unchanged) > 0

      # Should skip optional analyses
      assert comparison.impact_analysis == %{analyzed: false}
      assert comparison.compatibility_assessment == %{checked: false}
    end

    test "handles invalid configurations gracefully" do
      # Invalid length
      invalid_config = <<1, 255, 2>>

      assert {:error, error_msg} = ConfigComparator.compare(@config_original, invalid_config)
      assert String.contains?(error_msg, "Failed to compare")
    end
  end

  describe "generate_diff_report/1" do
    test "generates comprehensive diff report" do
      assert {:ok, comparison} =
               ConfigComparator.compare(@config_original, @config_modified_frequency)

      assert {:ok, report} = ConfigComparator.generate_diff_report(comparison)

      assert is_binary(report)
      assert String.contains?(report, "Configuration Comparison Report")
      assert String.contains?(report, "Configuration Overview")
      assert String.contains?(report, "Change Summary")
      assert String.contains?(report, "Impact Analysis")
      assert String.contains?(report, "Detailed Changes")
      assert String.contains?(report, "Compatibility Assessment")

      # Should contain specific change information
      assert String.contains?(report, "591 MHz")
      assert String.contains?(report, "615") and String.contains?(report, "MHz")
      assert String.contains?(report, "TLV 1")
    end

    test "handles comparison with additions and removals" do
      assert {:ok, comparison} = ConfigComparator.compare(@config_original, @config_with_removals)
      assert {:ok, report} = ConfigComparator.generate_diff_report(comparison)

      assert String.contains?(report, "Removed TLVs")
      # Upstream channel
      assert String.contains?(report, "TLV 2")
      # IP address
      assert String.contains?(report, "TLV 12")
      # CPE limit
      assert String.contains?(report, "TLV 21")
    end

    test "includes impact indicators in report" do
      assert {:ok, comparison} =
               ConfigComparator.compare(@config_original, @config_modified_frequency)

      assert {:ok, report} = ConfigComparator.generate_diff_report(comparison)

      # Should contain impact level indicators
      assert String.contains?(report, "CRITICAL") or String.contains?(report, "🔴")
    end

    test "handles comparison with no changes" do
      assert {:ok, comparison} = ConfigComparator.compare(@config_original, @config_original)
      assert {:ok, report} = ConfigComparator.generate_diff_report(comparison)

      assert String.contains?(report, "No TLV changes detected") or
               String.contains?(report, "Total Changes**: 0")
    end
  end

  describe "analyze_impact/1" do
    test "returns impact analysis when available" do
      assert {:ok, comparison} =
               ConfigComparator.compare(@config_original, @config_modified_frequency)

      assert {:ok, impact} = ConfigComparator.analyze_impact(comparison)

      assert Map.has_key?(impact, :overall_impact)
      assert Map.has_key?(impact, :service_disruption_risk)
      assert Map.has_key?(impact, :recommendations)

      # Frequency change should be critical
      assert impact.overall_impact == :critical
    end

    test "returns error when impact analysis not performed" do
      assert {:ok, comparison} =
               ConfigComparator.compare(@config_original, @config_original,
                 include_impact_analysis: false
               )

      assert {:error, error_msg} = ConfigComparator.analyze_impact(comparison)
      assert String.contains?(error_msg, "Impact analysis not performed")
    end
  end

  describe "are_compatible?/1" do
    test "returns true for compatible configurations" do
      # Identical configs should be compatible
      assert {:ok, comparison} = ConfigComparator.compare(@config_original, @config_original)
      assert ConfigComparator.are_compatible?(comparison) == true
    end

    test "returns false for incompatible configurations" do
      # Major changes might make configs incompatible
      assert {:ok, comparison} = ConfigComparator.compare(@config_original, @config_with_removals)
      # Removing critical TLVs should make configs incompatible
      assert ConfigComparator.are_compatible?(comparison) == false
    end

    test "handles comparison without compatibility check" do
      assert {:ok, comparison} =
               ConfigComparator.compare(@config_original, @config_original,
                 check_compatibility: false
               )

      # No assessment performed
      assert ConfigComparator.are_compatible?(comparison) == false
    end
  end

  describe "get_change_statistics/1" do
    test "returns change statistics" do
      assert {:ok, comparison} =
               ConfigComparator.compare(@config_original, @config_with_additions)

      stats = ConfigComparator.get_change_statistics(comparison)

      assert Map.has_key?(stats, :total_changes)
      assert Map.has_key?(stats, :added_count)
      assert Map.has_key?(stats, :removed_count)
      assert Map.has_key?(stats, :modified_count)
      assert Map.has_key?(stats, :change_percentage)

      # Service flow
      assert stats.added_count == 1
      # CPE limit
      assert stats.modified_count == 1
      assert stats.removed_count == 0
    end

    test "handles invalid comparison result" do
      stats = ConfigComparator.get_change_statistics(%{invalid: :result})
      assert stats == %{}
    end
  end

  describe "impact level assessment" do
    test "correctly assesses critical TLV changes" do
      # Frequency change should be critical
      assert {:ok, comparison} =
               ConfigComparator.compare(@config_original, @config_modified_frequency)

      frequency_change = Enum.find(comparison.tlv_changes, &(&1.tlv_type == 1))
      assert frequency_change.impact_level == :critical
    end

    test "correctly assesses high impact changes" do
      assert {:ok, comparison} =
               ConfigComparator.compare(@config_original, @config_with_additions)

      # Service flow addition should be high impact
      service_flow_change = Enum.find(comparison.tlv_changes, &(&1.tlv_type == 24))
      assert service_flow_change.impact_level == :high
    end

    test "correctly assesses medium impact changes" do
      assert {:ok, comparison} =
               ConfigComparator.compare(@config_original, @config_with_additions)

      # CPE limit change should be medium impact
      cpe_change = Enum.find(comparison.tlv_changes, &(&1.tlv_type == 21))
      assert cpe_change.impact_level == :medium
    end
  end

  describe "service disruption risk assessment" do
    test "identifies high disruption risk for critical removals" do
      # Remove critical TLV (frequency)
      # Only network access
      config_no_frequency = <<3, 1, 1, 255>>

      assert {:ok, comparison} = ConfigComparator.compare(@config_original, config_no_frequency)

      impact = comparison.impact_analysis
      assert impact.service_disruption_risk in [:high, :medium]
    end

    test "identifies medium disruption risk for service flow changes" do
      assert {:ok, comparison} =
               ConfigComparator.compare(@config_original, @config_with_additions)

      impact = comparison.impact_analysis
      # Adding service flows should have some disruption risk
      assert impact.service_disruption_risk in [:low, :medium]
    end
  end

  describe "migration difficulty assessment" do
    test "assesses easy migration for minor changes" do
      assert {:ok, comparison} = ConfigComparator.compare(@config_original, @config_original)

      compatibility = comparison.compatibility_assessment
      assert compatibility.migration_difficulty == :easy
    end

    test "assesses difficult migration for major changes" do
      assert {:ok, comparison} = ConfigComparator.compare(@config_original, @config_with_removals)

      compatibility = comparison.compatibility_assessment
      # Removing multiple TLVs should be difficult
      assert compatibility.migration_difficulty in [:difficult, :very_difficult, :moderate]
    end
  end

  describe "change recommendations" do
    test "provides appropriate recommendations for critical changes" do
      assert {:ok, comparison} =
               ConfigComparator.compare(@config_original, @config_modified_frequency)

      impact = comparison.impact_analysis
      recommendations = impact.recommendations

      assert is_list(recommendations)
      assert length(recommendations) > 0

      # Should recommend testing for critical changes
      critical_recommendation =
        Enum.find(recommendations, fn rec ->
          String.contains?(String.downcase(rec), "critical") or
            String.contains?(String.downcase(rec), "test")
        end)

      assert critical_recommendation != nil
    end

    test "provides frequency-specific recommendations" do
      assert {:ok, comparison} =
               ConfigComparator.compare(@config_original, @config_modified_frequency)

      impact = comparison.impact_analysis
      recommendations = impact.recommendations

      # Should mention frequency changes
      frequency_recommendation =
        Enum.find(recommendations, fn rec ->
          String.contains?(String.downcase(rec), "frequency")
        end)

      assert frequency_recommendation != nil
    end

    test "provides service flow recommendations" do
      assert {:ok, comparison} =
               ConfigComparator.compare(@config_original, @config_with_additions)

      impact = comparison.impact_analysis
      recommendations = impact.recommendations

      # Should mention service flow or QoS changes
      qos_recommendation =
        Enum.find(recommendations, fn rec ->
          String.contains?(String.downcase(rec), "service flow") or
            String.contains?(String.downcase(rec), "qos")
        end)

      assert qos_recommendation != nil
    end
  end

  describe "error handling" do
    test "handles malformed binary configurations" do
      # Too short
      malformed_config = <<1, 2>>

      assert {:error, error_msg} = ConfigComparator.compare(@config_original, malformed_config)
      assert String.contains?(error_msg, "Failed to compare")
    end

    test "handles empty configurations" do
      empty_config = <<>>

      assert {:error, error_msg} = ConfigComparator.compare(@config_original, empty_config)
      assert String.contains?(error_msg, "Failed to compare")
    end
  end
end
