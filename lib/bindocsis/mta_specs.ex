defmodule Bindocsis.MtaSpecs do
  @moduledoc """
  PacketCable MTA TLV specifications for multimedia terminal adapters.
  
  Provides comprehensive TLV type definitions, descriptions, and version-specific
  support information for PacketCable MTA configuration parsing and validation.
  
  ## Supported PacketCable Versions
  
  - **PacketCable 1.0**: Basic voice services
  - **PacketCable 1.5**: Enhanced security and features  
  - **PacketCable 2.0**: Advanced voice and multimedia services
  
  ## TLV Categories
  
  - **Basic Configuration** (1-30): Core DOCSIS parameters (shared with CM)
  - **Security & Privacy** (31-42): Encryption and authentication
  - **Voice Services** (64-70): PacketCable voice-specific TLVs
  - **MTA-Specific** (71-85): MTA device configuration
  - **Vendor Specific** (200-254): Vendor-defined extensions
  
  ## Key Differences from DOCSIS CM Files
  
  - Includes voice endpoint configuration
  - PacketCable security model support
  - Voice service flows and QoS parameters
  - MTA device provisioning parameters
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

  # Core DOCSIS TLVs that are also used in MTA files (1-63)
  # These are inherited from DOCSIS but may have different usage in MTA context
  @shared_docsis_tlvs %{
    1 => %{
      name: "Downstream Frequency",
      description: "Center frequency of the downstream channel in Hz",
      introduced_version: "1.0",
      subtlv_support: false,
      value_type: :uint32,
      max_length: 4,
      mta_specific: false
    },
    2 => %{
      name: "Upstream Channel ID", 
      description: "Upstream channel identifier",
      introduced_version: "1.0",
      subtlv_support: false,
      value_type: :uint8,
      max_length: 1,
      mta_specific: false
    },
    3 => %{
      name: "Network Access Control",
      description: "Enable/disable network access for the MTA",
      introduced_version: "1.0",
      subtlv_support: false,
      value_type: :boolean,
      max_length: 1,
      mta_specific: false
    },
    4 => %{
      name: "Class of Service",
      description: "Service class configuration",
      introduced_version: "1.0",
      subtlv_support: true,
      value_type: :compound,
      max_length: :unlimited,
      mta_specific: false
    },
    5 => %{
      name: "Modem Capabilities",
      description: "MTA device capabilities",
      introduced_version: "1.0",
      subtlv_support: true,
      value_type: :compound,
      max_length: :unlimited,
      mta_specific: true
    },
    6 => %{
      name: "CM MIC",
      description: "Cable Modem Message Integrity Check",
      introduced_version: "1.0",
      subtlv_support: false,
      value_type: :raw,
      max_length: 16,
      mta_specific: false
    },
    7 => %{
      name: "CMTS MIC",
      description: "Cable Modem Termination System Message Integrity Check",
      introduced_version: "1.0",
      subtlv_support: false,
      value_type: :raw,
      max_length: 16,
      mta_specific: false
    }
  }

  # PacketCable voice-specific TLVs (64-85)
  @packetcable_tlvs %{
    64 => %{
      name: "MTA Configuration File",
      description: "PacketCable MTA configuration parameters",
      introduced_version: "1.0",
      subtlv_support: true,
      value_type: :compound,
      max_length: :unlimited,
      mta_specific: true
    },
    65 => %{
      name: "Voice Configuration",
      description: "Voice service configuration parameters",
      introduced_version: "1.0", 
      subtlv_support: true,
      value_type: :compound,
      max_length: :unlimited,
      mta_specific: true
    },
    66 => %{
      name: "Call Signaling",
      description: "Call signaling protocol configuration",
      introduced_version: "1.0",
      subtlv_support: true,
      value_type: :compound,
      max_length: :unlimited,
      mta_specific: true,
      accepts_simple_value: true,
      simple_value_type: :string
    },
    67 => %{
      name: "Media Gateway",
      description: "Media gateway configuration",
      introduced_version: "1.0",
      subtlv_support: true,
      value_type: :compound,
      max_length: :unlimited,
      mta_specific: true,
      accepts_simple_value: true,
      simple_value_type: :string
    },
    68 => %{
      name: "Security Association",
      description: "PacketCable security association parameters",
      introduced_version: "1.0",
      subtlv_support: true,
      value_type: :compound,
      max_length: :unlimited,
      mta_specific: true
    },
    69 => %{
      name: "Kerberos Realm",
      description: "Kerberos realm configuration for secure provisioning",
      introduced_version: "1.0",
      subtlv_support: false,
      value_type: :string,
      max_length: 255,
      mta_specific: true
    },
    70 => %{
      name: "DNS Server",
      description: "DNS server IP addresses for MTA",
      introduced_version: "1.0",
      subtlv_support: false,
      value_type: :ipv4,
      max_length: 4,
      mta_specific: true
    },
    71 => %{
      name: "MTA IP Provisioning Mode",
      description: "IP provisioning mode (DHCP, static, etc.)",
      introduced_version: "1.0",
      subtlv_support: false,
      value_type: :uint8,
      max_length: 1,
      mta_specific: true
    },
    72 => %{
      name: "Provisioning Timer",
      description: "MTA provisioning timeout values",
      introduced_version: "1.0",
      subtlv_support: true,
      value_type: :compound,
      max_length: :unlimited,
      mta_specific: true
    },
    73 => %{
      name: "Ticket Control",
      description: "Kerberos ticket control parameters",
      introduced_version: "1.5",
      subtlv_support: true,
      value_type: :compound,
      max_length: :unlimited,
      mta_specific: true
    },
    74 => %{
      name: "Realm Organization Name",
      description: "Organization name for Kerberos realm",
      introduced_version: "1.5",
      subtlv_support: false,
      value_type: :string,
      max_length: 255,
      mta_specific: true
    },
    75 => %{
      name: "Provisioning Server",
      description: "PacketCable provisioning server configuration",
      introduced_version: "1.0",
      subtlv_support: true,
      value_type: :compound,
      max_length: :unlimited,
      mta_specific: true
    },
    76 => %{
      name: "MTA Hardware Version",
      description: "MTA hardware version information",
      introduced_version: "1.0",
      subtlv_support: false,
      value_type: :string,
      max_length: 64,
      mta_specific: true
    },
    77 => %{
      name: "MTA Software Version",
      description: "MTA software version information",
      introduced_version: "1.0",
      subtlv_support: false,
      value_type: :string,
      max_length: 64,
      mta_specific: true
    },
    78 => %{
      name: "MTA MAC Address",
      description: "MTA MAC address",
      introduced_version: "1.0",
      subtlv_support: false,
      value_type: :mac,
      max_length: 6,
      mta_specific: true
    },
    79 => %{
      name: "Subscriber ID",
      description: "Subscriber identification for voice services",
      introduced_version: "1.0",
      subtlv_support: false,
      value_type: :string,
      max_length: 255,
      mta_specific: true
    },
    80 => %{
      name: "Voice Profile",
      description: "Voice codec and media configuration profile",
      introduced_version: "2.0",
      subtlv_support: true,
      value_type: :compound,
      max_length: :unlimited,
      mta_specific: true
    },
    81 => %{
      name: "Emergency Services",
      description: "E911 and emergency services configuration",
      introduced_version: "1.5",
      subtlv_support: true,
      value_type: :compound,
      max_length: :unlimited,
      mta_specific: true
    },
    82 => %{
      name: "Lawful Intercept",
      description: "Lawful intercept capability configuration",
      introduced_version: "1.5",
      subtlv_support: true,
      value_type: :compound,
      max_length: :unlimited,
      mta_specific: true
    },
    83 => %{
      name: "Call Feature Configuration",
      description: "Call features like call waiting, forwarding, etc.",
      introduced_version: "1.0",
      subtlv_support: true,
      value_type: :compound,
      max_length: :unlimited,
      mta_specific: true
    },
    84 => %{
      name: "Line Package",
      description: "Voice line package and service configuration",
      introduced_version: "1.0",
      subtlv_support: true,
      value_type: :compound,
      max_length: :unlimited,
      mta_specific: true
    },
    85 => %{
      name: "MTA Certificate",
      description: "X.509 certificate for MTA authentication",
      introduced_version: "1.0",
      subtlv_support: false,
      value_type: :raw,
      max_length: 2048,
      mta_specific: true
    }
  }

  # Vendor-specific TLVs (200-254) - same as DOCSIS but with MTA context
  @vendor_tlvs %{
    200 => %{
      name: "Vendor Specific Information",
      description: "Vendor-specific configuration data",
      introduced_version: "1.0",
      subtlv_support: true,
      value_type: :compound,
      max_length: :unlimited,
      mta_specific: false
    }
    # Additional vendor TLVs would be added here as needed
  }

  @doc """
  Gets TLV information for a specific type and PacketCable version.
  
  ## Parameters
  
  - `type` - TLV type number (1-254)
  - `version` - PacketCable version ("1.0", "1.5", "2.0")
  
  ## Returns
  
  - `{:ok, tlv_info}` - TLV information map
  - `{:error, :unsupported_type}` - TLV type not supported
  - `{:error, :unsupported_version}` - Version doesn't support this TLV
  
  ## Examples
  
      iex> Bindocsis.MtaSpecs.get_tlv_info(64, "1.0")
      {:ok, %{name: "MTA Configuration File"}}
      
      iex> Bindocsis.MtaSpecs.get_tlv_info(999, "1.0")
      {:error, :unsupported_type}
  """
  @spec get_tlv_info(non_neg_integer(), String.t()) :: 
    {:ok, tlv_info()} | {:error, :unsupported_type | :unsupported_version}
  def get_tlv_info(type, version \\ "2.0") do
    case get_all_tlvs()[type] do
      nil -> {:error, :unsupported_type}
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
    get_spec("2.0")  # Default to latest
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

  defp get_all_tlvs do
    Map.merge(@shared_docsis_tlvs, @packetcable_tlvs)
    |> Map.merge(@vendor_tlvs)
  end

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