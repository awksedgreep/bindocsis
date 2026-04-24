defmodule Bindocsis.DocsisConfigfileComparator do
  @moduledoc """
  Compare `docsis-configfile` YAML fixtures against production MTA binaries.

  This module is intended for external fixture directories and does not require
  checking any production artifacts into the repository.
  """

  @type mismatch_example :: %{
          base: String.t(),
          classification: atom(),
          prod_size: non_neg_integer() | nil,
          generated_size: non_neg_integer() | nil,
          details: String.t() | nil
        }

  @type summary :: %{
          total_pairs: non_neg_integer(),
          exact_matches: non_neg_integer(),
          mismatches: non_neg_integer(),
          parse_errors: non_neg_integer(),
          generation_errors: non_neg_integer(),
          classifications: map(),
          mismatch_examples: [mismatch_example()]
        }

  @spec compare_directory(String.t(), keyword()) :: {:ok, summary()} | {:error, String.t()}
  def compare_directory(directory, opts \\ []) when is_binary(directory) do
    expanded_dir = Path.expand(directory)

    if File.dir?(expanded_dir) do
      summary =
        expanded_dir
        |> collect_pairs()
        |> Enum.reduce(empty_summary(), fn {base, yaml_path, bin_path}, acc ->
          update_summary(acc, compare_pair(base, yaml_path, bin_path, opts))
        end)

      {:ok, summary}
    else
      {:error, "Directory not found: #{directory}"}
    end
  end

  @spec compare_pair(String.t(), String.t(), String.t(), keyword()) ::
          {:exact_match, mismatch_example()} | {:mismatch, mismatch_example()}
  def compare_pair(base, yaml_path, bin_path, opts) do
    yaml = File.read!(yaml_path)
    prod = File.read!(bin_path)
    generate_opts = [format: :mta, terminate: false, length_encoding: :docsis_configfile_legacy]
    generate_opts = Keyword.merge(generate_opts, opts)

    case Bindocsis.parse(yaml, format: :docsis_configfile_yaml) do
      {:ok, tlvs} ->
        case Bindocsis.generate(tlvs, generate_opts) do
          {:ok, generated} ->
            if generated == prod do
              {:exact_match,
               %{
                 base: base,
                 classification: :exact_match,
                 prod_size: byte_size(prod),
                 generated_size: byte_size(generated),
                 details: nil
               }}
            else
              classification = classify_mismatch(prod, generated)

              {:mismatch,
               %{
                 base: base,
                 classification: classification,
                 prod_size: byte_size(prod),
                 generated_size: byte_size(generated),
                 details: mismatch_details(prod, generated)
               }}
            end

          {:error, reason} ->
            {:mismatch,
             %{
               base: base,
               classification: :generation_error,
               prod_size: byte_size(prod),
               generated_size: nil,
               details: reason
             }}
        end

      {:error, reason} ->
        {:mismatch,
         %{
           base: base,
           classification: :parse_error,
           prod_size: byte_size(prod),
           generated_size: nil,
           details: reason
         }}
    end
  end

  defp collect_pairs(directory) do
    directory
    |> Path.join("*.siptemplate.yaml")
    |> Path.wildcard()
    |> Enum.sort()
    |> Enum.flat_map(fn yaml_path ->
      base = Path.basename(yaml_path, ".siptemplate.yaml")
      bin_path = Path.join(directory, base <> ".bin")

      if File.exists?(bin_path), do: [{base, yaml_path, bin_path}], else: []
    end)
  end

  defp empty_summary do
    %{
      total_pairs: 0,
      exact_matches: 0,
      mismatches: 0,
      parse_errors: 0,
      generation_errors: 0,
      classifications: %{},
      mismatch_examples: []
    }
  end

  defp update_summary(summary, {status, example}) do
    summary =
      summary
      |> Map.update!(:total_pairs, &(&1 + 1))
      |> Map.update!(
        :classifications,
        &Map.update(&1, example.classification, 1, fn count -> count + 1 end)
      )

    case status do
      :exact_match ->
        Map.update!(summary, :exact_matches, &(&1 + 1))

      :mismatch ->
        summary
        |> Map.update!(:mismatches, &(&1 + 1))
        |> maybe_increment_error_bucket(example.classification)
        |> maybe_store_example(example)
    end
  end

  defp maybe_increment_error_bucket(summary, :parse_error) do
    Map.update!(summary, :parse_errors, &(&1 + 1))
  end

  defp maybe_increment_error_bucket(summary, :generation_error) do
    Map.update!(summary, :generation_errors, &(&1 + 1))
  end

  defp maybe_increment_error_bucket(summary, _classification), do: summary

  defp maybe_store_example(summary, example) do
    if length(summary.mismatch_examples) < 20 do
      Map.update!(summary, :mismatch_examples, &(&1 ++ [example]))
    else
      summary
    end
  end

  defp classify_mismatch(prod, generated) do
    cond do
      byte_size(prod) == byte_size(generated) ->
        :same_size_content_difference

      byte_size(generated) < byte_size(prod) ->
        :generated_smaller_than_production

      true ->
        :generated_larger_than_production
    end
  end

  defp mismatch_details(prod, generated) do
    mismatch_offset =
      0..(min(byte_size(prod), byte_size(generated)) - 1)
      |> Enum.find(fn index -> :binary.at(prod, index) != :binary.at(generated, index) end)

    "first_diff_offset=#{inspect(mismatch_offset)}"
  end
end
