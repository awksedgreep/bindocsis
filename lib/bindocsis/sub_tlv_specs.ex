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
      # Classifier nested encodings, shared by TLV 22/23/60
      # Per CL-SP-CANN 11.1.4 and CM-SP-MULPIv3.1 Annex C.2.1
      [c, 8] when c in [22, 23, 60] ->
        {:ok, classifier_error_subtlvs()}

      [c, 9] when c in [22, 23, 60] ->
        {:ok, ipv4_classification_subtlvs()}

      [c, 10] when c in [22, 23, 60] ->
        {:ok, ethernet_llc_classification_subtlvs()}

      [c, 11] when c in [22, 23, 60] ->
        {:ok, dot1pq_classification_subtlvs()}

      [c, 12] when c in [22, 23, 60] ->
        {:ok, ipv6_classification_field_subtlvs()}

      [c, 14] when c in [22, 23, 60] ->
        {:ok, dot1ad_classification_subtlvs()}

      [c, 15] when c in [22, 23, 60] ->
        {:ok, dot1ah_classification_subtlvs()}

      [c, 16] when c in [22, 23, 60] ->
        {:ok, icmp_classification_subtlvs()}

      [c, 17] when c in [22, 23, 60] ->
        {:ok, mpls_classification_subtlvs()}

      # Service flow nested encodings (CM-SP-MULPIv3.1 Annex C.2.2.7)
      [sf, 35] when sf in [24, 25, 70, 71] ->
        {:ok, buffer_control_subtlvs()}

      [sf, 40] when sf in [24, 25] ->
        {:ok, aqm_encodings_subtlvs()}

      # Downstream Channel List (CM-SP-MULPIv3.1 Annex C.1.1.22)
      [41, 1] ->
        {:ok, single_downstream_channel_subtlvs()}

      [41, 2] ->
        {:ok, downstream_frequency_range_subtlvs()}

      # SNMPv1v2c Coexistence Transport Address Access (Annex C.1.2.13.2)
      [53, 2] ->
        {:ok, snmp_transport_address_access_subtlvs()}

      # MESP Bandwidth Profile (CANN 11.1.7)
      [72, 2] ->
        {:ok, mesp_bandwidth_profile_subtlvs()}

      [72, 2, 6] ->
        {:ok, mesp_color_mode_subtlvs()}

      [72, 2, 7] ->
        {:ok, mesp_color_marking_subtlvs()}

      # Energy Management mode encodings (MULPI C.1.1.30)
      [74, m] when m in [2, 4] ->
        {:ok, energy_mgmt_mode_subtlvs()}

      [74, m, 1] when m in [2, 4] ->
        {:ok, em_downstream_activity_subtlvs()}

      [74, m, 2] when m in [2, 4] ->
        {:ok, em_upstream_activity_subtlvs()}

      # eRouter (TLV 202) nested contexts per CM-SP-eRouter / ETSI ES 203 386 Annex B.4
      # TLV 202.2 = TR-069 Management Server Encoding (B.4.3)
      [202, 2] ->
        {:ok, erouter_tr069_mgmt_server_subtlvs()}

      # TLV 202.43 = eRouter Vendor Specific Information (B.4.7)
      [202, 43] ->
        {:ok, erouter_vendor_specific_subtlvs()}

      # TLV 202.53.2 = SNMPv1v2c Transport Address Access (B.4.5.2)
      [202, 53, 2] ->
        {:ok, snmp_transport_address_access_subtlvs()}

      # TLV 202.53 = SNMPv1v2c Coexistence Configuration (B.4.5)
      [202, 53] ->
        {:ok, snmpv1v2c_coexistence_subtlvs()}

      # TLV 202.54 = SNMPv3 Access View Configuration (B.4.6)
      [202, 54] ->
        {:ok, snmpv3_access_view_subtlvs()}

      # Service Flow Error Encodings (5) and QoS Parameter Set (6) should not
      # reuse global TLV 5/6 specs when nested under service-flow parents.
      # TLV 24/25 = Service Flows, TLV 70/71 = Aggregate Service Flows
      # Treat these nested contexts as having no further structured sub-TLV
      # specs so their values remain opaque (typically hex) instead of
      # fabricating bogus "SubTLV 0" children.
      [parent, sub] when parent in [24, 25, 70, 71] and sub in [5, 6] ->
        {:error, :unknown_tlv}

      # DOCSIS Extension Field (43) nested subtypes can appear at top level
      # or inside classifiers/service flows/PHS - resolve by path suffix,
      # then fall back to the last element for standard subtlv lookup.
      path when path != [] ->
        case extension_field_context(path) do
          {:ok, _} = ok -> ok
          :none -> get_subtlv_specs(List.last(path))
        end

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
      # TLV 53 = SNMPv1v2c Coexistence (CANN 11.1.6, MULPI C.1.2.13)
      53 -> {:ok, snmpv1v2c_coexistence_subtlvs()}
      # TLV 54 = SNMPv3 Access View Configuration (CANN 11.1.6, MULPI C.1.2.14)
      54 -> {:ok, snmpv3_access_view_subtlvs()}
      # TLV 56 = Channel Assignment Configuration Settings (MULPI C.1.1.25)
      56 -> {:ok, channel_assignment_subtlvs()}
      # TLV 60 = Upstream Drop Packet Classification - shares the classifier
      # sub-TLV numbering plan with TLV 22/23 (CANN 11.1.4)
      60 -> {:ok, packet_classification_subtlvs()}
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

  # DOCSIS Extension Field (TLV 43) subtype tables addressed by path suffix,
  # so [43, 6], [22, 43, 6], [24, 43, 6], ... all resolve identically.
  # Per CM-SP-MULPIv3.1 Annex C.1.1.18.1, CL-SP-CANN 11.1.2, and
  # DEMARCv1.0 Annex B. Longest suffix wins.
  defp extension_field_context(path) do
    cond do
      # L2VPN Encoding (43.5) subtree - CANN 11.1.2.1
      Enum.take(path, -4) == [43, 5, 2, 4] ->
        {:ok, mpls_service_multiplexing_value_subtlvs()}

      Enum.take(path, -4) in [[43, 5, 24, 1], [43, 5, 24, 2]] ->
        {:ok, l2vpn_soam_mep_config_subtlvs()}

      Enum.take(path, -4) == [43, 5, 24, 3] ->
        {:ok, l2vpn_soam_fault_mgmt_subtlvs()}

      Enum.take(path, -4) == [43, 5, 24, 4] ->
        {:ok, l2vpn_soam_perf_mgmt_subtlvs()}

      Enum.take(path, -4) == [43, 5, 2, 6] ->
        {:ok, dot1ah_encapsulation_subtlvs()}

      Enum.take(path, -3) == [43, 5, 2] ->
        {:ok, service_multiplexing_subtlvs()}

      Enum.take(path, -3) == [43, 5, 14] ->
        {:ok, l2vpn_tpid_translation_subtlvs()}

      Enum.take(path, -3) == [43, 5, 15] ->
        {:ok, l2vpn_l2cp_processing_subtlvs()}

      Enum.take(path, -3) == [43, 5, 19] ->
        {:ok, l2vpn_service_delimiter_subtlvs()}

      Enum.take(path, -3) == [43, 5, 20] ->
        {:ok, l2vpn_vsi_encoding_subtlvs()}

      Enum.take(path, -3) == [43, 5, 21] ->
        {:ok, l2vpn_bgp_attribute_subtlvs()}

      Enum.take(path, -3) == [43, 5, 24] ->
        {:ok, l2vpn_soam_subtlvs()}

      Enum.take(path, -3) == [43, 5, 254] ->
        {:ok, l2vpn_error_subtlvs()}

      Enum.take(path, -2) == [43, 5] ->
        {:ok, l2vpn_encoding_subtlvs()}

      # Other DOCSIS Extension Field subtypes - MULPI C.1.1.18.1
      Enum.take(path, -3) == [43, 7, 2] ->
        {:ok, sav_static_prefix_subtlvs()}

      Enum.take(path, -3) == [43, 10, 2] ->
        {:ok, multicast_session_rule_subtlvs()}

      Enum.take(path, -2) == [43, 6] ->
        {:ok, extended_cmts_mic_subtlvs()}

      Enum.take(path, -2) == [43, 7] ->
        {:ok, sav_authorization_subtlvs()}

      Enum.take(path, -2) == [43, 9] ->
        {:ok, cm_attribute_masks_subtlvs()}

      Enum.take(path, -2) == [43, 10] ->
        {:ok, ip_multicast_join_subtlvs()}

      Enum.take(path, -2) == [43, 12] ->
        {:ok, demarc_autoconfiguration_subtlvs()}

      true ->
        :none
    end
  end

  # Private helper function for extended TLVs.
  # Only spec-verified tables are returned; everything else is :unknown_tlv so
  # children get honest generic naming instead of masquerading as global TLVs.
  defp check_extended_tlv_subtlvs(parent_tlv_type) do
    cond do
      # TLV 202 = eRouter Configuration Encodings per CM-SP-eRouter Annex B.4
      parent_tlv_type == 202 ->
        {:ok, erouter_config_subtlvs()}

      parent_tlv_type in 200..253 ->
        {:ok, vendor_specific_subtlvs()}

      parent_tlv_type in 62..199 ->
        case extended_compound_subtlvs(parent_tlv_type) do
          empty when map_size(empty) == 0 -> {:error, :unknown_tlv}
          specs -> {:ok, specs}
        end

      true ->
        {:error, :unknown_tlv}
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
        name: "CM Interface Mask (CMIM) Encoding",
        description: "Cable Modem Interface Mask (CMIM) encoding (CANN 11.1.4, L2VPN)",
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
      16 => %{
        name: "ICMPv4/ICMPv6 Packet Classification Encodings",
        description: "ICMPv4/ICMPv6 type classification (compound, MULPI C.2.1.12)",
        value_type: :compound,
        max_length: :unlimited,
        enum_values: nil
      },
      17 => %{
        name: "MPLS Classification Encodings",
        description: "MPLS packet classification on outermost label (compound, MULPI C.2.1.15)",
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

  # ===========================================================================
  # Classifier nested field encodings, shared by TLV 22/23/60
  # Per CM-SP-MULPIv3.1 Annex C.2.1 and CL-SP-CANN 11.1.4.
  # NOTE: leaf specs in these nested contexts avoid enum_values because
  # round-trip enum reverse-lookup only knows the immediate parent type.
  # ===========================================================================

  # [22/23/60].8 - Classifier Error Encodings (MULPI C.2.1.3.x)
  defp classifier_error_subtlvs do
    %{
      1 => %{
        name: "Errored Parameter",
        description: "Type of the TLV parameter in error",
        value_type: :binary,
        max_length: :unlimited
      },
      2 => %{
        name: "Error Code",
        description: "Confirmation code for the error",
        value_type: :uint8,
        max_length: 1
      },
      3 => %{
        name: "Error Message",
        description: "Human-readable error message",
        value_type: :string,
        max_length: :unlimited
      }
    }
  end

  # [22/23/60].9 - IPv4/TCP/UDP Packet Classification (MULPI C.2.1.6-C.2.1.7)
  defp ipv4_classification_subtlvs do
    %{
      1 => %{
        name: "IPv4 Type of Service Range and Mask",
        description: "tos-low, tos-high, tos-mask (MULPI C.2.1.6.1)",
        value_type: :binary,
        max_length: 3
      },
      2 => %{
        name: "IP Protocol",
        description: "IP protocol number; 256 matches all, 257 matches TCP and UDP (C.2.1.6.2)",
        value_type: :uint16,
        max_length: 2
      },
      3 => %{
        name: "IPv4 Source Address",
        description: "Matching value for the IPv4 source address (C.2.1.6.3)",
        value_type: :ipv4,
        max_length: 4
      },
      4 => %{
        name: "IPv4 Source Mask",
        description: "Mask applied to the IPv4 source address (C.2.1.6.4)",
        value_type: :ipv4,
        max_length: 4
      },
      5 => %{
        name: "IPv4 Destination Address",
        description: "Matching value for the IPv4 destination address (C.2.1.6.5)",
        value_type: :ipv4,
        max_length: 4
      },
      6 => %{
        name: "IPv4 Destination Mask",
        description: "Mask applied to the IPv4 destination address (C.2.1.6.6)",
        value_type: :ipv4,
        max_length: 4
      },
      7 => %{
        name: "TCP/UDP Source Port Start",
        description: "Low end of the source port range (C.2.1.7.1)",
        value_type: :uint16,
        max_length: 2
      },
      8 => %{
        name: "TCP/UDP Source Port End",
        description: "High end of the source port range (C.2.1.7.2)",
        value_type: :uint16,
        max_length: 2
      },
      9 => %{
        name: "TCP/UDP Destination Port Start",
        description: "Low end of the destination port range (C.2.1.7.3)",
        value_type: :uint16,
        max_length: 2
      },
      10 => %{
        name: "TCP/UDP Destination Port End",
        description: "High end of the destination port range (C.2.1.7.4)",
        value_type: :uint16,
        max_length: 2
      }
    }
  end

  # [22/23/60].10 - Ethernet LLC Packet Classification (MULPI C.2.1.8)
  defp ethernet_llc_classification_subtlvs do
    %{
      1 => %{
        name: "Destination MAC Address",
        description: "Destination MAC address and mask, dst[6] + msk[6] (C.2.1.8.1)",
        value_type: :binary,
        max_length: 12
      },
      2 => %{
        name: "Source MAC Address",
        description: "Matching value for the source MAC address (C.2.1.8.2)",
        value_type: :mac_address,
        max_length: 6
      },
      3 => %{
        name: "Ethertype/DSAP/MacType",
        description: "type + eprot1/eprot2 layer-3 protocol selector (C.2.1.8.3)",
        value_type: :binary,
        max_length: 3
      },
      4 => %{
        name: "Slow Protocol Subtype",
        description: "Slow protocol subtype classification (CANN 11.1.4)",
        value_type: :binary,
        max_length: :unlimited
      }
    }
  end

  # [22/23/60].11 - IEEE 802.1P/Q Packet Classification (MULPI C.2.1.9)
  defp dot1pq_classification_subtlvs do
    %{
      1 => %{
        name: "IEEE 802.1P User Priority",
        description: "pri-low, pri-high (0-7 each) (C.2.1.9.1)",
        value_type: :binary,
        max_length: 2
      },
      2 => %{
        name: "IEEE 802.1Q VLAN_ID",
        description: "VLAN ID in the 12 most significant bits (C.2.1.9.2)",
        value_type: :uint16,
        max_length: 2
      }
    }
  end

  # [22/23/60].12 - IPv6 Packet Classification (MULPI C.2.1.10)
  defp ipv6_classification_field_subtlvs do
    %{
      1 => %{
        name: "IPv6 Traffic Class Range and Mask",
        description: "tc-low, tc-high, tc-mask (C.2.1.10.1)",
        value_type: :binary,
        max_length: 3
      },
      2 => %{
        name: "IPv6 Flow Label",
        description: "20-bit flow label in the least significant bits (C.2.1.10.2)",
        value_type: :uint32,
        max_length: 4
      },
      3 => %{
        name: "IPv6 Next Header Type",
        description: "Upper-layer protocol; 256 matches all, 257 matches TCP and UDP (C.2.1.10.3)",
        value_type: :uint16,
        max_length: 2
      },
      4 => %{
        name: "IPv6 Source Address",
        description: "Matching value for the IPv6 source address (C.2.1.10.4)",
        value_type: :ipv6,
        max_length: 16
      },
      5 => %{
        name: "IPv6 Source Prefix Length",
        description: "Prefix length in bits, 0-128 (default 128) (C.2.1.10.5)",
        value_type: :uint8,
        max_length: 1
      },
      6 => %{
        name: "IPv6 Destination Address",
        description: "Matching value for the IPv6 destination address (C.2.1.10.6)",
        value_type: :ipv6,
        max_length: 16
      },
      7 => %{
        name: "IPv6 Destination Prefix Length",
        description: "Prefix length in bits, 0-128 (default 128) (C.2.1.10.7)",
        value_type: :uint8,
        max_length: 1
      }
    }
  end

  # [22/23/60].14 - IEEE 802.1ad S-VLAN Packet Classification (MULPI C.2.1.13)
  defp dot1ad_classification_subtlvs do
    %{
      1 => %{name: "IEEE 802.1ad S-TPID", description: "Service tag protocol identifier", value_type: :uint16, max_length: 2},
      2 => %{name: "IEEE 802.1ad S-VID", description: "Service VLAN ID bit map", value_type: :binary, max_length: 2},
      3 => %{name: "IEEE 802.1ad S-PCP", description: "Service priority code point bit map", value_type: :binary, max_length: 1},
      4 => %{name: "IEEE 802.1ad S-DEI", description: "Service drop eligible indicator bit map", value_type: :binary, max_length: 1},
      5 => %{name: "IEEE 802.1ad C-TPID", description: "Customer tag protocol identifier", value_type: :uint16, max_length: 2},
      6 => %{name: "IEEE 802.1ad C-VID", description: "Customer VLAN ID bit map", value_type: :binary, max_length: 2},
      7 => %{name: "IEEE 802.1ad C-PCP", description: "Customer priority code point bit map", value_type: :binary, max_length: 1},
      8 => %{name: "IEEE 802.1ad C-CFI", description: "Customer canonical format indicator bit map", value_type: :binary, max_length: 1},
      9 => %{name: "IEEE 802.1ad S-TCI", description: "Service tag control information", value_type: :binary, max_length: 2},
      10 => %{name: "IEEE 802.1ad C-TCI", description: "Customer tag control information", value_type: :binary, max_length: 2}
    }
  end

  # [22/23/60].15 - IEEE 802.1ah I-TAG Packet Classification (MULPI C.2.1.14)
  defp dot1ah_classification_subtlvs do
    %{
      1 => %{name: "IEEE 802.1ah I-TPID", description: "Backbone service instance TPID", value_type: :uint16, max_length: 2},
      2 => %{name: "IEEE 802.1ah I-SID", description: "Backbone service instance identifier (24 bits)", value_type: :binary, max_length: 3},
      3 => %{name: "IEEE 802.1ah I-TCI", description: "Backbone service instance tag control information (40 bits)", value_type: :binary, max_length: 5},
      4 => %{name: "IEEE 802.1ah I-PCP", description: "Backbone priority code point bit map", value_type: :binary, max_length: 1},
      5 => %{name: "IEEE 802.1ah I-DEI", description: "Backbone drop eligible indicator bit map", value_type: :binary, max_length: 1},
      6 => %{name: "IEEE 802.1ah I-UCA", description: "Use customer address bit map", value_type: :binary, max_length: 1},
      7 => %{name: "IEEE 802.1ah B-TPID", description: "Backbone tag protocol identifier", value_type: :uint16, max_length: 2},
      8 => %{name: "IEEE 802.1ah B-TCI", description: "Backbone tag control information", value_type: :binary, max_length: 2},
      9 => %{name: "IEEE 802.1ah B-PCP", description: "Backbone priority code point bit map", value_type: :binary, max_length: 1},
      10 => %{name: "IEEE 802.1ah B-DEI", description: "Backbone drop eligible indicator bit map", value_type: :binary, max_length: 1},
      11 => %{name: "IEEE 802.1ah B-VID", description: "Backbone VLAN ID bit map", value_type: :binary, max_length: 2},
      12 => %{name: "IEEE 802.1ah B-DA", description: "Backbone destination MAC address", value_type: :mac_address, max_length: 6},
      13 => %{name: "IEEE 802.1ah B-SA", description: "Backbone source MAC address", value_type: :mac_address, max_length: 6}
    }
  end

  # [22/23/60].16 - ICMPv4/ICMPv6 Packet Classification (MULPI C.2.1.12)
  defp icmp_classification_subtlvs do
    %{
      1 => %{
        name: "ICMPv4/ICMPv6 Type Start",
        description: "Low end of the ICMP type range",
        value_type: :uint8,
        max_length: 1
      },
      2 => %{
        name: "ICMPv4/ICMPv6 Type End",
        description: "High end of the ICMP type range",
        value_type: :uint8,
        max_length: 1
      }
    }
  end

  # [22/23/60].17 - MPLS Classification (MULPI C.2.1.15)
  defp mpls_classification_subtlvs do
    %{
      1 => %{
        name: "MPLS TC bits",
        description: "MPLS traffic class, 3 least significant bits (C.2.1.15.1)",
        value_type: :uint8,
        max_length: 1
      },
      2 => %{
        name: "MPLS Label",
        description: "MPLS label, 20 least significant bits (C.2.1.15.2)",
        value_type: :binary,
        max_length: 3
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
        description: "Zero-terminated name of the service class (MULPI C.2.2.3.4)",
        value_type: :string_null,
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
        description: "Application identifier for the service flow (MULPI C.2.2.7.10, 4 bytes)",
        value_type: :uint32,
        max_length: 4,
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
      },
      39 => %{
        name: "Service Flow to IATC Profile Name Reference",
        description: "Zero-terminated IATC profile name (MULPI C.2.2.7.14)",
        value_type: :string_null,
        max_length: 16,
        enum_values: nil
      },
      40 => %{
        name: "AQM Encodings",
        description: "Active queue management encodings (compound, MULPI C.2.2.7.15)",
        value_type: :compound,
        max_length: :unlimited,
        enum_values: nil
      },
      41 => %{
        name: "Data Rate Unit Setting",
        description: "Unit for data rate parameters (MULPI C.2.2.7.16)",
        value_type: :uint8,
        max_length: 1,
        enum_values: nil
      }
    }
  end

  # [24/25].35 - Buffer Control sub-TLVs (MULPI C.2.2.7.11, CANN 11.1.3)
  defp buffer_control_subtlvs do
    %{
      1 => %{
        name: "Minimum Buffer",
        description: "Minimum buffer size in bytes (0 - 4294967295)",
        value_type: :uint32,
        max_length: 4
      },
      2 => %{
        name: "Target Buffer",
        description: "Target buffer size in bytes (0 - 4294967295)",
        value_type: :uint32,
        max_length: 4
      },
      3 => %{
        name: "Maximum Buffer",
        description: "Maximum buffer size in bytes (0 - 4294967295)",
        value_type: :uint32,
        max_length: 4
      }
    }
  end

  # [24/25].40 - AQM Encodings sub-TLVs (MULPI C.2.2.7.15, CANN 11.1.3)
  defp aqm_encodings_subtlvs do
    %{
      1 => %{
        name: "SF AQM Disable",
        description: "0 = enable AQM on service flow, 1 = disable",
        value_type: :uint8,
        max_length: 1
      },
      2 => %{
        name: "SF AQM Latency Target",
        description: "AQM latency target in milliseconds",
        value_type: :uint8,
        max_length: 1
      },
      3 => %{
        name: "AQM Algorithm",
        description: "AQM algorithm selection (CANN 11.1.3)",
        value_type: :binary,
        max_length: :unlimited
      },
      4 => %{
        name: "Immediate AQM Min Threshold",
        description: "Immediate AQM minimum threshold (CANN 11.1.3)",
        value_type: :binary,
        max_length: :unlimited
      },
      5 => %{
        name: "Immediate AQM Range Exponent of Ramp Function",
        description: "Immediate AQM range exponent (CANN 11.1.3)",
        value_type: :binary,
        max_length: :unlimited
      },
      6 => %{
        name: "Latency Histogram Encodings",
        description: "Latency histogram configuration (CANN 11.1.3)",
        value_type: :binary,
        max_length: :unlimited
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
        name: "Downstream Frequency Range",
        description: "Downstream frequency range specification (compound, MULPI C.1.1.22.2)",
        value_type: :compound,
        max_length: :unlimited,
        enum_values: nil
      },
      3 => %{
        name: "Default Scanning",
        description: "Default scanning timeout in seconds (MULPI C.1.1.22.3)",
        value_type: :uint16,
        max_length: 2,
        enum_values: nil
      }
    }
  end

  # TLV 41.1 - Single Downstream Channel sub-TLVs (MULPI C.1.1.22.1)
  defp single_downstream_channel_subtlvs do
    %{
      1 => %{
        name: "Single Downstream Channel Timeout",
        description: "Acquisition timeout in seconds; 0 = no timeout (C.1.1.22.1.1)",
        value_type: :uint16,
        max_length: 2
      },
      2 => %{
        name: "Single Downstream Channel Frequency",
        description: "Downstream center frequency in Hz (C.1.1.22.1.2)",
        value_type: :uint32,
        max_length: 4
      },
      3 => %{
        name: "Single Downstream Channel Type",
        description: "0 = OFDM, 1 = SC-QAM (C.1.1.22.1.3)",
        value_type: :uint8,
        max_length: 1
      }
    }
  end

  # TLV 41.2 - Downstream Frequency Range sub-TLVs (MULPI C.1.1.22.2)
  defp downstream_frequency_range_subtlvs do
    %{
      1 => %{
        name: "Downstream Frequency Range Timeout",
        description: "Acquisition timeout in seconds; 0 = no timeout (C.1.1.22.2.1)",
        value_type: :uint16,
        max_length: 2
      },
      2 => %{
        name: "Downstream Frequency Range Start",
        description: "First center frequency to scan, in Hz (C.1.1.22.2.2)",
        value_type: :uint32,
        max_length: 4
      },
      3 => %{
        name: "Downstream Frequency Range End",
        description: "Last center frequency to scan, in Hz (C.1.1.22.2.3)",
        value_type: :uint32,
        max_length: 4
      },
      4 => %{
        name: "Downstream Frequency Range Step Size",
        description: "Scan step size in Hz (C.1.1.22.2.4)",
        value_type: :uint32,
        max_length: 4
      },
      5 => %{
        name: "Downstream Frequency Range Channel Type",
        description: "Channel type for the scanned range (C.1.1.22.2.5)",
        value_type: :uint8,
        max_length: 1
      }
    }
  end

  # TLV 56 - Channel Assignment Configuration Settings (MULPI C.1.1.25)
  defp channel_assignment_subtlvs do
    %{
      1 => %{
        name: "Transmit Channel Assignment",
        description: "Upstream channel ID to include in the transmit channel set (C.1.1.25.1)",
        value_type: :uint8,
        max_length: 1
      },
      2 => %{
        name: "Receive Channel Assignment",
        description: "Downstream channel frequency to include in the receive channel set (C.1.1.25.2)",
        value_type: :uint32,
        max_length: 4
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
        name: "Vendor ID Encoding",
        description: "Three-byte vendor OUI qualifying this extension field (MULPI C.1.1.18.2)",
        value_type: :vendor_oui,
        max_length: 3,
        enum_values: nil
      },
      9 => %{
        name: "CM Attribute Masks",
        description: "Cable modem attribute masks (MULPI C.1.1.18.1.8)",
        value_type: :compound,
        max_length: :unlimited,
        enum_values: nil
      },
      10 => %{
        name: "IP Multicast Join Authorization",
        description: "IP multicast join authorization encoding (MULPI C.1.1.18.1.9)",
        value_type: :compound,
        max_length: :unlimited,
        enum_values: nil
      },
      11 => %{
        name: "Service Type Identifier",
        description: "Service type identifier used by the CMTS for provisioning (MULPI C.1.1.18.1.10)",
        value_type: :string,
        max_length: 16,
        enum_values: nil
      },
      12 => %{
        name: "DEMARC Auto Configuration",
        description: "DEMARC auto-configuration (DAC) encoding (MULPI C.1.1.18.1.11)",
        value_type: :compound,
        max_length: :unlimited,
        enum_values: nil
      }
    }
  end

  # ===========================================================================
  # DOCSIS Extension Field (43.x) subtype tables
  # Per CM-SP-MULPIv3.1 Annex C.1.1.18.1 / CL-SP-CANN 11.1.2 / DEMARCv1.0
  # ===========================================================================

  # 43.6 - Extended CMTS MIC Configuration Setting (MULPI C.1.1.18.1.6)
  defp extended_cmts_mic_subtlvs do
    %{
      1 => %{
        name: "Extended CMTS MIC HMAC Type",
        description: "1 = MD5 HMAC, 2 = MMH16 HMAC, 43 = vendor-specific (C.1.1.18.1.6.1)",
        value_type: :uint8,
        max_length: 1
      },
      2 => %{
        name: "Extended CMTS MIC Bitmap",
        description: "BITS encoding of top-level TLVs covered by the extended MIC (C.1.1.18.1.6.2)",
        value_type: :binary,
        max_length: :unlimited
      },
      3 => %{
        name: "Explicit Extended CMTS MIC Digest Subtype",
        description: "Calculated MIC digest using the configured HMAC type (C.1.1.18.1.6.3)",
        value_type: :binary,
        max_length: :unlimited
      }
    }
  end

  # 43.7 - SAV Authorization Encoding (MULPI C.1.1.18.1.7)
  defp sav_authorization_subtlvs do
    %{
      1 => %{
        name: "SAV Group Name",
        description: "Name of an SAV group configured in the CMTS (C.1.1.18.1.7.1)",
        value_type: :string,
        max_length: 15
      },
      2 => %{
        name: "SAV Static Prefix Rule",
        description: "SAV static prefix subtype encodings (C.1.1.18.1.7.2)",
        value_type: :compound,
        max_length: :unlimited
      }
    }
  end

  # 43.7.2 - SAV Static Prefix Rule sub-TLVs (MULPI C.1.1.18.1.7.2)
  defp sav_static_prefix_subtlvs do
    %{
      1 => %{
        name: "SAV Static Prefix Address",
        description: "IPv4 (4 bytes) or IPv6 (16 bytes) prefix address (C.1.1.18.1.7.2.1)",
        value_type: :binary,
        max_length: 16
      },
      2 => %{
        name: "SAV Static Prefix Length",
        description: "0..32 for IPv4 or 0..128 for IPv6 prefixes (C.1.1.18.1.7.2.2)",
        value_type: :uint8,
        max_length: 1
      }
    }
  end

  # 43.9 - Cable Modem Attribute Masks (MULPI C.1.1.18.1.8)
  defp cm_attribute_masks_subtlvs do
    %{
      1 => %{
        name: "CM Required Downstream Attribute Mask",
        description: "32-bit mask of channel attributes required for the CM (C.1.1.18.1.8.1)",
        value_type: :binary,
        max_length: 4
      },
      2 => %{
        name: "CM Downstream Forbidden Attribute Mask",
        description: "32-bit mask of channel attributes forbidden for the CM (C.1.1.18.1.8.2)",
        value_type: :binary,
        max_length: 4
      },
      3 => %{
        name: "CM Upstream Required Attribute Mask",
        description: "32-bit mask of channel attributes required for the CM (C.1.1.18.1.8.3)",
        value_type: :binary,
        max_length: 4
      },
      4 => %{
        name: "CM Upstream Forbidden Attribute Mask",
        description: "32-bit mask of channel attributes forbidden for the CM (C.1.1.18.1.8.4)",
        value_type: :binary,
        max_length: 4
      }
    }
  end

  # 43.10 - IP Multicast Join Authorization (MULPI C.1.1.18.1.9)
  defp ip_multicast_join_subtlvs do
    %{
      1 => %{
        name: "IP Multicast Profile Name",
        description: "Name of an IP multicast profile configured in the CMTS (C.1.1.18.1.9.1)",
        value_type: :string,
        max_length: 15
      },
      2 => %{
        name: "IP Multicast Join Authorization Static Session Rule",
        description: "Static session rule subtype encodings (C.1.1.18.1.9.2)",
        value_type: :compound,
        max_length: :unlimited
      },
      3 => %{
        name: "Maximum Multicast Sessions",
        description: "Maximum number of dynamically joined sessions, 0-65534 (C.1.1.18.1.9.3)",
        value_type: :uint16,
        max_length: 2
      }
    }
  end

  # 43.10.2 - Static Session Rule sub-TLVs (MULPI C.1.1.18.1.9.2)
  defp multicast_session_rule_subtlvs do
    %{
      1 => %{
        name: "Rule Priority",
        description: "0..255; higher values indicate higher priority (C.1.1.18.1.9.2.1)",
        value_type: :uint8,
        max_length: 1
      },
      2 => %{
        name: "Authorization Action",
        description: "0 = permit, 1 = deny (C.1.1.18.1.9.2.2)",
        value_type: :uint8,
        max_length: 1
      },
      3 => %{
        name: "Source Prefix Address",
        description: "IPv4 or IPv6 prefix for the multicast source (C.1.1.18.1.9.2.3)",
        value_type: :binary,
        max_length: 16
      },
      4 => %{
        name: "Source Prefix Length",
        description: "Most significant bits of the source prefix matched (C.1.1.18.1.9.2.4)",
        value_type: :uint8,
        max_length: 1
      },
      5 => %{
        name: "Group Prefix Address",
        description: "IPv4 or IPv6 prefix for the multicast group (C.1.1.18.1.9.2.5)",
        value_type: :binary,
        max_length: 16
      },
      6 => %{
        name: "Group Prefix Length",
        description: "Most significant bits of the group prefix matched (C.1.1.18.1.9.2.6)",
        value_type: :uint8,
        max_length: 1
      }
    }
  end

  # 43.12 - DEMARC Auto-Configuration sub-TLVs (DEMARCv1.0 Annex B)
  defp demarc_autoconfiguration_subtlvs do
    %{
      1 => %{
        name: "DAC Disable/Enable Configuration",
        description: "0 = disabled, 1 = enabled (DEMARCv1.0 Annex B.1)",
        value_type: :uint8,
        max_length: 1
      },
      2 => %{
        name: "DEMARC CMIM Encoding",
        description: "CM interface mask for the DEMARC device (DEMARCv1.0 Annex B.2)",
        value_type: :binary,
        max_length: :unlimited
      },
      3 => %{
        name: "Upstream Service Class Name",
        description: "Zero-terminated service class name, 2-16 bytes (DEMARCv1.0 Annex B.3)",
        value_type: :string_null,
        max_length: 16
      },
      4 => %{
        name: "Downstream Service Class Name",
        description: "Zero-terminated service class name, 2-16 bytes (DEMARCv1.0 Annex B.4)",
        value_type: :string_null,
        max_length: 16
      }
    }
  end

  # ===========================================================================
  # 43.5 - L2VPN Encoding subtree (CL-SP-CANN 11.1.2.1, CM-SP-L2VPN)
  # Value types are conservative (:binary/:compound) where the L2VPN spec
  # defines vendor- or deployment-specific lengths.
  # ===========================================================================
  defp l2vpn_encoding_subtlvs do
    %{
      1 => %{name: "VPN Identifier", description: "L2VPN identifier (CANN 11.1.2.1)", value_type: :binary, max_length: :unlimited},
      2 => %{name: "NSI Encapsulation Subtype", description: "Network system interface encapsulation (CANN 11.1.2.1)", value_type: :compound, max_length: :unlimited},
      3 => %{name: "eSAFE DHCP Snooping", description: "eSAFE DHCP snooping control (CANN 11.1.2.1)", value_type: :binary, max_length: :unlimited},
      4 => %{name: "CM Interface Mask Subtype", description: "CMIM for the L2VPN forwarding (CANN 11.1.2.1)", value_type: :binary, max_length: :unlimited},
      5 => %{name: "Attachment Group ID", description: "Attachment group ID (AGI) (CANN 11.1.2.1)", value_type: :binary, max_length: :unlimited},
      6 => %{name: "Source Attachment Individual ID", description: "SAII (CANN 11.1.2.1)", value_type: :binary, max_length: :unlimited},
      7 => %{name: "Target Attachment Individual ID", description: "TAII (CANN 11.1.2.1)", value_type: :binary, max_length: :unlimited},
      8 => %{name: "Upstream User Priority", description: "Upstream user priority subtype (CANN 11.1.2.1)", value_type: :uint8, max_length: 1},
      9 => %{name: "Downstream User Priority Range", description: "Downstream user priority range (CANN 11.1.2.1)", value_type: :binary, max_length: 2},
      10 => %{name: "L2VPN SA-Descriptor Subtype", description: "Security association descriptor (CANN 11.1.2.1)", value_type: :compound, max_length: :unlimited},
      12 => %{name: "Pseudowire Type", description: "Pseudowire type (CANN 11.1.2.1)", value_type: :binary, max_length: :unlimited},
      13 => %{name: "L2VPN Mode", description: "L2VPN mode (CANN 11.1.2.1)", value_type: :binary, max_length: :unlimited},
      14 => %{name: "TPID Translation", description: "Tag protocol identifier translation (CANN 11.1.2.1)", value_type: :compound, max_length: :unlimited},
      15 => %{name: "L2CP Processing", description: "Layer 2 control protocol processing (CANN 11.1.2.1)", value_type: :compound, max_length: :unlimited},
      16 => %{name: "Reserved (formerly DAC)", description: "Reserved (CANN 11.1.2.1)", value_type: :binary, max_length: :unlimited},
      18 => %{name: "Pseudowire Class", description: "Pseudowire class (CANN 11.1.2.1)", value_type: :binary, max_length: :unlimited},
      19 => %{name: "Service Delimiter", description: "Service delimiter (CANN 11.1.2.1)", value_type: :compound, max_length: :unlimited},
      20 => %{name: "VSI Encoding", description: "Virtual switch instance encoding (CANN 11.1.2.1)", value_type: :compound, max_length: :unlimited},
      21 => %{name: "BGP Attribute", description: "BGP attribute (CANN 11.1.2.1)", value_type: :compound, max_length: :unlimited},
      22 => %{name: "VPN-SG Attribute", description: "VPN-SG attribute (CANN 11.1.2.1)", value_type: :binary, max_length: :unlimited},
      23 => %{name: "Pseudowire Signaling", description: "Pseudowire signaling (CANN 11.1.2.1)", value_type: :binary, max_length: :unlimited},
      24 => %{name: "L2VPN SOAM Subtype", description: "Service OAM configuration (CANN 11.1.2.1)", value_type: :compound, max_length: :unlimited},
      25 => %{name: "Network Timing Profile Reference", description: "Network timing profile reference (CANN 11.1.2.1)", value_type: :binary, max_length: :unlimited},
      26 => %{name: "L2VPN DSID", description: "L2VPN downstream service ID (CANN 11.1.2.1)", value_type: :binary, max_length: 3},
      27 => %{name: "Multipoint Enable/Disable", description: "Multipoint forwarding control (CANN 11.1.2.1)", value_type: :binary, max_length: :unlimited},
      43 => %{name: "Vendor Specific L2VPN Subtype", description: "Vendor-specific L2VPN parameters (CANN 11.1.2.1)", value_type: :vendor, max_length: :unlimited},
      254 => %{name: "L2VPN Error Encoding", description: "L2VPN error encoding (CANN 11.1.2.1)", value_type: :compound, max_length: :unlimited}
    }
  end

  # 43.5.2 - NSI Encapsulation sub-TLVs (CANN 11.1.2.1, DPoE)
  defp service_multiplexing_subtlvs do
    %{
      1 => %{name: "Other", description: "Other NSI encapsulation (CANN 11.1.2.1)", value_type: :binary, max_length: :unlimited},
      2 => %{name: "IEEE 802.1Q Encapsulation", description: "802.1Q tag encapsulation (CANN 11.1.2.1)", value_type: :binary, max_length: 2},
      3 => %{name: "IEEE 802.1ad Encapsulation", description: "802.1ad S-tag/C-tag encapsulation (CANN 11.1.2.1)", value_type: :binary, max_length: 4},
      4 => %{name: "MPLS PW Encapsulation", description: "MPLS pseudowire encapsulation (CANN 11.1.2.1)", value_type: :compound, max_length: :unlimited},
      5 => %{name: "L2TPv3 Peer", description: "L2TPv3 peer encapsulation (CANN 11.1.2.1)", value_type: :binary, max_length: 16},
      6 => %{name: "IEEE 802.1ah Encapsulation", description: "802.1ah encapsulation (CANN 11.1.2.1)", value_type: :compound, max_length: :unlimited},
      8 => %{name: "IEEE 802.1ad S-TPID", description: "802.1ad S-TPID value (CANN 11.1.2.1)", value_type: :uint16, max_length: 2}
    }
  end

  # 43.5.2.4 - MPLS PW Encapsulation sub-TLVs (CANN 11.1.2.1, DPoE 2.0)
  defp mpls_service_multiplexing_value_subtlvs do
    %{
      1 => %{name: "MPLS Pseudowire ID", description: "CANN 11.1.2.1", value_type: :uint32, max_length: 4},
      2 => %{name: "MPLS Peer IP Address", description: "IPv4 or IPv6 peer address (CANN 11.1.2.1)", value_type: :binary, max_length: 16},
      3 => %{name: "Pseudowire Type", description: "CANN 11.1.2.1", value_type: :uint8, max_length: 1},
      4 => %{name: "MPLS Backup Pseudowire ID", description: "CANN 11.1.2.1", value_type: :uint32, max_length: 4},
      5 => %{name: "MPLS Backup Peer IP Address", description: "IPv4 or IPv6 peer address (CANN 11.1.2.1)", value_type: :binary, max_length: 16}
    }
  end

  # 43.5.2.6 - IEEE 802.1ah Encapsulation sub-TLVs (CANN 11.1.2.1, DPoE)
  defp dot1ah_encapsulation_subtlvs do
    %{
      1 => %{name: "IEEE 802.1ah I-Tag TCI", description: "Backbone service instance tag TCI (CANN 11.1.2.1)", value_type: :binary, max_length: :unlimited},
      2 => %{name: "IEEE 802.1ah B-DA", description: "Destination backbone edge bridge MAC address (CANN 11.1.2.1)", value_type: :mac_address, max_length: 6},
      3 => %{name: "IEEE 802.1ah B-Tag TCI", description: "16-bit B-Tag TCI (CANN 11.1.2.1)", value_type: :uint16, max_length: 2},
      4 => %{name: "IEEE 802.1ah I-Tag TPID", description: "16-bit I-Tag TPID (CANN 11.1.2.1)", value_type: :uint16, max_length: 2},
      5 => %{name: "IEEE 802.1ah I-PCP", description: "3-bit I-PCP (CANN 11.1.2.1)", value_type: :uint8, max_length: 1},
      6 => %{name: "IEEE 802.1ah I-DEI", description: "1-bit I-DEI (CANN 11.1.2.1)", value_type: :uint8, max_length: 1},
      7 => %{name: "IEEE 802.1ah I-UCA", description: "1-bit I-UCA (CANN 11.1.2.1)", value_type: :uint8, max_length: 1},
      8 => %{name: "IEEE 802.1ah I-SID", description: "24-bit backbone service instance identifier (CANN 11.1.2.1)", value_type: :binary, max_length: 3},
      9 => %{name: "IEEE 802.1ah B-Tag TPID", description: "16-bit B-Tag TPID (CANN 11.1.2.1)", value_type: :uint16, max_length: 2},
      10 => %{name: "IEEE 802.1ah B-PCP", description: "B-PCP bit (CANN 11.1.2.1)", value_type: :uint8, max_length: 1},
      11 => %{name: "IEEE 802.1ah B-DEI", description: "B-DEI bit (CANN 11.1.2.1)", value_type: :uint8, max_length: 1},
      12 => %{name: "IEEE 802.1ah B-VID", description: "12-bit B-VID (CANN 11.1.2.1)", value_type: :uint16, max_length: 2}
    }
  end

  # 43.5.14 - TPID Translation sub-TLVs (CANN 11.1.2.1)
  defp l2vpn_tpid_translation_subtlvs do
    %{
      1 => %{name: "Upstream TPID Translation", description: "CANN 11.1.2.1", value_type: :binary, max_length: 2},
      2 => %{name: "Downstream TPID Translation", description: "CANN 11.1.2.1", value_type: :binary, max_length: 2},
      3 => %{name: "Upstream S-TPID Translation", description: "CANN 11.1.2.1", value_type: :binary, max_length: 2},
      4 => %{name: "Downstream S-TPID Translation", description: "CANN 11.1.2.1", value_type: :binary, max_length: 2},
      5 => %{name: "Upstream B-TPID Translation", description: "CANN 11.1.2.1", value_type: :binary, max_length: 2},
      6 => %{name: "Downstream B-TPID Translation", description: "CANN 11.1.2.1", value_type: :binary, max_length: 2},
      7 => %{name: "Upstream I-TPID Translation", description: "CANN 11.1.2.1", value_type: :binary, max_length: 2},
      8 => %{name: "Downstream I-TPID Translation", description: "CANN 11.1.2.1", value_type: :binary, max_length: 2}
    }
  end

  # 43.5.15 - L2CP Processing sub-TLVs (CANN 11.1.2.1)
  defp l2vpn_l2cp_processing_subtlvs do
    %{
      1 => %{name: "L2CP Tunnel Mode", description: "CANN 11.1.2.1", value_type: :binary, max_length: :unlimited},
      2 => %{name: "L2CP D-MAC Address", description: "CANN 11.1.2.1", value_type: :mac_address, max_length: 6},
      3 => %{name: "L2CP L2PT D-MAC Address", description: "CANN 11.1.2.1", value_type: :mac_address, max_length: 6},
      4 => %{name: "L2CP Filter", description: "CANN 11.1.2.1", value_type: :binary, max_length: :unlimited}
    }
  end

  # 43.5.19 - Service Delimiter sub-TLVs (CANN 11.1.2.1)
  defp l2vpn_service_delimiter_subtlvs do
    %{
      1 => %{name: "C-VID", description: "Customer VLAN ID (CANN 11.1.2.1)", value_type: :uint16, max_length: 2},
      2 => %{name: "S-VID", description: "Service VLAN ID (CANN 11.1.2.1)", value_type: :uint16, max_length: 2},
      3 => %{name: "I-SID", description: "Backbone service instance ID (CANN 11.1.2.1)", value_type: :binary, max_length: 3},
      4 => %{name: "B-VID", description: "Backbone VLAN ID (CANN 11.1.2.1)", value_type: :uint16, max_length: 2}
    }
  end

  # 43.5.20 - VSI Encoding sub-TLVs (CANN 11.1.2.1)
  defp l2vpn_vsi_encoding_subtlvs do
    %{
      1 => %{name: "VPLS Class", description: "CANN 11.1.2.1", value_type: :binary, max_length: :unlimited},
      2 => %{name: "E-Tree Role", description: "CANN 11.1.2.1", value_type: :binary, max_length: :unlimited},
      3 => %{name: "E-Tree Root VID", description: "CANN 11.1.2.1", value_type: :uint16, max_length: 2},
      4 => %{name: "E-Tree Leaf VID", description: "CANN 11.1.2.1", value_type: :uint16, max_length: 2}
    }
  end

  # 43.5.21 - BGP Attribute sub-TLVs (CANN 11.1.2.1)
  defp l2vpn_bgp_attribute_subtlvs do
    %{
      1 => %{name: "BGP VPNID", description: "CANN 11.1.2.1", value_type: :binary, max_length: :unlimited},
      2 => %{name: "Route Distinguisher", description: "CANN 11.1.2.1", value_type: :binary, max_length: 8},
      3 => %{name: "Route Target (import)", description: "CANN 11.1.2.1", value_type: :binary, max_length: 8},
      4 => %{name: "Route Target (export)", description: "CANN 11.1.2.1", value_type: :binary, max_length: 8},
      5 => %{name: "CE-ID or VE-ID", description: "CANN 11.1.2.1", value_type: :binary, max_length: :unlimited}
    }
  end

  # 43.5.24 - L2VPN SOAM sub-TLVs (CANN 11.1.2.1)
  defp l2vpn_soam_subtlvs do
    %{
      1 => %{name: "MEP Configuration", description: "Maintenance end point configuration (CANN 11.1.2.1)", value_type: :compound, max_length: :unlimited},
      2 => %{name: "Remote MEP Configuration", description: "Remote maintenance end point configuration (CANN 11.1.2.1)", value_type: :compound, max_length: :unlimited},
      3 => %{name: "Fault Management Configuration", description: "CANN 11.1.2.1", value_type: :compound, max_length: :unlimited},
      4 => %{name: "Performance Management Configuration", description: "CANN 11.1.2.1", value_type: :compound, max_length: :unlimited}
    }
  end

  # 43.5.24.1 / 43.5.24.2 - (Remote) MEP Configuration sub-TLVs (CANN 11.1.2.1)
  defp l2vpn_soam_mep_config_subtlvs do
    %{
      1 => %{name: "MD Level", description: "Maintenance domain level (CANN 11.1.2.1)", value_type: :uint8, max_length: 1},
      2 => %{name: "MD Name", description: "Maintenance domain name (CANN 11.1.2.1)", value_type: :string, max_length: :unlimited},
      3 => %{name: "MA Name", description: "Maintenance association name (CANN 11.1.2.1)", value_type: :string, max_length: :unlimited},
      4 => %{name: "MEP ID", description: "Maintenance end point ID (CANN 11.1.2.1)", value_type: :uint16, max_length: 2}
    }
  end

  # 43.5.24.3 - Fault Management Configuration sub-TLVs (CANN 11.1.2.1)
  defp l2vpn_soam_fault_mgmt_subtlvs do
    %{
      1 => %{name: "Continuity Check Messages", description: "CANN 11.1.2.1", value_type: :binary, max_length: :unlimited},
      2 => %{name: "Enable Loopback Reply Messages", description: "CANN 11.1.2.1", value_type: :binary, max_length: :unlimited},
      3 => %{name: "Enable Linktrace Messages", description: "CANN 11.1.2.1", value_type: :binary, max_length: :unlimited}
    }
  end

  # 43.5.24.4 - Performance Management Configuration sub-TLVs (CANN 11.1.2.1)
  defp l2vpn_soam_perf_mgmt_subtlvs do
    %{
      1 => %{name: "Frame Delay Measurement", description: "CANN 11.1.2.1", value_type: :binary, max_length: :unlimited},
      2 => %{name: "Frame Loss Measurement", description: "CANN 11.1.2.1", value_type: :binary, max_length: :unlimited}
    }
  end

  # 43.5.254 - L2VPN Error Encoding sub-TLVs (CANN 11.1.2.1)
  defp l2vpn_error_subtlvs do
    %{
      1 => %{name: "L2VPN Errored Parameter", description: "CANN 11.1.2.1", value_type: :binary, max_length: :unlimited},
      2 => %{name: "L2VPN Confirmation Code", description: "CANN 11.1.2.1", value_type: :uint8, max_length: 1},
      3 => %{name: "L2VPN Error Message Subtype", description: "CANN 11.1.2.1", value_type: :string, max_length: :unlimited}
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
        value_type: :binary,
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

  # =============================================================================
  # DOCSIS 3.1 OFDM/OFDMA Profile Sub-TLVs (TLVs 62-63)
  # =============================================================================



  # Extended compound TLV sub-TLVs (TLVs 62-85)
  defp extended_compound_subtlvs(parent_type) do
    case parent_type do
      64 -> cmts_static_multicast_session_subtlvs()
      65 -> l2vpn_mac_aging_subtlvs()
      67 -> subscriber_mgmt_cpe_ipv6_subtlvs()
      69 -> mac_address_learning_control_subtlvs()
      70 -> aggregate_service_flow_subtlvs()
      71 -> aggregate_service_flow_subtlvs()
      72 -> metro_ethernet_service_subtlvs()
      73 -> network_timing_profile_subtlvs()
      74 -> energy_parameters_subtlvs()
      79 -> uni_control_encodings_subtlvs()
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
  defp snmpv1v2c_coexistence_subtlvs do
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
  defp snmp_transport_address_access_subtlvs do
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
  defp snmpv3_access_view_subtlvs do
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



  # =============================================================================
  # Extended Compound TLV Sub-TLV Specifications (TLVs 66-85)
  # =============================================================================


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




  # =============================================================================
  # Extended TLV Sub-TLV Specifications (TLVs 86-199)
  # =============================================================================




  # =============================================================================
  # Remaining Compound TLV Sub-TLVs (TLVs 77-85) - DOCSIS 3.1 Advanced Features
  # =============================================================================









  # =============================================================================
  # Remaining Extended TLV Sub-TLVs (TLVs 87-107) - Complete Implementation
  # =============================================================================













  # ===========================================================================
  # Extended TLVs 64-79 - spec-verified tables
  # ===========================================================================

  # TLV 64 - CMTS Static Multicast Session Encoding (MULPI C.1.1.27)
  defp cmts_static_multicast_session_subtlvs do
    %{
      1 => %{
        name: "Static Multicast Group Encoding",
        description: "Multicast group address, IPv4 (4 bytes) or IPv6 (16 bytes) (C.1.1.27.1)",
        value_type: :binary,
        max_length: 16
      },
      2 => %{
        name: "Static Multicast Source Encoding",
        description: "Source IP address, IPv4 (4 bytes) or IPv6 (16 bytes) (C.1.1.27.2)",
        value_type: :binary,
        max_length: 16
      },
      3 => %{
        name: "Static Multicast CMIM Encoding",
        description: "CM interface mask for the static session (C.1.1.27.3)",
        value_type: :binary,
        max_length: :unlimited
      }
    }
  end

  # TLV 65 - L2VPN MAC Aging Encoding (CL-SP-CANN 11.1.2.3)
  defp l2vpn_mac_aging_subtlvs do
    %{
      1 => %{
        name: "L2VPN MAC Aging Mode",
        description: "MAC aging mode (CANN 11.1.2.3)",
        value_type: :uint8,
        max_length: 1
      }
    }
  end

  # TLV 72 - Metro Ethernet Service Profile (CL-SP-CANN 11.1.7, DPoE 2.0)
  defp metro_ethernet_service_subtlvs do
    %{
      1 => %{
        name: "MESP Reference",
        description: "Metro Ethernet service profile reference, 1-255 (MULPI C.2.2.10.1)",
        value_type: :uint8,
        max_length: 1
      },
      2 => %{
        name: "MESP Bandwidth Profile",
        description: "MESP bandwidth profile encodings (CANN 11.1.7)",
        value_type: :compound,
        max_length: :unlimited
      },
      3 => %{
        name: "MESP Name",
        description: "Zero-terminated Metro Ethernet service profile name (MULPI C.2.2.10.3)",
        value_type: :string_null,
        max_length: :unlimited
      }
    }
  end

  # TLV 72.2 - MESP Bandwidth Profile sub-TLVs (CL-SP-CANN 11.1.7)
  defp mesp_bandwidth_profile_subtlvs do
    %{
      1 => %{name: "MESP-BP Committed Information Rate", description: "CANN 11.1.7", value_type: :uint32, max_length: 4},
      2 => %{name: "MESP-BP Committed Burst Size", description: "CANN 11.1.7", value_type: :uint32, max_length: 4},
      3 => %{name: "MESP-BP Excess Information Rate", description: "CANN 11.1.7", value_type: :uint32, max_length: 4},
      4 => %{name: "MESP-BP Excess Burst Size", description: "CANN 11.1.7", value_type: :uint32, max_length: 4},
      5 => %{name: "MESP-BP Coupling Flag", description: "CANN 11.1.7", value_type: :uint8, max_length: 1},
      6 => %{name: "MESP-BP Color Mode", description: "CANN 11.1.7", value_type: :compound, max_length: :unlimited},
      7 => %{name: "MESP-BP Color Marking", description: "CANN 11.1.7", value_type: :compound, max_length: :unlimited}
    }
  end

  # TLV 73 - Network Timing Profile (MULPI C.1.2.19)
  defp network_timing_profile_subtlvs do
    %{
      1 => %{
        name: "Network Timing Profile Reference",
        description: "Network timing profile reference (C.1.2.19.1)",
        value_type: :uint16,
        max_length: 2
      },
      2 => %{
        name: "Network Timing Profile Name",
        description: "Zero-terminated network timing profile name (C.1.2.19.2)",
        value_type: :string_null,
        max_length: :unlimited
      }
    }
  end

  # TLV 74 - Energy Management Parameter Encoding (MULPI C.1.1.30)
  defp energy_parameters_subtlvs do
    %{
      1 => %{
        name: "Energy Management Feature Control",
        description: "Enabled energy management features bitmask (C.1.1.30.1)",
        value_type: :binary,
        max_length: 4
      },
      2 => %{
        name: "Energy Management 1x1 Mode Encodings",
        description: "EM 1x1 mode activity detection parameters (C.1.1.30.2)",
        value_type: :compound,
        max_length: :unlimited
      },
      3 => %{
        name: "Energy Management Cycle Period",
        description: "Minimum seconds between EM-REQ transactions (C.1.1.30.5)",
        value_type: :uint16,
        max_length: 2
      },
      4 => %{
        name: "Energy Management DOCSIS Light Sleep Mode Encodings",
        description: "DLS mode activity detection parameters (C.1.1.30.3)",
        value_type: :compound,
        max_length: :unlimited
      }
    }
  end

  # TLV 79 - UNI Control Encodings (MULPI C.3.3, DPoE 2.0)
  defp uni_control_encodings_subtlvs do
    %{
      1 => %{
        name: "Context CMIM",
        description: "CMIM encoding representing the given UNI (C.3.3.1)",
        value_type: :binary,
        max_length: :unlimited
      },
      2 => %{
        name: "UNI Admin Status",
        description: "0 = disabled, 1 = enabled (C.3.3.2)",
        value_type: :uint8,
        max_length: 1
      },
      3 => %{
        name: "UNI Auto-Negotiation Status",
        description: "0 = disabled, 1 = enabled (C.3.3.3)",
        value_type: :uint8,
        max_length: 1
      },
      4 => %{
        name: "UNI Operating Speed",
        description: "Operating or preferred speed for the UNI port (C.3.3.4)",
        value_type: :uint8,
        max_length: 1
      },
      5 => %{
        name: "UNI Duplex",
        description: "Duplex or preferred duplex configuration (C.3.3.5)",
        value_type: :uint8,
        max_length: 1
      },
      6 => %{
        name: "EEE Status",
        description: "Energy Efficient Ethernet admin status (C.3.3.6)",
        value_type: :uint8,
        max_length: 1
      },
      7 => %{
        name: "Maximum Frame Size",
        description: "MTU for the given UNI (C.3.3.7)",
        value_type: :uint16,
        max_length: 2
      },
      8 => %{
        name: "PoE Status",
        description: "Power over Ethernet status (C.3.3.8)",
        value_type: :uint8,
        max_length: 1
      },
      9 => %{
        name: "Media Type",
        description: "UNI media type (C.3.3.9)",
        value_type: :uint8,
        max_length: 1
      }
    }
  end

  # TLV 69 - MAC Address Learning Control Encoding (MULPI C.1.2.18)
  defp mac_address_learning_control_subtlvs do
    %{
      1 => %{
        name: "MAC Address Learning Control",
        description: "0 = do not remove learned MAC addresses (C.1.2.18.1)",
        value_type: :uint8,
        max_length: 1
      },
      2 => %{
        name: "MAC Address Learning Holdoff Timer",
        description: "Holdoff timer in seconds, 0-10 (C.1.2.18.2)",
        value_type: :uint8,
        max_length: 1
      }
    }
  end

  # TLV 74.2 / 74.4 - EM mode activity detection wrappers (MULPI C.1.1.30.4)
  defp energy_mgmt_mode_subtlvs do
    %{
      1 => %{
        name: "Downstream Activity Detection Parameters",
        description: "Downstream activity detection (C.1.1.30.4.1)",
        value_type: :compound,
        max_length: :unlimited
      },
      2 => %{
        name: "Upstream Activity Detection Parameters",
        description: "Upstream activity detection (C.1.1.30.4.2)",
        value_type: :compound,
        max_length: :unlimited
      }
    }
  end

  # TLV 74.[2/4].1 - Downstream Activity Detection (MULPI C.1.1.30.4.1)
  defp em_downstream_activity_subtlvs do
    %{
      1 => %{name: "Downstream Entry Bitrate Threshold", description: "bps (C.1.1.30.4.1.1)", value_type: :uint32, max_length: 4},
      2 => %{name: "Downstream Entry Time Threshold", description: "seconds (C.1.1.30.4.1.2)", value_type: :uint16, max_length: 2},
      3 => %{name: "Downstream Exit Bitrate Threshold", description: "bps (C.1.1.30.4.1.3)", value_type: :uint32, max_length: 4},
      4 => %{name: "Downstream Exit Time Threshold", description: "seconds (C.1.1.30.4.1.4)", value_type: :uint16, max_length: 2}
    }
  end

  # TLV 74.[2/4].2 - Upstream Activity Detection (MULPI C.1.1.30.4.2)
  defp em_upstream_activity_subtlvs do
    %{
      1 => %{name: "Upstream Entry Bitrate Threshold", description: "bps (C.1.1.30.4.2.1)", value_type: :uint32, max_length: 4},
      2 => %{name: "Upstream Entry Time Threshold", description: "seconds (C.1.1.30.4.2.2)", value_type: :uint16, max_length: 2},
      3 => %{name: "Upstream Exit Bitrate Threshold", description: "bps (C.1.1.30.4.2.3)", value_type: :uint32, max_length: 4},
      4 => %{name: "Upstream Exit Time Threshold", description: "seconds (C.1.1.30.4.2.4)", value_type: :uint16, max_length: 2}
    }
  end

  # TLV 72.2.6 / 72.2.7 - MESP-BP Color Mode / Color Marking (CANN 11.1.7)
  defp mesp_color_mode_subtlvs do
    %{
      1 => %{name: "MESP-BP-CM Color Identification Field", description: "CANN 11.1.7", value_type: :binary, max_length: :unlimited},
      2 => %{name: "MESP-BP-CM Color Identification Field Value", description: "CANN 11.1.7", value_type: :binary, max_length: :unlimited}
    }
  end

  defp mesp_color_marking_subtlvs do
    %{
      1 => %{name: "MESP-BP-CR Color Marking Field", description: "CANN 11.1.7", value_type: :binary, max_length: :unlimited},
      2 => %{name: "MESP-BP-CR Color Marking Field Value", description: "CANN 11.1.7", value_type: :binary, max_length: :unlimited}
    }
  end
end
