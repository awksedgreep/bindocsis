defmodule Mix.Tasks.Bindocsis.CompareDocsisConfigfile do
  @moduledoc """
  Compare external `docsis-configfile` YAML fixtures to production `.bin` files.

  ## Usage

      mix bindocsis.compare_docsis_configfile ../mtafixtures

  ## Options

    * `--show-mismatches` - Print stored mismatch examples
  """

  use Mix.Task

  @shortdoc "Compare docsis-configfile YAML fixtures to production MTA binaries"

  @switches [show_mismatches: :boolean]

  def run(args) do
    {opts, argv, _} = OptionParser.parse(args, switches: @switches)

    case argv do
      [directory] ->
        run_comparison(directory, opts)

      _ ->
        print_usage()
    end
  end

  defp run_comparison(directory, opts) do
    case Bindocsis.DocsisConfigfileComparator.compare_directory(directory) do
      {:ok, summary} ->
        Mix.shell().info("Compared #{summary.total_pairs} paired fixtures in #{directory}")
        Mix.shell().info("Exact matches: #{summary.exact_matches}")
        Mix.shell().info("Mismatches: #{summary.mismatches}")
        Mix.shell().info("Parse errors: #{summary.parse_errors}")
        Mix.shell().info("Generation errors: #{summary.generation_errors}")

        if map_size(summary.classifications) > 0 do
          Mix.shell().info("Classifications:")

          summary.classifications
          |> Enum.sort()
          |> Enum.each(fn {classification, count} ->
            Mix.shell().info("  #{classification}: #{count}")
          end)
        end

        if opts[:show_mismatches] && summary.mismatch_examples != [] do
          Mix.shell().info("Mismatch examples:")

          Enum.each(summary.mismatch_examples, fn example ->
            Mix.shell().info(
              "  #{example.base} classification=#{example.classification} prod=#{inspect(example.prod_size)} generated=#{inspect(example.generated_size)} #{example.details || ""}"
            )
          end)
        end

      {:error, reason} ->
        Mix.shell().error(reason)
        System.halt(1)
    end
  end

  defp print_usage do
    Mix.shell().info("""
    Compare external docsis-configfile YAML fixtures to production binaries.

    Usage:
      mix bindocsis.compare_docsis_configfile <directory> [--show-mismatches]
    """)
  end
end
