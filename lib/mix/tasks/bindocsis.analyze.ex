defmodule Mix.Tasks.Bindocsis.Analyze do
  @moduledoc """
  Create detailed analysis of DOCSIS configuration files.

  ## Usage

      mix bindocsis.analyze <input_file> [options]

  ## Examples

      # Create analysis file
      mix bindocsis.analyze config.cm

      # Show summary only (no file output)
      mix bindocsis.analyze config.cm --summary-only

      # Custom output file
      mix bindocsis.analyze config.cm --output analysis.json

      # Compare two configurations
      mix bindocsis.analyze config1.cm config2.cm --compare

  ## Options

  * `--output PATH` - Output file path (default: <input>_analysis.json)
  * `--summary-only` - Show summary without creating output file
  * `--compare` - Compare two configuration files
  * `--quiet` - Suppress progress output
  """

  use Mix.Task

  @shortdoc "Create detailed analysis of DOCSIS configuration files"

  @switches [
    output: :string,
    summary_only: :boolean,
    compare: :boolean,
    quiet: :boolean
  ]

  @aliases [
    o: :output,
    s: :summary_only,
    c: :compare,
    q: :quiet
  ]

  def run(args) do
    {opts, argv, _} = OptionParser.parse(args, switches: @switches, aliases: @aliases)

    case {argv, opts[:compare]} do
      {[], _} ->
        print_usage()

      {[file1, file2], true} ->
        compare_configs(file1, file2, opts)

      {[input_file], _} ->
        analyze_config(input_file, opts)

      {[_file1, _file2], false} ->
        Mix.shell().error("Error: Use --compare flag to compare two files")
        print_usage()

      _ ->
        print_usage()
    end
  end

  defp analyze_config(input_file, opts) do
    quiet = opts[:quiet] || false
    summary_only = opts[:summary_only] || false

    unless quiet do
      Mix.shell().info("📋 Analyzing DOCSIS configuration: #{input_file}")
    end

    case Bindocsis.parse_file(input_file) do
      {:ok, tlvs} ->
        summary = create_detailed_summary(tlvs, input_file)

        # Always show summary
        print_summary(summary)

        unless summary_only do
          output_file = opts[:output] || String.replace(input_file, ~r/\.[^.]+$/, "_analysis.json")

          # Create enhanced JSON analysis
          {:ok, pretty_json} = Bindocsis.generate(tlvs,
            format: :json,
            pretty: true,
            include_names: true,
            detect_subtlvs: true
          )

          enhanced_json = add_analysis_to_json(pretty_json, summary)
          File.write!(output_file, enhanced_json)

          unless quiet do
            Mix.shell().info("📄 Detailed analysis saved: #{output_file}")
            Mix.shell().info("📊 File size: #{byte_size(enhanced_json)} bytes")
          end
        end

      {:error, reason} ->
        Mix.shell().error("❌ Failed to parse file: #{reason}")
        System.halt(1)
    end
  end

  defp compare_configs(file1, file2, opts) do
    quiet = opts[:quiet] || false

    unless quiet do
      Mix.shell().info("🔍 Comparing configurations: #{file1} vs #{file2}")
    end

    with {:ok, tlvs1} <- Bindocsis.parse_file(file1),
         {:ok, tlvs2} <- Bindocsis.parse_file(file2) do

      summary1 = create_detailed_summary(tlvs1, file1)
      summary2 = create_detailed_summary(tlvs2, file2)

      comparison = create_comparison(summary1, summary2, tlvs1, tlvs2)
      print_comparison(comparison)

      # Save comparison if requested
      if opts[:output] do
        comparison_json = inspect(comparison, pretty: true)
        File.write!(opts[:output], comparison_json)
        unless quiet do
          Mix.shell().info("📄 Comparison saved: #{opts[:output]}")
        end
      end

    else
      {:error, reason} ->
        Mix.shell().error("❌ Failed to parse files: #{reason}")
        System.halt(1)
    end
  end

  defp create_detailed_summary(tlvs, filename) do
    file_stats = File.stat!(filename)

    %{
      file_info: %{
        name: Path.basename(filename),
        size_bytes: file_stats.size,
        modified: file_stats.mtime |> NaiveDateTime.from_erl!() |> NaiveDateTime.to_iso8601()
      },
      tlv_stats: %{
        total_tlvs: length(tlvs),
        unique_types: tlvs |> Enum.map(& &1.type) |> Enum.uniq() |> length(),
        type_distribution: count_tlv_types(tlvs)
      },
      docsis_features: %{
        service_flows: analyze_service_flows(tlvs),
        certificates: count_certificates(tlvs),
        security_settings: analyze_security(tlvs),
        network_settings: analyze_network_settings(tlvs)
      },
      bandwidth_analysis: analyze_bandwidth(tlvs),
      configuration_profile: determine_config_profile(tlvs)
    }
  end

  defp count_tlv_types(tlvs) do
    tlvs
    |> Enum.group_by(& &1.type)
    |> Enum.map(fn {type, instances} -> {type, length(instances)} end)
    |> Enum.sort()
    |> Enum.into(%{})
  end

  defp analyze_service_flows(tlvs) do
    upstream = Enum.filter(tlvs, &(&1.type == 24))
    downstream = Enum.filter(tlvs, &(&1.type == 25))

    %{
      upstream: length(upstream),
      downstream: length(downstream),
      total: length(upstream) + length(downstream)
    }
  end

  defp count_certificates(tlvs) do
    Enum.count(tlvs, &(&1.type == 32))
  end

  defp analyze_security(tlvs) do
    settings = []

    # Network Access Control
    settings = case Enum.find(tlvs, &(&1.type == 3)) do
      %{value: <<1>>} -> ["Network Access: Enabled" | settings]
      %{value: <<0>>} -> ["Network Access: Disabled" | settings]
      _ -> settings
    end

    # BPKM settings
    bpkm_count = Enum.count(tlvs, &(&1.type in [35, 36, 37]))
    settings = if bpkm_count > 0 do
      ["BPKM Configuration: #{bpkm_count} settings" | settings]
    else
      settings
    end

    Enum.reverse(settings)
  end

  defp analyze_network_settings(tlvs) do
    settings = []

    # Max CPEs
    settings = case Enum.find(tlvs, &(&1.type == 18)) do
      %{value: <<count>>} -> ["Max CPEs: #{count}" | settings]
      _ -> settings
    end

    # SNMP settings
    snmp_count = Enum.count(tlvs, &(&1.type == 11))
    settings = if snmp_count > 0 do
      ["SNMP Objects: #{snmp_count}" | settings]
    else
      settings
    end

    Enum.reverse(settings)
  end

  defp analyze_bandwidth(tlvs) do
    # Look for common bandwidth patterns in service flows
    service_flows = Enum.filter(tlvs, &(&1.type in [24, 25]))

    Enum.flat_map(service_flows, fn flow ->
      case flow.value do
        binary when is_binary(binary) ->
          find_bandwidth_patterns(binary, flow.type)
        _ -> []
      end
    end)
  end

  defp find_bandwidth_patterns(binary, flow_type) do
    # Common bandwidth values in bps
    patterns = [
      {1_000_000, "1 Mbps"},
      {5_000_000, "5 Mbps"},
      {10_000_000, "10 Mbps"},
      {25_000_000, "25 Mbps"},
      {50_000_000, "50 Mbps"},
      {100_000_000, "100 Mbps"},
      {200_000_000, "200 Mbps"},
      {300_000_000, "300 Mbps"},
      {500_000_000, "500 Mbps"},
      {1_000_000_000, "1 Gbps"}
    ]

    flow_name = if flow_type == 24, do: "Downstream", else: "Upstream"

    patterns
    |> Enum.filter(fn {value, _description} ->
      String.contains?(binary, <<value::32>>)
    end)
    |> Enum.map(fn {_value, description} ->
      "#{flow_name}: #{description}"
    end)
  end

  defp determine_config_profile(tlvs) do
    has_service_flows = Enum.any?(tlvs, &(&1.type in [24, 25]))
    has_certificates = Enum.any?(tlvs, &(&1.type == 32))
    has_security = Enum.any?(tlvs, &(&1.type in [3, 35, 36, 37]))
    snmp_count = Enum.count(tlvs, &(&1.type == 11))

    cond do
      has_certificates -> "Production/Secure"
      has_service_flows and has_security -> "Standard Service"
      snmp_count > 5 -> "Management/Monitoring"
      has_service_flows -> "Basic Service"
      true -> "Minimal/Test"
    end
  end

  defp create_comparison(summary1, summary2, tlvs1, tlvs2) do
    %{
      files: %{
        file1: summary1.file_info,
        file2: summary2.file_info
      },
      tlv_differences: compare_tlv_distributions(summary1.tlv_stats.type_distribution, summary2.tlv_stats.type_distribution),
      feature_differences: compare_features(summary1.docsis_features, summary2.docsis_features),
      unique_to_file1: find_unique_tlvs(tlvs1, tlvs2),
      unique_to_file2: find_unique_tlvs(tlvs2, tlvs1),
      similarity_score: calculate_similarity(summary1, summary2)
    }
  end

  defp compare_tlv_distributions(dist1, dist2) do
    all_types = Map.keys(dist1) ++ Map.keys(dist2) |> Enum.uniq()

    Enum.map(all_types, fn type ->
      count1 = Map.get(dist1, type, 0)
      count2 = Map.get(dist2, type, 0)

      %{
        type: type,
        file1_count: count1,
        file2_count: count2,
        difference: count2 - count1
      }
    end)
    |> Enum.filter(& &1.difference != 0)
  end

  defp compare_features(features1, features2) do
    %{
      service_flows: %{
        file1: features1.service_flows,
        file2: features2.service_flows
      },
      security_differences: features1.security_settings -- features2.security_settings,
      network_differences: features1.network_settings -- features2.network_settings
    }
  end

  defp find_unique_tlvs(tlvs1, tlvs2) do
    types2 = MapSet.new(tlvs2, & &1.type)

    tlvs1
    |> Enum.reject(&MapSet.member?(types2, &1.type))
    |> Enum.map(&%{type: &1.type, length: &1.length})
    |> Enum.uniq()
  end

  defp calculate_similarity(summary1, summary2) do
    types1 = MapSet.new(Map.keys(summary1.tlv_stats.type_distribution))
    types2 = MapSet.new(Map.keys(summary2.tlv_stats.type_distribution))

    intersection = MapSet.intersection(types1, types2) |> MapSet.size()
    union = MapSet.union(types1, types2) |> MapSet.size()

    if union == 0, do: 1.0, else: intersection / union
  end

  defp add_analysis_to_json(json_string, summary) do
    analysis_header = """
    {
      "_analysis": {
        "generated_by": "mix bindocsis.analyze",
        "generated_at": "#{DateTime.utc_now() |> DateTime.to_iso8601()}",
        "summary": #{inspect(summary)}
      },
    """

    String.replace(json_string, ~r/^\{/, analysis_header, global: false)
  end

  defp print_summary(summary) do
    Mix.shell().info("")
    Mix.shell().info("📊 Configuration Analysis Summary")
    Mix.shell().info("═" <> String.duplicate("═", 50))

    Mix.shell().info("📄 File: #{summary.file_info.name}")
    Mix.shell().info("📐 Size: #{summary.file_info.size_bytes} bytes")
    Mix.shell().info("🔧 Profile: #{summary.configuration_profile}")
    Mix.shell().info("")

    Mix.shell().info("📋 TLV Statistics:")
    Mix.shell().info("  • Total TLVs: #{summary.tlv_stats.total_tlvs}")
    Mix.shell().info("  • Unique Types: #{summary.tlv_stats.unique_types}")

    # Show top TLV types
    top_types =
      summary.tlv_stats.type_distribution
      |> Enum.sort_by(&elem(&1, 1), :desc)
      |> Enum.take(5)

    Mix.shell().info("  • Top Types: #{Enum.map(top_types, fn {type, count} -> "#{type}(#{count})" end) |> Enum.join(", ")}")

    Mix.shell().info("")
    Mix.shell().info("🚀 DOCSIS Features:")
    Mix.shell().info("  • Service Flows: #{summary.docsis_features.service_flows.total} (#{summary.docsis_features.service_flows.upstream} up, #{summary.docsis_features.service_flows.downstream} down)")
    Mix.shell().info("  • Certificates: #{summary.docsis_features.certificates}")

    if length(summary.docsis_features.security_settings) > 0 do
      Mix.shell().info("  • Security:")
      Enum.each(summary.docsis_features.security_settings, fn setting ->
        Mix.shell().info("    - #{setting}")
      end)
    end

    if length(summary.docsis_features.network_settings) > 0 do
      Mix.shell().info("  • Network:")
      Enum.each(summary.docsis_features.network_settings, fn setting ->
        Mix.shell().info("    - #{setting}")
      end)
    end

    if length(summary.bandwidth_analysis) > 0 do
      Mix.shell().info("  • Bandwidth:")
      Enum.each(summary.bandwidth_analysis, fn setting ->
        Mix.shell().info("    - #{setting}")
      end)
    end
  end

  defp print_comparison(comparison) do
    Mix.shell().info("")
    Mix.shell().info("🔍 Configuration Comparison")
    Mix.shell().info("═" <> String.duplicate("═", 50))

    Mix.shell().info("📊 Similarity: #{Float.round(comparison.similarity_score * 100, 1)}%")
    Mix.shell().info("")

    if length(comparison.tlv_differences) > 0 do
      Mix.shell().info("📋 TLV Differences:")
      Enum.each(comparison.tlv_differences, fn diff ->
        change = if diff.difference > 0, do: "+#{diff.difference}", else: "#{diff.difference}"
        Mix.shell().info("  • Type #{diff.type}: #{diff.file1_count} → #{diff.file2_count} (#{change})")
      end)
    end

    if length(comparison.unique_to_file1) > 0 do
      Mix.shell().info("")
      Mix.shell().info("📄 Only in #{comparison.files.file1.name}:")
      Enum.each(comparison.unique_to_file1, fn tlv ->
        Mix.shell().info("  • Type #{tlv.type} (length #{tlv.length})")
      end)
    end

    if length(comparison.unique_to_file2) > 0 do
      Mix.shell().info("")
      Mix.shell().info("📄 Only in #{comparison.files.file2.name}:")
      Enum.each(comparison.unique_to_file2, fn tlv ->
        Mix.shell().info("  • Type #{tlv.type} (length #{tlv.length})")
      end)
    end
  end

  defp print_usage do
    Mix.shell().info("""
    Create detailed analysis of DOCSIS configuration files.

    Usage:
      mix bindocsis.analyze <input_file> [options]
      mix bindocsis.analyze <file1> <file2> --compare

    Examples:
      mix bindocsis.analyze config.cm
      mix bindocsis.analyze config.cm --summary-only
      mix bindocsis.analyze config1.cm config2.cm --compare

    Options:
      --output PATH       Output file path
      --summary-only      Show summary without creating file
      --compare           Compare two configurations
      --quiet             Suppress progress output
    """)
  end
end
