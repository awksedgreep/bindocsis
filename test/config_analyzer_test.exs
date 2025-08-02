defmodule Bindocsis.ConfigAnalyzerTest do
  use ExUnit.Case
  doctest Bindocsis.ConfigAnalyzer

  alias Bindocsis.ConfigAnalyzer

  # Sample binary configurations for testing
  @residential_config <<
    # Downstream Frequency: 591 MHz
    1, 4, 35, 57, 241, 192,
    # Upstream Channel ID: 2
    2, 1, 2,
    # Network Access Control: Enabled
    3, 1, 1,
    # Modem IP Address: 192.168.1.100
    12, 4, 192, 168, 1, 100,
    # Max CPE IP Addresses: 8
    21, 1, 8,
    # End marker
    255
  >>

  @business_config <<
    # Downstream Frequency: 615 MHz  
    1, 4, 36, 171, 195, 64,
    # Upstream Channel ID: 1
    2, 1, 1,
    # Network Access Control: Enabled
    3, 1, 1,
    # Modem IP Address: 10.1.1.100
    12, 4, 10, 1, 1, 100,
    # Max CPE IP Addresses: 32
    21, 1, 32,
    # Downstream Service Flow
    24, 10, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10,
    # Upstream Service Flow
    25, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19, 20,
    # End marker
    255
  >>

  @minimal_config <<
    # Downstream Frequency: 591 MHz
    1, 4, 35, 57, 241, 192,
    # Network Access Control: Enabled
    3, 1, 1,
    # End marker
    255
  >>

  describe "analyze/2" do
    test "analyzes residential configuration correctly" do
      assert {:ok, analysis} = ConfigAnalyzer.analyze(@residential_config)
      
      assert analysis.configuration_type == :cable_modem
      assert analysis.service_tier == :residential
      assert is_binary(analysis.summary)
      assert String.contains?(analysis.summary, "Residential")
      
      # Check key settings
      assert analysis.key_settings.downstream_frequency == "591 MHz" 
      assert analysis.key_settings.max_cpe_count == "8"
      assert analysis.key_settings.service_flows == 0
      
      # Check performance metrics
      assert analysis.performance_metrics.total_service_flows == 0
      assert analysis.performance_metrics.has_qos_configuration == false
      assert analysis.performance_metrics.configuration_complexity >= 3
    end

    test "analyzes business configuration correctly" do
      assert {:ok, analysis} = ConfigAnalyzer.analyze(@business_config)
      
      assert analysis.configuration_type == :cable_modem
      assert analysis.service_tier == :business
      assert String.contains?(analysis.summary, "Business")
      
      # Check key settings for business features
      assert analysis.key_settings.max_cpe_count == "32"
      assert analysis.key_settings.service_flows == 2
      
      # Check performance metrics
      assert analysis.performance_metrics.total_service_flows == 2
      assert analysis.performance_metrics.has_qos_configuration == true
      assert analysis.performance_metrics.configuration_complexity > 5
    end

    test "analyzes minimal configuration correctly" do
      assert {:ok, analysis} = ConfigAnalyzer.analyze(@minimal_config)
      
      assert analysis.configuration_type == :cable_modem
      assert analysis.service_tier == :standard  # No CPE limit specified
      assert String.contains?(analysis.summary, "minimal")
      
      # Check that it identifies basic configuration
      assert analysis.performance_metrics.total_service_flows == 0
      assert analysis.performance_metrics.configuration_complexity < 4
    end

    test "includes compliance checking by default" do
      assert {:ok, analysis} = ConfigAnalyzer.analyze(@residential_config)
      
      # Should have compliance status
      assert Map.has_key?(analysis.compliance_status, :compliant)
      assert Map.has_key?(analysis.compliance_status, :docsis_version)
      assert analysis.compliance_status.docsis_version == "3.1"
    end

    test "includes security assessment by default" do
      assert {:ok, analysis} = ConfigAnalyzer.analyze(@residential_config)
      
      # Should have security assessment
      assert Map.has_key?(analysis.security_assessment, :security_level)
      assert Map.has_key?(analysis.security_assessment, :has_baseline_privacy)
      
      # Basic config shouldn't have advanced security
      assert analysis.security_assessment.security_level == :low
      assert analysis.security_assessment.has_baseline_privacy == false
    end

    test "includes optimization suggestions by default" do
      assert {:ok, analysis} = ConfigAnalyzer.analyze(@minimal_config)
      
      # Should have suggestions for minimal config
      assert is_list(analysis.optimization_suggestions)
      assert length(analysis.optimization_suggestions) > 0
      
      # Should suggest QoS for minimal config
      qos_suggestion = Enum.find(analysis.optimization_suggestions, fn suggestion ->
        String.contains?(suggestion, "Quality of Service")
      end)
      assert qos_suggestion != nil
    end

    test "includes TLV analysis by default" do
      assert {:ok, analysis} = ConfigAnalyzer.analyze(@residential_config)
      
      assert is_list(analysis.tlv_analysis)
      assert length(analysis.tlv_analysis) > 0
      
      # Check first TLV analysis
      first_tlv = hd(analysis.tlv_analysis)
      assert Map.has_key?(first_tlv, :type)
      assert Map.has_key?(first_tlv, :name)
      assert Map.has_key?(first_tlv, :category)
      assert Map.has_key?(first_tlv, :importance)
    end

    test "respects analysis options" do
      opts = [
        include_tlv_details: false,
        check_compliance: false,
        include_security_check: false,
        suggest_optimizations: false
      ]
      
      assert {:ok, analysis} = ConfigAnalyzer.analyze(@residential_config, opts)
      
      # Should skip optional analyses
      assert analysis.tlv_analysis == []
      assert analysis.compliance_status == %{checked: false}
      assert analysis.security_assessment == %{checked: false}
      assert analysis.optimization_suggestions == []
    end

    test "handles different DOCSIS versions" do
      assert {:ok, analysis} = ConfigAnalyzer.analyze(@residential_config, docsis_version: "3.0")
      
      assert analysis.compliance_status.docsis_version == "3.0"
    end

    test "handles invalid binary data gracefully" do
      invalid_binary = <<1, 255, 2>>  # Invalid length
      
      assert {:error, error_msg} = ConfigAnalyzer.analyze(invalid_binary)
      assert String.contains?(error_msg, "Failed to parse")
    end
  end

  describe "generate_summary/1" do
    test "generates summary from analysis result" do
      assert {:ok, analysis} = ConfigAnalyzer.analyze(@residential_config)
      assert {:ok, summary} = ConfigAnalyzer.generate_summary(analysis)
      
      assert is_binary(summary)
      assert String.contains?(summary, "Residential")
      assert String.contains?(summary, "Cable Modem")
      assert String.contains?(summary, "591 MHz")
    end

    test "handles invalid analysis result" do
      assert {:error, _} = ConfigAnalyzer.generate_summary(%{invalid: :result})
    end
  end

  describe "get_optimization_suggestions/1" do
    test "gets suggestions from analysis result" do
      assert {:ok, analysis} = ConfigAnalyzer.analyze(@minimal_config)
      assert {:ok, suggestions} = ConfigAnalyzer.get_optimization_suggestions(analysis)
      
      assert is_list(suggestions)
      assert length(suggestions) > 0
      
      # Should suggest QoS for minimal config
      qos_suggestion = Enum.find(suggestions, &String.contains?(&1, "Quality of Service"))
      assert qos_suggestion != nil
    end

    test "handles invalid analysis result" do
      assert {:error, _} = ConfigAnalyzer.get_optimization_suggestions(%{invalid: :result})
    end
  end

  describe "is_compliant?/1" do
    test "returns compliance status" do
      assert {:ok, analysis} = ConfigAnalyzer.analyze(@residential_config)
      
      # Should be compliant (has required TLVs 1, 2, 3)
      assert ConfigAnalyzer.is_compliant?(analysis) == true
    end

    test "handles invalid analysis result" do
      assert ConfigAnalyzer.is_compliant?(%{invalid: :result}) == false
    end
  end

  describe "configuration type detection" do
    test "detects cable modem configuration" do
      assert {:ok, analysis} = ConfigAnalyzer.analyze(@residential_config)
      assert analysis.configuration_type == :cable_modem
    end

    test "detects business configuration features" do
      # Business config with high CPE count and service flows
      assert {:ok, analysis} = ConfigAnalyzer.analyze(@business_config)
      assert analysis.configuration_type == :cable_modem
      
      # But should be detected as business service tier
      assert analysis.service_tier == :business
    end
  end

  describe "service tier detection" do
    test "detects residential tier" do
      assert {:ok, analysis} = ConfigAnalyzer.analyze(@residential_config)
      assert analysis.service_tier == :residential
    end

    test "detects business tier" do
      assert {:ok, analysis} = ConfigAnalyzer.analyze(@business_config)
      assert analysis.service_tier == :business
    end

    test "detects standard tier for minimal config" do
      assert {:ok, analysis} = ConfigAnalyzer.analyze(@minimal_config)
      assert analysis.service_tier == :standard
    end
  end

  describe "performance analysis" do
    test "analyzes basic configuration performance" do
      assert {:ok, analysis} = ConfigAnalyzer.analyze(@residential_config)
      
      metrics = analysis.performance_metrics
      assert metrics.total_service_flows == 0
      assert metrics.has_qos_configuration == false
      assert String.contains?(metrics.estimated_downstream_capacity, "Unknown")
      assert String.contains?(metrics.estimated_upstream_capacity, "Unknown")
      assert is_integer(metrics.configuration_complexity)
    end

    test "analyzes advanced configuration performance" do
      assert {:ok, analysis} = ConfigAnalyzer.analyze(@business_config)
      
      metrics = analysis.performance_metrics
      assert metrics.total_service_flows == 2
      assert metrics.has_qos_configuration == true
      assert String.contains?(metrics.estimated_downstream_capacity, "Standard")
      assert String.contains?(metrics.estimated_upstream_capacity, "Standard")
      assert metrics.configuration_complexity > 5
    end
  end

  describe "compliance checking" do
    test "checks for required TLVs" do
      assert {:ok, analysis} = ConfigAnalyzer.analyze(@residential_config)
      
      compliance = analysis.compliance_status
      assert compliance.compliant == true
      assert compliance.docsis_version == "3.1"
      assert is_list(compliance.issues)
      assert is_list(compliance.warnings)
    end

    test "can be disabled" do
      assert {:ok, analysis} = ConfigAnalyzer.analyze(@residential_config, check_compliance: false)
      
      assert analysis.compliance_status == %{checked: false}
    end
  end

  describe "security assessment" do
    test "assesses basic security configuration" do
      assert {:ok, analysis} = ConfigAnalyzer.analyze(@residential_config)
      
      security = analysis.security_assessment
      assert Map.has_key?(security, :has_baseline_privacy)
      assert Map.has_key?(security, :has_certificates)
      assert Map.has_key?(security, :security_level)
      assert is_list(security.issues)
      assert is_list(security.warnings)
      
      # Basic config should have low security
      assert security.security_level == :low
    end

    test "can be disabled" do
      assert {:ok, analysis} = ConfigAnalyzer.analyze(@residential_config, include_security_check: false)
      
      assert analysis.security_assessment == %{checked: false}
    end
  end

  describe "optimization suggestions" do
    test "suggests QoS for configurations without service flows" do
      assert {:ok, analysis} = ConfigAnalyzer.analyze(@residential_config)
      
      qos_suggestion = Enum.find(analysis.optimization_suggestions, fn suggestion ->
        String.contains?(suggestion, "Quality of Service") or String.contains?(suggestion, "QoS")
      end)
      assert qos_suggestion != nil
    end

    test "suggests CPE limit increases for low limits" do
      # Create config with very low CPE limit
      low_cpe_config = <<
        1, 4, 35, 57, 241, 192,  # Frequency
        3, 1, 1,                 # Network access
        21, 1, 2,                # Max CPE: only 2
        255
      >>
      
      assert {:ok, analysis} = ConfigAnalyzer.analyze(low_cpe_config)
      
      cpe_suggestion = Enum.find(analysis.optimization_suggestions, fn suggestion ->
        String.contains?(suggestion, "CPE") or String.contains?(suggestion, "customer devices")
      end)
      assert cpe_suggestion != nil
    end

    test "suggests vendor extensions for basic configs" do
      assert {:ok, analysis} = ConfigAnalyzer.analyze(@minimal_config)
      
      vendor_suggestion = Enum.find(analysis.optimization_suggestions, fn suggestion ->
        String.contains?(suggestion, "vendor") or String.contains?(suggestion, "extensions")
      end)
      assert vendor_suggestion != nil
    end

    test "can be disabled" do
      assert {:ok, analysis} = ConfigAnalyzer.analyze(@residential_config, suggest_optimizations: false)
      
      assert analysis.optimization_suggestions == []
    end
  end

  describe "TLV analysis" do
    test "analyzes individual TLVs" do
      assert {:ok, analysis} = ConfigAnalyzer.analyze(@residential_config)
      
      assert is_list(analysis.tlv_analysis)
      assert length(analysis.tlv_analysis) > 0
      
      # Check structure of TLV analysis
      first_tlv = hd(analysis.tlv_analysis)
      assert Map.has_key?(first_tlv, :type)
      assert Map.has_key?(first_tlv, :name)  
      assert Map.has_key?(first_tlv, :category)
      assert Map.has_key?(first_tlv, :importance)
      assert Map.has_key?(first_tlv, :formatted_value)
    end

    test "categorizes TLVs correctly" do
      assert {:ok, analysis} = ConfigAnalyzer.analyze(@residential_config)
      
      # Find downstream frequency TLV (type 1)
      freq_tlv = Enum.find(analysis.tlv_analysis, &(&1.type == 1))
      assert freq_tlv != nil
      assert freq_tlv.category == :channel_configuration
      assert freq_tlv.importance == :critical
      
      # Find network access TLV (type 3)
      access_tlv = Enum.find(analysis.tlv_analysis, &(&1.type == 3))
      assert access_tlv != nil
      assert access_tlv.category == :access_control
      assert access_tlv.importance == :critical
    end

    test "can be disabled" do
      assert {:ok, analysis} = ConfigAnalyzer.analyze(@residential_config, include_tlv_details: false)
      
      assert analysis.tlv_analysis == []
    end
  end

  describe "summary generation" do
    test "generates descriptive summaries for different configurations" do
      # Test residential config summary
      assert {:ok, residential_analysis} = ConfigAnalyzer.analyze(@residential_config)
      residential_summary = residential_analysis.summary
      
      assert String.contains?(residential_summary, "Residential")
      assert String.contains?(residential_summary, "Cable Modem")
      assert String.contains?(residential_summary, "591 MHz")
      assert String.contains?(residential_summary, "8 customer devices")
      
      # Test business config summary
      assert {:ok, business_analysis} = ConfigAnalyzer.analyze(@business_config)
      business_summary = business_analysis.summary
      
      assert String.contains?(business_summary, "Business")
      assert String.contains?(business_summary, "32 customer devices")
      assert String.contains?(business_summary, "2 service flow")
    end

    test "handles missing information gracefully" do
      assert {:ok, analysis} = ConfigAnalyzer.analyze(@minimal_config)
      
      # Should still generate readable summary even with minimal info
      assert is_binary(analysis.summary)
      assert String.length(analysis.summary) > 50
      assert String.contains?(analysis.summary, "minimal")
    end
  end

  describe "error handling" do
    test "handles corrupted binary data" do
      corrupted_binary = <<1, 2, 3>>  # Too short
      
      assert {:error, error_msg} = ConfigAnalyzer.analyze(corrupted_binary)
      assert String.contains?(error_msg, "Failed to parse")
    end

    test "handles empty binary data" do
      assert {:error, error_msg} = ConfigAnalyzer.analyze(<<>>)
      assert String.contains?(error_msg, "too small to analyze")
    end
  end
end