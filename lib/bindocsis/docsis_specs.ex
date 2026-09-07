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

  # TLV 0 - Pad (CableLabs CANN-I22)
  @reserved_tlv %{
    0 => %{
      name: "Pad",
      description: "Padding TLV for alignment (zero or more bytes)",
      introduced_version: "1.0",
      subtlv_support: false,
      value_type: :binary,
      max_length: :unlimited
    }
  }

  # Core DOCSIS TLV specifications (1-15) - Per CableLabs CANN-I22-230308
  # Note: TLV 16 is reserved/skipped in official spec
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
      description: "Enable/disable network access (0=disabled, 1=enabled)",
      introduced_version: "1.0",
      subtlv_support: false,
      value_type: :boolean,
      max_length: 1
    },
    4 => %{
      name: "Class of Service",
      description: "DOCSIS 1.0 Class of Service configuration",
      introduced_version: "1.0",
      subtlv_support: true,
      value_type: :compound,
      max_length: :unlimited
    },
    5 => %{
      name: "Modem Capabilities",
      description: "Cable modem capability parameters encoding",
      introduced_version: "1.0",
      subtlv_support: true,
      value_type: :compound,
      max_length: :unlimited
    },
    6 => %{
      name: "CM Message Integrity Check",
      description: "Cable Modem Message Integrity Check (CM MIC) for configuration integrity",
      introduced_version: "1.0",
      subtlv_support: false,
      value_type: :binary,
      max_length: 16
    },
    7 => %{
      name: "CMTS MIC",
      description: "CMTS Message Integrity Check for configuration integrity",
      introduced_version: "1.0",
      subtlv_support: false,
      value_type: :binary,
      max_length: 16
    },
    8 => %{
      name: "Vendor ID",
      description: "Vendor identification encoding",
      introduced_version: "1.0",
      subtlv_support: false,
      value_type: :hex,
      max_length: 3
    },
    9 => %{
      name: "SW Upgrade Filename",
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
      description: "SNMP VarBind (ASN.1 BER), applied as an SNMP SET (MULPI C.1.1.11)",
      introduced_version: "1.0",
      subtlv_support: false,
      value_type: :asn1_der,
      max_length: 255
    },
    12 => %{
      name: "Modem IP Address",
      description: "IPv4 address for the cable modem (deprecated - use DHCP)",
      introduced_version: "1.0",
      subtlv_support: false,
      value_type: :ipv4,
      max_length: 4
    },
    13 => %{
      name: "Services Not Available Response",
      description: "Service(s) Not Available Response code",
      introduced_version: "1.0",
      subtlv_support: false,
      value_type: :uint8,
      max_length: 1
    },
    14 => %{
      name: "CPE Ethernet MAC Address",
      description: "CPE Ethernet MAC address for provisioning",
      introduced_version: "1.0",
      subtlv_support: false,
      value_type: :mac,
      max_length: 6
    },
    15 => %{
      name: "Telephone Settings Option",
      description: "Telephone settings option (deprecated)",
      introduced_version: "1.0",
      subtlv_support: true,
      value_type: :compound,
      max_length: :unlimited
    },
    # TLV 16 is reserved/skipped in CableLabs spec
    # TLVs 17-30 per CableLabs CANN-I22-230308
    17 => %{
      name: "Baseline Privacy",
      description: "Baseline Privacy (BPI+) security configuration",
      introduced_version: "1.0",
      subtlv_support: true,
      value_type: :compound,
      max_length: :unlimited
    },
    18 => %{
      name: "Max Number of CPEs",
      description: "Maximum number of CPEs allowed behind the CM",
      introduced_version: "1.0",
      subtlv_support: false,
      value_type: :uint8,
      max_length: 1
    },
    19 => %{
      name: "TFTP Server Timestamp",
      description: "TFTP server timestamp for configuration versioning",
      introduced_version: "1.0",
      subtlv_support: false,
      value_type: :uint32,
      max_length: 4
    },
    20 => %{
      name: "TFTP Server Provisioned Modem Address",
      description: "TFTP server provisioned modem IPv4 address",
      introduced_version: "1.0",
      subtlv_support: false,
      value_type: :ipv4,
      max_length: 4
    },
    21 => %{
      name: "SW Upgrade IPv4 TFTP Server",
      description: "IPv4 address of TFTP server for software upgrades",
      introduced_version: "1.0",
      subtlv_support: false,
      value_type: :ipv4,
      max_length: 4
    },
    22 => %{
      name: "Upstream Packet Classification",
      description: "Upstream packet classification rules",
      introduced_version: "1.1",
      subtlv_support: true,
      value_type: :compound,
      max_length: :unlimited
    },
    23 => %{
      name: "Downstream Packet Classification",
      description: "Downstream packet classification rules",
      introduced_version: "1.1",
      subtlv_support: true,
      value_type: :compound,
      max_length: :unlimited
    },
    24 => %{
      name: "Upstream Service Flow",
      description: "Upstream service flow QoS parameters",
      introduced_version: "1.1",
      subtlv_support: true,
      value_type: :service_flow,
      max_length: :unlimited
    },
    25 => %{
      name: "Downstream Service Flow",
      description: "Downstream service flow QoS parameters",
      introduced_version: "1.1",
      subtlv_support: true,
      value_type: :service_flow,
      max_length: :unlimited
    },
    26 => %{
      name: "Payload Header Suppression",
      description: "Payload Header Suppression (PHS) rules",
      introduced_version: "1.1",
      subtlv_support: true,
      value_type: :compound,
      max_length: :unlimited
    },
    27 => %{
      name: "HMAC Digest",
      description: "HMAC digest for configuration file authentication",
      introduced_version: "3.1",
      subtlv_support: false,
      value_type: :binary,
      max_length: 64
    },
    28 => %{
      name: "Maximum Number of Classifiers",
      description: "Maximum number of classifiers the CM can support",
      introduced_version: "1.1",
      subtlv_support: false,
      value_type: :uint16,
      max_length: 2
    },
    29 => %{
      name: "Privacy Enable",
      description: "Enable/disable BPI+ privacy (0=disabled, 1=enabled)",
      introduced_version: "1.1",
      subtlv_support: false,
      value_type: :boolean,
      max_length: 1
    },
    30 => %{
      name: "Authorization Block",
      description: "Authorization block for BPI+ key exchange",
      introduced_version: "1.1",
      subtlv_support: false,
      value_type: :binary,
      max_length: :unlimited
    }
  }

  # TLVs 31-50 per CableLabs CANN-I22-230308
  @security_tlvs %{
    31 => %{
      name: "Key Sequence Number",
      description: "Key sequence number for BPI+ authorization",
      introduced_version: "1.1",
      subtlv_support: false,
      value_type: :uint8,
      max_length: 1
    },
    32 => %{
      name: "Manufacturer CVC",
      description: "Manufacturer Code Verification Certificate",
      introduced_version: "1.1",
      subtlv_support: false,
      value_type: :binary,
      max_length: :unlimited
    },
    33 => %{
      name: "Co-Signer CVC",
      description: "Co-Signer Code Verification Certificate",
      introduced_version: "1.1",
      subtlv_support: false,
      value_type: :binary,
      max_length: :unlimited
    },
    34 => %{
      name: "SNMPv3 Kickstart Value",
      description: "SNMPv3 kickstart configuration value",
      introduced_version: "1.1",
      subtlv_support: true,
      value_type: :compound,
      max_length: :unlimited
    },
    35 => %{
      name: "Subscriber Mgmt Control",
      description: "Subscriber management control parameters",
      introduced_version: "1.1",
      subtlv_support: false,
      value_type: :binary,
      max_length: :unlimited
    },
    36 => %{
      name: "Subscriber Mgmt CPE IPv4 List",
      description: "Subscriber management CPE IPv4 address list",
      introduced_version: "1.1",
      subtlv_support: false,
      value_type: :binary,
      max_length: :unlimited
    },
    37 => %{
      name: "Subscriber Mgmt Filter Groups",
      description: "Subscriber management filter groups",
      introduced_version: "1.1",
      subtlv_support: false,
      value_type: :binary,
      max_length: :unlimited
    },
    38 => %{
      name: "SNMPv3 Notification Receiver",
      description: "SNMPv3 notification receiver configuration",
      introduced_version: "1.1",
      subtlv_support: true,
      value_type: :compound,
      max_length: :unlimited
    },
    39 => %{
      name: "Enable 2.0 Mode",
      description: "Enable DOCSIS 2.0 mode (A-TDMA/S-CDMA)",
      introduced_version: "2.0",
      subtlv_support: false,
      value_type: :boolean,
      max_length: 1
    },
    40 => %{
      name: "Enable Test Modes",
      description: "Enable test modes for CM diagnostics",
      introduced_version: "2.0",
      subtlv_support: false,
      value_type: :uint8,
      max_length: 1
    },
    41 => %{
      name: "Downstream Channel List",
      description: "Downstream channel list configuration",
      introduced_version: "2.0",
      subtlv_support: true,
      value_type: :compound,
      max_length: :unlimited
    },
    42 => %{
      name: "Static Multicast MAC Address",
      description: "Static multicast MAC address configuration",
      introduced_version: "2.0",
      subtlv_support: false,
      value_type: :mac,
      max_length: 6
    },
    43 => %{
      name: "Vendor Specific",
      description: "DOCSIS extension field / vendor specific capabilities",
      introduced_version: "1.0",
      subtlv_support: true,
      value_type: :vendor,
      max_length: :unlimited
    },
    44 => %{
      name: "Vendor Specific Capabilities",
      description: "Vendor specific capability encodings",
      introduced_version: "1.0",
      subtlv_support: true,
      value_type: :vendor,
      max_length: :unlimited
    },
    45 => %{
      name: "DUT Filtering",
      description: "Downstream Unencrypted Traffic filtering encodings",
      introduced_version: "2.0",
      subtlv_support: true,
      value_type: :compound,
      max_length: :unlimited
    },
    46 => %{
      name: "Transmit Channel Configuration",
      description: "Transmit Channel Configuration (TCC) encodings",
      introduced_version: "3.0",
      subtlv_support: true,
      value_type: :compound,
      max_length: :unlimited
    },
    47 => %{
      name: "Service Flow SID Cluster Assignment",
      description: "Service flow SID cluster assignment encodings",
      introduced_version: "3.0",
      subtlv_support: true,
      value_type: :compound,
      max_length: :unlimited
    },
    48 => %{
      name: "Receive Channel Profile",
      description: "Receive channel profile configuration",
      introduced_version: "3.0",
      subtlv_support: true,
      value_type: :compound,
      max_length: :unlimited
    },
    49 => %{
      name: "Receive Channel Configuration",
      description: "Receive channel configuration encodings",
      introduced_version: "3.0",
      subtlv_support: true,
      value_type: :compound,
      max_length: :unlimited
    },
    50 => %{
      name: "DSID Encodings",
      description: "Downstream Service ID encodings",
      introduced_version: "3.0",
      subtlv_support: true,
      value_type: :compound,
      max_length: :unlimited
    }
  }

  # TLVs 51-66 per CableLabs CANN-I22-230308
  @advanced_tlvs %{
    51 => %{
      name: "Security Association Encoding",
      description: "Security association configuration encodings",
      introduced_version: "3.0",
      subtlv_support: true,
      value_type: :compound,
      max_length: :unlimited
    },
    52 => %{
      name: "Initializing Channel Timeout",
      description: "Initializing channel timeout value in seconds",
      introduced_version: "3.0",
      subtlv_support: false,
      value_type: :uint16,
      max_length: 2
    },
    53 => %{
      name: "SNMPv1v2c Coexistence",
      description: "SNMPv1/v2c coexistence configuration",
      introduced_version: "3.0",
      subtlv_support: true,
      value_type: :compound,
      max_length: :unlimited
    },
    54 => %{
      name: "SNMPv3 Access View Configuration",
      description: "SNMPv3 access view configuration",
      introduced_version: "3.0",
      subtlv_support: true,
      value_type: :compound,
      max_length: :unlimited
    },
    55 => %{
      name: "SNMP CPE Access Control",
      description: "SNMP CPE access control configuration",
      introduced_version: "3.0",
      subtlv_support: false,
      value_type: :uint8,
      max_length: 1
    },
    56 => %{
      name: "Channel Assignment Configuration",
      description: "Channel assignment configuration settings",
      introduced_version: "3.0",
      subtlv_support: true,
      value_type: :compound,
      max_length: :unlimited
    },
    57 => %{
      name: "CM Initialization Reason",
      description: "Cable modem initialization reason code",
      introduced_version: "3.0",
      subtlv_support: false,
      value_type: :uint8,
      max_length: 1
    },
    58 => %{
      name: "SW Upgrade IPv6 TFTP Server",
      description: "IPv6 address of TFTP server for software upgrades",
      introduced_version: "3.0",
      subtlv_support: false,
      value_type: :ipv6,
      max_length: 16
    },
    59 => %{
      name: "TFTP Server Provisioned Modem IPv6 Address",
      description: "TFTP server provisioned modem IPv6 address",
      introduced_version: "3.0",
      subtlv_support: false,
      value_type: :ipv6,
      max_length: 16
    },
    60 => %{
      name: "Upstream Drop Packet Classification",
      description: "Upstream drop packet classification rules",
      introduced_version: "3.0",
      subtlv_support: true,
      value_type: :compound,
      max_length: :unlimited
    },
    61 => %{
      name: "Subscriber Mgmt CPE IPv6 Prefix List",
      description: "Subscriber management CPE IPv6 prefix list",
      introduced_version: "3.0",
      subtlv_support: false,
      value_type: :binary,
      max_length: :unlimited
    },
    62 => %{
      name: "Upstream Drop Classifier Group ID",
      description: "List of upstream drop classifier group IDs, one byte each (MULPI C.1.1.26)",
      introduced_version: "3.0",
      subtlv_support: false,
      value_type: :binary,
      max_length: :unlimited
    },
    63 => %{
      name: "Subscriber Mgmt Control Max CPE IPv6 Prefix",
      description: "Maximum number of IPv6 prefixes for CPEs (MULPI C.1.1.19.5)",
      introduced_version: "3.0",
      subtlv_support: false,
      value_type: :uint16,
      max_length: 2
    },
    64 => %{
      name: "CMTS Static Multicast Session Encoding",
      description: "CMTS static multicast session encodings",
      introduced_version: "3.0",
      subtlv_support: true,
      value_type: :compound,
      max_length: :unlimited
    },
    65 => %{
      name: "L2VPN MAC Aging Encoding",
      description: "L2VPN MAC aging configuration encodings",
      introduced_version: "3.0",
      subtlv_support: true,
      value_type: :compound,
      max_length: :unlimited
    },
    66 => %{
      name: "Management Event Control Encoding",
      description: "32-bit event ID to individually enable DOCSIS events (MULPI C.1.2.16)",
      introduced_version: "3.0",
      subtlv_support: false,
      value_type: :uint32,
      max_length: 4
    },
  }

  # TLVs 67-76 per CableLabs CANN-I22-230308
  @docsis_30_extensions %{
    67 => %{
      name: "Subscriber Mgmt CPE IPv6 Prefix List Default",
      description: "Subscriber management CPE IPv6 prefix list default",
      introduced_version: "3.0",
      subtlv_support: false,
      value_type: :binary,
      max_length: :unlimited
    },
    68 => %{
      name: "Default Upstream Target Buffer Configuration",
      description: "Default upstream service flow buffer target in milliseconds (MULPI C.1.2.17)",
      introduced_version: "3.0",
      subtlv_support: false,
      value_type: :uint16,
      max_length: 2
    },
    69 => %{
      name: "MAC Address Learning Control Encoding",
      description: "MAC address learning control configuration",
      introduced_version: "3.0",
      subtlv_support: true,
      value_type: :compound,
      max_length: :unlimited
    },
    70 => %{
      name: "Upstream Aggregate Service Flow",
      description: "Upstream aggregate service flow encodings",
      introduced_version: "3.1",
      subtlv_support: true,
      value_type: :service_flow,
      max_length: :unlimited
    },
    71 => %{
      name: "Downstream Aggregate Service Flow",
      description: "Downstream aggregate service flow encodings",
      introduced_version: "3.1",
      subtlv_support: true,
      value_type: :service_flow,
      max_length: :unlimited
    },
    72 => %{
      name: "Metro Ethernet Service Profile",
      description: "Metro Ethernet service profile configuration",
      introduced_version: "3.1",
      subtlv_support: true,
      value_type: :compound,
      max_length: :unlimited
    },
    73 => %{
      name: "Network Timing Profile",
      description: "Network timing profile configuration",
      introduced_version: "3.1",
      subtlv_support: true,
      value_type: :compound,
      max_length: :unlimited
    },
    74 => %{
      name: "Energy Management Parameter Encoding",
      description: "Energy management parameter encodings",
      introduced_version: "3.0",
      subtlv_support: true,
      value_type: :compound,
      max_length: :unlimited
    },
    75 => %{
      name: "Energy Mgt Mode Indicator",
      description: "Energy management mode indicator",
      introduced_version: "3.1",
      subtlv_support: false,
      value_type: :uint8,
      max_length: 1
    },
    76 => %{
      name: "CM Upstream AQM Disable",
      description: "CM upstream AQM disable configuration",
      introduced_version: "3.1",
      subtlv_support: false,
      value_type: :boolean,
      max_length: 1
    }
  }

  # TLVs 77-85 per CableLabs CANN-I22-230308
  @docsis_31_extensions %{
    77 => %{
      name: "DOCSIS Time Protocol Encoding",
      description: "DOCSIS Time Protocol (DTP) configuration",
      introduced_version: "3.1",
      subtlv_support: true,
      value_type: :compound,
      max_length: :unlimited
    },
    78 => %{
      name: "Energy Management Identifier List for CM",
      description: "Energy management identifier list for cable modem",
      introduced_version: "3.1",
      subtlv_support: true,
      value_type: :compound,
      max_length: :unlimited
    },
    79 => %{
      name: "UNI Control Encoding",
      description: "User Network Interface control encodings",
      introduced_version: "3.0",
      subtlv_support: true,
      value_type: :compound,
      max_length: :unlimited
    },
    80 => %{
      name: "Energy Management DOCSIS Light Sleep Encodings",
      description: "Energy management DOCSIS light sleep configuration",
      introduced_version: "3.1",
      subtlv_support: true,
      value_type: :compound,
      max_length: :unlimited
    },
    81 => %{
      name: "Manufacturer CVC Chain",
      description: "Manufacturer CVC certificate chain",
      introduced_version: "3.1",
      subtlv_support: false,
      value_type: :binary,
      max_length: :unlimited
    },
    82 => %{
      name: "Co-Signer CVC Chain",
      description: "Co-Signer CVC certificate chain",
      introduced_version: "3.1",
      subtlv_support: false,
      value_type: :binary,
      max_length: :unlimited
    },
    83 => %{
      name: "DTP Mode Configuration",
      description: "DOCSIS Time Protocol mode configuration",
      introduced_version: "3.1",
      subtlv_support: false,
      value_type: :uint8,
      max_length: 1
    },
    84 => %{
      name: "Diplexer Band Edge",
      description: "Diplexer band edge configuration (CL-SP-CANN 11.1)",
      introduced_version: "3.1",
      subtlv_support: false,
      value_type: :uint8,
      max_length: 1
    },
    85 => %{
      name: "FDX Transmission Group Assignment",
      description: "Full Duplex DOCSIS transmission group assignment (CL-SP-CANN 11.1)",
      introduced_version: "4.0",
      subtlv_support: true,
      value_type: :compound,
      max_length: :unlimited
    },
  }

  # TLVs 86-105 per CableLabs CANN-I22-230308 (DOCSIS 4.0 extensions)
  @extended_tlvs %{
    86 => %{
      name: "FDX Reset",
      description: "Full Duplex DOCSIS reset configuration (CL-SP-CANN 11.1)",
      introduced_version: "4.0",
      subtlv_support: false,
      value_type: :uint8,
      max_length: 1
    },
    87 => %{
      name: "CM Echo Cancellation Training Control",
      description: "CM echo cancellation training control configuration (CL-SP-CANN 11.1)",
      introduced_version: "4.0",
      subtlv_support: false,
      value_type: :uint8,
      max_length: 1
    },
    88 => %{
      name: "QoS Framework for DOCSIS Encodings",
      description: "QoS framework for DOCSIS configuration encodings (CL-SP-CANN 11.1)",
      introduced_version: "3.1",
      subtlv_support: true,
      value_type: :compound,
      max_length: :unlimited
    },
    89 => %{
      name: "Extended SID Cluster Assignment",
      description: "Extended SID cluster assignment encodings (CL-SP-CANN 11.1)",
      introduced_version: "3.1",
      subtlv_support: true,
      value_type: :compound,
      max_length: :unlimited
    },
    90 => %{
      name: "Primary Service Flow Indicator",
      description: "Primary service flow indicator (CL-SP-CANN 11.1)",
      introduced_version: "3.1",
      subtlv_support: false,
      value_type: :uint8,
      max_length: 1
    },
    91 => %{
      name: "Low Latency Disable",
      description: "Low latency disable configuration (CL-SP-CANN 11.1)",
      introduced_version: "3.1",
      subtlv_support: false,
      value_type: :boolean,
      max_length: 1
    },
    92 => %{
      name: "Distributed HQoS Enable",
      description: "Distributed Hierarchical QoS enable (CL-SP-CANN 11.1)",
      introduced_version: "3.1",
      subtlv_support: false,
      value_type: :boolean,
      max_length: 1
    },
    93 => %{
      name: "Upstream Enhanced HQoS ASF",
      description: "Upstream enhanced HQoS aggregate service flow (CL-SP-CANN 11.1)",
      introduced_version: "3.1",
      subtlv_support: true,
      value_type: :compound,
      max_length: :unlimited
    },
    94 => %{
      name: "Downstream Enhanced HQoS ASF",
      description: "Downstream enhanced HQoS aggregate service flow (CL-SP-CANN 11.1)",
      introduced_version: "3.1",
      subtlv_support: true,
      value_type: :compound,
      max_length: :unlimited
    },
    95 => %{
      name: "DHQoS ASF SID Bundle Assignment",
      description: "Distributed HQoS ASF SID bundle assignment (CL-SP-CANN 11.1)",
      introduced_version: "3.1",
      subtlv_support: true,
      value_type: :compound,
      max_length: :unlimited
    },
    96 => %{
      name: "Advanced Diplexer Band Edge",
      description: "Advanced diplexer band edge configuration (CL-SP-CANN 11.1)",
      introduced_version: "4.0",
      subtlv_support: false,
      value_type: :uint8,
      max_length: 1
    },
    97 => %{
      name: "Advanced Band Plan Support",
      description: "Advanced band plan support configuration (CL-SP-CANN 11.1)",
      introduced_version: "4.0",
      subtlv_support: true,
      value_type: :compound,
      max_length: :unlimited
    },
    98 => %{
      name: "CM SSH Server Configuration Settings",
      description: "Cable modem SSH server configuration settings (CL-SP-CANN 11.1)",
      introduced_version: "4.0",
      subtlv_support: true,
      value_type: :compound,
      max_length: :unlimited
    },
    99 => %{
      name: "Security Configuration Settings",
      description: "Security configuration settings (CL-SP-CANN 11.1)",
      introduced_version: "4.0",
      subtlv_support: true,
      value_type: :compound,
      max_length: :unlimited
    },
  }

  # eCM eSAFE Configuration File TLVs (201-231) and special TLVs per CANN-I22
  @vendor_specific_tlvs %{
    200 => %{
      name: "Vendor Specific TLV 200",
      description: "Vendor-specific configuration (200)",
      introduced_version: "1.0",
      subtlv_support: true,
      value_type: :vendor,
      max_length: :unlimited
    },
    201 => %{
      name: "ePS",
      description: "Embedded PacketCable Service configuration",
      introduced_version: "3.0",
      subtlv_support: true,
      value_type: :compound,
      max_length: :unlimited
    },
    202 => %{
      name: "eRouter",
      description: "Embedded Router configuration",
      introduced_version: "3.0",
      subtlv_support: true,
      value_type: :compound,
      max_length: :unlimited
    },
    216 => %{
      name: "eMTA",
      description: "Embedded MTA (PacketCable 1.x) configuration",
      introduced_version: "3.0",
      subtlv_support: true,
      value_type: :compound,
      max_length: :unlimited
    },
    217 => %{
      name: "eSTB",
      description: "Embedded Set-Top Box (DSG) configuration",
      introduced_version: "3.0",
      subtlv_support: true,
      value_type: :compound,
      max_length: :unlimited
    },
    219 => %{
      name: "eTEA",
      description: "Embedded TDM Emulation Adapter configuration (CM-SP-TEI, CL-SP-CANN 11.1)",
      introduced_version: "3.0",
      subtlv_support: true,
      value_type: :compound,
      max_length: :unlimited
    },
    220 => %{
      name: "eDVA",
      description: "Embedded Digital Voice Adapter (PacketCable 2.0) configuration (CL-SP-CANN 11.1)",
      introduced_version: "3.0",
      subtlv_support: true,
      value_type: :compound,
      max_length: :unlimited
    },
    221 => %{
      name: "eSG",
      description: "Embedded SMA Gateway configuration (CL-SP-CANN 11.1)",
      introduced_version: "3.0",
      subtlv_support: true,
      value_type: :compound,
      max_length: :unlimited
    },
    255 => %{
      name: "End-of-Data",
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
      nil ->
        {:error, :unknown_tlv}

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
    @reserved_tlv
    |> Map.merge(@core_tlvs)
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
    @reserved_tlv
    |> Map.merge(@core_tlvs)
    |> Map.merge(@security_tlvs)
    |> filter_by_version(version)
  end

  def get_spec(_unknown_version) do
    # Default to latest
    get_spec("3.1")
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
    @reserved_tlv
    |> Map.merge(@core_tlvs)
    |> Map.merge(@security_tlvs)
    |> Map.merge(@advanced_tlvs)
    |> Map.merge(@docsis_30_extensions)
    |> Map.merge(@docsis_31_extensions)
    |> Map.merge(@extended_tlvs)
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
      "3.1" => 5,
      "4.0" => 6
    }

    current_level = Map.get(version_order, current_version, 6)
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

  Service flows (TLVs 24, 25, 70, 71) contain nested subtlvs that define QoS parameters.
  Per CableLabs CANN-I22: TLV 24 = Upstream SF, TLV 25 = Downstream SF
  """
  @spec get_service_flow_subtlvs(24 | 25 | 70 | 71) :: {:ok, map()} | {:error, String.t()}
  def get_service_flow_subtlvs(24), do: {:ok, upstream_service_flow_subtlvs()}
  def get_service_flow_subtlvs(25), do: {:ok, downstream_service_flow_subtlvs()}
  def get_service_flow_subtlvs(70), do: {:ok, upstream_service_flow_subtlvs()}
  def get_service_flow_subtlvs(71), do: {:ok, downstream_service_flow_subtlvs()}
  def get_service_flow_subtlvs(_), do: {:error, "Not a service flow TLV"}

  # Downstream Service Flow Subtlvs (TLV 25, 71)
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
        description:
          "Scheduling type (1=undefined, 2=best effort, 3=non-real-time polling, 4=real-time polling, 5=unsolicited grant, 6=unsolicited grant with activity detection)",
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

  # Upstream Service Flow Subtlvs (TLV 24, 70)
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
        description:
          "Scheduling type (1=undefined, 2=best effort, 3=non-real-time polling, 4=real-time polling, 5=unsolicited grant, 6=unsolicited grant with activity detection)",
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
