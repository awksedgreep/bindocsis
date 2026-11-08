defmodule Bindocsis.MtaSpecs do
  @moduledoc """
  TLV types of a PacketCable MTA configuration file.

  Source: PKT-SP-PROV1.5-C01-191120 §9.1 ("MTA Configuration File") and
  §11 (TLV-38). An MTA file is a sequence of:

  | TLV | Name                                  | Length field |
  |-----|---------------------------------------|--------------|
  | 254 | Telephony Config File Start / End     | 1 byte (value 0x01 = start, 0xFF = end) |
  | 11  | SNMP MIB Object (variable binding)    | 1 byte       |
  | 64  | SNMP MIB Object, 2-byte length        | 2 bytes      |
  | 38  | SNMP Notification Receiver (sub-TLVs) | 1 byte       |
  | 43  | Vendor Specific (DOCSIS)              | 1 byte       |

  All service parameters (lines, SIP/NCS servers, realms, ...) are SNMP MIB
  objects carried in TLV 11/64, not TLVs of their own. Files built with DOCSIS
  tooling may also carry the DOCSIS CM MIC (6) and CMTS MIC (7) after the end
  marker, so those are listed too (DOCSIS MULPI).

  Earlier versions of this table listed TLVs 1-5 and 64-85 ("MTA
  Configuration File", "Kerberos Realm", "Line Package", ...) that no
  PacketCable specification defines. They were removed. See CLAUDE.md:
  TLVs must come from the specifications.

  The version argument is kept for API compatibility. Every entry is part
  of the PacketCable 1.x MTA file format, so all versions return the same
  table.
  """

  @type tlv_info :: %{
          name: String.t(),
          description: String.t(),
          introduced_version: String.t(),
          subtlv_support: boolean(),
          value_type: atom(),
          max_length: non_neg_integer() | :unlimited,
          mta_specific: boolean()
        }

  @type packetcable_version :: String.t()

  @spec_tlvs %{
    6 => %{
      name: "CM MIC",
      description:
        "DOCSIS CM Message Integrity Check; appears after the MTA end marker in files " <>
          "built with DOCSIS tooling and is not used by the MTA",
      introduced_version: "1.0",
      subtlv_support: false,
      value_type: :binary,
      max_length: 16,
      mta_specific: false
    },
    7 => %{
      name: "CMTS MIC",
      description:
        "DOCSIS CMTS Message Integrity Check; appears after the MTA end marker in files " <>
          "built with DOCSIS tooling and is not used by the MTA",
      introduced_version: "1.0",
      subtlv_support: false,
      value_type: :binary,
      max_length: 16,
      mta_specific: false
    },
    11 => %{
      name: "SNMP MIB Object",
      description:
        "SNMP variable binding (BER-encoded OID and value), applied as an SNMP Set; " <>
          "1-byte length, at most 254 bytes (PKT-SP-PROV1.5 §9.1)",
      introduced_version: "1.0",
      subtlv_support: false,
      value_type: :asn1_der,
      max_length: 254,
      mta_specific: false
    },
    38 => %{
      name: "SNMP Notification Receiver",
      description:
        "Network management station that receives the MTA's SNMP notifications " <>
          "(PKT-SP-PROV1.5 §11)",
      introduced_version: "1.0",
      subtlv_support: true,
      value_type: :compound,
      max_length: 255,
      mta_specific: false
    },
    43 => %{
      name: "Vendor Specific",
      description:
        "DOCSIS vendor-specific information; an MTA ignores a TLV 43 whose vendor ID " <>
          "is not its own (PKT-SP-PROV1.5 §9.1)",
      introduced_version: "1.0",
      subtlv_support: true,
      value_type: :vendor,
      max_length: 255,
      mta_specific: false
    },
    64 => %{
      name: "SNMP MIB Object Long",
      description:
        "SNMP variable binding with a 2-byte length field; required for variable " <>
          "bindings longer than 254 bytes (PKT-SP-PROV1.5 §9.1)",
      introduced_version: "1.0",
      subtlv_support: false,
      value_type: :asn1_der,
      max_length: 65_535,
      mta_specific: true
    },
    254 => %{
      name: "Telephony Config File Delimiter",
      description:
        "Telephony configuration file start (value 0x01) and end (value 0xFF) markers; " <>
          "an MTA file must begin and end with them (PKT-SP-PROV1.5 §9.1)",
      introduced_version: "1.0",
      subtlv_support: false,
      value_type: :uint8,
      max_length: 1,
      mta_specific: true
    }
  }

  @doc """
  Gets TLV information for a specific type and PacketCable version.

  ## Parameters

  - `type` - TLV type number
  - `version` - PacketCable version ("1.0", "1.5", "2.0")

  ## Returns

  - `{:ok, tlv_info}` - TLV information map
  - `{:error, :unsupported_type}` - TLV type not supported
  - `{:error, :unsupported_version}` - Version doesn't support this TLV

  ## Examples

      iex> {:ok, info} = Bindocsis.MtaSpecs.get_tlv_info(254, "1.0")
      iex> info.name
      "Telephony Config File Delimiter"
      
      iex> Bindocsis.MtaSpecs.get_tlv_info(999, "1.0")
      {:error, :unsupported_type}
  """
  @spec get_tlv_info(non_neg_integer(), String.t()) ::
          {:ok, tlv_info()} | {:error, :unsupported_type | :unsupported_version}
  def get_tlv_info(type, version \\ "2.0") do
    case get_all_tlvs()[type] do
      nil ->
        {:error, :unsupported_type}

      tlv_info ->
        if version_supports_tlv?(version, tlv_info.introduced_version) do
          {:ok, tlv_info}
        else
          {:error, :unsupported_version}
        end
    end
  end

  @doc """
  Gets the TLV specification for a PacketCable version.
  """
  @spec get_spec(String.t()) :: map()
  def get_spec("1.0") do
    get_all_tlvs()
    |> filter_by_version("1.0")
  end

  def get_spec("1.5") do
    get_all_tlvs()
    |> filter_by_version("1.5")
  end

  def get_spec("2.0") do
    get_all_tlvs()
    |> filter_by_version("2.0")
  end

  def get_spec(_unknown_version) do
    # Default to latest
    get_spec("2.0")
  end

  @doc """
  Checks if a TLV type is valid for the given PacketCable version.
  """
  @spec valid_tlv_type?(non_neg_integer(), String.t()) :: boolean()
  def valid_tlv_type?(type, version \\ "2.0") do
    case get_tlv_info(type, version) do
      {:ok, _} -> true
      {:error, _} -> false
    end
  end

  @doc """
  Gets all supported TLV types for a PacketCable version.
  """
  @spec get_supported_types(String.t()) :: [non_neg_integer()]
  def get_supported_types(version \\ "2.0") do
    get_spec(version)
    |> Map.keys()
    |> Enum.sort()
  end

  @doc """
  Gets the human-readable name for a TLV type.
  """
  @spec get_tlv_name(non_neg_integer(), String.t()) :: String.t() | nil
  def get_tlv_name(type, version \\ "2.0") do
    case get_tlv_info(type, version) do
      {:ok, info} -> info.name
      {:error, _} -> nil
    end
  end

  @doc """
  Checks if a TLV type supports sub-TLVs.
  """
  @spec supports_subtlvs?(non_neg_integer(), String.t()) :: boolean()
  def supports_subtlvs?(type, version \\ "2.0") do
    case get_tlv_info(type, version) do
      {:ok, info} -> info.subtlv_support
      {:error, _} -> false
    end
  end

  @doc """
  Gets the description for a TLV type.
  """
  @spec get_tlv_description(non_neg_integer(), String.t()) :: String.t() | nil
  def get_tlv_description(type, version \\ "2.0") do
    case get_tlv_info(type, version) do
      {:ok, info} -> info.description
      {:error, _} -> nil
    end
  end

  @doc """
  Gets the value type for a TLV.
  """
  @spec get_tlv_value_type(non_neg_integer(), String.t()) :: atom() | nil
  def get_tlv_value_type(type, version \\ "2.0") do
    case get_tlv_info(type, version) do
      {:ok, info} -> info.value_type
      {:error, _} -> nil
    end
  end

  @doc """
  Gets the maximum length for a TLV value.
  """
  @spec get_tlv_max_length(non_neg_integer(), String.t()) :: non_neg_integer() | :unlimited | nil
  def get_tlv_max_length(type, version \\ "2.0") do
    case get_tlv_info(type, version) do
      {:ok, info} -> info.max_length
      {:error, _} -> nil
    end
  end

  @doc """
  Gets the PacketCable version where a TLV was introduced.
  """
  @spec get_tlv_introduced_version(non_neg_integer()) :: String.t() | nil
  def get_tlv_introduced_version(type) do
    case get_all_tlvs()[type] do
      nil -> nil
      info -> info.introduced_version
    end
  end

  @doc """
  Checks if a TLV is MTA-specific or shared with DOCSIS.
  """
  @spec mta_specific?(non_neg_integer()) :: boolean()
  def mta_specific?(type) do
    case get_all_tlvs()[type] do
      nil -> false
      info -> Map.get(info, :mta_specific, false)
    end
  end

  @doc """
  Gets all MTA-specific TLV types.
  """
  @spec get_mta_specific_types() :: [non_neg_integer()]
  def get_mta_specific_types do
    get_all_tlvs()
    |> Enum.filter(fn {_type, info} -> Map.get(info, :mta_specific, false) end)
    |> Enum.map(fn {type, _info} -> type end)
    |> Enum.sort()
  end

  # Private functions

  defp get_all_tlvs, do: @spec_tlvs

  defp version_supports_tlv?(current_version, introduced_version) do
    version_priority = %{
      "1.0" => 1,
      "1.5" => 2,
      "2.0" => 3
    }

    current_priority = Map.get(version_priority, current_version, 0)
    introduced_priority = Map.get(version_priority, introduced_version, 999)

    current_priority >= introduced_priority
  end

  defp filter_by_version(tlv_map, version) do
    tlv_map
    |> Enum.filter(fn {_type, info} ->
      version_supports_tlv?(version, info.introduced_version)
    end)
    |> Enum.into(%{})
  end
end
