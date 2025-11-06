defmodule Bindocsis.Validation do
  @moduledoc """
  DOCSIS configuration validation module.

  Provides validation functions to ensure DOCSIS configurations comply
  with the specified DOCSIS version requirements.
  """

  # DOCSIS 3.0 TLV types
  @docsis_30_tlvs %{
    1 => "Downstream Frequency",
    2 => "Upstream Channel ID",
    3 => "Network Access Control",
    4 => "Class of Service",
    5 => "Modem Capabilities",
    6 => "CM Message Integrity Check",
    7 => "CMTS Message Integrity Check",
    8 => "Vendor ID",
    9 => "Software Upgrade Filename",
    10 => "SNMP Write Access Control",
    11 => "SNMP MIB Object",
    12 => "Modem IP Address",
    13 => "Service Provider Name",
    14 => "Software Upgrade Server",
    15 => "Upstream Packet Classification",
    16 => "Downstream Packet Classification",
    17 => "Upstream Service Flow",
    18 => "Downstream Service Flow",
    19 => "PHS Rule",
    20 => "HMac Digest",
    21 => "Max CPE IP Addresses",
    22 => "TFTP Server Timestamp",
    23 => "TFTP Server Address",
    24 => "Upstream Channel Descriptor",
    25 => "Downstream Channel List",
    26 => "TFTP Modem Address",
    27 => "Software Upgrade Log Server",
    28 => "Software Upgrade Log Filename",
    29 => "DHCP Option Code",
    30 => "Baseline Privacy Config",
    31 => "Baseline Privacy Key Management",
    32 => "Max Classifiers",
    33 => "Privacy Enable",
    34 => "Authorization Block",
    35 => "Key Sequence Number",
    36 => "Manufacturer CVC",
    37 => "CoSign CVC",
    38 => "SnmpV3 Kickstart",
    39 => "Subscriber Management Control",
    40 => "Subscriber Management CPE IP List",
    41 => "Subscriber Management Filter Groups",
    42 => "SNMPv3 Notification Receiver",
    43 => "Enable 20/40 MHz Operation",
    44 => "Software Upgrade HTTP Server",
    50 => "Transmit Pre-Equalizer",
    51 => "Downstream Channel List Override",
    60 => "Software Upgrade TFTP Server",
    61 => "Software Upgrade HTTP Server",
    254 => "Pad",
    255 => "End-of-Data Marker"
  }

  # DOCSIS 3.1 additional TLVs
  @docsis_31_additional_tlvs %{
    45 => "IPv4 Multicast Join Authorization",
    46 => "IPv6 Multicast Join Authorization",
    47 => "Upstream Drop Packet Classification",
    48 => "Subscriber Management Event Control",
    49 => "Test Mode Configuration",
    52 => "Diplexer Upstream Upper Band Edge Configuration",
    53 => "Diplexer Downstream Lower Band Edge Configuration",
    54 => "Diplexer Downstream Upper Band Edge Configuration",
    55 => "Diplexer Upstream Upper Band Edge Override",
    56 => "Extended Upstream Transmit Power",
    57 => "Optional RFI Mitigation Override",
    58 => "Energy Management 1x1 Mode",
    59 => "Extended Power Mode",
    62 => "Downstream OFDM Profile",
    63 => "Downstream OFDMA Profile",
    64 => "Two Way Operation",
    65 => "Downstream OFDM Channel Configuration",
    66 => "Upstream OFDMA Channel Configuration",
    67 => "Downstream OFDMA Channel Configuration",
    68 => "Upstream Frequency Range",
    69 => "Symbol Clock Locking Indicator",
    70 => "CM Status Event Control",
    71 => "Upstream Power Back Off",
    72 => "Downstream Power Back Off",
    73 => "Channel Assignment Configuration",
    74 => "CM Attribute Masks",
    75 => "OUI Associated to Device",
    76 => "Multicast DSID Forward",
    77 => "FCType Forwarding",
    78 => "Multicast PHS Rule",
    79 => "DUT Filtering Control",
    80 => "Subscriber Management Enable",
    81 => "IP Multicast Join Authorization Static Session Rule",
    82 => "Fan Control",
    83 => "Extended CMTS Message Integrity Check"
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

  defp validate_single_tlv_value(%{type: 21, value: value}, _version) do
    # Max CPE IP Addresses - should be reasonable number
    case parse_integer(value) do
      {:ok, count} when count >= 1 and count <= 254 -> []
      {:ok, _count} -> [{:invalid_tlv, 21, "CPE count must be between 1-254"}]
      {:error, reason} -> [{:invalid_tlv, 21, "Invalid CPE count format: #{reason}"}]
    end
  end

  defp validate_single_tlv_value(%{type: 4, subtlvs: subtlvs}, _version) when is_list(subtlvs) do
    # Class of Service validation
    validate_cos_subtlvs(subtlvs)
  end

  defp validate_single_tlv_value(%{type: 17, subtlvs: subtlvs}, _version) when is_list(subtlvs) do
    # Upstream Service Flow validation
    validate_service_flow_subtlvs(subtlvs, :upstream)
  end

  defp validate_single_tlv_value(%{type: 18, subtlvs: subtlvs}, _version) when is_list(subtlvs) do
    # Downstream Service Flow validation  
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

  defp validate_service_flow_subtlvs(subtlvs, direction) do
    errors = []

    # Check for required Service Flow Reference
    has_sf_ref = Enum.any?(subtlvs, fn %{type: type} -> type == 1 end)

    if not has_sf_ref do
      dir_name = if direction == :upstream, do: "Upstream", else: "Downstream"

      [
        {:invalid_tlv, if(direction == :upstream, do: 17, else: 18),
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

    # Some TLVs should only appear once
    single_occurrence_tlvs = [1, 2, 8, 12, 21, 22, 23]

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
