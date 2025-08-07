defmodule Bindocsis.SubTlvSpecs do
  @moduledoc """
  Comprehensive sub-TLV specifications for all compound DOCSIS TLVs.
  
  This module provides detailed specifications for sub-TLVs contained within
  compound TLV types. Each compound TLV can contain nested sub-TLVs that define
  specific parameters for that TLV type.
  
  ## Supported Compound TLVs
  
  - **TLV 4**: Class of Service
  - **TLV 5**: Modem Capabilities  
  - **TLV 10**: SNMP Write Access Control
  - **TLV 11**: SNMP MIB Object
  - **TLV 15**: Upstream Packet Classification
  - **TLV 16**: Downstream Packet Classification
  - **TLV 17**: Upstream Service Flow
  - **TLV 18**: Downstream Service Flow
  - **TLV 19**: PHS Rule
  - **TLV 22**: Upstream Packet Classification (Extended)
  - **TLV 23**: Downstream Packet Classification (Extended)
  - **TLV 24**: Downstream Service Flow (QoS)
  - **TLV 25**: Upstream Service Flow (QoS)
  - **TLV 30**: Baseline Privacy Config
  - **TLV 31**: Baseline Privacy Key Management
  - **TLV 38**: SNMPv3 Kickstart
  - **TLV 39**: Subscriber Management Control
  - **TLV 40**: Subscriber Management CPE IP List
  - **TLV 41**: Subscriber Management Filter Groups
  - **TLV 42**: SNMPv3 Notification Receiver
  - **TLV 43**: L2VPN Encoding
  - **TLV 45**: IPv4 Multicast Join Authorization
  - **TLV 46**: IPv6 Multicast Join Authorization
  - **TLV 47**: Upstream Drop Packet Classification
  - **TLV 60**: IPv6 Packet Classification
  - **TLV 64**: PacketCable Configuration
  - And many more...
  """

  @type sub_tlv_info :: %{
    name: String.t(),
    description: String.t(),
    value_type: atom(),
    max_length: non_neg_integer() | :unlimited,
    enum_values: map() | nil
  }

  @doc """
  Get sub-TLV specifications for a given parent TLV type.
  
  ## Parameters
  
  - `parent_tlv_type` - The parent TLV type (integer)
  
  ## Returns
  
  - `{:ok, sub_tlv_specs}` - Map of sub-TLV type to specification
  - `{:error, :no_subtlvs}` - Parent TLV doesn't support sub-TLVs
  - `{:error, :unknown_tlv}` - Unknown parent TLV type
  
  ## Examples
  
      iex> Bindocsis.SubTlvSpecs.get_subtlv_specs(5)
      {:ok, %{1 => %{name: "Concatenation Support", ...}, ...}}
      
      iex> Bindocsis.SubTlvSpecs.get_subtlv_specs(24)
      {:ok, %{1 => %{name: "Service Flow Reference", ...}, ...}}
  """
  @spec get_subtlv_specs(non_neg_integer() | [non_neg_integer()]) :: 
    {:ok, %{non_neg_integer() => sub_tlv_info()}} | 
    {:error, :no_subtlvs | :unknown_tlv | :invalid_context_path}
  
  # Handle context path for nested subtlvs
  def get_subtlv_specs(context_path) when is_list(context_path) do
    case context_path do
      # MPLS Service Multiplexing Value context (TLV 22.43.5.2.4)
      # Based on actual data analysis - TLVs 1&4 contain TLV 0 markers
      [parent, 43, 5, 2, 4] when parent in [15, 16, 22, 23] ->
        {:ok, mpls_service_multiplexing_value_subtlvs()}
      
      # Service Multiplexing context (TLV 22.43.5.2)
      [parent, 43, 5, 2] when parent in [15, 16, 22, 23] ->
        {:ok, service_multiplexing_subtlvs()}
      
      # Special handling for L2VPN Encoding nested subtlvs
      # Only when we're inside 43.5 (L2VPN Encoding within L2VPN subtlv)
      [parent, 43, 5 | _rest] when parent in [15, 16, 22, 23] ->
        {:ok, l2vpn_encoding_nested_subtlvs()}
      
      # Default to the last element in the path for standard subtlv lookup
      path when length(path) > 0 ->
        get_subtlv_specs(List.last(path))
        
      _ ->
        {:error, :invalid_context_path}
    end
  end
  
  def get_subtlv_specs(parent_tlv_type) when is_integer(parent_tlv_type) do
    case parent_tlv_type do
      4 -> {:ok, class_of_service_subtlvs()}
      5 -> {:ok, modem_capabilities_subtlvs()}
      10 -> {:ok, snmp_write_access_subtlvs()}
      11 -> {:ok, snmp_mib_object_subtlvs()}
      15 -> {:ok, upstream_packet_classification_subtlvs()}
      16 -> {:ok, downstream_packet_classification_subtlvs()}
      17 -> {:ok, upstream_service_flow_subtlvs()}
      18 -> {:ok, downstream_service_flow_subtlvs()}
      19 -> {:ok, phs_rule_subtlvs()}
      22 -> {:ok, upstream_packet_classification_subtlvs()}
      23 -> {:ok, downstream_packet_classification_subtlvs()}
      24 -> {:ok, downstream_service_flow_qos_subtlvs()}
      25 -> {:ok, upstream_service_flow_qos_subtlvs()}
      30 -> {:ok, baseline_privacy_config_subtlvs()}
      31 -> {:ok, baseline_privacy_key_mgmt_subtlvs()}
      38 -> {:ok, snmpv3_kickstart_subtlvs()}
      39 -> {:ok, subscriber_mgmt_control_subtlvs()}
      40 -> {:ok, subscriber_mgmt_cpe_ip_subtlvs()}
      41 -> {:ok, subscriber_mgmt_filter_groups_subtlvs()}
      42 -> {:ok, snmpv3_notification_receiver_subtlvs()}
      43 -> {:ok, l2vpn_encoding_subtlvs()}
      45 -> {:ok, ipv4_multicast_join_auth_subtlvs()}
      46 -> {:ok, ipv6_multicast_join_auth_subtlvs()}
      47 -> {:ok, upstream_drop_classification_subtlvs()}
      60 -> {:ok, ipv6_packet_classification_subtlvs()}
      64 -> {:ok, packetcable_config_subtlvs()}
      _ -> check_extended_tlv_subtlvs(parent_tlv_type)
    end
  end

  @doc """
  Get sub-TLV information for a specific sub-TLV within a parent TLV.
  
  ## Examples
  
      iex> Bindocsis.SubTlvSpecs.get_subtlv_info(5, 1)
      {:ok, %{name: "Concatenation Support", ...}}
  """
  @spec get_subtlv_info(non_neg_integer(), non_neg_integer()) ::
    {:ok, sub_tlv_info()} | {:error, atom()}
  def get_subtlv_info(parent_tlv_type, sub_tlv_type) do
    case get_subtlv_specs(parent_tlv_type) do
      {:ok, subtlv_specs} ->
        case Map.get(subtlv_specs, sub_tlv_type) do
          nil -> {:error, :unknown_subtlv}
          subtlv_info -> {:ok, subtlv_info}
        end
      error -> error
    end
  end

  @doc """
  Check if a parent TLV type supports sub-TLVs.
  """
  @spec supports_subtlvs?(non_neg_integer()) :: boolean()
  def supports_subtlvs?(parent_tlv_type) do
    case get_subtlv_specs(parent_tlv_type) do
      {:ok, _} -> true
      {:error, _} -> false
    end
  end

  # Private helper function for extended TLVs
  defp check_extended_tlv_subtlvs(parent_tlv_type) do
    cond do
      parent_tlv_type in 66..85 -> {:ok, extended_compound_subtlvs(parent_tlv_type)}
      parent_tlv_type in 86..199 -> {:ok, extended_tlv_subtlvs(parent_tlv_type)}
      parent_tlv_type in 200..253 -> {:ok, vendor_specific_subtlvs()}
      true -> {:error, :unknown_tlv}
    end
  end

  # =============================================================================
  # Sub-TLV Specifications by Parent TLV Type
  # =============================================================================

  # TLV 4: Class of Service Sub-TLVs
  defp class_of_service_subtlvs do
    %{
      1 => %{
        name: "Class ID",
        description: "Service class identifier",
        value_type: :uint8,
        max_length: 1,
        enum_values: nil
      },
      2 => %{
        name: "Maximum Downstream Rate",
        description: "Maximum downstream data rate in bps",
        value_type: :uint32,
        max_length: 4,
        enum_values: nil
      },
      3 => %{
        name: "Maximum Upstream Rate", 
        description: "Maximum upstream data rate in bps",
        value_type: :uint32,
        max_length: 4,
        enum_values: nil
      },
      4 => %{
        name: "Upstream Channel Priority",
        description: "Priority for upstream channel selection",
        value_type: :uint8,
        max_length: 1,
        enum_values: nil
      },
      5 => %{
        name: "Guaranteed Minimum Upstream Rate",
        description: "Guaranteed minimum upstream data rate in bps",
        value_type: :uint32,
        max_length: 4,
        enum_values: nil
      },
      6 => %{
        name: "Maximum Upstream Burst Size",
        description: "Maximum upstream burst size in bytes",
        value_type: :uint16,
        max_length: 2,
        enum_values: nil
      }
    }
  end

  # Placeholder functions for other sub-TLV specifications
  # These will be implemented in subsequent phases

  # TLV 5: Modem Capabilities Sub-TLVs - Complete specification
  defp modem_capabilities_subtlvs do
    %{
      1 => %{
        name: "Concatenation Support",
        description: "Cable modem concatenation capability",
        value_type: :uint8,
        max_length: 1,
        enum_values: %{0 => "Not supported", 1 => "Supported"}
      },
      2 => %{
        name: "Modem DOCSIS Version",
        description: "DOCSIS version supported by the cable modem",
        value_type: :uint8,
        max_length: 1,
        enum_values: %{0 => "DOCSIS 1.0", 1 => "DOCSIS 1.1", 2 => "DOCSIS 2.0", 3 => "DOCSIS 3.0", 4 => "DOCSIS 3.1", 5 => "DOCSIS 4.0"}
      },
      3 => %{
        name: "Fragmentation Support",
        description: "Cable modem fragmentation capability",
        value_type: :uint8,
        max_length: 1,
        enum_values: %{0 => "Not supported", 1 => "Supported"}
      },
      4 => %{
        name: "PHS Support",
        description: "Payload Header Suppression support",
        value_type: :uint8,
        max_length: 1,
        enum_values: %{0 => "Not supported", 1 => "Supported"}
      },
      5 => %{
        name: "IGMP Support",
        description: "Internet Group Management Protocol support",
        value_type: :uint8,
        max_length: 1,
        enum_values: %{0 => "Not supported", 1 => "IGMPv1", 2 => "IGMPv2", 3 => "IGMPv3"}
      },
      6 => %{
        name: "Privacy Support",
        description: "Baseline Privacy Interface support",
        value_type: :uint8,
        max_length: 1,
        enum_values: %{0 => "Not supported", 1 => "BPI", 2 => "BPI+"}
      },
      7 => %{
        name: "Downstream SAV Support",
        description: "Downstream Source Address Verification support",
        value_type: :uint8,
        max_length: 1,
        enum_values: %{0 => "Not supported", 1 => "Supported"}
      },
      8 => %{
        name: "Upstream SID Support",
        description: "Upstream Service ID support",
        value_type: :uint8,
        max_length: 1,
        enum_values: %{0 => "Not supported", 1 => "Supported"}
      },
      9 => %{
        name: "Optional Filtering Support",
        description: "Optional filtering capability",
        value_type: :uint8,
        max_length: 1,
        enum_values: %{0 => "Not supported", 1 => "Supported"}
      },
      10 => %{
        name: "Transmit Pre-Equalizer Taps",
        description: "Number of transmit pre-equalizer taps per modulation",
        value_type: :uint8,
        max_length: 1,
        enum_values: nil
      },
      11 => %{
        name: "Number of Transmit Equalizer Taps",
        description: "Number of transmit equalizer taps supported",
        value_type: :uint8,
        max_length: 1,
        enum_values: nil
      },
      12 => %{
        name: "DCC Support",
        description: "Dynamic Channel Change support",
        value_type: :uint8,
        max_length: 1,
        enum_values: %{0 => "Not supported", 1 => "Supported"}
      },
      13 => %{
        name: "IP Filters Support",
        description: "Number of IP filters supported",
        value_type: :uint16,
        max_length: 2,
        enum_values: nil
      },
      14 => %{
        name: "LLC Filters Support",
        description: "Number of LLC filters supported",
        value_type: :uint16,
        max_length: 2,
        enum_values: nil
      },
      15 => %{
        name: "Expanded Unicast SID Space",
        description: "Expanded unicast SID space support",
        value_type: :uint8,
        max_length: 1,
        enum_values: %{0 => "Not supported", 1 => "Supported"}
      },
      16 => %{
        name: "Ranging Hold-Off Support",
        description: "Ranging hold-off support",
        value_type: :uint8,
        max_length: 1,
        enum_values: %{0 => "Not supported", 1 => "Supported"}
      },
      17 => %{
        name: "L2VPN Capability",
        description: "Layer 2 VPN capability",
        value_type: :compound,
        max_length: :unlimited,
        enum_values: nil
      },
      18 => %{
        name: "L2VPN eSAFE Host Capability",
        description: "L2VPN embedded Service Application Function Element host capability",
        value_type: :compound,
        max_length: :unlimited,
        enum_values: nil
      },
      19 => %{
        name: "DUT Filtering Support",
        description: "Device Under Test filtering support",
        value_type: :compound,
        max_length: :unlimited,
        enum_values: nil
      },
      20 => %{
        name: "Upstream Frequency Range Support",
        description: "Upstream frequency range support",
        value_type: :uint8,
        max_length: 1,
        enum_values: %{0 => "Standard", 1 => "Extended"}
      },
      21 => %{
        name: "Upstream Symbol Rate Support",
        description: "Upstream symbol rate support",
        value_type: :uint8,
        max_length: 1,
        enum_values: %{0 => "160 ksym/s", 1 => "320 ksym/s", 2 => "640 ksym/s", 3 => "1280 ksym/s", 4 => "2560 ksym/s", 5 => "5120 ksym/s"}
      },
      22 => %{
        name: "Selectable Active Code Mode 2 Support",
        description: "Selectable Active Code Mode 2 support",
        value_type: :uint8,
        max_length: 1,
        enum_values: %{0 => "Not supported", 1 => "Supported"}
      },
      23 => %{
        name: "Code Hopping Mode 2 Support",
        description: "Code Hopping Mode 2 support",
        value_type: :uint8,
        max_length: 1,
        enum_values: %{0 => "Not supported", 1 => "Supported"}
      },
      24 => %{
        name: "Multiple Transmit Channel Support",
        description: "Multiple transmit channel support",
        value_type: :uint8,
        max_length: 1,
        enum_values: nil
      },
      25 => %{
        name: "512 SAID Support",
        description: "512 Security Association ID support",
        value_type: :uint8,
        max_length: 1,
        enum_values: %{0 => "Not supported", 1 => "Supported"}
      },
      26 => %{
        name: "Satellite Backhaul Support",
        description: "Satellite backhaul support",
        value_type: :uint8,
        max_length: 1,
        enum_values: %{0 => "Not supported", 1 => "Supported"}
      },
      27 => %{
        name: "Multiple Receive Module Support",
        description: "Multiple receive module support",
        value_type: :uint8,
        max_length: 1,
        enum_values: nil
      },
      28 => %{
        name: "Total SID Cluster Support",
        description: "Total SID cluster support",
        value_type: :uint8,
        max_length: 1,
        enum_values: nil
      },
      29 => %{
        name: "SID Clusters per Service Flow Support",
        description: "SID clusters per service flow support",
        value_type: :uint8,
        max_length: 1,
        enum_values: nil
      },
      30 => %{
        name: "Multiple Receive Channel Support",
        description: "Multiple receive channel support",
        value_type: :uint8,
        max_length: 1,
        enum_values: nil
      },
      31 => %{
        name: "Total Downstream Service ID Support",
        description: "Total downstream service ID support",
        value_type: :uint8,
        max_length: 1,
        enum_values: nil
      },
      32 => %{
        name: "Resequencing Downstream Service ID Support",
        description: "Resequencing downstream service ID support",
        value_type: :uint8,
        max_length: 1,
        enum_values: nil
      },
      33 => %{
        name: "Multicast Downstream Service ID Support",
        description: "Multicast downstream service ID support",
        value_type: :uint8,
        max_length: 1,
        enum_values: nil
      },
      34 => %{
        name: "Multicast DSID Forwarding",
        description: "Multicast DSID forwarding capability",
        value_type: :uint8,
        max_length: 1,
        enum_values: %{0 => "Not supported", 1 => "Supported"}
      },
      35 => %{
        name: "Frame Control Type Forwarding Capability",
        description: "Frame control type forwarding capability",
        value_type: :uint8,
        max_length: 1,
        enum_values: %{0 => "Not supported", 1 => "Supported"}
      },
      36 => %{
        name: "DPV Capability",
        description: "DOCSIS Path Verify capability",
        value_type: :uint8,
        max_length: 1,
        enum_values: %{0 => "Not supported", 1 => "Supported"}
      },
      37 => %{
        name: "UGS-AD Support",
        description: "Unsolicited Grant Service with Activity Detection support",
        value_type: :uint8,
        max_length: 1,
        enum_values: %{0 => "Not supported", 1 => "Supported"}
      },
      38 => %{
        name: "MAP and UCD Receipt Support",
        description: "MAP and UCD receipt support",
        value_type: :uint8,
        max_length: 1,
        enum_values: %{0 => "Not supported", 1 => "Supported"}
      },
      39 => %{
        name: "Upstream Drop Classifier Support",
        description: "Upstream drop classifier support",
        value_type: :uint8,
        max_length: 1,
        enum_values: %{0 => "Not supported", 1 => "Supported"}
      },
      40 => %{
        name: "IPv6 Support",
        description: "IPv6 capability support",
        value_type: :uint8,
        max_length: 1,
        enum_values: %{0 => "Not supported", 1 => "Supported"}
      },
      41 => %{
        name: "Extended Upstream Power Support",
        description: "Extended upstream power support",
        value_type: :uint8,
        max_length: 1,
        enum_values: %{0 => "Not supported", 1 => "Supported"}
      },
      42 => %{
        name: "C-DOCSIS Capability",
        description: "C-DOCSIS (China DOCSIS) capability",
        value_type: :uint8,
        max_length: 1,
        enum_values: %{0 => "Not supported", 1 => "Supported"}
      },
      43 => %{
        name: "Energy Management Capability",
        description: "Energy management capability",
        value_type: :compound,
        max_length: :unlimited,
        enum_values: nil
      }
    }
  end
  defp snmp_write_access_subtlvs, do: %{}
  defp snmp_mib_object_subtlvs do
    %{
      11 => %{
        name: "Object Identifier",
        description: "SNMP MIB object identifier (OID)",
        value_type: :oid,
        max_length: :unlimited,
        enum_values: nil
      },
      47 => %{
        name: "Object Value (Reserved)",
        description: "Reserved for object value (not used in configuration files)",
        value_type: :binary,
        max_length: :unlimited,
        enum_values: nil
      },
      48 => %{
        name: "Object Value", 
        description: "SNMP MIB object value in ASN.1 DER encoding",
        value_type: :asn1_der,
        max_length: :unlimited,
        enum_values: nil
      }
    }
  end
  # TLVs 15, 16, 22, 23: Packet Classification Sub-TLVs - Comprehensive specification
  defp upstream_packet_classification_subtlvs do
    packet_classification_subtlvs()
  end

  defp downstream_packet_classification_subtlvs do  
    packet_classification_subtlvs()
  end

  # Common packet classification sub-TLVs used by TLVs 15, 16, 22, 23
  defp packet_classification_subtlvs do
    %{
      1 => %{
        name: "Classifier Reference",
        description: "Unique identifier for this classifier",
        value_type: :uint8,
        max_length: 1,
        enum_values: nil
      },
      2 => %{
        name: "Classifier ID", 
        description: "Classifier identifier assigned by CMTS",
        value_type: :uint16,
        max_length: 2,
        enum_values: nil
      },
      3 => %{
        name: "Service Flow Reference",
        description: "Service flow reference for this classifier",
        value_type: :uint16,
        max_length: 2,
        enum_values: nil
      },
      4 => %{
        name: "Service Flow ID",
        description: "Service flow identifier assigned by CMTS",
        value_type: :uint32,
        max_length: 4,
        enum_values: nil
      },
      5 => %{
        name: "Classifier Priority",
        description: "Priority for classifier matching (0-255, 0 is highest)",
        value_type: :uint8,
        max_length: 1,
        enum_values: nil
      },
      6 => %{
        name: "Classifier Activation State",
        description: "Activation state of the classifier",
        value_type: :uint8,
        max_length: 1,
        enum_values: %{0 => "Inactive", 1 => "Active"}
      },
      7 => %{
        name: "Dynamic Service Change Action",
        description: "Action for dynamic service change",
        value_type: :uint8,
        max_length: 1,
        enum_values: %{0 => "Add", 1 => "Replace", 2 => "Delete"}
      },
      8 => %{
        name: "DSC Error Encodings",
        description: "Dynamic Service Change error encodings",
        value_type: :compound,
        max_length: :unlimited,
        enum_values: nil
      },
      9 => %{
        name: "IP Packet Classification Encodings",
        description: "IP packet classification rules",
        value_type: :compound,
        max_length: :unlimited,
        enum_values: nil
      },
      10 => %{
        name: "Ethernet Packet Classification Encodings", 
        description: "Ethernet packet classification rules",
        value_type: :compound,
        max_length: :unlimited,
        enum_values: nil
      },
      11 => %{
        name: "Ethernet LLC Packet Classification",
        description: "Ethernet LLC frame classification rules",
        value_type: :compound,
        max_length: :unlimited,
        enum_values: nil
      },
      12 => %{
        name: "IEEE 802.1Q Packet Classification",
        description: "IEEE 802.1Q VLAN packet classification",
        value_type: :compound,
        max_length: :unlimited,
        enum_values: nil
      },
      43 => %{
        name: "L2VPN Encoding",
        description: "Layer 2 VPN specific classification encoding",
        value_type: :compound,
        max_length: :unlimited,
        enum_values: nil
      }
    }
  end
  # TLVs 17, 18: Legacy Service Flow Sub-TLVs (DOCSIS 1.0/1.1)
  defp upstream_service_flow_subtlvs do
    service_flow_subtlvs()
  end

  defp downstream_service_flow_subtlvs do
    service_flow_subtlvs()
  end

  # TLVs 24, 25: QoS Service Flow Sub-TLVs (DOCSIS 1.1+) - Enhanced version
  defp downstream_service_flow_qos_subtlvs do
    service_flow_subtlvs()
  end

  defp upstream_service_flow_qos_subtlvs do
    service_flow_subtlvs()
  end

  # Common service flow sub-TLVs used by TLVs 17, 18, 24, 25
  defp service_flow_subtlvs do
    %{
      1 => %{
        name: "Service Flow Reference",
        description: "Unique identifier for this service flow",
        value_type: :uint16,
        max_length: 2,
        enum_values: nil
      },
      2 => %{
        name: "Service Flow ID",
        description: "Service flow identifier assigned by CMTS",
        value_type: :uint32,
        max_length: 4,
        enum_values: nil
      },
      3 => %{
        name: "Service Identifier",
        description: "Service identifier assigned by provisioning system",
        value_type: :uint16,
        max_length: 2,
        enum_values: nil
      },
      4 => %{
        name: "Service Class Name",
        description: "Name of the service class",
        value_type: :string,
        max_length: 16,
        enum_values: nil
      },
      5 => %{
        name: "Error Encodings",
        description: "Error encodings for service flow",
        value_type: :compound,
        max_length: :unlimited,
        enum_values: nil
      },
      6 => %{
        name: "QoS Parameter Set",
        description: "QoS parameter set encoding",
        value_type: :compound,
        max_length: :unlimited,
        enum_values: nil
      },
      7 => %{
        name: "QoS Parameter Set Type",
        description: "Type of QoS parameter set",
        value_type: :uint8,
        max_length: 1,
        enum_values: %{0 => "Active", 1 => "Admitted", 2 => "Provisioned"}
      },
      8 => %{
        name: "Traffic Priority",
        description: "Traffic priority (0-7, 7 is highest)",
        value_type: :uint8,
        max_length: 1,
        enum_values: %{0 => "Best Effort", 1 => "Background", 2 => "Spare", 3 => "Excellent Effort", 4 => "Controlled Load", 5 => "Video", 6 => "Voice", 7 => "Network Control"}
      },
      9 => %{
        name: "Maximum Sustained Traffic Rate",
        description: "Maximum sustained rate in bits per second",
        value_type: :uint32,
        max_length: 4,
        enum_values: nil
      },
      10 => %{
        name: "Maximum Traffic Burst",
        description: "Maximum traffic burst in bytes",
        value_type: :uint32,
        max_length: 4,
        enum_values: nil
      },
      11 => %{
        name: "Minimum Reserved Traffic Rate",
        description: "Minimum reserved rate in bits per second",
        value_type: :uint32,
        max_length: 4,
        enum_values: nil
      },
      12 => %{
        name: "Minimum Packet Size",
        description: "Minimum packet size in bytes",
        value_type: :uint16,
        max_length: 2,
        enum_values: nil
      },
      13 => %{
        name: "Maximum Packet Size",
        description: "Maximum packet size in bytes",
        value_type: :uint16,
        max_length: 2,
        enum_values: nil
      },
      14 => %{
        name: "Maximum Concatenated Burst",
        description: "Maximum concatenated burst in bytes",
        value_type: :uint16,
        max_length: 2,
        enum_values: nil
      },
      15 => %{
        name: "Service Flow Scheduling Type",
        description: "Scheduling type for the service flow",
        value_type: :uint8,
        max_length: 1,
        enum_values: %{
          1 => "Undefined",
          2 => "Best Effort",
          3 => "Non-Real-Time Polling Service",
          4 => "Real-Time Polling Service", 
          5 => "Unsolicited Grant Service",
          6 => "Unsolicited Grant Service with Activity Detection"
        }
      },
      16 => %{
        name: "Request/Transmission Policy",
        description: "Request and transmission policy bit mask",
        value_type: :uint32,
        max_length: 4,
        enum_values: nil
      },
      17 => %{
        name: "Tolerated Jitter",
        description: "Maximum delay variation in microseconds",
        value_type: :uint32,
        max_length: 4,
        enum_values: nil
      },
      18 => %{
        name: "Maximum Latency",
        description: "Maximum latency in microseconds",
        value_type: :uint32,
        max_length: 4,
        enum_values: nil
      },
      19 => %{
        name: "Grants Per Interval",
        description: "Number of grants per interval for unsolicited grant service",
        value_type: :uint8,
        max_length: 1,
        enum_values: nil
      },
      20 => %{
        name: "Nominal Polling Interval",
        description: "Nominal polling interval in microseconds",
        value_type: :uint32,
        max_length: 4,
        enum_values: nil
      },
      21 => %{
        name: "Unsolicited Grant Size",
        description: "Unsolicited grant size in bytes",
        value_type: :uint16,
        max_length: 2,
        enum_values: nil
      },
      22 => %{
        name: "Nominal Grant Interval",
        description: "Nominal grant interval in microseconds",
        value_type: :uint32,
        max_length: 4,
        enum_values: nil
      },
      23 => %{
        name: "Tolerated Grant Jitter",
        description: "Tolerated grant jitter in microseconds",
        value_type: :uint32,
        max_length: 4,
        enum_values: nil
      },
      24 => %{
        name: "Multiplier to Nominal Grant Interval",
        description: "Multiplier to nominal grant interval",
        value_type: :uint8,
        max_length: 1,
        enum_values: nil
      },
      25 => %{
        name: "Active QoS Timeout",
        description: "Active QoS timeout value",
        value_type: :uint16,
        max_length: 2,
        enum_values: nil
      },
      26 => %{
        name: "Admitted QoS Timeout",
        description: "Admitted QoS timeout value",
        value_type: :uint16,
        max_length: 2,
        enum_values: nil
      },
      27 => %{
        name: "Service Flow SID",
        description: "Service ID for this service flow",
        value_type: :uint16,
        max_length: 2,
        enum_values: nil
      },
      28 => %{
        name: "Maximum Downstream Latency",
        description: "Maximum downstream latency in microseconds",
        value_type: :uint32,
        max_length: 4,
        enum_values: nil
      }
    }
  end

  # TLV 19: PHS Rule Sub-TLVs
  defp phs_rule_subtlvs do
    %{
      1 => %{
        name: "PHS Classifier Reference",
        description: "Reference to classifier for PHS rule",
        value_type: :uint8,
        max_length: 1,
        enum_values: nil
      },
      2 => %{
        name: "PHS Classifier ID",
        description: "Classifier ID for PHS rule",
        value_type: :uint16,
        max_length: 2,
        enum_values: nil
      },
      3 => %{
        name: "PHS Service Flow Reference",
        description: "Service flow reference for PHS rule",
        value_type: :uint16,
        max_length: 2,
        enum_values: nil
      },
      4 => %{
        name: "PHS Service Flow ID", 
        description: "Service flow ID for PHS rule",
        value_type: :uint32,
        max_length: 4,
        enum_values: nil
      },
      5 => %{
        name: "DSC Action",
        description: "Dynamic Service Change action",
        value_type: :uint8,
        max_length: 1,
        enum_values: %{0 => "Add", 1 => "Replace", 2 => "Delete"}
      },
      6 => %{
        name: "PHS Error Encodings",
        description: "PHS error encodings",
        value_type: :compound,
        max_length: :unlimited,
        enum_values: nil
      },
      7 => %{
        name: "PHS Field",
        description: "PHS field pattern",
        value_type: :binary,
        max_length: 255,
        enum_values: nil
      },
      8 => %{
        name: "PHS Index",
        description: "PHS index for the rule",
        value_type: :uint8,
        max_length: 1,
        enum_values: nil
      },
      9 => %{
        name: "PHS Mask",
        description: "PHS mask for the field",
        value_type: :binary,
        max_length: 255,
        enum_values: nil
      },
      10 => %{
        name: "PHS Size",
        description: "Size of PHS field in bytes",
        value_type: :uint8,
        max_length: 1,
        enum_values: nil
      },
      11 => %{
        name: "PHS Verification",
        description: "PHS verification enable/disable",
        value_type: :uint8,
        max_length: 1,
        enum_values: %{0 => "Disabled", 1 => "Enabled"}
      }
    }
  end
  # TLV 30: Baseline Privacy Config Sub-TLVs
  defp baseline_privacy_config_subtlvs do
    %{
      1 => %{
        name: "Authorization Timeout",
        description: "Authorization timeout in seconds",
        value_type: :uint32,
        max_length: 4,
        enum_values: nil
      },
      2 => %{
        name: "Reauthorization Timeout",
        description: "Reauthorization timeout in seconds",
        value_type: :uint32,
        max_length: 4,
        enum_values: nil
      },
      3 => %{
        name: "Authorization Grace Time",
        description: "Authorization grace time in seconds",
        value_type: :uint32,
        max_length: 4,
        enum_values: nil
      },
      4 => %{
        name: "Operational Timeout",
        description: "Operational timeout in seconds",
        value_type: :uint32,
        max_length: 4,
        enum_values: nil
      },
      5 => %{
        name: "Rekey Timeout",
        description: "Rekey timeout in seconds",
        value_type: :uint32,
        max_length: 4,
        enum_values: nil
      },
      6 => %{
        name: "TEK Grace Time",
        description: "Traffic Encryption Key grace time in seconds",
        value_type: :uint32,
        max_length: 4,
        enum_values: nil
      },
      7 => %{
        name: "Authorization Reject Timeout",
        description: "Authorization reject timeout in seconds",
        value_type: :uint32,
        max_length: 4,
        enum_values: nil
      }
    }
  end

  # TLV 31: Baseline Privacy Key Management Sub-TLVs
  defp baseline_privacy_key_mgmt_subtlvs do
    %{
      1 => %{
        name: "Authorization Timeout",
        description: "Authorization timeout for key management",
        value_type: :uint32,
        max_length: 4,
        enum_values: nil
      },
      2 => %{
        name: "Reauthorization Timeout",
        description: "Reauthorization timeout for key management",
        value_type: :uint32,
        max_length: 4,
        enum_values: nil
      },
      3 => %{
        name: "Authorization Grace Time",
        description: "Authorization grace time for key management",
        value_type: :uint32,
        max_length: 4,
        enum_values: nil
      },
      4 => %{
        name: "Operational Timeout",
        description: "Operational timeout for key management",
        value_type: :uint32,
        max_length: 4,
        enum_values: nil
      },
      5 => %{
        name: "Rekey Timeout",
        description: "Rekey timeout for key management",
        value_type: :uint32,
        max_length: 4,
        enum_values: nil
      },
      6 => %{
        name: "TEK Grace Time",
        description: "TEK grace time for key management",
        value_type: :uint32,
        max_length: 4,
        enum_values: nil
      }
    }
  end

  # TLV 38: SNMPv3 Kickstart Sub-TLVs
  defp snmpv3_kickstart_subtlvs do
    %{
      1 => %{
        name: "SNMPv3 Kickstart Security Name",
        description: "SNMPv3 kickstart security name",
        value_type: :string,
        max_length: 16,
        enum_values: nil
      },
      2 => %{
        name: "SNMPv3 Kickstart Manager Public Number",
        description: "SNMPv3 kickstart manager public number",
        value_type: :binary,
        max_length: :unlimited,
        enum_values: nil
      }
    }
  end

  # TLV 39: Subscriber Management Control Sub-TLVs
  defp subscriber_mgmt_control_subtlvs do
    %{
      1 => %{
        name: "Subscriber Management Filter Groups",
        description: "Filter groups for subscriber management",
        value_type: :compound,
        max_length: :unlimited,
        enum_values: nil
      },
      2 => %{
        name: "Subscriber Management CPE IP Table",
        description: "CPE IP table for subscriber management",
        value_type: :compound,
        max_length: :unlimited,
        enum_values: nil
      },
      3 => %{
        name: "Subscriber Management Maximum CPE IP",
        description: "Maximum CPE IP addresses",
        value_type: :uint16,
        max_length: 2,
        enum_values: nil
      },
      4 => %{
        name: "Subscriber Management Upstream Drop Filter Group ID",
        description: "Upstream drop filter group identifier",
        value_type: :uint8,
        max_length: 1,
        enum_values: nil
      },
      5 => %{
        name: "Subscriber Management Unknown CPE IP Action",
        description: "Action for unknown CPE IP addresses",
        value_type: :uint8,
        max_length: 1,
        enum_values: %{0 => "Forward", 1 => "Discard"}
      }
    }
  end

  # TLV 40: Subscriber Management CPE IP List Sub-TLVs  
  defp subscriber_mgmt_cpe_ip_subtlvs do
    %{
      1 => %{
        name: "CPE IP Address",
        description: "CPE IP address",
        value_type: :ipv4,
        max_length: 4,
        enum_values: nil
      },
      2 => %{
        name: "CPE IP Subnet Mask",
        description: "CPE IP subnet mask",
        value_type: :ipv4,
        max_length: 4,
        enum_values: nil
      }
    }
  end

  # TLV 41: Subscriber Management Filter Groups Sub-TLVs
  defp subscriber_mgmt_filter_groups_subtlvs do
    %{
      1 => %{
        name: "Filter Group ID",
        description: "Filter group identifier",
        value_type: :compound,  # Changed from :uint8 - these contain nested subtlvs
        max_length: :unlimited,
        enum_values: nil
      },
      2 => %{
        name: "Internet Access",
        description: "Internet access permission",
        value_type: :compound,  # Changed from :uint8 - these contain nested subtlvs
        max_length: :unlimited,
        enum_values: nil
      },
      3 => %{
        name: "CPE Access",
        description: "CPE access permission",
        value_type: :compound,  # Changed from :uint8 - these contain nested subtlvs
        max_length: :unlimited,
        enum_values: nil
      }
    }
  end

  # TLV 42: SNMPv3 Notification Receiver Sub-TLVs
  defp snmpv3_notification_receiver_subtlvs do
    %{
      1 => %{
        name: "SNMPv3 Notification Receiver IP",
        description: "IP address of SNMPv3 notification receiver",
        value_type: :ipv4,
        max_length: 4,
        enum_values: nil
      },
      2 => %{
        name: "SNMPv3 Notification Receiver UDP Port",
        description: "UDP port of SNMPv3 notification receiver",
        value_type: :uint16,
        max_length: 2,
        enum_values: nil
      },
      3 => %{
        name: "SNMPv3 Notification Receiver Trap Type",
        description: "Type of SNMP trap",
        value_type: :uint16,
        max_length: 2,
        enum_values: %{1 => "Trap", 2 => "Inform"}
      },
      4 => %{
        name: "SNMPv3 Notification Receiver Timeout",
        description: "Notification receiver timeout",
        value_type: :uint16,
        max_length: 2,
        enum_values: nil
      },
      5 => %{
        name: "SNMPv3 Notification Receiver Retries",
        description: "Number of notification retries",
        value_type: :uint16,
        max_length: 2,
        enum_values: nil
      },
      6 => %{
        name: "SNMPv3 Notification Receiver Filter OID",
        description: "Filter OID for notifications",
        value_type: :binary,
        max_length: :unlimited,
        enum_values: nil
      },
      7 => %{
        name: "SNMPv3 Notification Receiver Security Name",
        description: "Security name for notifications",
        value_type: :string,
        max_length: 16,
        enum_values: nil
      },
      8 => %{
        name: "SNMPv3 Notification Receiver IPv6",
        description: "IPv6 address of SNMPv3 notification receiver", 
        value_type: :ipv6,
        max_length: 16,
        enum_values: nil
      }
    }
  end
  # TLV 43: L2VPN Encoding Sub-TLVs - Complex nested structure
  defp l2vpn_encoding_subtlvs do
    %{
      1 => %{
        name: "CM Load Balancing Policy ID",
        description: "Cable modem load balancing policy identifier",
        value_type: :uint32,
        max_length: 4,
        enum_values: nil
      },
      2 => %{
        name: "CM Load Balancing Priority",
        description: "Cable modem load balancing priority",
        value_type: :uint32,
        max_length: 4,
        enum_values: nil
      },
      3 => %{
        name: "CM Load Balancing Group ID",
        description: "Cable modem load balancing group identifier",
        value_type: :uint32,
        max_length: 4,
        enum_values: nil
      },
      4 => %{
        name: "CM Range Class ID Override",
        description: "Cable modem range class ID override",
        value_type: :uint32,
        max_length: 4,
        enum_values: nil
      },
      5 => %{
        name: "L2VPN Encoding",
        description: "Layer 2 VPN encoding configuration (nested sub-TLVs)",
        value_type: :compound,
        max_length: :unlimited,
        enum_values: nil
      },
      6 => %{
        name: "Extended CMTS MIC Configuration",
        description: "Extended CMTS Message Integrity Check configuration",
        value_type: :compound,
        max_length: :unlimited,
        enum_values: nil
      },
      7 => %{
        name: "SAV Authorization Encoding",
        description: "Source Address Verification authorization encoding",
        value_type: :compound,
        max_length: :unlimited,
        enum_values: nil
      },
      8 => %{
        name: "Vendor Specific Encoding",
        description: "Vendor-specific L2VPN encoding",
        value_type: :compound,
        max_length: :unlimited,
        enum_values: nil
      },
      9 => %{
        name: "CM Attribute Masks",
        description: "Cable modem attribute masks",
        value_type: :compound,
        max_length: :unlimited,
        enum_values: nil
      },
      10 => %{
        name: "IP Multicast Join Authorization",
        description: "IP multicast join authorization encoding",
        value_type: :binary,  # Changed from :compound - actual data shows this is binary, not subtlvs
        max_length: :unlimited,
        enum_values: nil
      },
      11 => %{
        name: "IP Multicast Leave Authorization", 
        description: "IP multicast leave authorization encoding",
        value_type: :binary,  # Changed from :compound - likely same issue as TLV 10
        max_length: :unlimited,
        enum_values: nil
      },
      12 => %{
        name: "DEMARC Auto Configuration",
        description: "Demarcation point auto configuration",
        value_type: :compound,
        max_length: :unlimited,
        enum_values: nil
      },
      # Sub-TLV 5 contains nested L2VPN sub-TLVs
      # These would be accessed as 43.5.x where x is the nested sub-TLV type
      13 => %{
        name: "L2VPN Mode",
        description: "L2VPN operating mode",
        value_type: :uint8,
        max_length: 1,
        enum_values: %{
          0 => "Point-to-Point",
          1 => "Point-to-Multipoint", 
          2 => "Multipoint-to-Multipoint",
          3 => "VPLS"
        }
      },
      14 => %{
        name: "DPoE L2VPN Configuration",
        description: "DPoE (DOCSIS Provisioning of EPON) L2VPN configuration",
        value_type: :compound,
        max_length: :unlimited,
        enum_values: nil
      },
      15 => %{
        name: "L2CP Processing",
        description: "Layer 2 Control Protocol processing configuration",
        value_type: :compound,
        max_length: :unlimited,
        enum_values: nil
      },
      16 => %{
        name: "IEEE 802.1Q C-Tag",
        description: "IEEE 802.1Q Customer Tag configuration",
        value_type: :compound,
        max_length: :unlimited,
        enum_values: nil
      },
      17 => %{
        name: "IEEE 802.1Q S-Tag",
        description: "IEEE 802.1Q Service Tag configuration", 
        value_type: :compound,
        max_length: :unlimited,
        enum_values: nil
      },
      18 => %{
        name: "L2VPN Tunnel Identifier",
        description: "L2VPN tunnel identifier",
        value_type: :uint32,
        max_length: 4,
        enum_values: nil
      },
      19 => %{
        name: "L2VPN Session Identifier",
        description: "L2VPN session identifier",
        value_type: :uint32,
        max_length: 4,
        enum_values: nil
      },
      20 => %{
        name: "L2VPN Pseudowire Type",
        description: "L2VPN pseudowire type",
        value_type: :uint16,
        max_length: 2,
        enum_values: %{
          1 => "Frame Relay DLCI",
          2 => "ATM AAL5 SDU VCC transport",
          3 => "ATM transparent cell transport",
          4 => "Ethernet VLAN",
          5 => "Ethernet port",
          6 => "PPP",
          7 => "HDLC",
          8 => "Frame Relay Port mode"
        }
      },
      21 => %{
        name: "BGP Attribute",
        description: "BGP (Border Gateway Protocol) attribute for L2VPN",
        value_type: :compound,
        max_length: :unlimited,
        enum_values: nil
      },
      22 => %{
        name: "L2VPN Quality of Service",
        description: "L2VPN Quality of Service parameters",
        value_type: :compound,
        max_length: :unlimited,
        enum_values: nil
      },
      23 => %{
        name: "Pseudowire Signaling",
        description: "Pseudowire signaling configuration",
        value_type: :compound,
        max_length: :unlimited,
        enum_values: nil
      },
      24 => %{
        name: "SOAM Subtype",
        description: "Service Operations, Administration and Maintenance subtype",
        value_type: :compound,
        max_length: :unlimited,
        enum_values: nil
      },
      25 => %{
        name: "L2VPN Port Configuration",
        description: "L2VPN port configuration parameters",
        value_type: :compound,
        max_length: :unlimited,
        enum_values: nil
      },
      26 => %{
        name: "L2VPN DSID",
        description: "L2VPN Downstream Service ID", 
        value_type: :binary,
        max_length: 3,
        enum_values: nil
      }
    }
  end
  defp ipv4_multicast_join_auth_subtlvs, do: %{}
  defp ipv6_multicast_join_auth_subtlvs, do: %{}
  defp upstream_drop_classification_subtlvs, do: %{}
  # TLV 60: IPv6 Packet Classification Sub-TLVs - Extended classification with IPv6 support
  defp ipv6_packet_classification_subtlvs do
    # Start with standard classification sub-TLVs
    base_subtlvs = packet_classification_subtlvs()
    
    # Add IPv6-specific sub-TLVs
    ipv6_specific = %{
      13 => %{
        name: "IPv6 Traffic Class Range and Mask",
        description: "IPv6 traffic class range and mask for classification",
        value_type: :compound,
        max_length: :unlimited,
        enum_values: nil
      },
      14 => %{
        name: "IPv6 Flow Label",
        description: "IPv6 flow label for packet classification",
        value_type: :uint32,
        max_length: 4,
        enum_values: nil
      },
      15 => %{
        name: "IPv6 Next Header Type",
        description: "IPv6 next header type for classification",
        value_type: :uint8,
        max_length: 1,
        enum_values: %{
          0 => "Hop-by-Hop Options", 
          6 => "TCP", 
          17 => "UDP", 
          41 => "IPv6", 
          43 => "Routing Header",
          44 => "Fragment Header",
          58 => "ICMPv6",
          60 => "Destination Options"
        }
      },
      16 => %{
        name: "IPv6 Source Prefix",
        description: "IPv6 source address prefix for classification",
        value_type: :compound,
        max_length: :unlimited,
        enum_values: nil
      },
      17 => %{
        name: "IPv6 Destination Prefix",
        description: "IPv6 destination address prefix for classification",
        value_type: :compound,
        max_length: :unlimited,
        enum_values: nil
      }
    }
    
    Map.merge(base_subtlvs, ipv6_specific)
  end
  defp packetcable_config_subtlvs, do: %{}
  # Extended compound TLV sub-TLVs (TLVs 66-85)
  defp extended_compound_subtlvs(parent_type) do
    case parent_type do
      66 -> management_event_control_subtlvs()
      67 -> subscriber_mgmt_cpe_ipv6_subtlvs()
      70 -> aggregate_service_flow_subtlvs()
      72 -> metro_ethernet_service_subtlvs()
      73 -> network_timing_profile_subtlvs()
      74 -> energy_parameters_subtlvs()
      77 -> dls_encoding_subtlvs()
      79 -> uni_control_encodings_subtlvs()
      80 -> downstream_resequencing_subtlvs()
      81 -> multicast_dsid_forward_subtlvs()
      82 -> symmetric_service_flow_subtlvs()
      83 -> dbc_request_subtlvs()
      84 -> dbc_response_subtlvs()
      85 -> dbc_acknowledge_subtlvs()
      _ -> %{}
    end
  end

  # Extended TLV sub-TLVs (TLVs 86-199)
  defp extended_tlv_subtlvs(parent_type) do
    case parent_type do
      86 -> erouter_init_mode_subtlvs()
      87 -> erouter_topology_mode_subtlvs()
      91 -> erouter_ipv6_rapid_access_subtlvs()
      97 -> erouter_subnet_mgmt_control_subtlvs()
      98 -> erouter_subnet_mgmt_cpe_subtlvs()
      99 -> erouter_subnet_mgmt_filter_subtlvs()
      101 -> dpd_configuration_subtlvs()
      102 -> enhanced_video_qa_subtlvs()
      103 -> dynamic_qos_config_subtlvs()
      105 -> link_aggregation_config_subtlvs()
      106 -> multicast_session_rules_subtlvs()
      107 -> ipv6_prefix_delegation_subtlvs()
      108 -> extended_modem_capabilities_subtlvs()
      109 -> advanced_encryption_config_subtlvs()
      110 -> quality_metrics_collection_subtlvs()
      _ -> %{}
    end
  end

  # Vendor-specific sub-TLVs (TLVs 200-253)
  defp vendor_specific_subtlvs do
    %{
      1 => %{
        name: "Vendor OUI",
        description: "Organizationally Unique Identifier",
        value_type: :vendor_oui,
        max_length: 3
      },
      2 => %{
        name: "Vendor Data",
        description: "Vendor-specific configuration data",
        value_type: :binary,
        max_length: :unlimited
      }
    }
  end

  # L2VPN Encoding nested subtlvs (for TLV 43.5 within packet classification)
  # Note: Without proper DOCSIS specs, these are conservative defaults
  # Treat anything with unexpected length as compound/binary
  defp l2vpn_encoding_nested_subtlvs do
    %{
      1 => %{
        name: "L2VPN Sub-TLV 1",
        description: "L2VPN encoding sub-TLV 1",
        value_type: :compound,
        max_length: :unlimited,
        enum_values: nil
      },
      2 => %{
        name: "Service Multiplexing",
        description: "Service multiplexing configuration",
        value_type: :compound,
        max_length: :unlimited,
        enum_values: nil
      },
      3 => %{
        name: "L2VPN Sub-TLV 3",
        description: "L2VPN encoding sub-TLV 3",
        value_type: :compound,
        max_length: :unlimited,
        enum_values: nil
      },
      4 => %{
        name: "L2VPN Sub-TLV 4",
        description: "L2VPN encoding sub-TLV 4",
        value_type: :compound,
        max_length: :unlimited,
        enum_values: nil
      },
      5 => %{
        name: "L2VPN Sub-TLV 5",
        description: "L2VPN encoding sub-TLV 5",
        value_type: :compound,
        max_length: :unlimited,
        enum_values: nil
      },
      6 => %{
        name: "L2VPN Sub-TLV 6",
        description: "L2VPN encoding sub-TLV 6",
        value_type: :compound,
        max_length: :unlimited,
        enum_values: nil
      },
      7 => %{
        name: "L2VPN Sub-TLV 7",
        description: "L2VPN encoding sub-TLV 7",
        value_type: :compound,
        max_length: :unlimited,
        enum_values: nil
      },
      8 => %{
        name: "L2VPN Sub-TLV 8",
        description: "L2VPN encoding sub-TLV 8",
        value_type: :compound,
        max_length: :unlimited,
        enum_values: nil
      },
      9 => %{
        name: "L2VPN Sub-TLV 9",
        description: "L2VPN encoding sub-TLV 9",
        value_type: :compound,
        max_length: :unlimited,
        enum_values: nil
      },
      10 => %{
        name: "L2VPN Sub-TLV 10",
        description: "L2VPN encoding sub-TLV 10",
        value_type: :binary,
        max_length: :unlimited,
        enum_values: nil
      },
      11 => %{
        name: "L2VPN Sub-TLV 11",
        description: "L2VPN encoding sub-TLV 11",
        value_type: :binary,
        max_length: :unlimited,
        enum_values: nil
      },
      12 => %{
        name: "L2VPN Sub-TLV 12",
        description: "L2VPN encoding sub-TLV 12",
        value_type: :binary,
        max_length: :unlimited,
        enum_values: nil
      },
      13 => %{
        name: "L2VPN Mode",
        description: "Layer 2 VPN mode configuration",
        value_type: :binary,
        max_length: :unlimited,
        enum_values: nil
      },
      14 => %{
        name: "L2VPN Sub-TLV 14",
        description: "L2VPN encoding sub-TLV 14",
        value_type: :compound,
        max_length: :unlimited,
        enum_values: nil
      },
      15 => %{
        name: "L2VPN Sub-TLV 15",
        description: "L2VPN encoding sub-TLV 15",
        value_type: :compound,
        max_length: :unlimited,
        enum_values: nil
      },
      16 => %{
        name: "L2VPN Sub-TLV 16",
        description: "L2VPN encoding sub-TLV 16",
        value_type: :compound,
        max_length: :unlimited,
        enum_values: nil
      },
      17 => %{
        name: "L2VPN Sub-TLV 17",
        description: "L2VPN encoding sub-TLV 17",
        value_type: :compound,
        max_length: :unlimited,
        enum_values: nil
      },
      18 => %{
        name: "L2VPN Sub-TLV 18",
        description: "L2VPN encoding sub-TLV 18",
        value_type: :compound,
        max_length: :unlimited,
        enum_values: nil
      },
      19 => %{
        name: "L2VPN Sub-TLV 19",
        description: "L2VPN encoding sub-TLV 19",
        value_type: :compound,
        max_length: :unlimited,
        enum_values: nil
      },
      20 => %{
        name: "L2VPN Sub-TLV 20",
        description: "L2VPN encoding sub-TLV 20",
        value_type: :compound,
        max_length: :unlimited,
        enum_values: nil
      },
      21 => %{
        name: "L2VPN Sub-TLV 21",
        description: "L2VPN encoding sub-TLV 21",
        value_type: :binary,
        max_length: :unlimited,
        enum_values: nil
      },
      22 => %{
        name: "L2VPN Sub-TLV 22",
        description: "L2VPN encoding sub-TLV 22",
        value_type: :compound,
        max_length: :unlimited,
        enum_values: nil
      },
      23 => %{
        name: "L2VPN Sub-TLV 23",
        description: "L2VPN encoding sub-TLV 23",
        value_type: :compound,
        max_length: :unlimited,
        enum_values: nil
      },
      24 => %{
        name: "L2VPN Sub-TLV 24",
        description: "L2VPN encoding sub-TLV 24",
        value_type: :compound,
        max_length: :unlimited,
        enum_values: nil
      },
      25 => %{
        name: "L2VPN Sub-TLV 25",
        description: "L2VPN encoding sub-TLV 25",
        value_type: :compound,
        max_length: :unlimited,
        enum_values: nil
      },
      26 => %{
        name: "L2VPN Sub-TLV 26",
        description: "L2VPN encoding sub-TLV 26",
        value_type: :compound,
        max_length: :unlimited,
        enum_values: nil
      }
    }
  end

  # Service Multiplexing subtlvs (TLV 22.43.5.2)
  defp service_multiplexing_subtlvs do
    %{
      1 => %{
        name: "Service Multiplexing Sub-TLV 1",
        description: "Service multiplexing sub-TLV 1",
        value_type: :compound,
        max_length: :unlimited,
        enum_values: nil
      },
      2 => %{
        name: "Service Multiplexing Sub-TLV 2",
        description: "Service multiplexing sub-TLV 2",
        value_type: :compound,
        max_length: :unlimited,
        enum_values: nil
      },
      3 => %{
        name: "Service Multiplexing Sub-TLV 3",
        description: "Service multiplexing sub-TLV 3",
        value_type: :compound,
        max_length: :unlimited,
        enum_values: nil
      },
      4 => %{
        name: "Service Multiplexing Value",
        description: "MPLS service multiplexing value configuration",
        value_type: :compound,
        max_length: :unlimited,
        enum_values: nil
      },
      5 => %{
        name: "Service Multiplexing Sub-TLV 5",
        description: "Service multiplexing sub-TLV 5",
        value_type: :compound,
        max_length: :unlimited,
        enum_values: nil
      },
      6 => %{
        name: "IEEE 802.1ah Encapsulation",
        description: "IEEE 802.1ah encapsulation configuration",
        value_type: :compound,
        max_length: :unlimited,
        enum_values: nil
      }
    }
  end

  # MPLS Service Multiplexing Value subtlvs (TLV 22.43.5.2.4)
  # Based on actual data: TLVs 1&4 contain TLV 0 markers, TLV 2 contains TLV 1, etc.
  defp mpls_service_multiplexing_value_subtlvs do
    %{
      1 => %{
        name: "MPLS Service ID",
        description: "MPLS service identifier with marker",
        value_type: :compound,  # Contains TLV 0 marker
        max_length: :unlimited,
        enum_values: nil
      },
      2 => %{
        name: "MPLS VC ID",
        description: "MPLS virtual circuit identifier",
        value_type: :compound,  # Contains TLV 1 with hex data
        max_length: :unlimited,
        enum_values: nil
      },
      3 => %{
        name: "MPLS Service Type",
        description: "MPLS service type indicator",
        value_type: :hex_string,  # Single hex value
        max_length: 4,
        enum_values: nil
      },
      4 => %{
        name: "MPLS Peer Configuration",
        description: "MPLS peer configuration with marker",
        value_type: :compound,  # Contains TLV 0 marker
        max_length: :unlimited,
        enum_values: nil
      },
      5 => %{
        name: "MPLS Extended Configuration",
        description: "Extended MPLS configuration parameters",
        value_type: :compound,  # Contains complex nested data
        max_length: :unlimited,
        enum_values: nil
      }
    }
  end
  
  # =============================================================================
  # Extended Compound TLV Sub-TLV Specifications (TLVs 66-85)
  # =============================================================================

  # TLV 66: Management Event Control Sub-TLVs
  defp management_event_control_subtlvs do
    %{
      1 => %{
        name: "Event Priority Threshold",
        description: "Minimum event priority to report",
        value_type: :uint8,
        max_length: 1,
        enum_values: %{
          1 => "Emergency",
          2 => "Alert", 
          3 => "Critical",
          4 => "Error",
          5 => "Warning",
          6 => "Notice",
          7 => "Information",
          8 => "Debug"
        }
      },
      2 => %{
        name: "Event Reporting Server",
        description: "IP address of event reporting server",
        value_type: :ipv4,
        max_length: 4
      },
      3 => %{
        name: "Event Reporting Port",
        description: "UDP port for event reporting",
        value_type: :uint16,
        max_length: 2
      },
      4 => %{
        name: "SNMP Trap Community",
        description: "SNMP trap community string",
        value_type: :string,
        max_length: 32
      }
    }
  end

  # TLV 67: Subscriber Management CPE IPv6 Table Sub-TLVs
  defp subscriber_mgmt_cpe_ipv6_subtlvs do
    %{
      1 => %{
        name: "CPE IPv6 Prefix",
        description: "IPv6 prefix for CPE device",
        value_type: :ipv6,
        max_length: 16
      },
      2 => %{
        name: "CPE IPv6 Prefix Length",
        description: "IPv6 prefix length in bits",
        value_type: :uint8,
        max_length: 1
      },
      3 => %{
        name: "IPv6 Lease Time",
        description: "IPv6 address lease time in seconds",
        value_type: :uint32,
        max_length: 4
      }
    }
  end

  # TLV 70: Aggregate Service Flow Sub-TLVs
  defp aggregate_service_flow_subtlvs do
    %{
      1 => %{
        name: "Aggregate Service Flow Reference",
        description: "Reference to aggregate service flow",
        value_type: :uint16,
        max_length: 2
      },
      2 => %{
        name: "Service Flow Reference List",
        description: "List of service flow references",
        value_type: :compound,
        max_length: :unlimited
      },
      3 => %{
        name: "Aggregate Maximum Rate",
        description: "Maximum aggregate data rate",
        value_type: :uint32,
        max_length: 4
      },
      4 => %{
        name: "Aggregate Minimum Rate",
        description: "Minimum aggregate data rate",
        value_type: :uint32,
        max_length: 4
      }
    }
  end

  # TLV 72: Metro Ethernet Service Profile Sub-TLVs
  defp metro_ethernet_service_subtlvs do
    %{
      1 => %{
        name: "Service Type",
        description: "Metro Ethernet service type",
        value_type: :uint8,
        max_length: 1,
        enum_values: %{
          1 => "EPL (Ethernet Private Line)",
          2 => "EVPL (Ethernet Virtual Private Line)",
          3 => "EP-LAN (Ethernet Private LAN)",
          4 => "EVP-LAN (Ethernet Virtual Private LAN)",
          5 => "EP-Tree (Ethernet Private Tree)",
          6 => "EVP-Tree (Ethernet Virtual Private Tree)"
        }
      },
      2 => %{
        name: "Service ID",
        description: "Metro Ethernet service identifier",
        value_type: :uint32,
        max_length: 4
      },
      3 => %{
        name: "Bandwidth Profile",
        description: "Bandwidth profile configuration",
        value_type: :compound,
        max_length: :unlimited
      },
      4 => %{
        name: "VLAN Configuration",
        description: "VLAN configuration parameters",
        value_type: :compound,
        max_length: :unlimited
      }
    }
  end

  # TLV 73: Network Timing Profile Sub-TLVs
  defp network_timing_profile_subtlvs do
    %{
      1 => %{
        name: "Timing Reference Source",
        description: "Primary timing reference source",
        value_type: :uint8,
        max_length: 1,
        enum_values: %{
          1 => "Internal Oscillator",
          2 => "GPS",
          3 => "Network Time Protocol (NTP)",
          4 => "Precision Time Protocol (PTP)",
          5 => "DOCSIS Timestamp"
        }
      },
      2 => %{
        name: "Timing Server Address",
        description: "IP address of timing server",
        value_type: :ipv4,
        max_length: 4
      },
      3 => %{
        name: "Synchronization Accuracy",
        description: "Required synchronization accuracy in microseconds",
        value_type: :uint16,
        max_length: 2
      }
    }
  end

  # TLV 74: Energy Parameters Sub-TLVs
  defp energy_parameters_subtlvs do
    %{
      1 => %{
        name: "Energy Management Mode",
        description: "Energy management operating mode",
        value_type: :uint8,
        max_length: 1,
        enum_values: %{
          0 => "Disabled",
          1 => "Light Sleep",
          2 => "Deep Sleep",
          3 => "Dynamic Power Management"
        }
      },
      2 => %{
        name: "Power Threshold",
        description: "Power consumption threshold in watts",
        value_type: :uint16,
        max_length: 2
      },
      3 => %{
        name: "Sleep Timer",
        description: "Sleep timer duration in seconds",
        value_type: :uint32,
        max_length: 4
      }
    }
  end

  # =============================================================================
  # Extended TLV Sub-TLV Specifications (TLVs 86-199)
  # =============================================================================

  # TLV 86: eRouter Initialization Mode Override Sub-TLVs
  defp erouter_init_mode_subtlvs do
    %{
      1 => %{
        name: "Initialization Mode",
        description: "eRouter initialization mode",
        value_type: :uint8,
        max_length: 1,
        enum_values: %{
          0 => "Disabled",
          1 => "IPv4 Only",
          2 => "IPv6 Only",
          3 => "Dual Stack"
        }
      },
      2 => %{
        name: "IPv4 Configuration Method",
        description: "IPv4 address configuration method",
        value_type: :uint8,
        max_length: 1,
        enum_values: %{
          1 => "Static",
          2 => "DHCP",
          3 => "PPPoE"
        }
      },
      3 => %{
        name: "IPv6 Configuration Method",
        description: "IPv6 address configuration method",
        value_type: :uint8,
        max_length: 1,
        enum_values: %{
          1 => "Static",
          2 => "DHCP",
          3 => "SLAAC"
        }
      }
    }
  end

  # TLV 101: Deep Packet Detection Configuration Sub-TLVs
  defp dpd_configuration_subtlvs do
    %{
      1 => %{
        name: "DPD Enable",
        description: "Enable/disable deep packet detection",
        value_type: :uint8,
        max_length: 1,
        enum_values: %{
          0 => "Disabled",
          1 => "Enabled"
        }
      },
      2 => %{
        name: "Detection Rules",
        description: "Deep packet detection rules",
        value_type: :compound,
        max_length: :unlimited
      },
      3 => %{
        name: "Action Policy",
        description: "Action to take on detection",
        value_type: :uint8,
        max_length: 1,
        enum_values: %{
          1 => "Log Only",
          2 => "Rate Limit",
          3 => "Block",
          4 => "Redirect"
        }
      }
    }
  end

  # TLV 108: Extended Modem Capabilities Sub-TLVs
  defp extended_modem_capabilities_subtlvs do
    %{
      1 => %{
        name: "DOCSIS 4.0 Support",
        description: "DOCSIS 4.0 capability support",
        value_type: :uint8,
        max_length: 1,
        enum_values: %{
          0 => "Not Supported",
          1 => "Supported"
        }
      },
      2 => %{
        name: "Low Latency DOCSIS Support",
        description: "Low Latency DOCSIS (LLD) support",
        value_type: :uint8,
        max_length: 1,
        enum_values: %{
          0 => "Not Supported",
          1 => "Supported"
        }
      },
      3 => %{
        name: "Maximum Upstream Channels",
        description: "Maximum number of upstream channels supported",
        value_type: :uint8,
        max_length: 1
      },
      4 => %{
        name: "Maximum Downstream Channels", 
        description: "Maximum number of downstream channels supported",
        value_type: :uint8,
        max_length: 1
      },
      5 => %{
        name: "OFDM/OFDMA Support",
        description: "OFDM/OFDMA modulation support",
        value_type: :uint8,
        max_length: 1,
        enum_values: %{
          0 => "Not Supported",
          1 => "OFDM Only",
          2 => "OFDMA Only",
          3 => "Both OFDM and OFDMA"
        }
      }
    }
  end

  # =============================================================================
  # Remaining Compound TLV Sub-TLVs (TLVs 77-85) - DOCSIS 3.1 Advanced Features
  # =============================================================================

  # TLV 77: DLS Encoding Sub-TLVs
  defp dls_encoding_subtlvs do
    %{
      1 => %{
        name: "DLS Service Flow Reference",
        description: "Reference to downstream service flow",
        value_type: :uint16,
        max_length: 2
      },
      2 => %{
        name: "DLS QoS Parameters",
        description: "Quality of Service parameters for DLS",
        value_type: :compound,
        max_length: :unlimited
      },
      3 => %{
        name: "DLS Classifier Rules",
        description: "Packet classification rules for DLS",
        value_type: :compound,
        max_length: :unlimited
      },
      4 => %{
        name: "DLS Error Correction",
        description: "Error correction method for DLS",
        value_type: :uint8,
        max_length: 1,
        enum_values: %{
          0 => "None",
          1 => "Reed-Solomon",
          2 => "LDPC",
          3 => "BCH"
        }
      }
    }
  end

  # TLV 79: UNI Control Encodings Sub-TLVs
  defp uni_control_encodings_subtlvs do
    %{
      1 => %{
        name: "UNI Interface Type",
        description: "User Network Interface type",
        value_type: :uint8,
        max_length: 1,
        enum_values: %{
          1 => "Ethernet",
          2 => "WiFi",
          3 => "MoCA",
          4 => "USB",
          5 => "HomePlug"
        }
      },
      2 => %{
        name: "UNI MAC Address",
        description: "MAC address of UNI interface",
        value_type: :mac_address,
        max_length: 6
      },
      3 => %{
        name: "UNI VLAN Configuration",
        description: "VLAN configuration for UNI",
        value_type: :compound,
        max_length: :unlimited
      },
      4 => %{
        name: "UNI Bandwidth Limit",
        description: "Bandwidth limit for UNI in Mbps",
        value_type: :uint32,
        max_length: 4
      },
      5 => %{
        name: "UNI Service Profile",
        description: "Service profile identifier for UNI",
        value_type: :uint16,
        max_length: 2
      }
    }
  end

  # TLV 80: Downstream Resequencing Sub-TLVs
  defp downstream_resequencing_subtlvs do
    %{
      1 => %{
        name: "Resequencing Enable",
        description: "Enable/disable downstream resequencing",
        value_type: :uint8,
        max_length: 1,
        enum_values: %{
          0 => "Disabled",
          1 => "Enabled"
        }
      },
      2 => %{
        name: "Resequencing Buffer Size",
        description: "Resequencing buffer size in bytes",
        value_type: :uint32,
        max_length: 4
      },
      3 => %{
        name: "Resequencing Timeout",
        description: "Resequencing timeout in milliseconds",
        value_type: :uint16,
        max_length: 2
      },
      4 => %{
        name: "Out of Order Threshold",
        description: "Threshold for out-of-order packet detection",
        value_type: :uint16,
        max_length: 2
      }
    }
  end

  # TLV 81: Multicast DSID Forward Sub-TLVs
  defp multicast_dsid_forward_subtlvs do
    %{
      1 => %{
        name: "Multicast Group Address",
        description: "Multicast group IPv4/IPv6 address",
        value_type: :binary,  # Can be IPv4 or IPv6
        max_length: 16
      },
      2 => %{
        name: "DSID Forward Rule",
        description: "DSID forwarding rule configuration",
        value_type: :compound,
        max_length: :unlimited
      },
      3 => %{
        name: "Multicast Source Address",
        description: "Source address for multicast traffic",
        value_type: :binary,  # Can be IPv4 or IPv6
        max_length: 16
      },
      4 => %{
        name: "Forward Action",
        description: "Action to take for multicast traffic",
        value_type: :uint8,
        max_length: 1,
        enum_values: %{
          1 => "Forward",
          2 => "Drop", 
          3 => "Mirror",
          4 => "Rate Limit"
        }
      }
    }
  end

  # TLV 82: Symmetric Service Flow Sub-TLVs
  defp symmetric_service_flow_subtlvs do
    %{
      1 => %{
        name: "Symmetric Service Flow ID",
        description: "Identifier for symmetric service flow",
        value_type: :uint16,
        max_length: 2
      },
      2 => %{
        name: "Upstream Service Flow Reference",
        description: "Reference to upstream service flow",
        value_type: :uint16,
        max_length: 2
      },
      3 => %{
        name: "Downstream Service Flow Reference",
        description: "Reference to downstream service flow",
        value_type: :uint16,
        max_length: 2
      },
      4 => %{
        name: "Symmetric QoS Parameters",
        description: "QoS parameters applied symmetrically",
        value_type: :compound,
        max_length: :unlimited
      },
      5 => %{
        name: "Load Balancing Mode",
        description: "Load balancing mode for symmetric flow",
        value_type: :uint8,
        max_length: 1,
        enum_values: %{
          0 => "None",
          1 => "Round Robin",
          2 => "Weighted",
          3 => "Least Loaded"
        }
      }
    }
  end

  # TLV 83: DBC Request Sub-TLVs
  defp dbc_request_subtlvs do
    %{
      1 => %{
        name: "DBC Transaction ID",
        description: "Dynamic Bonding Change transaction identifier",
        value_type: :uint32,
        max_length: 4
      },
      2 => %{
        name: "Requested Channel List",
        description: "List of channels requested for bonding",
        value_type: :compound,
        max_length: :unlimited
      },
      3 => %{
        name: "DBC Request Type",
        description: "Type of dynamic bonding change request",
        value_type: :uint8,
        max_length: 1,
        enum_values: %{
          1 => "Add Channels",
          2 => "Remove Channels",
          3 => "Replace Channels",
          4 => "Reorder Channels"
        }
      },
      4 => %{
        name: "Priority Level",
        description: "Priority level for DBC request",
        value_type: :uint8,
        max_length: 1,
        enum_values: %{
          1 => "Low",
          2 => "Normal",
          3 => "High",
          4 => "Critical"
        }
      }
    }
  end

  # TLV 84: DBC Response Sub-TLVs
  defp dbc_response_subtlvs do
    %{
      1 => %{
        name: "DBC Transaction ID",
        description: "Dynamic Bonding Change transaction identifier",
        value_type: :uint32,
        max_length: 4
      },
      2 => %{
        name: "Response Code",
        description: "Response code for DBC request",
        value_type: :uint8,
        max_length: 1,
        enum_values: %{
          0 => "Success",
          1 => "Partial Success",
          2 => "Failure - Resource Unavailable",
          3 => "Failure - Invalid Request",
          4 => "Failure - System Error"
        }
      },
      3 => %{
        name: "Assigned Channel List",
        description: "List of channels assigned after DBC",
        value_type: :compound,
        max_length: :unlimited
      },
      4 => %{
        name: "Effective Time",
        description: "Time when DBC becomes effective",
        value_type: :timestamp,
        max_length: 4
      }
    }
  end

  # TLV 85: DBC Acknowledge Sub-TLVs
  defp dbc_acknowledge_subtlvs do
    %{
      1 => %{
        name: "DBC Transaction ID",
        description: "Dynamic Bonding Change transaction identifier",
        value_type: :uint32,
        max_length: 4
      },
      2 => %{
        name: "Acknowledgment Status",
        description: "Status of DBC acknowledgment",
        value_type: :uint8,
        max_length: 1,
        enum_values: %{
          0 => "Acknowledged",
          1 => "Rejected - Invalid Transaction",
          2 => "Rejected - Timeout",
          3 => "Rejected - System Error"
        }
      },
      3 => %{
        name: "Final Channel Configuration",
        description: "Final channel configuration after DBC",
        value_type: :compound,
        max_length: :unlimited
      }
    }
  end

  # =============================================================================
  # Remaining Extended TLV Sub-TLVs (TLVs 87-107) - Complete Implementation
  # =============================================================================

  # TLV 87: eRouter Topology Mode Override Sub-TLVs
  defp erouter_topology_mode_subtlvs do
    %{
      1 => %{
        name: "Topology Mode",
        description: "eRouter network topology mode",
        value_type: :uint8,
        max_length: 1,
        enum_values: %{
          1 => "Bridge Mode",
          2 => "Router Mode",
          3 => "Pass-through Mode",
          4 => "Hybrid Mode"
        }
      },
      2 => %{
        name: "NAT Enable",
        description: "Enable/disable Network Address Translation",
        value_type: :uint8,
        max_length: 1,
        enum_values: %{
          0 => "Disabled",
          1 => "Enabled"
        }
      },
      3 => %{
        name: "Firewall Configuration",
        description: "Firewall configuration parameters",
        value_type: :compound,
        max_length: :unlimited
      }
    }
  end

  # TLV 91: eRouter IPv6 Rapid Access Sub-TLVs
  defp erouter_ipv6_rapid_access_subtlvs do
    %{
      1 => %{
        name: "IPv6 Rapid Access Enable",
        description: "Enable IPv6 rapid access feature",
        value_type: :uint8,
        max_length: 1,
        enum_values: %{
          0 => "Disabled",
          1 => "Enabled"
        }
      },
      2 => %{
        name: "IPv6 Prefix Delegation",
        description: "IPv6 prefix delegation configuration",
        value_type: :compound,
        max_length: :unlimited
      },
      3 => %{
        name: "DHCPv6 Server Configuration",
        description: "DHCPv6 server configuration parameters",
        value_type: :compound,
        max_length: :unlimited
      },
      4 => %{
        name: "IPv6 Address Pool",
        description: "IPv6 address pool for rapid access",
        value_type: :compound,
        max_length: :unlimited
      }
    }
  end

  # TLV 97: eRouter Subnet Management Control Sub-TLVs
  defp erouter_subnet_mgmt_control_subtlvs do
    %{
      1 => %{
        name: "Subnet Management Enable",
        description: "Enable eRouter subnet management",
        value_type: :uint8,
        max_length: 1,
        enum_values: %{
          0 => "Disabled",
          1 => "Enabled"
        }
      },
      2 => %{
        name: "Maximum CPE Devices",
        description: "Maximum number of CPE devices allowed",
        value_type: :uint16,
        max_length: 2
      },
      3 => %{
        name: "Subnet Learning Mode",
        description: "Subnet learning mode configuration",
        value_type: :uint8,
        max_length: 1,
        enum_values: %{
          1 => "DHCP Learning",
          2 => "ARP Learning",
          3 => "Static Configuration",
          4 => "Hybrid Learning"
        }
      },
      4 => %{
        name: "Lease Time",
        description: "DHCP lease time in seconds",
        value_type: :uint32,
        max_length: 4
      }
    }
  end

  # TLV 98: eRouter Subnet Management CPE Table Sub-TLVs
  defp erouter_subnet_mgmt_cpe_subtlvs do
    %{
      1 => %{
        name: "CPE MAC Address",
        description: "MAC address of CPE device",
        value_type: :mac_address,
        max_length: 6
      },
      2 => %{
        name: "CPE IPv4 Address",
        description: "IPv4 address assigned to CPE",
        value_type: :ipv4,
        max_length: 4
      },
      3 => %{
        name: "CPE IPv6 Address",
        description: "IPv6 address assigned to CPE",
        value_type: :ipv6,
        max_length: 16
      },
      4 => %{
        name: "CPE Lease Expiration",
        description: "Lease expiration timestamp",
        value_type: :timestamp,
        max_length: 4
      },
      5 => %{
        name: "CPE Device Type",
        description: "Type of CPE device",
        value_type: :uint8,
        max_length: 1,
        enum_values: %{
          1 => "PC/Laptop",
          2 => "Mobile Device",
          3 => "IoT Device",
          4 => "Gaming Console",
          5 => "Set Top Box",
          6 => "Smart TV",
          99 => "Unknown"
        }
      }
    }
  end

  # TLV 99: eRouter Subnet Management Filter Groups Sub-TLVs
  defp erouter_subnet_mgmt_filter_subtlvs do
    %{
      1 => %{
        name: "Filter Group ID",
        description: "Unique identifier for filter group",
        value_type: :uint16,
        max_length: 2
      },
      2 => %{
        name: "Filter Rules",
        description: "Packet filtering rules for group",
        value_type: :compound,
        max_length: :unlimited
      },
      3 => %{
        name: "Group Priority",
        description: "Priority level for filter group",
        value_type: :uint8,
        max_length: 1
      },
      4 => %{
        name: "Applied Interfaces",
        description: "Interfaces where filter group is applied",
        value_type: :compound,
        max_length: :unlimited
      }
    }
  end

  # TLV 102: Enhanced Video Quality Assurance Sub-TLVs
  defp enhanced_video_qa_subtlvs do
    %{
      1 => %{
        name: "Video QA Enable",
        description: "Enable enhanced video quality assurance",
        value_type: :uint8,
        max_length: 1,
        enum_values: %{
          0 => "Disabled",
          1 => "Enabled"
        }
      },
      2 => %{
        name: "Video Stream Classification",
        description: "Classification rules for video streams",
        value_type: :compound,
        max_length: :unlimited
      },
      3 => %{
        name: "Quality Metrics Collection",
        description: "Video quality metrics collection settings",
        value_type: :compound,
        max_length: :unlimited
      },
      4 => %{
        name: "Adaptive Bitrate Control",
        description: "Adaptive bitrate control parameters",
        value_type: :compound,
        max_length: :unlimited
      },
      5 => %{
        name: "Video Codec Support",
        description: "Supported video codec types",
        value_type: :uint16,
        max_length: 2,
        enum_values: %{
          1 => "H.264",
          2 => "H.265/HEVC",
          4 => "VP9",
          8 => "AV1",
          16 => "MPEG-4"
        }
      }
    }
  end

  # TLV 103: Dynamic QoS Configuration Sub-TLVs
  defp dynamic_qos_config_subtlvs do
    %{
      1 => %{
        name: "Dynamic QoS Enable",
        description: "Enable dynamic Quality of Service adaptation",
        value_type: :uint8,
        max_length: 1,
        enum_values: %{
          0 => "Disabled",
          1 => "Enabled"
        }
      },
      2 => %{
        name: "QoS Adaptation Algorithm",
        description: "Algorithm used for QoS adaptation",
        value_type: :uint8,
        max_length: 1,
        enum_values: %{
          1 => "Load Based",
          2 => "Latency Based",
          3 => "Application Aware",
          4 => "Machine Learning"
        }
      },
      3 => %{
        name: "Monitoring Interval",
        description: "QoS monitoring interval in seconds",
        value_type: :uint16,
        max_length: 2
      },
      4 => %{
        name: "Adaptation Thresholds",
        description: "Thresholds for QoS adaptation triggers",
        value_type: :compound,
        max_length: :unlimited
      },
      5 => %{
        name: "Service Flow Priority Matrix",
        description: "Priority matrix for service flows",
        value_type: :compound,
        max_length: :unlimited
      }
    }
  end

  # TLV 105: Link Aggregation Configuration Sub-TLVs
  defp link_aggregation_config_subtlvs do
    %{
      1 => %{
        name: "Aggregation Mode",
        description: "Link aggregation operating mode",
        value_type: :uint8,
        max_length: 1,
        enum_values: %{
          1 => "Static LAG",
          2 => "LACP Active",
          3 => "LACP Passive",
          4 => "Load Balance Only"
        }
      },
      2 => %{
        name: "Member Channel List",
        description: "List of channels in aggregation group",
        value_type: :compound,
        max_length: :unlimited
      },
      3 => %{
        name: "Load Balance Algorithm",
        description: "Load balancing algorithm",
        value_type: :uint8,
        max_length: 1,
        enum_values: %{
          1 => "Round Robin",
          2 => "Hash Based",
          3 => "Weighted Distribution",
          4 => "Flow Based"
        }
      },
      4 => %{
        name: "Failover Mode",
        description: "Failover behavior configuration",
        value_type: :uint8,
        max_length: 1,
        enum_values: %{
          1 => "Hot Standby",
          2 => "Load Sharing",
          3 => "Primary/Backup"
        }
      }
    }
  end

  # TLV 106: Multicast Session Rules Sub-TLVs
  defp multicast_session_rules_subtlvs do
    %{
      1 => %{
        name: "Multicast Group Address",
        description: "Multicast group address (IPv4 or IPv6)",
        value_type: :binary,
        max_length: 16
      },
      2 => %{
        name: "Source Address Filter",
        description: "Source address filtering rules",
        value_type: :compound,
        max_length: :unlimited
      },
      3 => %{
        name: "Session Action",
        description: "Action to take for multicast session",
        value_type: :uint8,
        max_length: 1,
        enum_values: %{
          1 => "Allow",
          2 => "Deny",
          3 => "Rate Limit",
          4 => "Mirror"
        }
      },
      4 => %{
        name: "Bandwidth Limit",
        description: "Bandwidth limit for multicast session",
        value_type: :uint32,
        max_length: 4
      },
      5 => %{
        name: "Session Priority",
        description: "Priority level for multicast session",
        value_type: :uint8,
        max_length: 1,
        enum_values: %{
          1 => "Low",
          2 => "Normal",
          3 => "High",
          4 => "Critical"
        }
      }
    }
  end

  # TLV 107: IPv6 Prefix Delegation Sub-TLVs
  defp ipv6_prefix_delegation_subtlvs do
    %{
      1 => %{
        name: "Delegated Prefix",
        description: "IPv6 prefix to be delegated",
        value_type: :ipv6,
        max_length: 16
      },
      2 => %{
        name: "Prefix Length",
        description: "Length of delegated IPv6 prefix",
        value_type: :uint8,
        max_length: 1
      },
      3 => %{
        name: "Delegation Lifetime",
        description: "Lifetime of prefix delegation in seconds",
        value_type: :uint32,
        max_length: 4
      },
      4 => %{
        name: "Delegation Method",
        description: "Method used for prefix delegation",
        value_type: :uint8,
        max_length: 1,
        enum_values: %{
          1 => "DHCPv6-PD",
          2 => "Static Assignment",
          3 => "Router Advertisement",
          4 => "Manual Configuration"
        }
      },
      5 => %{
        name: "Recursive DNS Servers",
        description: "IPv6 addresses of recursive DNS servers",
        value_type: :compound,
        max_length: :unlimited
      }
    }
  end

  # TLV 109: Advanced Encryption Configuration Sub-TLVs
  defp advanced_encryption_config_subtlvs do
    %{
      1 => %{
        name: "Encryption Algorithm",
        description: "Advanced encryption algorithm selection",
        value_type: :uint8,
        max_length: 1,
        enum_values: %{
          1 => "AES-128",
          2 => "AES-256",
          3 => "ChaCha20",
          4 => "AES-GCM",
          5 => "Post-Quantum Crypto"
        }
      },
      2 => %{
        name: "Key Exchange Method",
        description: "Key exchange method for encryption",
        value_type: :uint8,
        max_length: 1,
        enum_values: %{
          1 => "ECDHE",
          2 => "RSA",
          3 => "DH",
          4 => "Post-Quantum KEM"
        }
      },
      3 => %{
        name: "Certificate Chain",
        description: "X.509 certificate chain for authentication",
        value_type: :certificate,
        max_length: 4096
      },
      4 => %{
        name: "Encryption Scope",
        description: "Scope of encryption application",
        value_type: :uint8,
        max_length: 1,
        enum_values: %{
          1 => "Management Traffic Only",
          2 => "Data Traffic Only",
          3 => "All Traffic",
          4 => "Selective Encryption"
        }
      },
      5 => %{
        name: "Perfect Forward Secrecy",
        description: "Enable Perfect Forward Secrecy",
        value_type: :uint8,
        max_length: 1,
        enum_values: %{
          0 => "Disabled",
          1 => "Enabled"
        }
      }
    }
  end

  # TLV 110: Quality Metrics Collection Sub-TLVs
  defp quality_metrics_collection_subtlvs do
    %{
      1 => %{
        name: "Metrics Collection Enable",
        description: "Enable quality metrics collection",
        value_type: :uint8,
        max_length: 1,
        enum_values: %{
          0 => "Disabled",
          1 => "Enabled"
        }
      },
      2 => %{
        name: "Collection Interval",
        description: "Metrics collection interval in seconds",
        value_type: :uint16,
        max_length: 2
      },
      3 => %{
        name: "Metric Types",
        description: "Types of metrics to collect (bitmask)",
        value_type: :uint32,
        max_length: 4,
        enum_values: %{
          1 => "Latency",
          2 => "Jitter",
          4 => "Packet Loss",
          8 => "Throughput",
          16 => "Error Rate",
          32 => "Signal Quality",
          64 => "Buffer Utilization"
        }
      },
      4 => %{
        name: "Reporting Server",
        description: "Server for metrics reporting",
        value_type: :ipv4,
        max_length: 4
      },
      5 => %{
        name: "Reporting Protocol",
        description: "Protocol used for metrics reporting",
        value_type: :uint8,
        max_length: 1,
        enum_values: %{
          1 => "SNMP",
          2 => "HTTP/REST",
          3 => "Syslog",
          4 => "Custom Protocol"
        }
      },
      6 => %{
        name: "Storage Duration",
        description: "Local storage duration for metrics in hours",
        value_type: :uint16,
        max_length: 2
      }
    }
  end
end