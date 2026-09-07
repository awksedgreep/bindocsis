defmodule Bindocsis.SubTlvSpecs do
  @moduledoc """
  Comprehensive sub-TLV specifications for all compound DOCSIS TLVs.

  This module provides detailed specifications for sub-TLVs contained within
  compound TLV types. Each compound TLV can contain nested sub-TLVs that define
  specific parameters for that TLV type.

  Reference: CableLabs CANN-I22-230308 specification.

  ## Supported Compound TLVs

  - **TLV 4**: Class of Service
  - **TLV 5**: Modem Capabilities
  - **TLV 10**: SNMP Write Access Control
  - **TLV 11**: SNMP MIB Object
  - **TLV 17**: Baseline Privacy (BPI+ configuration)
  - **TLV 22**: Upstream Packet Classification
  - **TLV 23**: Downstream Packet Classification
  - **TLV 24**: Upstream Service Flow
  - **TLV 25**: Downstream Service Flow
  - **TLV 26**: Payload Header Suppression (PHS)
  - **TLV 34**: SNMPv3 Kickstart Value
  - **TLV 38**: SNMPv3 Notification Receiver
  - **TLV 41**: Downstream Channel List
  - **TLV 43**: Vendor Specific
  - **TLV 46**: Transmit Channel Configuration
  - **TLV 48**: Receive Channel Profile
  - **TLV 50**: DSID Encodings
  - **TLV 60**: Upstream Drop Packet Classification
  - **TLV 70**: Upstream Aggregate Service Flow
  - **TLV 71**: Downstream Aggregate Service Flow
  - **TLV 202**: eRouter Configuration Encodings (per CM-SP-eRouter Annex B.4),
    including nested TR-069 Management Server (202.2), Vendor Specific (202.43),
    SNMPv1v2c Coexistence (202.53), and SNMPv3 Access View (202.54) encodings
  - And more per CANN-I22...

  Note: TLV 18 (Max Number of CPEs) has no sub-TLVs - it's a simple uint8 value.
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
          {:ok, %{non_neg_integer() => sub_tlv_info()}}
          | {:error, :no_subtlvs | :unknown_tlv | :invalid_context_path}

  # Handle context path for nested subtlvs
  def get_subtlv_specs(context_path) when is_list(context_path) do
    case context_path do
      # MPLS Service Multiplexing Value context (TLV 22.43.5.2.4)
      # Per CANN-I22: TLV 22=Upstream Classifier, TLV 23=Downstream Classifier
      [parent, 43, 5, 2, 4] when parent in [22, 23] ->
        {:ok, mpls_service_multiplexing_value_subtlvs()}

      # Service Multiplexing context (TLV 22.43.5.2)
      [parent, 43, 5, 2] when parent in [22, 23] ->
        {:ok, service_multiplexing_subtlvs()}

      # Special handling for L2VPN Encoding nested subtlvs
      # Only when we're inside 43.5 (L2VPN Encoding within L2VPN subtlv)
      [parent, 43, 5 | _rest] when parent in [22, 23] ->
        {:ok, l2vpn_encoding_nested_subtlvs()}

      # eRouter (TLV 202) nested contexts per CM-SP-eRouter / ETSI ES 203 386 Annex B.4
      # TLV 202.2 = TR-069 Management Server Encoding (B.4.3)
      [202, 2] ->
        {:ok, erouter_tr069_mgmt_server_subtlvs()}

      # TLV 202.43 = eRouter Vendor Specific Information (B.4.7)
      [202, 43] ->
        {:ok, erouter_vendor_specific_subtlvs()}

      # TLV 202.53.2 = SNMPv1v2c Transport Address Access (B.4.5.2)
      [202, 53, 2] ->
        {:ok, erouter_snmp_transport_address_access_subtlvs()}

      # TLV 202.53 = SNMPv1v2c Coexistence Configuration (B.4.5)
      [202, 53] ->
        {:ok, erouter_snmpv1v2c_coexistence_subtlvs()}

      # TLV 202.54 = SNMPv3 Access View Configuration (B.4.6)
      [202, 54] ->
        {:ok, erouter_snmpv3_access_view_subtlvs()}

      # Service Flow Error Encodings (5) and QoS Parameter Set (6) should not
      # reuse global TLV 5/6 specs when nested under service-flow parents.
      # TLV 24/25 = Service Flows, TLV 70/71 = Aggregate Service Flows
      # Treat these nested contexts as having no further structured sub-TLV
      # specs so their values remain opaque (typically hex) instead of
      # fabricating bogus "SubTLV 0" children.
      [parent, sub] when parent in [24, 25, 70, 71] and sub in [5, 6] ->
        {:error, :unknown_tlv}

      # Default to the last element in the path for standard subtlv lookup
      path when path != [] ->
        get_subtlv_specs(List.last(path))

      _ ->
        {:error, :invalid_context_path}
    end
  end

  def get_subtlv_specs(parent_tlv_type) when is_integer(parent_tlv_type) do
    # Per CANN-I22-230308 specification
    case parent_tlv_type do
      4 -> {:ok, class_of_service_subtlvs()}
      5 -> {:ok, modem_capabilities_subtlvs()}
      10 -> {:ok, snmp_write_access_subtlvs()}
      11 -> {:ok, snmp_mib_object_subtlvs()}
      # TLV 17 = Baseline Privacy (NOT service flow!)
      17 -> {:ok, baseline_privacy_subtlvs()}
      # TLV 18 = Max Number of CPEs - has NO subtlvs (simple uint8)
      # TLV 22 = Upstream Packet Classification
      22 -> {:ok, upstream_packet_classification_subtlvs()}
      # TLV 23 = Downstream Packet Classification
      23 -> {:ok, downstream_packet_classification_subtlvs()}
      # TLV 24 = UPSTREAM Service Flow (per CANN-I22)
      24 -> {:ok, upstream_service_flow_subtlvs()}
      # TLV 25 = DOWNSTREAM Service Flow (per CANN-I22)
      25 -> {:ok, downstream_service_flow_subtlvs()}
      # TLV 26 = Payload Header Suppression
      26 -> {:ok, phs_rule_subtlvs()}
      # TLV 30 = Baseline Privacy Configuration Settings
      30 -> {:ok, baseline_privacy_config_subtlvs()}
      # TLV 31 = Baseline Privacy Key Management Settings
      31 -> {:ok, baseline_privacy_key_mgmt_subtlvs()}
      34 -> {:ok, snmpv3_kickstart_subtlvs()}
      # TLV 35 = Subscriber Management Control
      35 -> {:ok, subscriber_mgmt_control_subtlvs()}
      # TLV 36 = Subscriber Management CPE IPv4 List
      36 -> {:ok, subscriber_mgmt_cpe_ip_subtlvs()}
      # TLV 37 = Subscriber Management Filter Groups
      37 -> {:ok, subscriber_mgmt_filter_groups_subtlvs()}
      38 -> {:ok, snmpv3_notification_receiver_subtlvs()}
      41 -> {:ok, downstream_channel_list_subtlvs()}
      43 -> {:ok, vendor_specific_tlv43_subtlvs()}
      46 -> {:ok, transmit_channel_config_subtlvs()}
      48 -> {:ok, receive_channel_profile_subtlvs()}
      50 -> {:ok, dsid_encodings_subtlvs()}
      # TLV 60 = Upstream Drop Packet Classification (uses IPv6 classification sub-TLVs)
      60 -> {:ok, ipv6_packet_classification_subtlvs()}
      # TLV 70 = Upstream Aggregate Service Flow (per CANN-I22)
      70 -> {:ok, aggregate_service_flow_subtlvs()}
      # TLV 71 = Downstream Aggregate Service Flow (per CANN-I22)
      71 -> {:ok, aggregate_service_flow_subtlvs()}
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

      error ->
        error
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
      parent_tlv_type in 62..85 -> {:ok, extended_compound_subtlvs(parent_tlv_type)}
      parent_tlv_type in 86..199 -> {:ok, extended_tlv_subtlvs(parent_tlv_type)}
      # TLV 202 = eRouter Configuration Encodings per CM-SP-eRouter Annex B.4
      parent_tlv_type == 202 -> {:ok, erouter_config_subtlvs()}
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
      },
      7 => %{
        name: "Privacy Enable",
        description: "Class of Service privacy enable (BPI)",
        value_type: :uint8,
        max_length: 1,
        enum_values: %{0 => "Disabled", 1 => "Enabled"}
      }
    }
  end

  # Placeholder functions for other sub-TLV specifications
  # These will be implemented in subsequent phases

  # TLV 5: Modem Capabilities Sub-TLVs - Per CANN-I22-230308 Section 11.1.1
  defp modem_capabilities_subtlvs do
    %{
      # DOCSIS 1.1 sub-TLVs (5.1-5.12)
      1 => %{
        name: "Concatenation Support",
        description: "Cable modem concatenation capability",
        value_type: :uint8,
        max_length: 1,
        enum_values: %{0 => "Not supported", 1 => "Supported"}
      },
      2 => %{
        name: "DOCSIS Version",
        description: "DOCSIS version supported by the cable modem",
        value_type: :uint8,
        max_length: 1,
        enum_values: %{
          0 => "DOCSIS 1.0",
          1 => "DOCSIS 1.1",
          2 => "DOCSIS 2.0",
          3 => "DOCSIS 3.0",
          4 => "DOCSIS 3.1",
          5 => "DOCSIS 4.0"
        }
      },
      3 => %{
        name: "Fragmentation Support",
        description: "Cable modem fragmentation capability",
        value_type: :uint8,
        max_length: 1,
        enum_values: %{0 => "Not supported", 1 => "Supported"}
      },
      4 => %{
        name: "Payload Header Suppression Support",
        description: "Payload Header Suppression (PHS) support",
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
        name: "Downstream SAID Support",
        description: "Downstream Security Association ID support",
        value_type: :uint8,
        max_length: 1,
        enum_values: nil
      },
      8 => %{
        name: "Upstream Service Flow Support",
        description: "Number of upstream service flows supported",
        value_type: :uint8,
        max_length: 1,
        enum_values: nil
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
        description: "Transmit pre-equalizer taps per modulation interval",
        value_type: :uint8,
        max_length: 1,
        enum_values: nil
      },
      11 => %{
        name: "Number of Transmit Pre-Equalizer Taps",
        description: "Total number of transmit pre-equalizer taps",
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
      # DOCSIS 2.0 sub-TLVs (5.13-5.16)
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
        value_type: :binary,
        max_length: 4,
        enum_values: nil
      },
      # L2VPN sub-TLVs (5.17-5.19)
      17 => %{
        name: "L2VPN Capability",
        description: "Layer 2 VPN capability",
        value_type: :uint8,
        max_length: 1,
        enum_values: nil
      },
      18 => %{
        name: "L2VPN eSAFE Host Capability",
        description: "L2VPN eSAFE host capability",
        value_type: :binary,
        max_length: :unlimited,
        enum_values: nil
      },
      19 => %{
        name: "Downstream Unencrypted Traffic (DUT) Filtering",
        description: "DUT filtering capability",
        value_type: :uint8,
        max_length: 1,
        enum_values: nil
      },
      # DOCSIS 3.0 sub-TLVs (5.20-5.41)
      20 => %{
        name: "Upstream Frequency Range Support",
        description: "Upstream frequency range support",
        value_type: :uint8,
        max_length: 1,
        enum_values: %{0 => "Standard (5-42 MHz)", 1 => "Extended (5-85 MHz)"}
      },
      21 => %{
        name: "Upstream SC-QAM Symbol Rate Support",
        description: "Upstream SC-QAM symbol rate support",
        value_type: :uint8,
        max_length: 1,
        enum_values: nil
      },
      22 => %{
        name: "Selectable Active Code Mode 2 Support",
        description: "S-CDMA selectable active code mode 2 support",
        value_type: :uint8,
        max_length: 1,
        enum_values: %{0 => "Not supported", 1 => "Supported"}
      },
      23 => %{
        name: "Code Hopping Mode 2 Support",
        description: "S-CDMA code hopping mode 2 support",
        value_type: :uint8,
        max_length: 1,
        enum_values: %{0 => "Not supported", 1 => "Supported"}
      },
      24 => %{
        name: "Multiple Transmit SC-QAM Channel Support",
        description: "Number of SC-QAM transmit channels supported",
        value_type: :uint8,
        max_length: 1,
        enum_values: nil
      },
      25 => %{
        name: "5.12 Msps Upstream Transmit SC-QAM Channel Support",
        description: "Number of 5.12 Msps upstream transmit channels",
        value_type: :uint8,
        max_length: 1,
        enum_values: nil
      },
      26 => %{
        name: "2.56 Msps Upstream Transmit SC-QAM Channel Support",
        description: "Number of 2.56 Msps upstream transmit channels",
        value_type: :uint8,
        max_length: 1,
        enum_values: nil
      },
      27 => %{
        name: "Total SID Cluster Support",
        description: "Total number of SID clusters supported",
        value_type: :uint8,
        max_length: 1,
        enum_values: nil
      },
      28 => %{
        name: "SID Clusters per Service Flow Support",
        description: "SID clusters per service flow supported",
        value_type: :uint8,
        max_length: 1,
        enum_values: nil
      },
      29 => %{
        name: "Multiple Receive SC-QAM Channel Support",
        description: "Number of SC-QAM receive channels supported",
        value_type: :uint8,
        max_length: 1,
        enum_values: nil
      },
      30 => %{
        name: "Total Downstream Service ID (DSID) Support",
        description: "Total downstream service IDs supported",
        value_type: :uint8,
        max_length: 1,
        enum_values: nil
      },
      31 => %{
        name: "Resequencing Downstream Service ID (DSID) Support",
        description: "Resequencing DSIDs supported",
        value_type: :uint8,
        max_length: 1,
        enum_values: nil
      },
      32 => %{
        name: "Multicast Downstream Service ID (DSID) Support",
        description: "Multicast DSIDs supported",
        value_type: :uint8,
        max_length: 1,
        enum_values: nil
      },
      33 => %{
        name: "Multicast DSID Forwarding",
        description: "Multicast DSID forwarding capability",
        value_type: :uint8,
        max_length: 1,
        enum_values: %{0 => "Not supported", 1 => "Supported"}
      },
      34 => %{
        name: "Frame Control Type Forwarding Capability",
        description: "Frame control type forwarding capability",
        value_type: :uint8,
        max_length: 1,
        enum_values: %{0 => "Not supported", 1 => "Supported"}
      },
      35 => %{
        name: "DPV Capability",
        description: "DOCSIS Path Verify capability",
        value_type: :uint8,
        max_length: 1,
        enum_values: %{0 => "Not supported", 1 => "Supported"}
      },
      36 => %{
        name: "Unsolicited Grant Service/Upstream Service Flow Support",
        description: "UGS/USF support",
        value_type: :uint8,
        max_length: 1,
        enum_values: %{0 => "Not supported", 1 => "Supported"}
      },
      37 => %{
        name: "MAP and UCD Receipt Support",
        description: "MAP and UCD receipt support",
        value_type: :uint8,
        max_length: 1,
        enum_values: %{0 => "Not supported", 1 => "Supported"}
      },
      38 => %{
        name: "Upstream Drop Classifier Support",
        description: "Upstream drop classifier support",
        value_type: :uint16,
        max_length: 2,
        enum_values: nil
      },
      39 => %{
        name: "IPv6 Support",
        description: "IPv6 capability support",
        value_type: :uint8,
        max_length: 1,
        enum_values: %{0 => "Not supported", 1 => "Supported"}
      },
      40 => %{
        name: "Extended Upstream Transmit Power Capability",
        description: "Extended upstream transmit power capability",
        value_type: :uint8,
        max_length: 1,
        enum_values: nil
      },
      41 => %{
        name: "Optional 802.1ad, 802.1ah, MPLS Classification Support",
        description: "Optional 802.1ad/802.1ah/MPLS classification support",
        value_type: :binary,
        max_length: :unlimited,
        enum_values: nil
      },
      # DPoE sub-TLVs (5.42)
      42 => %{
        name: "D-ONU Capabilities",
        description: "D-ONU capabilities (compound)",
        value_type: :compound,
        max_length: :unlimited,
        enum_values: nil
      },
      # Reserved (5.43)
      43 => %{
        name: "Reserved",
        description: "Reserved",
        value_type: :binary,
        max_length: :unlimited,
        enum_values: nil
      },
      # DOCSIS 3.0/3.1 sub-TLVs (5.44-5.62)
      44 => %{
        name: "Energy Management Capabilities",
        description: "Energy management capabilities",
        value_type: :binary,
        max_length: :unlimited,
        enum_values: nil
      },
      45 => %{
        name: "C-DOCSIS Capability Encoding",
        description: "C-DOCSIS (China DOCSIS) capability",
        value_type: :uint8,
        max_length: 1,
        enum_values: nil
      },
      46 => %{
        name: "CM-STATUS-ACK",
        description: "CM status acknowledgment support",
        value_type: :uint8,
        max_length: 1,
        enum_values: %{0 => "Not supported", 1 => "Supported"}
      },
      47 => %{
        name: "Energy Management Preferences",
        description: "Energy management preferences",
        value_type: :binary,
        max_length: :unlimited,
        enum_values: nil
      },
      48 => %{
        name: "Extended Packet Length Support Capability",
        description: "Extended packet length support",
        value_type: :uint8,
        max_length: 1,
        enum_values: nil
      },
      49 => %{
        name: "Multiple Receive OFDM Channel Support",
        description: "Number of OFDM receive channels supported",
        value_type: :uint8,
        max_length: 1,
        enum_values: nil
      },
      50 => %{
        name: "Multiple Transmit OFDMA Channel Support",
        description: "Number of OFDMA transmit channels supported",
        value_type: :uint8,
        max_length: 1,
        enum_values: nil
      },
      51 => %{
        name: "Downstream OFDM Profile Support",
        description: "Downstream OFDM profile support",
        value_type: :binary,
        max_length: :unlimited,
        enum_values: nil
      },
      52 => %{
        name: "Downstream OFDM Channel Subcarrier QAM Modulation Support",
        description: "DS OFDM subcarrier QAM modulation support",
        value_type: :binary,
        max_length: :unlimited,
        enum_values: nil
      },
      53 => %{
        name: "Upstream OFDMA Channel Subcarrier QAM Modulation Support",
        description: "US OFDMA subcarrier QAM modulation support",
        value_type: :binary,
        max_length: :unlimited,
        enum_values: nil
      },
      54 => %{
        name: "Downstream Lower Band Edge Configuration",
        description: "DS lower band edge configuration",
        value_type: :uint8,
        max_length: 1,
        enum_values: nil
      },
      55 => %{
        name: "Downstream Upper Band Edge Configuration",
        description: "DS upper band edge configuration",
        value_type: :uint8,
        max_length: 1,
        enum_values: nil
      },
      56 => %{
        name: "Diplexer Upstream Upper Band Edge Configuration",
        description: "Diplexer US upper band edge configuration",
        value_type: :uint8,
        max_length: 1,
        enum_values: nil
      },
      57 => %{
        name: "DOCSIS Time Protocol Mode",
        description: "DTP mode support",
        value_type: :uint8,
        max_length: 1,
        enum_values: nil
      },
      58 => %{
        name: "DOCSIS Time Protocol Performance Support",
        description: "DTP performance support",
        value_type: :uint8,
        max_length: 1,
        enum_values: nil
      },
      59 => %{
        name: "Pmax",
        description: "Maximum transmit power",
        value_type: :uint16,
        max_length: 2,
        enum_values: nil
      },
      60 => %{
        name: "Diplexer Downstream Lower Band Edge Options",
        description: "Diplexer DS lower band edge options",
        value_type: :binary,
        max_length: :unlimited,
        enum_values: nil
      },
      61 => %{
        name: "Diplexer Downstream Upper Band Edge Options",
        description: "Diplexer DS upper band edge options",
        value_type: :binary,
        max_length: :unlimited,
        enum_values: nil
      },
      62 => %{
        name: "Diplexer Upstream Upper Band Edge Options",
        description: "Diplexer US upper band edge options",
        value_type: :binary,
        max_length: :unlimited,
        enum_values: nil
      },
      # DOCSIS 4.0 FDX sub-TLVs (5.63-5.85)
      63 => %{
        name: "Advanced Band Plan Capability",
        description: "Advanced band plan capability",
        value_type: :binary,
        max_length: :unlimited,
        enum_values: nil
      },
      64 => %{
        name: "FDX DS State Lock (Deprecated)",
        description: "FDX DS state lock (deprecated)",
        value_type: :uint8,
        max_length: 1,
        enum_values: nil
      },
      65 => %{
        name: "FDX Switching Software Timing Uncertainty",
        description: "FDX switching software timing uncertainty",
        value_type: :uint8,
        max_length: 1,
        enum_values: nil
      },
      66 => %{
        name: "FDX DS to US Switching Time",
        description: "FDX DS to US switching time",
        value_type: :uint8,
        max_length: 1,
        enum_values: nil
      },
      67 => %{
        name: "FDX US to DS Switching Time - CWT",
        description: "FDX US to DS switching time CWT",
        value_type: :uint8,
        max_length: 1,
        enum_values: nil
      },
      68 => %{
        name: "RxMER Measurement Convergence Time",
        description: "RxMER measurement convergence time",
        value_type: :uint8,
        max_length: 1,
        enum_values: nil
      },
      69 => %{
        name: "t-ds-reacquisition Capability CWT",
        description: "DS reacquisition capability CWT",
        value_type: :uint8,
        max_length: 1,
        enum_values: nil
      },
      70 => %{
        name: "Simultaneous Data Transmission Capability",
        description: "Simultaneous data transmission capability",
        value_type: :uint8,
        max_length: 1,
        enum_values: nil
      },
      71 => %{
        name: "Extended Service Flow SID Cluster Assignments Support",
        description: "Extended SF SID cluster assignments support",
        value_type: :uint8,
        max_length: 1,
        enum_values: nil
      },
      72 => %{
        name: "Echo Cancelling RBA Sub-band Direction Sets Supported",
        description: "Echo cancelling RBA sub-band direction sets",
        value_type: :uint8,
        max_length: 1,
        enum_values: nil
      },
      73 => %{
        name: "Low Latency Support",
        description: "Low latency support",
        value_type: :uint8,
        max_length: 1,
        enum_values: nil
      },
      74 => %{
        name: "Absolute Queue-Depth Request Support",
        description: "Absolute queue-depth request support",
        value_type: :uint8,
        max_length: 1,
        enum_values: nil
      },
      75 => %{
        name: "Distributed HQoS Support",
        description: "Distributed HQoS support",
        value_type: :uint8,
        max_length: 1,
        enum_values: nil
      },
      76 => %{
        name: "Advanced Downstream Lower Band Edge Configuration",
        description: "Advanced DS lower band edge configuration",
        value_type: :binary,
        max_length: :unlimited,
        enum_values: nil
      },
      77 => %{
        name: "Advanced Downstream Upper Band Edge Configuration",
        description: "Advanced DS upper band edge configuration",
        value_type: :binary,
        max_length: :unlimited,
        enum_values: nil
      },
      78 => %{
        name: "Advanced Diplexer Upstream Upper Band Edge Configuration",
        description: "Advanced diplexer US upper band edge configuration",
        value_type: :binary,
        max_length: :unlimited,
        enum_values: nil
      },
      79 => %{
        name: "Advanced Diplexer Downstream Lower Band Edge Options List",
        description: "Advanced diplexer DS lower band edge options",
        value_type: :binary,
        max_length: :unlimited,
        enum_values: nil
      },
      80 => %{
        name: "Advanced Diplexer Downstream Upper Band Edge Options List",
        description: "Advanced diplexer DS upper band edge options",
        value_type: :binary,
        max_length: :unlimited,
        enum_values: nil
      },
      81 => %{
        name: "Advanced Diplexer Upstream Upper Band Edge Options List",
        description: "Advanced diplexer US upper band edge options",
        value_type: :binary,
        max_length: :unlimited,
        enum_values: nil
      },
      82 => %{
        name: "Extended Power Options",
        description: "Extended power options",
        value_type: :binary,
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

  # =============================================================================
  # TLV 22: Upstream Packet Classification Sub-TLVs
  # TLV 23: Downstream Packet Classification Sub-TLVs
  # TLV 60: Upstream Drop Classifier Sub-TLVs
  # Per CANN-I22-230308 Section 11.1.4
  # =============================================================================
  defp upstream_packet_classification_subtlvs do
    packet_classification_subtlvs()
  end

  defp downstream_packet_classification_subtlvs do
    packet_classification_subtlvs()
  end

  # Common packet classification sub-TLVs used by TLV 22/23/60
  # Per CANN-I22-230308 Section 11.1.4
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
        name: "Classifier Identifier",
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
        name: "Service Flow Identifier",
        description: "Service flow identifier assigned by CMTS",
        value_type: :uint32,
        max_length: 4,
        enum_values: nil
      },
      5 => %{
        name: "Rule Priority",
        description: "Priority for classifier matching (0-255)",
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
        name: "Classifier Error Encodings",
        description: "Classifier error encodings (compound)",
        value_type: :compound,
        max_length: :unlimited,
        enum_values: nil
      },
      9 => %{
        name: "IPv4 Packet Classification Encodings",
        description: "IPv4/TCP/UDP packet classification rules (compound)",
        value_type: :compound,
        max_length: :unlimited,
        enum_values: nil
      },
      10 => %{
        name: "Ethernet LLC Packet Classification Encodings",
        description: "Ethernet LLC packet classification rules (compound)",
        value_type: :compound,
        max_length: :unlimited,
        enum_values: nil
      },
      11 => %{
        name: "IEEE 802.1P/Q Packet Classification Encodings",
        description: "IEEE 802.1P/Q VLAN packet classification (compound)",
        value_type: :compound,
        max_length: :unlimited,
        enum_values: nil
      },
      12 => %{
        name: "IPv6 Packet Classification Encodings",
        description: "IPv6 packet classification rules (compound)",
        value_type: :compound,
        max_length: :unlimited,
        enum_values: nil
      },
      13 => %{
        name: "CM Interface Mask Encoding",
        description: "Cable Modem Interface Mask (CMIM) encoding",
        value_type: :binary,
        max_length: 4,
        enum_values: nil
      },
      14 => %{
        name: "IEEE 802.1ad S-VLAN Packet Classification Encodings",
        description: "IEEE 802.1ad Service VLAN classification (compound)",
        value_type: :compound,
        max_length: :unlimited,
        enum_values: nil
      },
      15 => %{
        name: "IEEE 802.1ah I-TAG Packet Classification Encodings",
        description: "IEEE 802.1ah I-TAG classification (compound)",
        value_type: :compound,
        max_length: :unlimited,
        enum_values: nil
      },
      43 => %{
        name: "Vendor Specific Classifier Parameters",
        description: "Vendor-specific classifier parameters",
        value_type: :vendor,
        max_length: :unlimited,
        enum_values: nil
      }
    }
  end

  # =============================================================================
  # TLV 17: Baseline Privacy (BPI+) Sub-TLVs
  # Per CANN-I22-230308 Section 11.1
  # =============================================================================
  defp baseline_privacy_subtlvs do
    %{
      1 => %{
        name: "Authorize Wait Timeout",
        description: "BPI+ authorize wait timeout in seconds",
        value_type: :uint32,
        max_length: 4,
        enum_values: nil
      },
      2 => %{
        name: "Reauthorize Wait Timeout",
        description: "BPI+ reauthorize wait timeout in seconds",
        value_type: :uint32,
        max_length: 4,
        enum_values: nil
      },
      3 => %{
        name: "Authorization Grace Time",
        description: "BPI+ authorization grace time in seconds",
        value_type: :uint32,
        max_length: 4,
        enum_values: nil
      },
      4 => %{
        name: "Operational Wait Timeout",
        description: "BPI+ operational wait timeout in seconds",
        value_type: :uint32,
        max_length: 4,
        enum_values: nil
      },
      5 => %{
        name: "Rekey Wait Timeout",
        description: "BPI+ rekey wait timeout in seconds",
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
        name: "Authorize Reject Wait Timeout",
        description: "BPI+ authorize reject wait timeout in seconds",
        value_type: :uint32,
        max_length: 4,
        enum_values: nil
      },
      8 => %{
        name: "SA Map Wait Timeout",
        description: "Security Association map wait timeout in seconds",
        value_type: :uint32,
        max_length: 4,
        enum_values: nil
      },
      9 => %{
        name: "SA Map Max Retries",
        description: "Maximum SA map retries",
        value_type: :uint32,
        max_length: 4,
        enum_values: nil
      }
    }
  end

  # =============================================================================
  # TLV 24: Upstream Service Flow Sub-TLVs
  # TLV 70: Upstream Aggregate Service Flow Sub-TLVs
  # Per CANN-I22-230308 Section 11.1.3
  # =============================================================================
  defp upstream_service_flow_subtlvs do
    Map.merge(common_service_flow_subtlvs(), %{
      # Upstream-specific sub-TLVs per CANN-I22 Section 11.1.3.1
      14 => %{
        name: "Maximum Concatenated Burst",
        description: "Maximum concatenated burst in bytes (upstream only)",
        value_type: :uint16,
        max_length: 2,
        enum_values: nil
      },
      15 => %{
        name: "Service Flow Scheduling Type",
        description: "Scheduling type for upstream service flow",
        value_type: :uint8,
        max_length: 1,
        enum_values: %{
          0 => "Reserved",
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
        description: "Request and transmission policy bitmask",
        value_type: :uint32,
        max_length: 4,
        enum_values: nil
      },
      17 => %{
        name: "Nominal Polling Interval",
        description: "Nominal polling interval in microseconds",
        value_type: :uint32,
        max_length: 4,
        enum_values: nil
      },
      18 => %{
        name: "Tolerated Poll Jitter",
        description: "Tolerated poll jitter in microseconds",
        value_type: :uint32,
        max_length: 4,
        enum_values: nil
      },
      19 => %{
        name: "Unsolicited Grant Size",
        description: "Unsolicited grant size in bytes",
        value_type: :uint16,
        max_length: 2,
        enum_values: nil
      },
      20 => %{
        name: "Nominal Grant Interval",
        description: "Nominal grant interval in microseconds",
        value_type: :uint32,
        max_length: 4,
        enum_values: nil
      },
      21 => %{
        name: "Tolerated Grant Jitter",
        description: "Tolerated grant jitter in microseconds",
        value_type: :uint32,
        max_length: 4,
        enum_values: nil
      },
      22 => %{
        name: "Grants Per Interval",
        description: "Number of grants per interval",
        value_type: :uint8,
        max_length: 1,
        enum_values: nil
      },
      24 => %{
        name: "Unsolicited Grant Time Reference",
        description: "Time reference for unsolicited grants",
        value_type: :uint32,
        max_length: 4,
        enum_values: nil
      },
      25 => %{
        name: "Multiplier to Contention Request Backoff Window",
        description: "Multiplier for contention request backoff",
        value_type: :uint8,
        max_length: 1,
        enum_values: nil
      },
      26 => %{
        name: "Multiplier to Number of Bytes Requested",
        description: "Multiplier for bytes requested",
        value_type: :uint8,
        max_length: 1,
        enum_values: nil
      },
      40 => %{
        name: "AQM Encodings",
        description: "Active Queue Management encodings (compound)",
        value_type: :compound,
        max_length: :unlimited,
        enum_values: nil
      },
      41 => %{
        name: "Latency Histogram Encodings",
        description: "Latency histogram configuration",
        value_type: :compound,
        max_length: :unlimited,
        enum_values: nil
      },
      43 => %{
        name: "Vendor Specific QoS Parameters",
        description: "Vendor-specific QoS parameters",
        value_type: :vendor,
        max_length: :unlimited,
        enum_values: nil
      },
      44 => %{
        name: "Guaranteed Grant Interval",
        description: "Guaranteed grant interval (GGI) in microseconds",
        value_type: :uint32,
        max_length: 4,
        enum_values: nil
      }
    })
  end

  # =============================================================================
  # TLV 25: Downstream Service Flow Sub-TLVs
  # TLV 71: Downstream Aggregate Service Flow Sub-TLVs
  # Per CANN-I22-230308 Section 11.1.3
  # =============================================================================
  defp downstream_service_flow_subtlvs do
    Map.merge(common_service_flow_subtlvs(), %{
      # Downstream-specific sub-TLVs per CANN-I22 Section 11.1.3.2
      14 => %{
        name: "Maximum Downstream Latency",
        description: "Maximum downstream latency in microseconds",
        value_type: :uint32,
        max_length: 4,
        enum_values: nil
      },
      15 => %{
        name: "Reserved",
        description: "Reserved for downstream service flow",
        value_type: :binary,
        max_length: :unlimited,
        enum_values: nil
      },
      17 => %{
        name: "Downstream Resequencing",
        description: "Downstream resequencing configuration",
        value_type: :compound,
        max_length: :unlimited,
        enum_values: nil
      }
    })
  end

  # Common sub-TLVs shared by TLV 24/25/70/71 (Service Flows)
  # Per CANN-I22-230308 Section 11.1.3
  defp common_service_flow_subtlvs do
    %{
      1 => %{
        name: "Service Flow Reference",
        description: "Unique reference for this service flow",
        value_type: :uint16,
        max_length: 2,
        enum_values: nil
      },
      2 => %{
        name: "Service Flow Identifier",
        description: "Service flow identifier assigned by CMTS",
        value_type: :uint32,
        max_length: 4,
        enum_values: nil
      },
      3 => %{
        name: "Service Identifier",
        description: "Service identifier (SID)",
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
        name: "Service Flow Error Encoding",
        description: "Error encoding for service flow (compound)",
        value_type: :compound,
        max_length: :unlimited,
        enum_values: nil
      },
      6 => %{
        name: "QoS Parameter Set Type",
        description: "Type of QoS parameter set",
        value_type: :uint8,
        max_length: 1,
        enum_values: %{
          0 => "Provisioned QoS Set",
          1 => "Admitted QoS Set",
          2 => "Active QoS Set",
          7 => "Provisioned+Admitted+Active"
        }
      },
      7 => %{
        name: "Traffic Priority",
        description: "Traffic priority (0-7, 7 is highest)",
        value_type: :uint8,
        max_length: 1,
        enum_values: nil
      },
      8 => %{
        name: "Maximum Sustained Traffic Rate",
        description: "Maximum sustained rate in bits per second",
        value_type: :uint32,
        max_length: 4,
        enum_values: nil
      },
      9 => %{
        name: "Maximum Traffic Burst",
        description: "Maximum traffic burst in bytes",
        value_type: :uint32,
        max_length: 4,
        enum_values: nil
      },
      10 => %{
        name: "Minimum Reserved Traffic Rate",
        description: "Minimum reserved rate in bits per second",
        value_type: :uint32,
        max_length: 4,
        enum_values: nil
      },
      11 => %{
        name: "Assumed Minimum Reserved Rate Packet Size",
        description: "Assumed minimum reserved rate packet size in bytes",
        value_type: :uint16,
        max_length: 2,
        enum_values: nil
      },
      12 => %{
        name: "Timeout for Active QoS Parameters",
        description: "Timeout for active QoS parameters in seconds",
        value_type: :uint16,
        max_length: 2,
        enum_values: nil
      },
      13 => %{
        name: "Timeout for Admitted QoS Parameters",
        description: "Timeout for admitted QoS parameters in seconds",
        value_type: :uint16,
        max_length: 2,
        enum_values: nil
      },
      23 => %{
        name: "IP ToS Overwrite",
        description: "IP Type of Service (DSCP) overwrite value",
        value_type: :uint16,
        max_length: 2,
        enum_values: nil
      },
      27 => %{
        name: "Peak Traffic Rate",
        description: "Peak traffic rate in bits per second",
        value_type: :uint32,
        max_length: 4,
        enum_values: nil
      },
      31 => %{
        name: "Service Flow Required Attribute Mask",
        description: "Required attribute mask for service flow",
        value_type: :binary,
        max_length: 4,
        enum_values: nil
      },
      32 => %{
        name: "Service Flow Forbidden Attribute Mask",
        description: "Forbidden attribute mask for service flow",
        value_type: :binary,
        max_length: 4,
        enum_values: nil
      },
      33 => %{
        name: "Service Flow Attribute Aggregation Rule Mask",
        description: "Attribute aggregation rule mask",
        value_type: :binary,
        max_length: 4,
        enum_values: nil
      },
      34 => %{
        name: "Application Identifier",
        description: "Application identifier for the service flow",
        value_type: :uint16,
        max_length: 2,
        enum_values: nil
      },
      35 => %{
        name: "Buffer Control",
        description: "Buffer control encoding (compound)",
        value_type: :compound,
        max_length: :unlimited,
        enum_values: nil
      },
      36 => %{
        name: "Aggregate Service Flow Reference",
        description: "Reference to aggregate service flow",
        value_type: :uint16,
        max_length: 2,
        enum_values: nil
      },
      37 => %{
        name: "Metro Ethernet Service Profile Reference",
        description: "MESP reference for service flow",
        value_type: :uint8,
        max_length: 1,
        enum_values: nil
      },
      38 => %{
        name: "Serving Group Name",
        description: "Name of the serving group",
        value_type: :string,
        max_length: 16,
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
        # Changed from :uint8 - these contain nested subtlvs
        value_type: :compound,
        max_length: :unlimited,
        enum_values: nil
      },
      2 => %{
        name: "Internet Access",
        description: "Internet access permission",
        # Changed from :uint8 - these contain nested subtlvs
        value_type: :compound,
        max_length: :unlimited,
        enum_values: nil
      },
      3 => %{
        name: "CPE Access",
        description: "CPE access permission",
        # Changed from :uint8 - these contain nested subtlvs
        value_type: :compound,
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

  # =============================================================================
  # TLV 41: Downstream Channel List Sub-TLVs
  # Per CANN-I22-230308 Section 11.1.2.3
  # =============================================================================
  defp downstream_channel_list_subtlvs do
    %{
      1 => %{
        name: "Single Downstream Channel",
        description: "Single downstream channel specification (compound)",
        value_type: :compound,
        max_length: :unlimited,
        enum_values: nil
      },
      2 => %{
        name: "DS Channel Range",
        description: "Downstream channel range specification (compound)",
        value_type: :compound,
        max_length: :unlimited,
        enum_values: nil
      },
      3 => %{
        name: "Default Scanning Timeout",
        description: "Default scanning timeout in seconds",
        value_type: :uint16,
        max_length: 2,
        enum_values: nil
      }
    }
  end

  # TLV 43: Vendor Specific / DOCSIS Extension Field Sub-TLVs
  # Per MULPI Annex C.1.1.18.1 - Complex nested structure
  # Note: Sub-TLV 43.5 (L2VPN Encoding) has its own deeply nested sub-TLVs (43.5.x)
  defp vendor_specific_tlv43_subtlvs do
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
        name: "CM Ranging Class ID Extension",
        description: "Cable modem ranging class ID extension",
        value_type: :uint32,
        max_length: 4,
        enum_values: nil
      },
      5 => %{
        name: "L2VPN Encoding",
        description: "Layer 2 VPN encoding configuration (contains nested 43.5.x sub-TLVs per CANN-I22 Section 11.1.2.1)",
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
        # Changed from :compound - actual data shows this is binary, not subtlvs
        value_type: :binary,
        max_length: :unlimited,
        enum_values: nil
      },
      11 => %{
        name: "IP Multicast Leave Authorization",
        description: "IP multicast leave authorization encoding",
        # Changed from :compound - likely same issue as TLV 10
        value_type: :binary,
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

  # =============================================================================
  # TLV 46: Transmit Channel Configuration Sub-TLVs
  # Per CANN-I22-230308
  # =============================================================================
  defp transmit_channel_config_subtlvs do
    %{
      1 => %{
        name: "Configuration Change Count",
        description: "Configuration change count",
        value_type: :uint8,
        max_length: 1,
        enum_values: nil
      },
      2 => %{
        name: "Ranging SID",
        description: "Service ID for ranging",
        value_type: :uint16,
        max_length: 2,
        enum_values: nil
      },
      3 => %{
        name: "US Channel Action",
        description: "Upstream channel action",
        value_type: :uint8,
        max_length: 1,
        enum_values: %{0 => "Add", 1 => "Change", 2 => "Delete"}
      },
      4 => %{
        name: "US Channel",
        description: "Upstream channel configuration (compound)",
        value_type: :compound,
        max_length: :unlimited,
        enum_values: nil
      }
    }
  end

  # =============================================================================
  # TLV 48: Receive Channel Profile Sub-TLVs
  # Per CANN-I22-230308
  # =============================================================================
  defp receive_channel_profile_subtlvs do
    %{
      1 => %{
        name: "RCP ID",
        description: "Receive Channel Profile identifier",
        value_type: :binary,
        max_length: 5,
        enum_values: nil
      },
      2 => %{
        name: "RCP Name",
        description: "Receive Channel Profile name",
        value_type: :string,
        max_length: 16,
        enum_values: nil
      },
      3 => %{
        name: "RCC Status",
        description: "Receive Channel Configuration status",
        value_type: :uint8,
        max_length: 1,
        enum_values: nil
      }
    }
  end

  # =============================================================================
  # TLV 50: DSID Encodings Sub-TLVs
  # Per CANN-I22-230308
  # =============================================================================
  defp dsid_encodings_subtlvs do
    %{
      1 => %{
        name: "DSID",
        description: "Downstream Service Identifier (20-bit value)",
        value_type: :uint24,
        max_length: 3,
        enum_values: nil
      },
      2 => %{
        name: "DSID Action",
        description: "DSID action type",
        value_type: :uint8,
        max_length: 1,
        enum_values: %{0 => "Add", 1 => "Change", 2 => "Delete"}
      },
      3 => %{
        name: "DS Resequencing",
        description: "Downstream resequencing encoding (compound)",
        value_type: :compound,
        max_length: :unlimited,
        enum_values: nil
      },
      4 => %{
        name: "Multicast",
        description: "Multicast encoding (compound)",
        value_type: :compound,
        max_length: :unlimited,
        enum_values: nil
      }
    }
  end

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

  # =============================================================================
  # DOCSIS 3.1 OFDM/OFDMA Profile Sub-TLVs (TLVs 62-63)
  # =============================================================================

  # TLV 62: Downstream OFDM Profile Sub-TLVs
  defp downstream_ofdm_profile_subtlvs do
    %{
      1 => %{
        name: "Profile ID",
        description: "OFDM profile identifier",
        value_type: :uint8,
        max_length: 1,
        enum_values: nil
      },
      2 => %{
        name: "Channel ID",
        description: "OFDM channel identifier",
        value_type: :uint8,
        max_length: 1,
        enum_values: nil
      },
      3 => %{
        name: "Configuration Change Count",
        description: "Configuration change counter for profile updates",
        value_type: :uint8,
        max_length: 1,
        enum_values: nil
      },
      4 => %{
        name: "Subcarrier Spacing",
        description: "OFDM subcarrier spacing selection",
        value_type: :uint8,
        max_length: 1,
        enum_values: %{
          0 => "25 kHz",
          1 => "50 kHz"
        }
      },
      5 => %{
        name: "Cyclic Prefix",
        description: "Cyclic prefix length for OFDM symbol",
        value_type: :uint8,
        max_length: 1,
        enum_values: %{
          0 => "192 samples",
          1 => "256 samples",
          2 => "384 samples",
          3 => "512 samples",
          4 => "640 samples",
          5 => "768 samples",
          6 => "896 samples",
          7 => "1024 samples"
        }
      },
      6 => %{
        name: "Roll-off Period",
        description: "Windowing roll-off period length",
        value_type: :uint8,
        max_length: 1,
        enum_values: %{
          0 => "0 samples",
          1 => "64 samples",
          2 => "128 samples",
          3 => "192 samples",
          4 => "256 samples"
        }
      },
      7 => %{
        name: "Interleaver Depth",
        description: "Time interleaver depth",
        value_type: :uint8,
        max_length: 1,
        enum_values: %{
          0 => "1 (no interleaving)",
          1 => "2",
          2 => "4",
          3 => "8",
          4 => "16",
          5 => "32"
        }
      },
      8 => %{
        name: "Modulation Profile",
        description: "QAM modulation profile for subcarriers",
        value_type: :compound,
        max_length: :unlimited,
        enum_values: nil
      },
      9 => %{
        name: "Start Frequency",
        description: "OFDM channel start frequency in Hz",
        value_type: :uint32,
        max_length: 4,
        enum_values: nil
      },
      10 => %{
        name: "End Frequency",
        description: "OFDM channel end frequency in Hz",
        value_type: :uint32,
        max_length: 4,
        enum_values: nil
      },
      11 => %{
        name: "Number of Subcarriers",
        description: "Total number of active subcarriers",
        value_type: :uint16,
        max_length: 2,
        enum_values: nil
      },
      12 => %{
        name: "Pilot Pattern",
        description: "Pilot subcarrier pattern configuration",
        value_type: :uint8,
        max_length: 1,
        enum_values: %{
          0 => "Scattered pilots",
          1 => "Continuous pilots",
          2 => "Mixed pattern"
        }
      }
    }
  end

  # TLV 63: Downstream OFDMA Profile Sub-TLVs
  defp downstream_ofdma_profile_subtlvs do
    %{
      1 => %{
        name: "Profile ID",
        description: "OFDMA profile identifier",
        value_type: :uint8,
        max_length: 1,
        enum_values: nil
      },
      2 => %{
        name: "Channel ID",
        description: "OFDMA channel identifier",
        value_type: :uint8,
        max_length: 1,
        enum_values: nil
      },
      3 => %{
        name: "Configuration Change Count",
        description: "Configuration change counter for profile updates",
        value_type: :uint8,
        max_length: 1,
        enum_values: nil
      },
      4 => %{
        name: "Subcarrier Spacing",
        description: "OFDMA subcarrier spacing selection",
        value_type: :uint8,
        max_length: 1,
        enum_values: %{
          0 => "25 kHz",
          1 => "50 kHz"
        }
      },
      5 => %{
        name: "Cyclic Prefix",
        description: "Cyclic prefix length for OFDMA symbol",
        value_type: :uint8,
        max_length: 1,
        enum_values: %{
          0 => "192 samples",
          1 => "256 samples",
          2 => "384 samples",
          3 => "512 samples",
          4 => "640 samples",
          5 => "768 samples",
          6 => "896 samples",
          7 => "1024 samples"
        }
      },
      6 => %{
        name: "Roll-off Period",
        description: "Windowing roll-off period length",
        value_type: :uint8,
        max_length: 1,
        enum_values: %{
          0 => "0 samples",
          1 => "64 samples",
          2 => "128 samples",
          3 => "192 samples",
          4 => "256 samples"
        }
      },
      7 => %{
        name: "Interleaver Depth",
        description: "Time interleaver depth",
        value_type: :uint8,
        max_length: 1,
        enum_values: %{
          0 => "1 (no interleaving)",
          1 => "2",
          2 => "4",
          3 => "8",
          4 => "16",
          5 => "32"
        }
      },
      8 => %{
        name: "Modulation Profile",
        description: "QAM modulation profile for subcarriers",
        value_type: :compound,
        max_length: :unlimited,
        enum_values: nil
      },
      9 => %{
        name: "Start Frequency",
        description: "OFDMA channel start frequency in Hz",
        value_type: :uint32,
        max_length: 4,
        enum_values: nil
      },
      10 => %{
        name: "End Frequency",
        description: "OFDMA channel end frequency in Hz",
        value_type: :uint32,
        max_length: 4,
        enum_values: nil
      },
      11 => %{
        name: "Mini-slot Size",
        description: "Upstream mini-slot size in OFDMA symbols",
        value_type: :uint8,
        max_length: 1,
        enum_values: nil
      },
      12 => %{
        name: "Pilot Pattern",
        description: "Pilot subcarrier pattern configuration",
        value_type: :uint8,
        max_length: 1,
        enum_values: %{
          0 => "Scattered pilots",
          1 => "Continuous pilots",
          2 => "Mixed pattern"
        }
      },
      13 => %{
        name: "Power Control",
        description: "Upstream power control parameter",
        value_type: :int8,
        max_length: 1,
        enum_values: nil
      }
    }
  end

  # Extended compound TLV sub-TLVs (TLVs 62-85)
  defp extended_compound_subtlvs(parent_type) do
    case parent_type do
      62 -> downstream_ofdm_profile_subtlvs()
      63 -> downstream_ofdma_profile_subtlvs()
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

  # =============================================================================
  # TLV 202: eRouter Configuration Encodings
  # Per CableLabs CM-SP-eRouter (transposed as ETSI ES 203 386 V1.1.1) Annex B.4
  # =============================================================================
  defp erouter_config_subtlvs do
    %{
      # B.4.2 eRouter Initialization Mode Encoding
      1 => %{
        name: "eRouter Initialization Mode",
        description: "eRouter initialization mode configured by the operator (default: 3)",
        value_type: :uint8,
        max_length: 1,
        enum_values: %{
          0 => "Disabled",
          1 => "IPv4 Protocol Enabled",
          2 => "IPv6 Protocol Enabled",
          3 => "Dual IP Protocol Enabled"
        }
      },
      # B.4.3 TR-069 Management Server Encoding (composite)
      2 => %{
        name: "TR-069 Management Server",
        description:
          "TR-069 Device.ManagementServer configuration (ACS URL, credentials, CWMP enable)",
        value_type: :compound,
        max_length: :unlimited
      },
      # B.4.4 eRouter Initialization Mode Override Encoding
      3 => %{
        name: "eRouter Initialization Mode Override",
        description:
          "Override for a manually disabled eRouter: 0 = follow Initialization Mode TLV, " <>
            "1 = ignore Initialization Mode TLV and keep the eRouter disabled (default: 0)",
        value_type: :uint8,
        max_length: 1,
        enum_values: %{
          0 => "Follow eRouter Initialization Mode TLV",
          1 => "Keep eRouter Disabled"
        }
      },
      # B.4.10 Router Advertisement (RA) Transmission Interval
      10 => %{
        name: "RA Transmission Interval",
        description:
          "Router Advertisement transmission period in seconds, 3-1800 (default: 30)",
        value_type: :uint16,
        max_length: 2
      },
      # B.4.8 SNMP MIB Object (ASN.1 BER-encoded SNMP VarBind, max 255 bytes each)
      11 => %{
        name: "SNMP MIB Object",
        description: "SNMP VarBind (ASN.1 BER) applied to the eRouter as an SNMP SET",
        value_type: :asn1_der,
        max_length: 255
      },
      # B.4.11 IP Multicast Configuration Server
      12 => %{
        name: "IP Multicast Configuration Server",
        description: "Multicast configuration server as ASCII-encoded IP address or DNS FQDN",
        value_type: :string,
        max_length: :unlimited
      },
      # B.4.12 Link ID Control
      13 => %{
        name: "Link ID Control",
        description: "Enables Link ID subdivision of the delegated IPv6 prefix (default: 0)",
        value_type: :uint8,
        max_length: 1,
        enum_values: %{
          0 => "Disabled",
          1 => "Enabled"
        }
      },
      # B.4.9 Topology Mode Encoding
      42 => %{
        name: "Topology Mode",
        description:
          "eRouter topology mode for subdividing an operator-delegated IPv6 prefix",
        value_type: :uint8,
        max_length: 1,
        enum_values: %{
          1 => "Favor Depth",
          2 => "Favor Width"
        }
      },
      # B.4.7 Vendor Specific Information (composite)
      43 => %{
        name: "Vendor Specific Information",
        description: "Vendor-specific eRouter settings, qualified by Vendor ID (sub-TLV 8)",
        value_type: :compound,
        max_length: :unlimited
      },
      # B.4.5 SNMPv1v2c Coexistence Configuration (composite)
      53 => %{
        name: "SNMPv1v2c Coexistence Configuration",
        description: "SNMPv1v2c coexistence access control configuration for the eRouter",
        value_type: :compound,
        max_length: :unlimited
      },
      # B.4.6 SNMPv3 Access View Configuration (composite)
      54 => %{
        name: "SNMPv3 Access View Configuration",
        description: "SNMPv3 simplified access view configuration for the eRouter",
        value_type: :compound,
        max_length: :unlimited
      }
    }
  end

  # TLV 202.2: TR-069 Management Server sub-TLVs (CM-SP-eRouter Annex B.4.3)
  # NOTE: These leaf specs intentionally avoid enum_values because nested
  # round-trip enum reverse-lookup only knows the immediate parent type (2).
  # 0/1 semantics are documented in the descriptions instead.
  defp erouter_tr069_mgmt_server_subtlvs do
    %{
      1 => %{
        name: "EnableCWMP",
        description: "Device.ManagementServer.EnableCWMP (0 = false, 1 = true)",
        value_type: :uint8,
        max_length: 1
      },
      2 => %{
        name: "URL",
        description: "Device.ManagementServer.URL (ACS URL)",
        value_type: :string,
        max_length: :unlimited
      },
      3 => %{
        name: "Username",
        description: "Device.ManagementServer.Username (ACS authentication username)",
        value_type: :string,
        max_length: :unlimited
      },
      4 => %{
        name: "Password",
        description: "Device.ManagementServer.Password (ACS authentication password)",
        value_type: :string,
        max_length: :unlimited
      },
      5 => %{
        name: "ConnectionRequestUsername",
        description: "Device.ManagementServer.ConnectionRequestUsername",
        value_type: :string,
        max_length: :unlimited
      },
      6 => %{
        name: "ConnectionRequestPassword",
        description: "Device.ManagementServer.ConnectionRequestPassword",
        value_type: :string,
        max_length: :unlimited
      },
      7 => %{
        name: "ACSOverride",
        description:
          "Accept CM config file ACS URL even if the ACS has overwritten it " <>
            "(0 = disabled, 1 = enabled)",
        value_type: :uint8,
        max_length: 1
      }
    }
  end

  # TLV 202.43: eRouter Vendor Specific Information sub-TLVs (Annex B.4.7)
  defp erouter_vendor_specific_subtlvs do
    %{
      8 => %{
        name: "Vendor ID",
        description: "Three-byte vendor OUI identifying the vendor these settings apply to",
        value_type: :vendor_oui,
        max_length: 3
      }
    }
  end

  # TLV 202.53: SNMPv1v2c Coexistence Configuration sub-TLVs (Annex B.4.5)
  defp erouter_snmpv1v2c_coexistence_subtlvs do
    %{
      1 => %{
        name: "SNMPv1v2c Community Name",
        description: "Community name (community string) used in SNMP requests to the eRouter",
        value_type: :string,
        max_length: 32
      },
      2 => %{
        name: "SNMPv1v2c Transport Address Access",
        description: "Transport address and mask pair used to grant SNMP access",
        value_type: :compound,
        max_length: :unlimited
      },
      3 => %{
        name: "SNMPv1v2c Access View Type",
        description:
          "Type of access granted to the community name: 1 = Read-only, 2 = Read-write " <>
            "(default: 1)",
        value_type: :uint8,
        max_length: 1
      },
      4 => %{
        name: "SNMPv1v2c Access View Name",
        description: "Name of the view providing the access indicated by the access view type",
        value_type: :string,
        max_length: 32
      }
    }
  end

  # TLV 202.53.2: SNMPv1v2c Transport Address Access sub-TLVs (Annex B.4.5.2)
  # NOTE: leaf specs avoid enum_values in nested contexts (see 202.2 note).
  defp erouter_snmp_transport_address_access_subtlvs do
    %{
      1 => %{
        name: "SNMPv1v2c Transport Address",
        description: "Transport address (6 bytes for IPv4, 18 bytes for IPv6, incl. port)",
        value_type: :binary,
        max_length: 18
      },
      2 => %{
        name: "SNMPv1v2c Transport Address Mask",
        description: "Transport address mask (6 bytes for IPv4, 18 bytes for IPv6)",
        value_type: :binary,
        max_length: 18
      }
    }
  end

  # TLV 202.54: SNMPv3 Access View Configuration sub-TLVs (Annex B.4.6)
  defp erouter_snmpv3_access_view_subtlvs do
    %{
      1 => %{
        name: "SNMPv3 Access View Name",
        description: "Administrative name of the SNMPv3 access view",
        value_type: :string,
        max_length: 32
      },
      2 => %{
        name: "SNMPv3 Access View Subtree",
        description:
          "ASN.1-encoded OID of the filter subtree (e.g. 06 03 01 03 06 for 1.3.6; default: 1.3.6)",
        value_type: :binary,
        max_length: :unlimited
      },
      3 => %{
        name: "SNMPv3 Access View Mask",
        description: "Bit mask applied to the access view subtree",
        value_type: :binary,
        max_length: 16
      },
      4 => %{
        name: "SNMPv3 Access View Type",
        description: "Subtree inclusion: 1 = included, 2 = excluded (default: 1)",
        value_type: :uint8,
        max_length: 1
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
        # Contains TLV 0 marker
        value_type: :compound,
        max_length: :unlimited,
        enum_values: nil
      },
      2 => %{
        name: "MPLS VC ID",
        description: "MPLS virtual circuit identifier",
        # Contains TLV 1 with hex data
        value_type: :compound,
        max_length: :unlimited,
        enum_values: nil
      },
      3 => %{
        name: "MPLS Service Type",
        description: "MPLS service type indicator",
        # Single hex value
        value_type: :hex_string,
        max_length: 4,
        enum_values: nil
      },
      4 => %{
        name: "MPLS Peer Configuration",
        description: "MPLS peer configuration with marker",
        # Contains TLV 0 marker
        value_type: :compound,
        max_length: :unlimited,
        enum_values: nil
      },
      5 => %{
        name: "MPLS Extended Configuration",
        description: "Extended MPLS configuration parameters",
        # Contains complex nested data
        value_type: :compound,
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
        # Can be IPv4 or IPv6
        value_type: :binary,
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
        # Can be IPv4 or IPv6
        value_type: :binary,
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
