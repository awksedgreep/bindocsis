defmodule Bindocsis.Validation.Rules do
  @moduledoc """
  Individual validation rules for DOCSIS configurations.

  Each function takes a Result and returns an updated Result with
  any new errors, warnings, or info added.
  """

  alias Bindocsis.Validation.Result
  alias Bindocsis.{DocsisSpecs, SubTlvSpecs}

  # Required TLVs by DOCSIS version
  @required_tlvs %{
    # Freq, Channel, Network Access
    "1.0" => [1, 2, 3],
    # + MICs
    "1.1" => [1, 2, 3, 6, 7],
    "2.0" => [1, 2, 3, 6, 7],
    "3.0" => [1, 2, 3, 6, 7],
    "3.1" => [1, 2, 3, 6, 7]
  }

  # TLVs that should only appear once
  @unique_tlvs [1, 2, 3, 8, 12, 21, 22, 23, 26]

  ## Syntax Validation

  @doc """
  Checks basic TLV structure (type, length, value present).
  """
  def check_tlv_structure(result, tlvs) do
    Enum.reduce(tlvs, result, fn tlv, acc ->
      cond do
        not is_map(tlv) ->
          Result.add_error(acc, "TLV is not a map structure")

        not Map.has_key?(tlv, :type) ->
          Result.add_error(acc, "TLV missing type field")

        not Map.has_key?(tlv, :length) and not Map.has_key?(tlv, :value) ->
          Result.add_error(acc, "TLV missing length or value field", %{tlv: tlv.type})

        true ->
          acc
      end
    end)
  end

  @doc """
  Checks that TLV length matches actual value size.
  """
  def check_length_consistency(result, tlvs) do
    Enum.reduce(tlvs, result, fn tlv, acc ->
      cond do
        Map.has_key?(tlv, :value) and Map.has_key?(tlv, :length) ->
          actual_length = byte_size(tlv.value)

          if tlv.length != actual_length do
            Result.add_error(
              acc,
              "TLV #{tlv.type} length mismatch: declared #{tlv.length}, actual #{actual_length}",
              %{tlv: tlv.type, declared: tlv.length, actual: actual_length}
            )
          else
            acc
          end

        true ->
          acc
      end
    end)
  end

  @doc """
  Checks sub-TLV structure if present.
  """
  def check_subtlv_structure(result, tlvs) do
    Enum.reduce(tlvs, result, fn tlv, acc ->
      if Map.has_key?(tlv, :subtlvs) and is_list(tlv.subtlvs) do
        # Recursively check sub-TLV structure
        check_tlv_structure(acc, tlv.subtlvs)
      else
        acc
      end
    end)
  end

  ## Semantic Validation

  @doc """
  Checks that required TLVs are present for the DOCSIS version.
  """
  def check_required_tlvs(result, tlvs, version) do
    required = Map.get(@required_tlvs, version, [])
    present = MapSet.new(tlvs, & &1.type)

    Enum.reduce(required, result, fn req_type, acc ->
      if MapSet.member?(present, req_type) do
        acc
      else
        tlv_name = get_tlv_name(req_type)

        Result.add_error(
          acc,
          "Missing required TLV: #{tlv_name}",
          %{tlv: req_type, version: version}
        )
      end
    end)
  end

  @doc """
  Checks that TLV values are in valid ranges.
  """
  def check_value_ranges(result, tlvs, _version) do
    Enum.reduce(tlvs, result, fn tlv, acc ->
      case validate_value_range(tlv) do
        :ok -> acc
        {:error, message} -> Result.add_error(acc, message, %{tlv: tlv.type})
      end
    end)
  end

  # Downstream Frequency (TLV 1): 54-1002 MHz
  defp validate_value_range(%{type: 1, value: <<freq::32>>}) do
    if freq >= 54_000_000 and freq <= 1_002_000_000 do
      :ok
    else
      {:error, "Downstream frequency #{freq} Hz out of range (54-1002 MHz)"}
    end
  end

  # Upstream Channel ID (TLV 2): 0-255
  defp validate_value_range(%{type: 2, value: <<channel_id>>}) do
    if channel_id >= 0 and channel_id <= 255 do
      :ok
    else
      {:error, "Upstream channel ID #{channel_id} out of range (0-255)"}
    end
  end

  # Network Access (TLV 3): 0 or 1
  defp validate_value_range(%{type: 3, value: <<enabled>>}) do
    if enabled in [0, 1] do
      :ok
    else
      {:error, "Network access must be 0 or 1, got #{enabled}"}
    end
  end

  # Max CPE (TLV 21): 1-254
  defp validate_value_range(%{type: 21, value: <<count>>}) do
    if count >= 1 and count <= 254 do
      :ok
    else
      {:error, "Max CPE count must be 1-254, got #{count}"}
    end
  end

  defp validate_value_range(_tlv), do: :ok

  @doc """
  Checks for duplicate TLVs that should be unique.
  """
  def check_duplicate_tlvs(result, tlvs) do
    tlvs
    |> Enum.group_by(& &1.type)
    |> Enum.reduce(result, fn {type, occurrences}, acc ->
      if type in @unique_tlvs and length(occurrences) > 1 do
        tlv_name = get_tlv_name(type)

        Result.add_warning(
          acc,
          "TLV #{tlv_name} appears #{length(occurrences)} times (should be unique)",
          %{tlv: type, count: length(occurrences)}
        )
      else
        acc
      end
    end)
  end

  @doc """
  Checks service flow configuration consistency.
  """
  def check_service_flow_consistency(result, tlvs) do
    # Find all service flows
    upstream_flows = Enum.filter(tlvs, &(&1.type == 17))
    downstream_flows = Enum.filter(tlvs, &(&1.type == 18))

    result
    |> check_service_flow_references(upstream_flows, :upstream)
    |> check_service_flow_references(downstream_flows, :downstream)
    |> check_service_flow_qos(upstream_flows ++ downstream_flows)
  end

  defp check_service_flow_references(result, flows, direction) do
    Enum.reduce(flows, result, fn flow, acc ->
      if Map.has_key?(flow, :subtlvs) do
        has_ref = Enum.any?(flow.subtlvs, &(&1.type == 1))

        if not has_ref do
          dir_str = if direction == :upstream, do: "Upstream", else: "Downstream"

          Result.add_error(
            acc,
            "#{dir_str} Service Flow missing required SF Reference (sub-TLV 1)",
            %{tlv: flow.type}
          )
        else
          acc
        end
      else
        acc
      end
    end)
  end

  defp check_service_flow_qos(result, flows) do
    Enum.reduce(flows, result, fn flow, acc ->
      if Map.has_key?(flow, :subtlvs) do
        # Check for QoS param consistency
        # Max Traffic Rate
        max_rate = find_subtlv(flow.subtlvs, 8)
        # Min Reserved Rate
        min_rate = find_subtlv(flow.subtlvs, 9)

        case {max_rate, min_rate} do
          {%{value: <<max::32>>}, %{value: <<min::32>>}} when min > max ->
            Result.add_error(
              acc,
              "Service Flow: Minimum rate (#{min}) exceeds maximum rate (#{max})",
              %{tlv: flow.type}
            )

          _ ->
            acc
        end
      else
        acc
      end
    end)
  end

  @doc """
  Checks Class of Service configuration.
  """
  def check_cos_configuration(result, tlvs) do
    cos_tlvs = Enum.filter(tlvs, &(&1.type == 4))

    Enum.reduce(cos_tlvs, result, fn cos, acc ->
      if Map.has_key?(cos, :subtlvs) do
        has_class_id = Enum.any?(cos.subtlvs, &(&1.type == 1))
        has_max_rate = Enum.any?(cos.subtlvs, &(&1.type == 2))

        acc =
          if not has_class_id do
            Result.add_error(acc, "CoS missing required Class ID (sub-TLV 1)", %{tlv: 4})
          else
            acc
          end

        if not has_max_rate do
          Result.add_error(acc, "CoS missing required Max Rate (sub-TLV 2)", %{tlv: 4})
        else
          acc
        end
      else
        acc
      end
    end)
  end

  @doc """
  Checks for MIC TLVs presence.
  """
  def check_mic_presence(result, tlvs) do
    has_cm_mic = Enum.any?(tlvs, &(&1.type == 6))
    has_cmts_mic = Enum.any?(tlvs, &(&1.type == 7))

    result =
      if not has_cm_mic do
        Result.add_warning(result, "CM MIC (TLV 6) not present - config is not secure", %{tlv: 6})
      else
        result
      end

    if not has_cmts_mic do
      Result.add_warning(result, "CMTS MIC (TLV 7) not present - config is not secure", %{tlv: 7})
    else
      result
    end
  end

  ## Compliance Validation

  @doc """
  Checks if TLVs are valid for the DOCSIS version.
  """
  def check_version_features(result, tlvs, version) do
    allowed_types = get_allowed_tlv_types(version)

    Enum.reduce(tlvs, result, fn tlv, acc ->
      # Vendor TLVs allowed
      if tlv.type in allowed_types or tlv.type >= 200 do
        acc
      else
        min_version = get_min_version_for_tlv(tlv.type)
        tlv_name = get_tlv_name(tlv.type)

        Result.add_error(
          acc,
          "#{tlv_name} requires DOCSIS #{min_version}, config is #{version}",
          %{tlv: tlv.type, required_version: min_version, config_version: version}
        )
      end
    end)
  end

  @doc """
  Checks for deprecated TLVs in newer DOCSIS versions.
  """
  def check_deprecated_tlvs(result, _tlvs, _version) do
    # Add warnings for deprecated TLVs
    # For now, no deprecated TLVs to check
    result
  end

  @doc """
  Checks mandatory features for DOCSIS version.
  """
  def check_mandatory_features(result, tlvs, version) do
    case version do
      "3.1" ->
        # DOCSIS 3.1 should have channel descriptors
        if not has_channel_descriptors?(tlvs) do
          Result.add_info(
            result,
            "DOCSIS 3.1 config typically includes channel descriptors (TLV 24/25)",
            %{version: version}
          )
        else
          result
        end

      _ ->
        result
    end
  end

  @doc """
  Checks vendor-specific TLV extensions.
  """
  def check_vendor_extensions(result, tlvs, _version) do
    vendor_tlvs = Enum.filter(tlvs, &(&1.type >= 200 and &1.type < 255))

    if length(vendor_tlvs) > 0 do
      Result.add_info(
        result,
        "Config contains #{length(vendor_tlvs)} vendor-specific TLV(s)",
        %{count: length(vendor_tlvs)}
      )
    else
      result
    end
  end

  ## Helper Functions

  defp find_subtlv(subtlvs, type) do
    Enum.find(subtlvs, &(&1.type == type))
  end

  defp get_tlv_name(type) do
    case DocsisSpecs.get_tlv_info(type) do
      {:ok, %{name: name}} -> "#{name} (TLV #{type})"
      _ -> "TLV #{type}"
    end
  end

  defp get_allowed_tlv_types("1.0"), do: 1..16 |> Enum.to_list()
  defp get_allowed_tlv_types("1.1"), do: 1..27 |> Enum.to_list()
  defp get_allowed_tlv_types("2.0"), do: 1..42 |> Enum.to_list()
  defp get_allowed_tlv_types("3.0"), do: 1..61 |> Enum.to_list()
  defp get_allowed_tlv_types("3.1"), do: 1..83 |> Enum.to_list()
  defp get_allowed_tlv_types(_), do: 1..255 |> Enum.to_list()

  defp get_min_version_for_tlv(type) when type <= 16, do: "1.0"
  defp get_min_version_for_tlv(type) when type <= 27, do: "1.1"
  defp get_min_version_for_tlv(type) when type <= 42, do: "2.0"
  defp get_min_version_for_tlv(type) when type <= 61, do: "3.0"
  defp get_min_version_for_tlv(type) when type <= 83, do: "3.1"
  defp get_min_version_for_tlv(_), do: "Unknown"

  defp has_channel_descriptors?(tlvs) do
    Enum.any?(tlvs, &(&1.type in [24, 25, 65, 66, 67]))
  end
end
