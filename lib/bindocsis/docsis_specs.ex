defmodule Bindocsis.DocsisSpecs do
  @moduledoc """
  DOCSIS TLV specifications for versions 3.0 and 3.1.
  
  Provides comprehensive TLV type definitions, descriptions, and version-specific
  support information for DOCSIS configuration parsing and validation.
  
  ## Supported DOCSIS Versions
  
  - **DOCSIS 3.0**: TLV types 1-76 with extended feature support
  - **DOCSIS 3.1**: TLV types 1-85 plus vendor-specific (200-254)
  
  ## TLV Categories
  
  - **Basic Configuration** (1-30): Core DOCSIS parameters
  - **Security & Privacy** (31-42): Encryption and authentication
  - **Advanced Features** (43-63): Enhanced capabilities
  - **DOCSIS 3.0 Extensions** (64-76): 3.0-specific features
  - **DOCSIS 3.1 Extensions** (77-85): 3.1-specific features
  - **Vendor Specific** (200-254): Vendor-defined extensions
  """

  @type tlv_info :: %{
    name: String.t(),
    description: String.t(),
    introduced_version: String.t(),
    subtlv_support: boolean(),
    value_type: atom(),
    max_length: non_neg_integer() | :unlimited
  }

  @type docsis_version :: String.t()

  # Core DOCSIS TLV specifications (1-30)
  @core_tlvs %{
    1 => %{
      name: "Downstream Frequency",
      description: "Center frequency of the downstream channel in Hz",
      introduced_version: "1.0",
      subtlv_support: false,
      value_type: :frequency,
      max_length: 4
    },
    2 => %{
      name: "Upstream Channel ID",
      description: "Upstream channel identifier",
      introduced_version: "1.0",
      subtlv_support: false,
      value_type: :uint8,
      max_length: 1
    },
    3 => %{
      name: "Network Access Control",
      description: "Enable/disable network access",
      introduced_version: "1.0",
      subtlv_support: false,
      value_type: :boolean,
      max_length: 1
    },
    4 => %{
      name: "Class of Service",
      description: "Service class configuration",
      introduced_version: "1.0",
      subtlv_support: true,
      value_type: :compound,
      max_length: :unlimited
    },
    5 => %{
      name: "Modem Capabilities",
      description: "Cable modem capability parameters",
      introduced_version: "1.0",
      subtlv_support: true,
      value_type: :compound,
      max_length: :unlimited
    },
    6 => %{
      name: "CM Message Integrity Check",
      description: "Cable modem MIC for configuration integrity",
      introduced_version: "1.0",
      subtlv_support: false,
      value_type: :binary,
      max_length: 16
    },
    7 => %{
      name: "CMTS Message Integrity Check",
      description: "CMTS MIC for configuration integrity",
      introduced_version: "1.0",
      subtlv_support: false,
      value_type: :binary,
      max_length: 16
    },
    8 => %{
      name: "Vendor ID",
      description: "Vendor identification",
      introduced_version: "1.0",
      subtlv_support: false,
      value_type: :string,
      max_length: 8
    },
    9 => %{
      name: "Software Upgrade Filename",
      description: "Filename for software upgrade",
      introduced_version: "1.0",
      subtlv_support: false,
      value_type: :string,
      max_length: 255
    },
    10 => %{
      name: "SNMP Write Access Control",
      description: "SNMP write access configuration",
      introduced_version: "1.0",
      subtlv_support: true,
      value_type: :compound,
      max_length: :unlimited
    },
    11 => %{
      name: "SNMP MIB Object",
      description: "SNMP MIB object configuration",
      introduced_version: "1.0",
      subtlv_support: true,
      value_type: :compound,
      max_length: :unlimited
    },
    12 => %{
      name: "Modem IP Address",
      description: "IPv4 address for the cable modem",
      introduced_version: "1.0",
      subtlv_support: false,
      value_type: :ipv4,
      max_length: 4
    },
    13 => %{
      name: "Service Provider Name",
      description: "Name of the service provider",
      introduced_version: "1.0",
      subtlv_support: false,
      value_type: :string,
      max_length: 255
    },
    14 => %{
      name: "Software Upgrade Server",
      description: "Software upgrade server address",
      introduced_version: "1.0",
      subtlv_support: false,
      value_type: :ipv4,
      max_length: 4
    },
    15 => %{
      name: "Upstream Packet Classification",
      description: "Upstream packet classification rules",
      introduced_version: "1.0",
      subtlv_support: true,
      value_type: :compound,
      max_length: :unlimited
    },
    16 => %{
      name: "Downstream Packet Classification",
      description: "Downstream packet classification rules",
      introduced_version: "1.0",
      subtlv_support: true,
      value_type: :compound,
      max_length: :unlimited
    },
    17 => %{
      name: "Upstream Service Flow",
      description: "Upstream service flow configuration",
      introduced_version: "1.0",
      subtlv_support: true,
      value_type: :compound,
      max_length: :unlimited
    },
    18 => %{
      name: "Downstream Service Flow",
      description: "Downstream service flow configuration",
      introduced_version: "1.0",
      subtlv_support: true,
      value_type: :compound,
      max_length: :unlimited
    },
    19 => %{
      name: "PHS Rule",
      description: "Payload Header Suppression rule",
      introduced_version: "1.0",
      subtlv_support: true,
      value_type: :compound,
      max_length: :unlimited
    },
    20 => %{
      name: "HMac Digest",
      description: "HMAC digest for authentication",
      introduced_version: "1.0",
      subtlv_support: false,
      value_type: :binary,
      max_length: 20
    },
    21 => %{
      name: "Max CPE IP Addresses",
      description: "Maximum number of CPE IP addresses",
      introduced_version: "1.0",
      subtlv_support: false,
      value_type: :uint8,
      max_length: 1
    },
    22 => %{
      name: "TFTP Server Timestamp",
      description: "TFTP server timestamp",
      introduced_version: "1.0",
      subtlv_support: false,
      value_type: :uint32,
      max_length: 4
    },
    23 => %{
      name: "TFTP Server Address",
      description: "TFTP server IP address",
      introduced_version: "1.0",
      subtlv_support: false,
      value_type: :ipv4,
      max_length: 4
    },
    24 => %{
      name: "Downstream Service Flow",
      description: "QoS parameters for downstream traffic",
      introduced_version: "1.1",
      subtlv_support: true,
      value_type: :service_flow,
      max_length: :unlimited
    },
    25 => %{
      name: "Upstream Service Flow",
      description: "QoS parameters for upstream traffic", 
      introduced_version: "1.1",
      subtlv_support: true,
      value_type: :service_flow,
      max_length: :unlimited
    },
    26 => %{
      name: "Upstream Service Flow Reference",
      description: "Reference to upstream service flow",
      introduced_version: "1.1",
      subtlv_support: false,
      value_type: :service_flow_ref,
      max_length: 2
    },
    27 => %{
      name: "Software Upgrade Log Server",
      description: "Software upgrade log server address",
      introduced_version: "2.0",
      subtlv_support: false,
      value_type: :ipv4,
      max_length: 4
    },
    28 => %{
      name: "Software Upgrade Log Filename",
      description: "Software upgrade log filename",
      introduced_version: "2.0",
      subtlv_support: false,
      value_type: :string,
      max_length: 255
    },
    29 => %{
      name: "DHCP Option Code",
      description: "DHCP option code configuration",
      introduced_version: "2.0",
      subtlv_support: false,
      value_type: :uint8,
      max_length: 1
    },
    30 => %{
      name: "Baseline Privacy Config",
      description: "Baseline privacy configuration",
      introduced_version: "1.1",
      subtlv_support: true,
      value_type: :compound,
      max_length: :unlimited
    }
  }

  # Security and Privacy TLVs (31-42)
  @security_tlvs %{
    31 => %{
      name: "Baseline Privacy Key Management",
      description: "BPI key management configuration",
      introduced_version: "1.1",
      subtlv_support: true,
      value_type: :compound,
      max_length: :unlimited
    },
    32 => %{
      name: "Max Classifiers",
      description: "Maximum number of classifiers",
      introduced_version: "1.1",
      subtlv_support: false,
      value_type: :uint16,
      max_length: 2
    },
    33 => %{
      name: "Privacy Enable",
      description: "Enable/disable privacy",
      introduced_version: "1.1",
      subtlv_support: false,
      value_type: :uint8,
      max_length: 1
    },
    34 => %{
      name: "Authorization Block",
      description: "Authorization block configuration",
      introduced_version: "1.1",
      subtlv_support: false,
      value_type: :binary,
      max_length: :unlimited
    },
    35 => %{
      name: "Key Sequence Number",
      description: "Key sequence number",
      introduced_version: "1.1",
      subtlv_support: false,
      value_type: :uint8,
      max_length: 1
    },
    36 => %{
      name: "Manufacturer CVC",
      description: "Manufacturer code verification certificate",
      introduced_version: "1.1",
      subtlv_support: false,
      value_type: :binary,
      max_length: :unlimited
    },
    37 => %{
      name: "CoSign CVC",
      description: "Co-signer code verification certificate",
      introduced_version: "1.1",
      subtlv_support: false,
      value_type: :binary,
      max_length: :unlimited
    },
    38 => %{
      name: "SnmpV3 Kickstart",
      description: "SNMPv3 kickstart configuration",
      introduced_version: "2.0",
      subtlv_support: true,
      value_type: :compound,
      max_length: :unlimited
    },
    39 => %{
      name: "Subscriber Management Control",
      description: "Subscriber management control parameters",
      introduced_version: "2.0",
      subtlv_support: true,
      value_type: :compound,
      max_length: :unlimited
    },
    40 => %{
      name: "Subscriber Management CPE IP List",
      description: "Subscriber management CPE IP list",
      introduced_version: "2.0",
      subtlv_support: true,
      value_type: :compound,
      max_length: :unlimited
    },
    41 => %{
      name: "Subscriber Management Filter Groups",
      description: "Subscriber management filter groups",
      introduced_version: "2.0",
      subtlv_support: true,
      value_type: :compound,
      max_length: :unlimited
    },
    42 => %{
      name: "SNMPv3 Notification Receiver",
      description: "SNMPv3 notification receiver configuration",
      introduced_version: "2.0",
      subtlv_support: true,
      value_type: :compound,
      max_length: :unlimited
    }
  }

  # Advanced Features TLVs (43-63)
  @advanced_tlvs %{
    43 => %{
      name: "Enable 20/40 MHz Operation",
      description: "Enable 20/40 MHz channel operation",
      introduced_version: "3.0",
      subtlv_support: false,
      value_type: :uint8,
      max_length: 1
    },
    44 => %{
      name: "Software Upgrade HTTP Server",
      description: "HTTP server for software upgrades",
      introduced_version: "3.0",
      subtlv_support: false,
      value_type: :string,
      max_length: 255
    },
    45 => %{
      name: "IPv4 Multicast Join Authorization",
      description: "IPv4 multicast join authorization",
      introduced_version: "3.0",
      subtlv_support: true,
      value_type: :compound,
      max_length: :unlimited
    },
    46 => %{
      name: "IPv6 Multicast Join Authorization",
      description: "IPv6 multicast join authorization",
      introduced_version: "3.0",
      subtlv_support: true,
      value_type: :compound,
      max_length: :unlimited
    },
    47 => %{
      name: "Upstream Drop Packet Classification",
      description: "Upstream drop packet classification",
      introduced_version: "3.0",
      subtlv_support: true,
      value_type: :compound,
      max_length: :unlimited
    },
    48 => %{
      name: "Subscriber Management Event Control",
      description: "Subscriber management event control",
      introduced_version: "3.0",
      subtlv_support: true,
      value_type: :compound,
      max_length: :unlimited
    },
    49 => %{
      name: "Test Mode Configuration",
      description: "Test mode configuration parameters",
      introduced_version: "3.0",
      subtlv_support: true,
      value_type: :compound,
      max_length: :unlimited
    },
    50 => %{
      name: "Transmit Pre-Equalizer",
      description: "Transmit pre-equalizer configuration",
      introduced_version: "3.0",
      subtlv_support: true,
      value_type: :compound,
      max_length: :unlimited
    },
    51 => %{
      name: "Downstream Channel List Override",
      description: "Override downstream channel list",
      introduced_version: "3.0",
      subtlv_support: true,
      value_type: :compound,
      max_length: :unlimited
    },
    52 => %{
      name: "Diplexer Upstream Upper Band Edge Configuration",
      description: "Diplexer upstream upper band edge",
      introduced_version: "3.0",
      subtlv_support: false,
      value_type: :uint8,
      max_length: 1
    },
    53 => %{
      name: "Diplexer Downstream Lower Band Edge Configuration",
      description: "Diplexer downstream lower band edge",
      introduced_version: "3.0",
      subtlv_support: false,
      value_type: :uint8,
      max_length: 1
    },
    54 => %{
      name: "Diplexer Downstream Upper Band Edge Configuration",
      description: "Diplexer downstream upper band edge",
      introduced_version: "3.0",
      subtlv_support: false,
      value_type: :uint8,
      max_length: 1
    },
    55 => %{
      name: "Diplexer Upstream Upper Band Edge Override",
      description: "Override diplexer upstream upper band edge",
      introduced_version: "3.0",
      subtlv_support: false,
      value_type: :uint8,
      max_length: 1
    },
    56 => %{
      name: "Extended Upstream Transmit Power",
      description: "Extended upstream transmit power",
      introduced_version: "3.0",
      subtlv_support: false,
      value_type: :uint8,
      max_length: 1
    },
    57 => %{
      name: "Optional RFI Mitigation Override",
      description: "Optional RFI mitigation override",
      introduced_version: "3.0",
      subtlv_support: false,
      value_type: :uint8,
      max_length: 1
    },
    58 => %{
      name: "Energy Management 1x1 Mode",
      description: "Energy management 1x1 mode configuration",
      introduced_version: "3.0",
      subtlv_support: false,
      value_type: :uint8,
      max_length: 1
    },
    59 => %{
      name: "Extended Power Mode",
      description: "Extended power mode configuration",
      introduced_version: "3.0",
      subtlv_support: false,
      value_type: :uint8,
      max_length: 1
    },
    60 => %{
      name: "Software Upgrade TFTP Server",
      description: "TFTP server for software upgrades",
      introduced_version: "3.0",
      subtlv_support: false,
      value_type: :ipv4,
      max_length: 4
    },
    61 => %{
      name: "Software Upgrade HTTP Server",
      description: "HTTP server for software upgrades",
      introduced_version: "3.0",
      subtlv_support: false,
      value_type: :string,
      max_length: 255
    },
    62 => %{
      name: "Downstream OFDM Profile",
      description: "Downstream OFDM profile configuration",
      introduced_version: "3.1",
      subtlv_support: true,
      value_type: :compound,
      max_length: :unlimited
    },
    63 => %{
      name: "Downstream OFDMA Profile",
      description: "Downstream OFDMA profile configuration",
      introduced_version: "3.1",
      subtlv_support: true,
      value_type: :compound,
      max_length: :unlimited
    }
  }

  # DOCSIS 3.0 Extension TLVs (64-76)
  @docsis_30_extensions %{
    64 => %{
      name: "PacketCable Configuration",
      description: "PacketCable configuration parameters",
      introduced_version: "3.0",
      subtlv_support: true,
      value_type: :compound,
      max_length: :unlimited
    },
    65 => %{
      name: "L2VPN MAC Aging",
      description: "L2VPN MAC aging configuration",
      introduced_version: "3.0",
      subtlv_support: false,
      value_type: :uint32,
      max_length: 4
    },
    66 => %{
      name: "Management Event Control",
      description: "Management event control configuration",
      introduced_version: "3.0",
      subtlv_support: true,
      value_type: :compound,
      max_length: :unlimited
    },
    67 => %{
      name: "Subscriber Management CPE IPv6 Table",
      description: "Subscriber management CPE IPv6 table",
      introduced_version: "3.0",
      subtlv_support: true,
      value_type: :compound,
      max_length: :unlimited
    },
    68 => %{
      name: "Default Upstream Target Buffer",
      description: "Default upstream target buffer size",
      introduced_version: "3.0",
      subtlv_support: false,
      value_type: :uint32,
      max_length: 4
    },
    69 => %{
      name: "MAC Address Learning Control",
      description: "MAC address learning control",
      introduced_version: "3.0",
      subtlv_support: false,
      value_type: :uint8,
      max_length: 1
    },
    70 => %{
      name: "Aggregate Service Flow Encoding",
      description: "Aggregate service flow encoding",
      introduced_version: "3.0",
      subtlv_support: true,
      value_type: :compound,
      max_length: :unlimited
    },
    71 => %{
      name: "Aggregate Service Flow Reference",
      description: "Aggregate service flow reference",
      introduced_version: "3.0",
      subtlv_support: false,
      value_type: :uint16,
      max_length: 2
    },
    72 => %{
      name: "Metro Ethernet Service Profile",
      description: "Metro Ethernet service profile",
      introduced_version: "3.0",
      subtlv_support: true,
      value_type: :compound,
      max_length: :unlimited
    },
    73 => %{
      name: "Network Timing Profile",
      description: "Network timing profile configuration",
      introduced_version: "3.0",
      subtlv_support: true,
      value_type: :compound,
      max_length: :unlimited
    },
    74 => %{
      name: "Energy Parameters",
      description: "Energy management parameters",
      introduced_version: "3.0",
      subtlv_support: true,
      value_type: :compound,
      max_length: :unlimited
    },
    75 => %{
      name: "CM Upstream AQM Disable",
      description: "CM upstream AQM disable configuration",
      introduced_version: "3.0",
      subtlv_support: false,
      value_type: :uint8,
      max_length: 1
    },
    76 => %{
      name: "CMTS Upstream AQM Disable",
      description: "CMTS upstream AQM disable configuration",
      introduced_version: "3.0",
      subtlv_support: false,
      value_type: :uint8,
      max_length: 1
    }
  }

  # DOCSIS 3.1 Extension TLVs (77-85)
  @docsis_31_extensions %{
    77 => %{
      name: "DLS Encoding",
      description: "Downstream Service (DLS) encoding",
      introduced_version: "3.1",
      subtlv_support: true,
      value_type: :compound,
      max_length: :unlimited
    },
    78 => %{
      name: "DLS Reference",
      description: "Downstream Service (DLS) reference",
      introduced_version: "3.1",
      subtlv_support: false,
      value_type: :uint16,
      max_length: 2
    },
    79 => %{
      name: "UNI Control Encodings",
      description: "User Network Interface control encodings",
      introduced_version: "3.1",
      subtlv_support: true,
      value_type: :compound,
      max_length: :unlimited
    },
    80 => %{
      name: "Downstream Resequencing",
      description: "Downstream resequencing configuration",
      introduced_version: "3.1",
      subtlv_support: true,
      value_type: :compound,
      max_length: :unlimited
    },
    81 => %{
      name: "Multicast DSID Forward",
      description: "Multicast DSID forwarding configuration",
      introduced_version: "3.1",
      subtlv_support: true,
      value_type: :compound,
      max_length: :unlimited
    },
    82 => %{
      name: "Symmetric Service Flow",
      description: "Symmetric service flow configuration",
      introduced_version: "3.1",
      subtlv_support: true,
      value_type: :compound,
      max_length: :unlimited
    },
    83 => %{
      name: "DBC Request",
      description: "Dynamic Bonding Change request",
      introduced_version: "3.1",
      subtlv_support: true,
      value_type: :compound,
      max_length: :unlimited
    },
    84 => %{
      name: "DBC Response",
      description: "Dynamic Bonding Change response",
      introduced_version: "3.1",
      subtlv_support: true,
      value_type: :compound,
      max_length: :unlimited
    },
    85 => %{
      name: "DBC Acknowledge",
      description: "Dynamic Bonding Change acknowledge",
      introduced_version: "3.1",
      subtlv_support: true,
      value_type: :compound,
      max_length: :unlimited
    }
  }

  # Vendor Specific TLVs (200-254)
  @vendor_specific_tlvs %{
    200 => %{
      name: "Vendor Specific TLV 200",
      description: "Vendor-specific configuration (200)",
      introduced_version: "1.0",
      subtlv_support: true,
      value_type: :vendor,
      max_length: :unlimited
    },
    # Note: TLVs 201-253 follow the same pattern
    254 => %{
      name: "Pad",
      description: "Padding TLV for alignment",
      introduced_version: "1.0",
      subtlv_support: false,
      value_type: :binary,
      max_length: :unlimited
    },
    255 => %{
      name: "End-of-Data Marker",
      description: "End of configuration data marker",
      introduced_version: "1.0",
      subtlv_support: false,
      value_type: :marker,
      max_length: 0
    }
  }

  @doc """
  Get TLV information by type and DOCSIS version.
  
  ## Parameters
  
  - `type` - TLV type (integer)
  - `version` - DOCSIS version (string, default: "3.1")
  
  ## Returns
  
  - `{:ok, tlv_info}` - TLV information map
  - `{:error, :unknown_tlv}` - Unknown TLV type
  - `{:error, :unsupported_version}` - TLV not supported in version
  
  ## Examples
  
      iex> Bindocsis.DocsisSpecs.get_tlv_info(3)
      {:ok, %{name: "Network Access Control", ...}}
      
      iex> Bindocsis.DocsisSpecs.get_tlv_info(77, "3.0")
      {:error, :unsupported_version}
  """
  @spec get_tlv_info(non_neg_integer(), docsis_version()) :: 
    {:ok, tlv_info()} | {:error, :unknown_tlv | :unsupported_version}
  def get_tlv_info(type, version \\ "3.1") when is_integer(type) and type >= 0 do
    all_tlvs = get_all_tlvs()
    
    case Map.get(all_tlvs, type) do
      nil -> {:error, :unknown_tlv}
      tlv_info -> 
        if version_supports_tlv?(version, tlv_info.introduced_version) do
          {:ok, tlv_info}
        else
          {:error, :unsupported_version}
        end
    end
  end

  @doc """
  Get specification for a specific DOCSIS version.
  
  Returns a map of all TLV types supported by the specified version.
  """
  @spec get_spec(docsis_version()) :: %{non_neg_integer() => tlv_info()}
  def get_spec("3.0") do
    @core_tlvs
    |> Map.merge(@security_tlvs)
    |> Map.merge(@advanced_tlvs)
    |> Map.merge(@docsis_30_extensions)
    |> Map.merge(get_vendor_tlvs())
    |> filter_by_version("3.0")
  end

  def get_spec("3.1") do
    get_all_tlvs()
    |> filter_by_version("3.1")
  end

  def get_spec(version) when version in ["1.0", "1.1", "2.0"] do
    @core_tlvs
    |> Map.merge(@security_tlvs)
    |> filter_by_version(version)
  end

  def get_spec(_unknown_version) do
    get_spec("3.1")  # Default to latest
  end

  @doc """
  Check if a TLV type is valid for a specific DOCSIS version.
  """
  @spec valid_tlv_type?(non_neg_integer(), docsis_version()) :: boolean()
  def valid_tlv_type?(type, version \\ "3.1") do
    case get_tlv_info(type, version) do
      {:ok, _} -> true
      {:error, _} -> false
    end
  end

  @doc """
  Get list of all supported TLV types for a DOCSIS version.
  """
  @spec get_supported_types(docsis_version()) :: [non_neg_integer()]
  def get_supported_types(version \\ "3.1") do
    get_spec(version)
    |> Map.keys()
    |> Enum.sort()
  end

  @doc """
  Get TLV name by type.
  """
  @spec get_tlv_name(non_neg_integer(), docsis_version()) :: String.t()
  def get_tlv_name(type, version \\ "3.1") do
    case get_tlv_info(type, version) do
      {:ok, tlv_info} -> tlv_info.name
      {:error, _} -> "Unknown TLV #{type}"
    end
  end

  @doc """
  Check if TLV supports subtlvs.
  """
  @spec supports_subtlvs?(non_neg_integer(), docsis_version()) :: boolean()
  def supports_subtlvs?(type, version \\ "3.1") do
    case get_tlv_info(type, version) do
      {:ok, tlv_info} -> tlv_info.subtlv_support
      {:error, _} -> false
    end
  end

  @doc """
  Get TLV description by type.
  """
  @spec get_tlv_description(non_neg_integer(), docsis_version()) :: String.t()
  def get_tlv_description(type, version \\ "3.1") do
    case get_tlv_info(type, version) do
      {:ok, tlv_info} -> tlv_info.description
      {:error, _} -> "Unknown TLV type #{type}"
    end
  end

  @doc """
  Get TLV value type by type.
  """
  @spec get_tlv_value_type(non_neg_integer(), docsis_version()) :: atom()
  def get_tlv_value_type(type, version \\ "3.1") do
    case get_tlv_info(type, version) do
      {:ok, tlv_info} -> tlv_info.value_type
      {:error, _} -> :unknown
    end
  end

  @doc """
  Get TLV maximum length by type.
  """
  @spec get_tlv_max_length(non_neg_integer(), docsis_version()) :: non_neg_integer() | :unlimited
  def get_tlv_max_length(type, version \\ "3.1") do
    case get_tlv_info(type, version) do
      {:ok, tlv_info} -> tlv_info.max_length
      {:error, _} -> :unlimited
    end
  end

  @doc """
  Get DOCSIS version when TLV was introduced.
  """
  @spec get_tlv_introduced_version(non_neg_integer()) :: String.t()
  def get_tlv_introduced_version(type) do
    case get_tlv_info(type, "3.1") do
      {:ok, tlv_info} -> tlv_info.introduced_version
      {:error, _} -> "Unknown"
    end
  end

  # Private helper functions

  defp get_all_tlvs do
    @core_tlvs
    |> Map.merge(@security_tlvs)
    |> Map.merge(@advanced_tlvs)
    |> Map.merge(@docsis_30_extensions)
    |> Map.merge(@docsis_31_extensions)
    |> Map.merge(get_vendor_tlvs())
  end

  defp get_vendor_tlvs do
    base_vendor_tlv = %{
      name: "Vendor Specific TLV",
      description: "Vendor-specific configuration",
      introduced_version: "1.0",
      subtlv_support: true,
      value_type: :vendor,
      max_length: :unlimited
    }

    # Generate TLVs 201-253 (200 and 254-255 are already defined)
    vendor_range = 201..253
    
    vendor_range
    |> Enum.map(fn type ->
      {type, Map.put(base_vendor_tlv, :name, "Vendor Specific TLV #{type}")}
    end)
    |> Enum.into(%{})
    |> Map.merge(@vendor_specific_tlvs)
  end

  defp version_supports_tlv?(current_version, introduced_version) do
    version_order = %{
      "1.0" => 1,
      "1.1" => 2,
      "2.0" => 3,
      "3.0" => 4,
      "3.1" => 5
    }

    current_level = Map.get(version_order, current_version, 5)
    introduced_level = Map.get(version_order, introduced_version, 1)

    current_level >= introduced_level
  end

  defp filter_by_version(tlv_map, version) do
    tlv_map
    |> Enum.filter(fn {_type, tlv_info} ->
      version_supports_tlv?(version, tlv_info.introduced_version)
    end)
    |> Enum.into(%{})
  end

  @doc """
  Gets service flow subtlv specifications for a given service flow type.
  
  Service flows (TLVs 24, 25) contain nested subtlvs that define QoS parameters.
  """
  @spec get_service_flow_subtlvs(24 | 25) :: {:ok, map()} | {:error, String.t()}
  def get_service_flow_subtlvs(24), do: {:ok, downstream_service_flow_subtlvs()}
  def get_service_flow_subtlvs(25), do: {:ok, upstream_service_flow_subtlvs()}
  def get_service_flow_subtlvs(_), do: {:error, "Not a service flow TLV"}

  # Downstream Service Flow Subtlvs (TLV 24)
  defp downstream_service_flow_subtlvs do
    %{
      1 => %{
        name: "Service Flow Reference",
        description: "Unique identifier for this service flow",
        value_type: :uint16,
        max_length: 2
      },
      2 => %{
        name: "Service Flow ID", 
        description: "Service flow identifier assigned by CMTS",
        value_type: :uint32,
        max_length: 4
      },
      3 => %{
        name: "Service Identifier",
        description: "Service identifier assigned by provisioning system",
        value_type: :uint16,
        max_length: 2
      },
      4 => %{
        name: "Service Class Name",
        description: "Name of the service class",
        value_type: :string,
        max_length: 16
      },
      7 => %{
        name: "QoS Parameter Set Type",
        description: "Type of QoS parameter set (0=active, 1=admitted, 2=provisioned)",
        value_type: :uint8,
        max_length: 1
      },
      8 => %{
        name: "Traffic Priority",
        description: "Traffic priority (0-7, 7 is highest)",
        value_type: :uint8,
        max_length: 1
      },
      9 => %{
        name: "Maximum Sustained Traffic Rate",
        description: "Maximum sustained rate in bits per second",
        value_type: :uint32,
        max_length: 4
      },
      10 => %{
        name: "Maximum Traffic Burst",
        description: "Maximum traffic burst in bytes",
        value_type: :uint32,
        max_length: 4
      },
      11 => %{
        name: "Minimum Reserved Traffic Rate",
        description: "Minimum reserved rate in bits per second",
        value_type: :uint32,
        max_length: 4
      },
      12 => %{
        name: "Minimum Packet Size",
        description: "Minimum packet size in bytes",
        value_type: :uint16,
        max_length: 2
      },
      13 => %{
        name: "Maximum Packet Size",
        description: "Maximum packet size in bytes",
        value_type: :uint16,
        max_length: 2
      },
      14 => %{
        name: "Maximum Concatenated Burst",
        description: "Maximum concatenated burst in bytes",
        value_type: :uint16,
        max_length: 2
      },
      15 => %{
        name: "Service Flow Scheduling Type",
        description: "Scheduling type (1=undefined, 2=best effort, 3=non-real-time polling, 4=real-time polling, 5=unsolicited grant, 6=unsolicited grant with activity detection)",
        value_type: :uint8,
        max_length: 1
      },
      16 => %{
        name: "Request/Transmission Policy",
        description: "Request and transmission policy bit mask",
        value_type: :uint32,
        max_length: 4
      },
      17 => %{
        name: "Tolerated Jitter",
        description: "Maximum delay variation in microseconds",
        value_type: :uint32,
        max_length: 4
      },
      18 => %{
        name: "Maximum Latency",
        description: "Maximum latency in microseconds",
        value_type: :uint32,
        max_length: 4
      }
    }
  end

  # Upstream Service Flow Subtlvs (TLV 25)
  defp upstream_service_flow_subtlvs do
    %{
      1 => %{
        name: "Service Flow Reference",
        description: "Unique identifier for this service flow",
        value_type: :uint16,
        max_length: 2
      },
      2 => %{
        name: "Service Flow ID",
        description: "Service flow identifier assigned by CMTS", 
        value_type: :uint32,
        max_length: 4
      },
      3 => %{
        name: "Service Identifier",
        description: "Service identifier assigned by provisioning system",
        value_type: :uint16,
        max_length: 2
      },
      4 => %{
        name: "Service Class Name",
        description: "Name of the service class",
        value_type: :string,
        max_length: 16
      },
      7 => %{
        name: "QoS Parameter Set Type",
        description: "Type of QoS parameter set (0=active, 1=admitted, 2=provisioned)",
        value_type: :uint8,
        max_length: 1
      },
      8 => %{
        name: "Traffic Priority",
        description: "Traffic priority (0-7, 7 is highest)",
        value_type: :uint8,
        max_length: 1
      },
      9 => %{
        name: "Maximum Sustained Traffic Rate",
        description: "Maximum sustained rate in bits per second",
        value_type: :uint32,
        max_length: 4
      },
      10 => %{
        name: "Maximum Traffic Burst",
        description: "Maximum traffic burst in bytes",
        value_type: :uint32,
        max_length: 4
      },
      11 => %{
        name: "Minimum Reserved Traffic Rate",
        description: "Minimum reserved rate in bits per second",
        value_type: :uint32,
        max_length: 4
      },
      12 => %{
        name: "Minimum Packet Size",
        description: "Minimum packet size in bytes",
        value_type: :uint16,
        max_length: 2
      },
      13 => %{
        name: "Maximum Packet Size",
        description: "Maximum packet size in bytes",
        value_type: :uint16,
        max_length: 2
      },
      14 => %{
        name: "Maximum Concatenated Burst",
        description: "Maximum concatenated burst in bytes",
        value_type: :uint16,
        max_length: 2
      },
      15 => %{
        name: "Service Flow Scheduling Type",
        description: "Scheduling type (1=undefined, 2=best effort, 3=non-real-time polling, 4=real-time polling, 5=unsolicited grant, 6=unsolicited grant with activity detection)",
        value_type: :uint8,
        max_length: 1
      },
      16 => %{
        name: "Request/Transmission Policy", 
        description: "Request and transmission policy bit mask",
        value_type: :uint32,
        max_length: 4
      },
      17 => %{
        name: "Tolerated Jitter",
        description: "Maximum delay variation in microseconds",
        value_type: :uint32,
        max_length: 4
      },
      18 => %{
        name: "Maximum Latency",
        description: "Maximum latency in microseconds",
        value_type: :uint32,
        max_length: 4
      },
      19 => %{
        name: "Grants Per Interval",
        description: "Number of grants per interval for unsolicited grant service",
        value_type: :uint8,
        max_length: 1
      },
      20 => %{
        name: "Nominal Polling Interval",
        description: "Nominal polling interval in microseconds",
        value_type: :uint32,
        max_length: 4
      },
      21 => %{
        name: "Unsolicited Grant Size",
        description: "Unsolicited grant size in bytes",
        value_type: :uint16,
        max_length: 2
      },
      22 => %{
        name: "Nominal Grant Interval",
        description: "Nominal grant interval in microseconds",
        value_type: :uint32,
        max_length: 4
      },
      23 => %{
        name: "Tolerated Grant Jitter",
        description: "Tolerated grant jitter in microseconds",
        value_type: :uint32,
        max_length: 4
      }
    }
  end
end