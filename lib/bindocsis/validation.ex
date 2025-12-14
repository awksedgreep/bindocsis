defmodule Bindocsis.Validation do
  @moduledoc """
  DOCSIS configuration validation module.

  Provides validation functions to ensure DOCSIS configurations comply
  with the specified DOCSIS version requirements.
  """

  # DOCSIS TLV types per CableLabs CANN-I22-230308
  # Note: This module should use DocsisSpecs for TLV names where possible
  @docsis_30_tlvs %{
    0 => "Pad",
    1 => "Downstream Frequency",
    2 => "Upstream Channel ID",
    3 => "Network Access Control",
    4 => "Class of Service",
    5 => "Modem Capabilities",
    6 => "CM MIC",
    7 => "CMTS MIC",
    8 => "Vendor ID",
    9 => "SW Upgrade Filename",
    10 => "SNMP Write Access Control",
    11 => "SNMP MIB Object",
    12 => "Modem IP Address",
    13 => "Services Not Available Response",
    14 => "CPE Ethernet MAC Address",
    15 => "Telephone Settings Option",
    # TLV 16 is reserved/skipped
    17 => "Baseline Privacy",
    18 => "Max Number of CPEs",
    19 => "TFTP Server Timestamp",
    20 => "TFTP Server Provisioned Modem Address",
    21 => "SW Upgrade IPv4 TFTP Server",
    22 => "Upstream Packet Classification",
    23 => "Downstream Packet Classification",
    24 => "Upstream Service Flow",
    25 => "Downstream Service Flow",
    26 => "Payload Header Suppression",
    27 => "HMAC Digest",
    28 => "Maximum Number of Classifiers",
    29 => "Privacy Enable",
    30 => "Authorization Block",
    31 => "Key Sequence Number",
    32 => "Manufacturer CVC",
    33 => "Co-Signer CVC",
    34 => "SNMPv3 Kickstart Value",
    35 => "Subscriber Mgmt Control",
    36 => "Subscriber Mgmt CPE IPv4 List",
    37 => "Subscriber Mgmt Filter Groups",
    38 => "SNMPv3 Notification Receiver",
    39 => "Enable 2.0 Mode",
    40 => "Enable Test Modes",
    41 => "Downstream Channel List",
    42 => "Static Multicast MAC Address",
    43 => "Vendor Specific",
    44 => "Vendor Specific Capabilities",
    45 => "DUT Filtering",
    46 => "Transmit Channel Configuration",
    47 => "Service Flow SID Cluster Assignment",
    48 => "Receive Channel Profile",
    49 => "Receive Channel Configuration",
    50 => "DSID Encodings",
    255 => "End-of-Data"
  }

  # DOCSIS 3.1/4.0 additional TLVs per CableLabs CANN-I22-230308
  @docsis_31_additional_tlvs %{
    51 => "Security Association Encoding",
    52 => "Initializing Channel Timeout",
    53 => "SNMPv1v2c Coexistence",
    54 => "SNMPv3 Access View Configuration",
    55 => "SNMP CPE Access Control",
    56 => "Channel Assignment Configuration",
    57 => "CM Initialization Reason",
    58 => "SW Upgrade IPv6 TFTP Server",
    59 => "TFTP Server Provisioned Modem IPv6 Address",
    60 => "Upstream Drop Packet Classification",
    61 => "Subscriber Mgmt CPE IPv6 Prefix List",
    62 => "Downstream OFDM Profile",
    63 => "Downstream OFDMA Profile",
    64 => "CMTS Static Multicast Session Encoding",
    65 => "L2VPN MAC Aging Encoding",
    66 => "Management Event Control Encoding",
    67 => "Subscriber Mgmt CPE IPv6 Prefix List Default",
    68 => "Upstream Target Buffer Configuration",
    69 => "MAC Address Learning Control Encoding",
    70 => "Upstream Aggregate Service Flow",
    71 => "Downstream Aggregate Service Flow",
    72 => "Metro Ethernet Service Profile",
    73 => "Network Timing Profile",
    74 => "Energy Management Parameter Encoding",
    75 => "Energy Mgt Mode Indicator",
    76 => "CM Upstream AQM Disable",
    77 => "FCType Forwarding",
    78 => "Energy Management Identifier List for CM",
    79 => "UNI Control Encoding",
    80 => "Energy Management DOCSIS Light Sleep Encodings",
    81 => "Manufacturer CVC Chain",
    82 => "Co-Signer CVC Chain",
    83 => "Extended CMTS Message Integrity Check",
    84 => "DTP Mode Configuration",
    85 => "Diplexer Band Edge"
  }

  # Network Access, CoS, CM MIC, CMTS MIC
  @required_tlvs [3, 4, 6, 7]

  def validate_tlvs(tlvs) when is_list(tlvs) do
    validate_docsis_compliance(tlvs, "3.1")
  end

  def validate_docsis_compliance(tlvs, version \\ "3.1") when is_list(tlvs) do
    case get_valid_tlvs_for_version(version) do
      {:error, reason} ->
        {:error, [reason]}

      valid_tlvs ->
        errors =
          []
          |> validate_tlv_types(tlvs, valid_tlvs)
          |> validate_required_tlvs(tlvs)
          |> validate_tlv_values(tlvs, version)
          |> validate_tlv_conflicts(tlvs)

        case errors do
          [] -> :ok
          errors -> {:error, errors}
        end
    end
  end

  defp get_valid_tlvs_for_version("3.0") do
    @docsis_30_tlvs
  end

  defp get_valid_tlvs_for_version("3.1") do
    Map.merge(@docsis_30_tlvs, @docsis_31_additional_tlvs)
  end

  defp get_valid_tlvs_for_version(version) do
    {:error,
     {:invalid_version, version,
      "Unsupported DOCSIS version: #{version}. Supported versions: 3.0, 3.1"}}
  end

  defp validate_tlv_types(errors, tlvs, valid_tlvs) do
    invalid_types =
      tlvs
      |> Enum.map(fn %{type: type} -> type end)
      |> Enum.uniq()
      |> Enum.reject(fn type -> Map.has_key?(valid_tlvs, type) end)

    new_errors =
      invalid_types
      |> Enum.map(fn type ->
        {:invalid_tlv, type, "Unknown TLV type for this DOCSIS version"}
      end)

    errors ++ new_errors
  end

  defp validate_required_tlvs(errors, tlvs) do
    present_types = Enum.map(tlvs, fn %{type: type} -> type end) |> MapSet.new()

    missing_required =
      @required_tlvs
      |> Enum.reject(fn type -> MapSet.member?(present_types, type) end)

    new_errors =
      missing_required
      |> Enum.map(fn type ->
        {:invalid_tlv, type, "Required TLV missing"}
      end)

    errors ++ new_errors
  end

  defp validate_tlv_values(errors, tlvs, version) do
    new_errors =
      tlvs
      |> Enum.flat_map(fn tlv -> validate_single_tlv_value(tlv, version) end)

    errors ++ new_errors
  end

  defp validate_single_tlv_value(%{type: 1, value: value}, _version) do
    # Downstream Frequency - should be valid frequency
    case parse_frequency(value) do
      {:ok, freq} when freq >= 54_000_000 and freq <= 1_000_000_000 -> []
      {:ok, _freq} -> [{:invalid_tlv, 1, "Frequency out of valid range (54-1000 MHz)"}]
      {:error, reason} -> [{:invalid_tlv, 1, "Invalid frequency format: #{reason}"}]
    end
  end

  defp validate_single_tlv_value(%{type: 18, value: value}, _version) do
    # Max Number of CPEs - should be reasonable number (per CANN-I22)
    case parse_integer(value) do
      {:ok, count} when count >= 1 and count <= 254 -> []
      {:ok, _count} -> [{:invalid_tlv, 18, "CPE count must be between 1-254"}]
      {:error, reason} -> [{:invalid_tlv, 18, "Invalid CPE count format: #{reason}"}]
    end
  end

  defp validate_single_tlv_value(%{type: 4, subtlvs: subtlvs}, _version) when is_list(subtlvs) do
    # Class of Service validation
    validate_cos_subtlvs(subtlvs)
  end

  defp validate_single_tlv_value(%{type: 17, subtlvs: subtlvs}, _version) when is_list(subtlvs) do
    # Baseline Privacy validation (per CANN-I22)
    # TLV 17 is now Baseline Privacy, not Upstream Service Flow
    validate_baseline_privacy_subtlvs(subtlvs)
  end

  defp validate_single_tlv_value(%{type: 24, subtlvs: subtlvs}, _version) when is_list(subtlvs) do
    # Upstream Service Flow validation (per CANN-I22)
    validate_service_flow_subtlvs(subtlvs, :upstream)
  end

  defp validate_single_tlv_value(%{type: 25, subtlvs: subtlvs}, _version) when is_list(subtlvs) do
    # Downstream Service Flow validation (per CANN-I22)
    validate_service_flow_subtlvs(subtlvs, :downstream)
  end

  defp validate_single_tlv_value(_tlv, _version), do: []

  defp validate_cos_subtlvs(subtlvs) do
    errors = []

    # Check for required CoS sub-TLVs
    has_class_id = Enum.any?(subtlvs, fn %{type: type} -> type == 1 end)
    has_max_rate = Enum.any?(subtlvs, fn %{type: type} -> type == 2 end)

    errors =
      if not has_class_id do
        [{:invalid_tlv, 4, "CoS missing required Class ID (sub-TLV 1)"} | errors]
      else
        errors
      end

    errors =
      if not has_max_rate do
        [{:invalid_tlv, 4, "CoS missing required Max Rate (sub-TLV 2)"} | errors]
      else
        errors
      end

    errors
  end

  defp validate_baseline_privacy_subtlvs(_subtlvs) do
    # Basic validation for Baseline Privacy (TLV 17)
    # BPI+ configuration - minimal validation for now
    []
  end

  defp validate_service_flow_subtlvs(subtlvs, direction) do
    errors = []

    # Check for required Service Flow Reference
    has_sf_ref = Enum.any?(subtlvs, fn %{type: type} -> type == 1 end)

    if not has_sf_ref do
      dir_name = if direction == :upstream, do: "Upstream", else: "Downstream"
      # TLV 24 = Upstream SF, TLV 25 = Downstream SF per CANN-I22
      tlv_type = if direction == :upstream, do: 24, else: 25

      [
        {:invalid_tlv, tlv_type,
         "#{dir_name} Service Flow missing required SF Reference (sub-TLV 1)"}
        | errors
      ]
    else
      errors
    end
  end

  defp validate_tlv_conflicts(errors, tlvs) do
    # Check for conflicting TLVs
    type_counts =
      tlvs
      |> Enum.group_by(fn %{type: type} -> type end)
      |> Enum.map(fn {type, list} -> {type, length(list)} end)
      |> Enum.into(%{})

    # Some TLVs should only appear once (per CANN-I22)
    # TLV 18 = Max Number of CPEs, TLV 19 = TFTP Server Timestamp
    single_occurrence_tlvs = [1, 2, 8, 12, 18, 19, 20]

    conflict_errors =
      single_occurrence_tlvs
      |> Enum.filter(fn type -> Map.get(type_counts, type, 0) > 1 end)
      |> Enum.map(fn type ->
        {:invalid_tlv, type, "TLV should only appear once in configuration"}
      end)

    errors ++ conflict_errors
  end

  # Helper functions for parsing values
  defp parse_frequency(<<freq::32>>), do: {:ok, freq}

  defp parse_frequency(value) when is_integer(value), do: {:ok, value}

  defp parse_frequency(value) when is_binary(value) do
    case Integer.parse(value) do
      {freq, ""} -> {:ok, freq}
      # Handle MHz to Hz conversion
      {freq, "000000"} -> {:ok, freq * 1_000_000}
      # Handle kHz to Hz conversion
      {freq, "000"} -> {:ok, freq * 1_000}
      _ -> {:error, "Invalid frequency format"}
    end
  end

  defp parse_frequency(_), do: {:error, "Unknown frequency format"}

  defp parse_integer(<<int::8>>), do: {:ok, int}
  defp parse_integer(<<int::16>>), do: {:ok, int}
  defp parse_integer(<<int::32>>), do: {:ok, int}

  defp parse_integer(value) when is_integer(value), do: {:ok, value}

  defp parse_integer(value) when is_binary(value) do
    case Integer.parse(value) do
      {int, ""} -> {:ok, int}
      _ -> {:error, "Invalid integer format"}
    end
  end

  defp parse_integer(_), do: {:error, "Unknown integer format"}

  @doc """
  Validates a single TLV for DOCSIS version compliance.
  """
  def validate_tlv_for_version(%{type: type} = tlv, version) do
    valid_tlvs = get_valid_tlvs_for_version(version)

    cond do
      not Map.has_key?(valid_tlvs, type) ->
        {:error, "TLV #{type} not supported in DOCSIS #{version}"}

      Map.has_key?(tlv, :subtlvs) and is_list(tlv.subtlvs) ->
        validate_subtlvs_for_version(tlv.subtlvs, type, version)

      true ->
        :ok
    end
  end

  defp validate_subtlvs_for_version(subtlvs, parent_type, version) do
    errors =
      subtlvs
      |> Enum.flat_map(fn subtlv ->
        case validate_subtlv_for_version(subtlv, parent_type, version) do
          :ok -> []
          {:error, reason} -> [reason]
        end
      end)

    case errors do
      [] -> :ok
      errors -> {:error, Enum.join(errors, "; ")}
    end
  end

  defp validate_subtlv_for_version(%{type: type}, parent_type, _version) do
    # For now, we'll do basic sub-TLV validation
    # This can be expanded with specific sub-TLV requirements
    if type >= 1 and type <= 255 do
      :ok
    else
      {:error, "Invalid sub-TLV #{type} in TLV #{parent_type}"}
    end
  end

  @doc """
  Returns human-readable description of TLV type.
  """
  def get_tlv_description(type, version \\ "3.1") do
    valid_tlvs = get_valid_tlvs_for_version(version)
    Map.get(valid_tlvs, type, "Unknown TLV")
  end

  @doc """
  Checks if a TLV type is valid for the given DOCSIS version.
  """
  def valid_tlv_type?(type, version \\ "3.1") do
    valid_tlvs = get_valid_tlvs_for_version(version)
    Map.has_key?(valid_tlvs, type)
  end

  @doc """
  Returns list of all valid TLV types for a DOCSIS version.
  """
  def get_valid_tlv_types(version \\ "3.1") do
    valid_tlvs = get_valid_tlvs_for_version(version)
    Map.keys(valid_tlvs) |> Enum.sort()
  end
end
