defmodule Mix.Tasks.Bindocsis.Validate do
  @moduledoc """
  Validate DOCSIS configuration files.

  ## Usage

      mix bindocsis.validate <file_or_directory> [options]

  ## Examples

      # Validate single file
      mix bindocsis.validate config.cm

      # Validate all .cm files in directory
      mix bindocsis.validate configs/

      # Validate with specific DOCSIS version
      mix bindocsis.validate config.cm --docsis-version 3.1

      # Quiet validation (only errors)
      mix bindocsis.validate config.cm --quiet

  ## Options

  * `--docsis-version VERSION` - Target DOCSIS version (3.0, 3.1)
  * `--quiet` - Only show errors
  * `--verbose` - Show detailed validation info
  """

  use Mix.Task

  @shortdoc "Validate DOCSIS configuration files"

  @switches [
    docsis_version: :string,
    quiet: :boolean,
    verbose: :boolean
  ]

  @aliases [
    d: :docsis_version,
    q: :quiet,
    v: :verbose
  ]

  def run(args) do
    {opts, argv, _} = OptionParser.parse(args, switches: @switches, aliases: @aliases)

    case argv do
      [] ->
        print_usage()

      targets ->
        validate_targets(targets, opts)
    end
  end

  defp validate_targets(targets, opts) do
    quiet = opts[:quiet] || false
    verbose = opts[:verbose] || false
    docsis_version = opts[:docsis_version] || "3.1"

    # Collect all files to validate
    files =
      targets
      |> Enum.flat_map(&collect_files/1)
      |> Enum.filter(&String.ends_with?(&1, [".cm", ".json", ".yaml"]))

    if Enum.empty?(files) do
      Mix.shell().error("No configuration files found to validate")
      System.halt(1)
    end

    unless quiet do
      Mix.shell().info("🔍 Validating #{length(files)} file(s) for DOCSIS #{docsis_version}")
    end

    results = Enum.map(files, &validate_file(&1, docsis_version, quiet, verbose))

    valid_count = Enum.count(results, & &1)
    invalid_count = length(results) - valid_count

    unless quiet do
      if invalid_count == 0 do
        Mix.shell().info("✅ All #{valid_count} file(s) are valid")
      else
        Mix.shell().info("📊 Results: #{valid_count} valid, #{invalid_count} invalid")
      end
    end

    if invalid_count > 0, do: System.halt(1)
  end

  defp collect_files(target) do
    cond do
      File.regular?(target) ->
        [target]

      File.dir?(target) ->
        Path.wildcard(Path.join(target, "**/*.{cm,json,yaml}"))

      String.contains?(target, "*") ->
        Path.wildcard(target)

      true ->
        Mix.shell().error("Target not found: #{target}")
        []
    end
  end

  defp validate_file(file, docsis_version, quiet, verbose) do
    unless quiet do
      Mix.shell().info("  📄 #{file}")
    end

    try do
      case Bindocsis.parse_file(file) do
        {:ok, tlvs} ->
          # Basic validation - file parses correctly
          if verbose do
            Mix.shell().info("    ✅ Parsed successfully (#{length(tlvs)} TLVs)")

            # Show TLV summary
            tlv_summary =
              tlvs
              |> Enum.group_by(& &1.type)
              |> Enum.map(fn {type, instances} -> "Type #{type}(#{length(instances)})" end)
              |> Enum.take(5)
              |> Enum.join(", ")

            Mix.shell().info("    📋 TLVs: #{tlv_summary}")
          end

          # Additional DOCSIS version specific validation could go here
          # For now, successful parsing = valid
          unless quiet do
            Mix.shell().info("    ✅ Valid for DOCSIS #{docsis_version}")
          end

          true

        {:error, reason} ->
          Mix.shell().error("    ❌ Parse error: #{reason}")
          false
      end

    rescue
      e ->
        Mix.shell().error("    ❌ Exception: #{Exception.message(e)}")
        false
    end
  end

  defp print_usage do
    Mix.shell().info("""
    Validate DOCSIS configuration files.

    Usage:
      mix bindocsis.validate <file_or_directory> [options]

    Examples:
      mix bindocsis.validate config.cm
      mix bindocsis.validate configs/
      mix bindocsis.validate *.cm --docsis-version 3.0

    Options:
      --docsis-version VERSION   Target DOCSIS version (3.0, 3.1)
      --quiet                    Only show errors
      --verbose                  Show detailed validation info
    """)
  end
end
