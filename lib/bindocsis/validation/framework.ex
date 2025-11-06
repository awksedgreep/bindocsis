defmodule Bindocsis.Validation.Framework do
  @moduledoc """
  Comprehensive DOCSIS configuration validation framework.

  Provides three levels of validation:
  1. **Syntax** - Binary structure and TLV format validation
  2. **Semantic** - Value correctness, required fields, consistency
  3. **Compliance** - DOCSIS version compatibility and spec adherence

  ## Examples

      # Validate at semantic level (default)
      {:ok, result} = Framework.validate(tlvs)
      
      if result.valid? do
        IO.puts "Configuration valid!"
      else
        Enum.each(result.errors, fn err ->
          IO.puts "Error: \#{err.message}"
        end)
      end
      
      # Strict validation (warnings become errors)
      {:ok, result} = Framework.validate(tlvs, strict: true)
      
      # Compliance validation for DOCSIS 3.0
      {:ok, result} = Framework.validate(tlvs, 
        level: :compliance,
        docsis_version: "3.0"
      )
  """

  alias Bindocsis.Validation.{Result, Rules}
  alias Bindocsis.{DocsisSpecs, SubTlvSpecs}

  @type validation_level :: :syntax | :semantic | :compliance
  @type docsis_version :: String.t()

  @doc """
  Validates a parsed configuration.

  ## Options

  - `:level` - Validation level (`:syntax`, `:semantic`, `:compliance`), default: `:semantic`
  - `:docsis_version` - DOCSIS version ("1.0", "1.1", "2.0", "3.0", "3.1"), default: auto-detect
  - `:strict` - Treat warnings as errors, default: `false`
  - `:rules` - Additional custom validation rules
  - `:skip_mic` - Skip MIC validation, default: `false`

  ## Examples

      {:ok, result} = Framework.validate(tlvs)
      
      {:ok, result} = Framework.validate(tlvs, 
        level: :compliance,
        docsis_version: "3.1",
        strict: true
      )
  """
  @spec validate(list(map()), keyword()) :: {:ok, Result.t()} | {:error, term()}
  def validate(tlvs, opts \\ []) when is_list(tlvs) do
    level = Keyword.get(opts, :level, :semantic)
    docsis_version = Keyword.get(opts, :docsis_version) || detect_version(tlvs)

    result = Result.new()

    result =
      result
      |> validate_syntax(tlvs, opts)
      |> then(fn res ->
        if level in [:semantic, :compliance] do
          validate_semantic(res, tlvs, docsis_version, opts)
        else
          res
        end
      end)
      |> then(fn res ->
        if level == :compliance do
          validate_compliance(res, tlvs, docsis_version, opts)
        else
          res
        end
      end)
      |> apply_strict_mode(opts)

    {:ok, result}
  rescue
    e -> {:error, "Validation failed: #{Exception.message(e)}"}
  end

  @doc """
  Quick validation check - returns boolean.

  ## Examples

      if Framework.valid?(tlvs) do
        IO.puts "Config is valid!"
      end
  """
  @spec valid?(list(map()), keyword()) :: boolean()
  def valid?(tlvs, opts \\ []) do
    case validate(tlvs, opts) do
      {:ok, %Result{valid?: true}} -> true
      _ -> false
    end
  end

  # Syntax validation - structure and format
  defp validate_syntax(result, tlvs, _opts) do
    result
    |> Rules.check_tlv_structure(tlvs)
    |> Rules.check_length_consistency(tlvs)
    |> Rules.check_subtlv_structure(tlvs)
  end

  # Semantic validation - value correctness
  defp validate_semantic(result, tlvs, version, opts) do
    result
    |> Rules.check_required_tlvs(tlvs, version)
    |> Rules.check_value_ranges(tlvs, version)
    |> Rules.check_duplicate_tlvs(tlvs)
    |> Rules.check_service_flow_consistency(tlvs)
    |> Rules.check_cos_configuration(tlvs)
    |> then(fn res ->
      if Keyword.get(opts, :skip_mic, false) do
        res
      else
        Rules.check_mic_presence(res, tlvs)
      end
    end)
  end

  # Compliance validation - DOCSIS version requirements
  defp validate_compliance(result, tlvs, version, _opts) do
    result
    |> Rules.check_version_features(tlvs, version)
    |> Rules.check_deprecated_tlvs(tlvs, version)
    |> Rules.check_mandatory_features(tlvs, version)
    |> Rules.check_vendor_extensions(tlvs, version)
  end

  # Apply strict mode if requested
  defp apply_strict_mode(result, opts) do
    if Keyword.get(opts, :strict, false) do
      Result.strict_mode(result)
    else
      result
    end
  end

  @doc """
  Detects DOCSIS version from TLV content.

  Uses heuristics based on TLV types present:
  - 3.1: Has OFDM/OFDMA TLVs (62-67, 68-83)
  - 3.0: Has channel bonding TLVs (24-26, 43)
  - 2.0: Has telephony TLVs (28-37)
  - 1.1: Has service flows (17-18, 24-25)
  - 1.0: Basic TLVs only (1-16)

  ## Examples

      iex> tlvs = [%{type: 62}, %{type: 1}]  # Has OFDM profile
      iex> Framework.detect_version(tlvs)
      "3.1"
  """
  @spec detect_version(list(map())) :: docsis_version()
  def detect_version(tlvs) when is_list(tlvs) do
    types = Enum.map(tlvs, & &1.type) |> MapSet.new()

    cond do
      # DOCSIS 3.1 - OFDM/OFDMA features
      has_any?(types, [62, 63, 65, 66, 67]) ->
        "3.1"

      # DOCSIS 3.1 - Advanced features
      has_any?(types, [68, 69, 70, 71, 72, 73, 74, 75, 76, 77, 78, 79, 80, 81, 82, 83]) ->
        "3.1"

      # DOCSIS 3.0 - Channel bonding
      has_any?(types, [24, 25, 43, 50, 51, 60, 61]) ->
        "3.0"

      # DOCSIS 2.0 - Telephony/PacketCable
      has_any?(types, [28, 29, 30, 31, 32, 33, 34, 35, 36, 37, 38, 39, 40, 41, 42]) ->
        "2.0"

      # DOCSIS 1.1 - Service flows
      has_any?(types, [17, 18, 19, 20, 21, 22, 23, 24, 25, 26, 27]) ->
        "1.1"

      # DOCSIS 1.0 - Basic
      true ->
        "1.0"
    end
  end

  defp has_any?(set, values) do
    Enum.any?(values, &MapSet.member?(set, &1))
  end

  @doc """
  Returns validation statistics for a result.

  ## Examples

      {:ok, result} = Framework.validate(tlvs)
      stats = Framework.stats(result)
      # => %{
      #   total_checks: 15,
      #   errors: 2,
      #   warnings: 3,
      #   info: 1,
      #   valid?: false
      # }
  """
  @spec stats(Result.t()) :: map()
  def stats(%Result{} = result) do
    %{
      total_checks: length(result.errors) + length(result.warnings) + length(result.info),
      errors: length(result.errors),
      warnings: length(result.warnings),
      info: length(result.info),
      valid?: result.valid?
    }
  end

  @doc """
  Formats validation result as human-readable text.

  ## Examples

      {:ok, result} = Framework.validate(tlvs)
      IO.puts Framework.format_result(result)
  """
  @spec format_result(Result.t()) :: String.t()
  def format_result(%Result{} = result) do
    parts = []

    parts =
      if result.valid? do
        ["✓ Configuration is valid"]
      else
        ["✗ Configuration has errors"]
      end

    parts =
      if length(result.errors) > 0 do
        parts ++
          ["\nErrors (#{length(result.errors)}):"] ++
          Enum.map(result.errors, fn issue ->
            "  • #{issue.message}" <> context_str(issue.context)
          end)
      else
        parts
      end

    parts =
      if length(result.warnings) > 0 do
        parts ++
          ["\nWarnings (#{length(result.warnings)}):"] ++
          Enum.map(result.warnings, fn issue ->
            "  • #{issue.message}" <> context_str(issue.context)
          end)
      else
        parts
      end

    parts =
      if length(result.info) > 0 do
        parts ++
          ["\nInfo (#{length(result.info)}):"] ++
          Enum.map(result.info, fn issue ->
            "  • #{issue.message}" <> context_str(issue.context)
          end)
      else
        parts
      end

    Enum.join(parts, "\n")
  end

  defp context_str(nil), do: ""

  defp context_str(context) when is_map(context) do
    if Map.has_key?(context, :tlv) do
      " (TLV #{context.tlv})"
    else
      ""
    end
  end

  @doc """
  Validates multiple configurations in batch.

  Returns a map of results keyed by config identifier.

  ## Examples

      configs = %{
        "config1" => tlvs1,
        "config2" => tlvs2
      }
      
      {:ok, results} = Framework.validate_batch(configs)
      
      Enum.each(results, fn {cfg_name, res} ->
        IO.puts "\#{cfg_name}: \#{if res.valid?, do: \"VALID\", else: \"INVALID\"}"
      end)
  """
  @spec validate_batch(map(), keyword()) :: {:ok, map()} | {:error, term()}
  def validate_batch(configs, opts \\ []) when is_map(configs) do
    results =
      configs
      |> Enum.map(fn {name, tlvs} ->
        case validate(tlvs, opts) do
          {:ok, result} ->
            {name, result}

          {:error, reason} ->
            {name, Result.new() |> Result.add_error("Validation failed: #{reason}")}
        end
      end)
      |> Enum.into(%{})

    {:ok, results}
  end
end
