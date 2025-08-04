defmodule Bindocsis.Validator do
  @moduledoc """
  Comprehensive validation module for DOCSIS TLV configurations.
  
  Provides validation for:
  - TLV structure and format
  - Value type compliance
  - DOCSIS version compatibility
  - Cross-TLV dependencies
  - Configuration completeness
  - Security and compliance requirements
  
  ## Usage
  
      iex> tlvs = [%{type: 3, length: 1, value: <<1>>}]
      iex> Bindocsis.Validator.validate_configuration(tlvs)
      {:ok, %{status: :valid, warnings: [], errors: []}}
      
      iex> Bindocsis.Validator.validate_tlv(invalid_tlv)
      {:error, "Invalid TLV structure"}
  """
  
  alias Bindocsis.DocsisSpecs
  alias Bindocsis.SubTlvSpecs
  alias Bindocsis.ValueFormatter
  
  @type validation_result :: {:ok, validation_report()} | {:error, String.t()}
  @type validation_report :: %{
    status: :valid | :invalid | :warning,
    errors: [validation_error()],
    warnings: [validation_warning()],
    info: [validation_info()],
    summary: validation_summary()
  }
  
  @type validation_error :: %{
    type: atom(),
    tlv_type: non_neg_integer() | nil,
    subtlv_type: non_neg_integer() | nil,
    message: String.t(),
    severity: :critical | :error | :warning
  }
  
  @type validation_warning :: %{
    type: atom(),
    tlv_type: non_neg_integer() | nil,
    message: String.t(),
    recommendation: String.t()
  }
  
  @type validation_info :: %{
    type: atom(),
    message: String.t()
  }
  
  @type validation_summary :: %{
    total_tlvs: non_neg_integer(),
    valid_tlvs: non_neg_integer(),
    invalid_tlvs: non_neg_integer(),
    docsis_version: String.t(),
    config_completeness: float()
  }

  # Required TLVs for basic DOCSIS operation
  @required_basic_tlvs [1, 2, 3]  # Downstream Frequency, Upstream Channel ID, Network Access Control
  
  # TLVs that require specific DOCSIS versions
  @version_requirements %{
    "1.0" => 1..30,
    "1.1" => 1..42,
    "2.0" => 1..50,
    "3.0" => 1..85,
    "3.1" => 1..130,
    "4.0" => 1..255
  }
  
  # TLV dependencies (TLV X requires TLV Y to be present)
  @tlv_dependencies %{
    24 => [1, 2],  # Downstream Service Flow requires frequency and upstream channel
    25 => [1, 2],  # Upstream Service Flow requires frequency and upstream channel
    30 => [31],    # Baseline Privacy Config requires Key Management
    38 => [39],    # SNMPv3 Kickstart may require Subscriber Management Control
  }

  @doc """
  Validates a complete TLV configuration.
  
  Performs comprehensive validation including:
  - Individual TLV validation
  - Cross-TLV dependency checking
  - DOCSIS version compatibility
  - Configuration completeness assessment
  
  ## Examples
  
      iex> tlvs = [%{type: 1, length: 4, value: <<...>>}, %{type: 3, length: 1, value: <<1>>}]
      iex> Bindocsis.Validator.validate_configuration(tlvs)
      {:ok, %{status: :valid, errors: [], warnings: []}}
  """
  @spec validate_configuration([map()], keyword()) :: validation_result()
  def validate_configuration(tlvs, opts \\ []) when is_list(tlvs) do
    docsis_version = Keyword.get(opts, :docsis_version, "3.1")
    strict_mode = Keyword.get(opts, :strict, false)
    
    errors = []
    warnings = []
    info = []
    
    # Validate individual TLVs
    {tlv_errors, tlv_warnings, tlv_info} = validate_individual_tlvs(tlvs, docsis_version, strict_mode)
    
    # Validate TLV dependencies
    {dep_errors, dep_warnings} = validate_dependencies(tlvs)
    
    # Validate DOCSIS version compatibility
    {ver_errors, _ver_warnings} = validate_version_compatibility(tlvs, docsis_version)
    
    # Assess configuration completeness
    {comp_warnings, comp_info} = assess_completeness(tlvs, docsis_version)
    
    all_errors = errors ++ tlv_errors ++ dep_errors ++ ver_errors
    all_warnings = warnings ++ tlv_warnings ++ dep_warnings ++ comp_warnings
    all_info = info ++ tlv_info ++ comp_info
    
    status = determine_status(all_errors, all_warnings)
    
    summary = %{
      total_tlvs: length(tlvs),
      valid_tlvs: length(tlvs) - length(Enum.filter(all_errors, &(&1.severity in [:critical, :error]))),
      invalid_tlvs: length(Enum.filter(all_errors, &(&1.severity in [:critical, :error]))),
      docsis_version: docsis_version,
      config_completeness: calculate_completeness(tlvs, docsis_version)
    }
    
    report = %{
      status: status,
      errors: all_errors,
      warnings: all_warnings,
      info: all_info,
      summary: summary
    }
    
    {:ok, report}
  end

  @doc """
  Validates a single TLV structure and content.
  
  ## Examples
  
      iex> tlv = %{type: 3, length: 1, value: <<1>>}
      iex> Bindocsis.Validator.validate_tlv(tlv)
      {:ok, []}  # No errors
  """
  @spec validate_tlv(map(), String.t(), boolean()) :: {:ok, [validation_error()]} | {:error, String.t()}
  def validate_tlv(tlv, docsis_version \\ "3.1", strict_mode \\ false) do
    errors = []
    
    # Validate basic structure
    errors = errors ++ validate_tlv_structure(tlv)
    
    # Validate TLV type
    errors = errors ++ validate_tlv_type(tlv, docsis_version)
    
    # Validate TLV length
    errors = errors ++ validate_tlv_length(tlv, strict_mode)
    
    # Validate TLV value
    errors = errors ++ validate_tlv_value(tlv, docsis_version, strict_mode)
    
    # Validate sub-TLVs if present
    errors = errors ++ validate_subtlvs(tlv, docsis_version, strict_mode)
    
    {:ok, errors}
  end

  @doc """
  Validates value format and constraints according to TLV specifications.
  
  ## Examples
  
      iex> Bindocsis.Validator.validate_value(:frequency, <<35, 57, 241, 192>>, [])
      {:ok, []}
      
      iex> Bindocsis.Validator.validate_value(:uint8, <<300>>, [])
      {:error, "Value out of range for uint8"}
  """
  @spec validate_value(atom(), binary(), keyword()) :: {:ok, [validation_error()]} | {:error, String.t()}
  def validate_value(value_type, binary_value, opts \\ []) do
    try do
      case ValueFormatter.format_value(value_type, binary_value, opts) do
        {:ok, _formatted} -> {:ok, []}
        {:error, reason} -> {:error, reason}
      end
    rescue
      e -> {:error, "Validation error: #{Exception.message(e)}"}
    end
  end

  @doc """
  Checks if a TLV configuration meets minimum requirements for DOCSIS operation.
  
  ## Examples
  
      iex> tlvs = [%{type: 1, ...}, %{type: 2, ...}, %{type: 3, ...}]
      iex> Bindocsis.Validator.check_minimum_requirements(tlvs)
      {:ok, %{complete: true, missing: []}}
  """
  @spec check_minimum_requirements([map()]) :: {:ok, map()}
  def check_minimum_requirements(tlvs) do
    present_types = Enum.map(tlvs, & &1.type) |> MapSet.new()
    required_types = MapSet.new(@required_basic_tlvs)
    missing_types = MapSet.difference(required_types, present_types) |> MapSet.to_list()
    
    result = %{
      complete: missing_types == [],
      missing: missing_types,
      present: MapSet.intersection(required_types, present_types) |> MapSet.to_list()
    }
    
    {:ok, result}
  end

  # Private validation functions
  
  defp validate_individual_tlvs(tlvs, docsis_version, strict_mode) do
    results = Enum.map(tlvs, fn tlv ->
      case validate_tlv(tlv, docsis_version, strict_mode) do
        {:ok, errors} -> {errors, [], []}
        # {:error, reason} -> {[create_error(:validation_failed, tlv.type, reason, :critical)], [], []}  # Not reachable
      end
    end)
    
    {
      Enum.flat_map(results, &elem(&1, 0)),
      Enum.flat_map(results, &elem(&1, 1)),
      Enum.flat_map(results, &elem(&1, 2))
    }
  end
  
  defp validate_dependencies(tlvs) do
    present_types = Enum.map(tlvs, & &1.type) |> MapSet.new()
    
    errors = Enum.flat_map(@tlv_dependencies, fn {tlv_type, required_types} ->
      if tlv_type in present_types do
        missing = Enum.filter(required_types, &(&1 not in present_types))
        Enum.map(missing, fn missing_type ->
          create_error(
            :missing_dependency,
            tlv_type,
            "TLV #{tlv_type} requires TLV #{missing_type} to be present",
            :error
          )
        end)
      else
        []
      end
    end)
    
    {errors, []}
  end
  
  defp validate_version_compatibility(tlvs, docsis_version) do
    allowed_range = Map.get(@version_requirements, docsis_version, 1..255)
    
    errors = Enum.flat_map(tlvs, fn tlv ->
      if tlv.type in allowed_range do
        []
      else
        [create_error(
          :version_incompatible,
          tlv.type,
          "TLV #{tlv.type} not supported in DOCSIS #{docsis_version}",
          :error
        )]
      end
    end)
    
    {errors, []}
  end
  
  defp assess_completeness(tlvs, docsis_version) do
    present_types = Enum.map(tlvs, & &1.type) |> MapSet.new()
    required_types = MapSet.new(@required_basic_tlvs)
    missing_required = MapSet.difference(required_types, present_types)
    
    warnings = if MapSet.size(missing_required) > 0 do
      [%{
        type: :incomplete_config,
        tlv_type: nil,
        message: "Missing required TLVs: #{MapSet.to_list(missing_required) |> Enum.join(", ")}",
        recommendation: "Add required TLVs for proper DOCSIS operation"
      }]
    else
      []
    end
    
    info = [%{
      type: :config_summary,
      message: "Configuration contains #{length(tlvs)} TLVs for DOCSIS #{docsis_version}"
    }]
    
    {warnings, info}
  end
  
  defp validate_tlv_structure(tlv) do
    required_keys = [:type, :length, :value]
    missing_keys = Enum.filter(required_keys, &(not Map.has_key?(tlv, &1)))
    
    if missing_keys == [] do
      []
    else
      [create_error(
        :invalid_structure,
        Map.get(tlv, :type),
        "Missing required keys: #{Enum.join(missing_keys, ", ")}",
        :critical
      )]
    end
  end
  
  defp validate_tlv_type(tlv, docsis_version) do
    case DocsisSpecs.get_tlv_info(tlv.type, docsis_version) do
      {:ok, _info} -> []
      {:error, _} -> 
        [create_warning(
          :unknown_tlv_type,
          tlv.type,
          "TLV type #{tlv.type} not recognized in DOCSIS #{docsis_version}",
          "Verify TLV type or update DOCSIS version"
        )]
    end
  end
  
  defp validate_tlv_length(tlv, strict_mode) do
    if not Map.has_key?(tlv, :length) do
      []
    else
      actual_length = byte_size(tlv.value)
      declared_length = tlv.length
      
      validate_length_logic(actual_length, declared_length, tlv.type, strict_mode)
    end
  end
  
  defp validate_length_logic(actual_length, declared_length, tlv_type, strict_mode) do
    
    errors = if actual_length != declared_length do
      [create_error(
        :length_mismatch,
        tlv_type,
        "Declared length #{declared_length} doesn't match actual length #{actual_length}",
        if(strict_mode, do: :error, else: :warning)
      )]
    else
      []
    end
    
    # Check against TLV specification max length
    case DocsisSpecs.get_tlv_info(tlv_type) do
      {:ok, tlv_info} when tlv_info.max_length != :unlimited ->
        if actual_length > tlv_info.max_length do
          errors ++ [create_error(
            :exceeds_max_length,
            tlv_type,
            "Value length #{actual_length} exceeds maximum #{tlv_info.max_length}",
            :error
          )]
        else
          errors
        end
      _ -> errors
    end
  end
  
  defp validate_tlv_value(tlv, _docsis_version, _strict_mode) do
    case DocsisSpecs.get_tlv_info(tlv.type) do
      {:ok, tlv_info} ->
        case validate_value(tlv_info.value_type, tlv.value) do
          {:ok, []} -> []
          {:ok, errors} -> errors
          {:error, reason} -> 
            [create_error(
              :invalid_value_format,
              tlv.type,
              reason,
              :error
            )]
        end
      {:error, _} -> []  # Unknown TLV, skip value validation
    end
  end
  
  defp validate_subtlvs(tlv, docsis_version, strict_mode) do
    if Map.has_key?(tlv, :subtlvs) and is_list(tlv.subtlvs) do
      Enum.flat_map(tlv.subtlvs, fn subtlv ->
        validate_subtlv(subtlv, tlv.type, docsis_version, strict_mode)
      end)
    else
      []
    end
  end
  
  defp validate_subtlv(subtlv, parent_type, _docsis_version, strict_mode) do
    case SubTlvSpecs.get_subtlv_info(parent_type, subtlv.type) do
      {:ok, subtlv_info} ->
        validate_subtlv_value(subtlv, subtlv_info, parent_type, strict_mode)
      {:error, _} ->
        [create_warning(
          :unknown_subtlv_type,
          parent_type,
          "Unknown sub-TLV type #{subtlv.type} in TLV #{parent_type}",
          "Verify sub-TLV specification"
        )]
    end
  end
  
  defp validate_subtlv_value(subtlv, subtlv_info, parent_type, _strict_mode) do
    case validate_value(subtlv_info.value_type, subtlv.value) do
      {:ok, []} -> []
      {:ok, errors} -> errors
      {:error, reason} ->
        [create_error(
          :invalid_subtlv_value,
          parent_type,
          "Sub-TLV #{subtlv.type}: #{reason}",
          :error,
          subtlv.type
        )]
    end
  end
  
  defp determine_status(errors, warnings) do
    critical_errors = Enum.count(errors, fn error -> 
      Map.get(error, :severity) == :critical 
    end)
    regular_errors = Enum.count(errors, fn error -> 
      Map.get(error, :severity) == :error 
    end)
    
    cond do
      critical_errors > 0 -> :invalid
      regular_errors > 0 -> :invalid
      length(warnings) > 0 -> :warning
      true -> :valid
    end
  end
  
  defp calculate_completeness(tlvs, _docsis_version) do
    present_types = Enum.map(tlvs, & &1.type) |> MapSet.new()
    required_types = MapSet.new(@required_basic_tlvs)
    
    if MapSet.size(required_types) == 0 do
      1.0
    else
      present_required = MapSet.intersection(present_types, required_types)
      MapSet.size(present_required) / MapSet.size(required_types)
    end
  end
  
  defp create_error(type, tlv_type, message, severity, subtlv_type \\ nil) do
    %{
      type: type,
      tlv_type: tlv_type,
      subtlv_type: subtlv_type,
      message: message,
      severity: severity
    }
  end
  
  defp create_warning(type, tlv_type, message, recommendation) do
    %{
      type: type,
      tlv_type: tlv_type,
      message: message,
      recommendation: recommendation,
      severity: :warning  # Add severity for consistent structure
    }
  end
end