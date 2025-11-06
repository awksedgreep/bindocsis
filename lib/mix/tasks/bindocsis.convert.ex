defmodule Mix.Tasks.Bindocsis.Convert do
  @moduledoc """
  Convert DOCSIS configuration files between different formats.

  ## Usage

      mix bindocsis.convert <input_file> --to <format> [options]

  ## Examples

      # Convert .cm to JSON with pretty formatting
      mix bindocsis.convert config.cm --to json

      # Convert .cm to YAML
      mix bindocsis.convert config.cm --to yaml

      # Convert YAML back to binary with custom output name
      mix bindocsis.convert config.yaml --to binary --output new_config.cm

      # Batch convert all .cm files to JSON
      mix bindocsis.convert *.cm --to json

  ## Formats

  * `json` - Pretty-formatted JSON with human-readable descriptions
  * `yaml` - YAML format (easiest for editing)
  * `binary` - DOCSIS binary format (.cm files)
  * `analyze` - Detailed analysis with summary (JSON format)

  ## Options

  * `--to FORMAT` - Output format (required)
  * `--output PATH` - Output file path (optional, auto-generated if not specified)
  * `--validate` - Validate the output after conversion
  * `--pretty` - Use pretty formatting (default: true for JSON/YAML)
  * `--quiet` - Suppress progress output
  """

  use Mix.Task

  @shortdoc "Convert DOCSIS configuration files between formats"

  @switches [
    to: :string,
    output: :string,
    validate: :boolean,
    pretty: :boolean,
    quiet: :boolean
  ]

  @aliases [
    t: :to,
    o: :output,
    v: :validate,
    q: :quiet
  ]

  def run(args) do
    {opts, argv, _} = OptionParser.parse(args, switches: @switches, aliases: @aliases)

    case {argv, opts[:to]} do
      {[], _} ->
        print_usage()

      {_, nil} ->
        Mix.shell().error("Error: --to format is required")
        print_usage()

      {input_files, format} ->
        convert_files(input_files, format, opts)
    end
  end

  defp convert_files(input_files, format, opts) do
    quiet = opts[:quiet] || false
    validate = opts[:validate] || false

    # Expand glob patterns
    files =
      input_files
      |> Enum.flat_map(&Path.wildcard/1)
      |> Enum.filter(&File.exists?/1)

    if Enum.empty?(files) do
      Mix.shell().error("Error: No valid input files found")
      System.halt(1)
    end

    unless quiet do
      Mix.shell().info("🔄 Converting #{length(files)} file(s) to #{format}")
    end

    Enum.each(files, fn input_file ->
      convert_single_file(input_file, format, opts, quiet, validate)
    end)

    unless quiet do
      Mix.shell().info("✅ Conversion complete!")
    end
  end

  defp convert_single_file(input_file, format, opts, quiet, validate) do
    output_file = opts[:output] || generate_output_filename(input_file, format)

    unless quiet do
      Mix.shell().info("  📁 #{input_file} → #{output_file}")
    end

    try do
      # Parse input file
      {:ok, tlvs} = Bindocsis.parse_file(input_file)

      # Generate output based on format
      result =
        case format do
          "json" ->
            Bindocsis.generate(tlvs,
              format: :json,
              pretty: opts[:pretty] != false,
              include_names: true,
              detect_subtlvs: true
            )

          "yaml" ->
            Bindocsis.generate(tlvs,
              format: :yaml,
              pretty: opts[:pretty] != false
            )

          "binary" ->
            Bindocsis.generate(tlvs, format: :binary)

          "analyze" ->
            # Create enhanced analysis like describe_config.exs
            summary = create_summary(tlvs)

            {:ok, json} =
              Bindocsis.generate(tlvs,
                format: :json,
                pretty: true,
                include_names: true,
                detect_subtlvs: true
              )

            {:ok, add_summary_to_json(json, summary)}

          _ ->
            {:error, "Unsupported format: #{format}"}
        end

      case result do
        {:ok, content} ->
          File.write!(output_file, content)

          # Validate if requested
          if validate and format == "binary" do
            case Bindocsis.parse_file(output_file) do
              {:ok, _} ->
                unless quiet, do: Mix.shell().info("    ✅ Validation passed")

              {:error, reason} ->
                Mix.shell().error("    ❌ Validation failed: #{reason}")
            end
          end

        {:error, reason} ->
          Mix.shell().error("    ❌ Conversion failed: #{reason}")
      end
    rescue
      e ->
        Mix.shell().error("    ❌ Error processing #{input_file}: #{Exception.message(e)}")
    end
  end

  defp generate_output_filename(input_file, format) do
    base = Path.rootname(input_file)

    extension =
      case format do
        "json" -> ".json"
        "yaml" -> ".yaml"
        "binary" -> ".cm"
        "analyze" -> "_analysis.json"
      end

    base <> extension
  end

  defp create_summary(tlvs) do
    %{
      total_tlvs: length(tlvs),
      service_flows: count_service_flows(tlvs),
      certificates: count_certificates(tlvs),
      timestamp: DateTime.utc_now() |> DateTime.to_iso8601()
    }
  end

  defp count_service_flows(tlvs) do
    upstream = Enum.count(tlvs, &(&1.type == 24))
    downstream = Enum.count(tlvs, &(&1.type == 25))
    %{upstream: upstream, downstream: downstream}
  end

  defp count_certificates(tlvs) do
    Enum.count(tlvs, &(&1.type == 32))
  end

  defp add_summary_to_json(json_string, summary) do
    summary_json = """
    {
      "_description": "DOCSIS Configuration File Analysis",
      "_generated_by": "mix bindocsis.convert",
      "_summary": #{inspect(summary)},
    """

    String.replace(json_string, ~r/^\{/, summary_json, global: false)
  end

  defp print_usage do
    Mix.shell().info("""
    Convert DOCSIS configuration files between different formats.

    Usage:
      mix bindocsis.convert <input_file> --to <format> [options]

    Examples:
      mix bindocsis.convert config.cm --to json
      mix bindocsis.convert config.cm --to yaml
      mix bindocsis.convert config.yaml --to binary --output new.cm
      mix bindocsis.convert *.cm --to json --validate

    Formats:
      json     Pretty JSON with descriptions
      yaml     YAML format (easiest to edit)
      binary   DOCSIS binary (.cm) format
      analyze  Enhanced analysis with summary

    Options:
      --to FORMAT      Output format (required)
      --output PATH    Output file path (auto-generated if not specified)
      --validate       Validate output after conversion
      --quiet          Suppress progress output
    """)
  end
end
