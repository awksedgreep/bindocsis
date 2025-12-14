# DOCSIS TLV Quick Reference

**Source:** Verified against CableLabs CANN-I22-230308, MULPI, and docsis project symtable.h
**Last Updated:** 2024-12-13

---

## Top-Level TLVs (CANN-I22 Section 11.1)

### DOCSIS 1.0/1.1 Core TLVs (0-50)

| TLV | Name | Type | Notes |
|-----|------|------|-------|
| 0 | Pad | - | Padding byte |
| 1 | Downstream Frequency | uint32 | Hz (88M-1008M) |
| 2 | Upstream Channel ID | uint8 | Channel identifier |
| 3 | Network Access Control | uint8 | 0=disabled, 1=enabled |
| 4 | Class of Service | compound | Legacy QoS |
| 5 | Modem Capabilities | compound | CM capabilities |
| 6 | CM MIC | binary(16) | MD5 digest |
| 7 | CMTS MIC | binary(16) | MD5 digest |
| 8 | Vendor ID | binary(3) | OUI |
| 9 | SW Upgrade Filename | string | TFTP filename |
| 10 | SNMP Write Access Control | compound | SNMP config |
| 11 | SNMP MIB Object | compound | MIB settings |
| 12 | Modem IP Address | ipv4 | CM IP |
| 13 | Services Not Available Response | string | |
| 14 | CPE Ethernet MAC Address | mac | |
| 15 | Telephone Settings Option | compound | |
| 17 | Baseline Privacy | compound | BPI+ config |
| 18 | Max Number of CPEs | uint8 | 1-254 |
| 19 | TFTP Server Timestamp | uint32 | |
| 20 | TFTP Server Provisioned Modem Address | ipv4 | |
| 21 | SW Upgrade IPv4 TFTP Server | ipv4 | |
| 22 | Upstream Packet Classification | compound | US classifier |
| 23 | Downstream Packet Classification | compound | DS classifier |
| 24 | Upstream Service Flow | compound | US QoS |
| 25 | Downstream Service Flow | compound | DS QoS |
| 26 | Payload Header Suppression | compound | PHS rules |
| 27 | HMAC Digest | binary | |
| 28 | Maximum Number of Classifiers | uint16 | |
| 29 | Privacy Enable | uint8 | |
| 30 | Authorization Block | binary | |
| 31 | Key Sequence Number | uint8 | |
| 32 | Manufacturer CVC | binary | |
| 33 | Co-Signer CVC | binary | |
| 34 | SNMPv3 Kickstart Value | compound | |
| 35 | Subscriber Mgmt Control | compound | |
| 36 | Subscriber Mgmt CPE IPv4 List | compound | |
| 37 | Subscriber Mgmt Filter Groups | compound | |
| 38 | SNMPv3 Notification Receiver | compound | |
| 39 | Enable 2.0 Mode | uint8 | |
| 40 | Enable Test Modes | uint8 | |
| 41 | Downstream Channel List | compound | DS channel config |
| 42 | Static Multicast MAC Address | mac | |
| 43 | Vendor Specific | compound | Extensions |
| 44 | Duplex Filter | compound | |
| 45 | DUT Filtering | compound | |
| 46 | Transmit Channel Configuration | compound | |
| 47 | Service Flow SID Cluster Assignment | compound | |
| 48 | Receive Channel Profile | compound | |
| 49 | Receive Channel Configuration | compound | |
| 50 | DSID Encodings | compound | |

### DOCSIS 3.0/3.1 TLVs (51-85)

| TLV | Name | Type |
|-----|------|------|
| 51 | Security Association Encoding | compound |
| 52 | Initializing Channel Timeout | uint16 |
| 53 | SNMPv1v2c Coexistence | compound |
| 54 | SNMPv3 Access View Configuration | compound |
| 55 | SNMP CPE Access Control | compound |
| 56 | Channel Assignment Configuration | compound |
| 57 | CM Initialization Reason | uint8 |
| 58 | SW Upgrade IPv6 TFTP Server | ipv6 |
| 59 | TFTP Server Provisioned Modem IPv6 Address | ipv6 |
| 60 | Upstream Drop Packet Classification | compound |
| 61 | Subscriber Mgmt CPE IPv6 Prefix List | compound |
| 62 | Upstream Drop Classifier Group ID | uint8 |
| 63 | Subscriber Mgmt Control Max CPE IPv6 Prefix | uint16 |
| 64 | CMTS Static Multicast Session Encoding | compound |
| 65 | L2VPN MAC Aging Encoding | compound |
| 66 | Management Event Control Encoding | compound |
| 67 | Subscriber Mgmt CPE IPv6 Prefix List Default | compound |
| 68 | Upstream Target Buffer Configuration | compound |
| 69 | MAC Address Learning Control Encoding | compound |
| 70 | Upstream Aggregate Service Flow | compound |
| 71 | Downstream Aggregate Service Flow | compound |
| 72 | Metro Ethernet Service Profile | compound |
| 73 | Network Timing Profile | compound |
| 74 | Energy Management Parameter Encoding | compound |
| 75 | Energy Mgt Mode Indicator | uint8 |
| 76 | CM Upstream AQM Disable | uint8 |
| 77 | DOCSIS Time Protocol Encoding | compound |
| 78 | Energy Management Identifier List for CM | compound |
| 79 | UNI Control Encoding | compound |
| 80 | Energy Management DOCSIS Light Sleep Encodings | compound |
| 81 | Manufacturer CVC Chain | binary |
| 82 | Co-Signer CVC Chain | binary |
| 83 | DTP Mode Configuration | compound |
| 84 | L2CP Management | compound |
| 85 | Diplexer Band Edge | compound |

### DOCSIS 4.0 TLVs (86-105)

| TLV | Name | Type |
|-----|------|------|
| 86-105 | DOCSIS 4.0/FDX Extensions | various |
| 255 | End-of-Data | - |

---

## Sub-TLV Specifications

### TLV 4: Class of Service Sub-TLVs

| Sub-TLV | Name | Type | Range |
|---------|------|------|-------|
| 4.1 | Class ID | uint8 | 1-16 |
| 4.2 | Maximum Downstream Rate | uint32 | bps |
| 4.3 | Maximum Upstream Rate | uint32 | bps |
| 4.4 | Upstream Channel Priority | uint8 | 0-7 |
| 4.5 | Guaranteed Minimum Upstream Rate | uint32 | bps |
| 4.6 | Maximum Upstream Burst Size | uint16 | bytes |
| 4.7 | Privacy Enable | uint8 | 0-1 |

### TLV 5: Modem Capabilities Sub-TLVs (CANN-I22 Section 11.1.1)

#### DOCSIS 1.1 (5.1-5.12)
| Sub-TLV | Name | Type |
|---------|------|------|
| 5.1 | Concatenation Support | uint8 |
| 5.2 | DOCSIS Version | uint8 |
| 5.3 | Fragmentation Support | uint8 |
| 5.4 | Payload Header Suppression Support | uint8 |
| 5.5 | IGMP Support | uint8 |
| 5.6 | Privacy Support | uint8 |
| 5.7 | Downstream SAID Support | uint8 |
| 5.8 | Upstream Service Flow Support | uint8 |
| 5.9 | Optional Filtering Support | uint8 |
| 5.10 | Transmit Pre-Equalizer Taps | uint8 |
| 5.11 | Number of Transmit Pre-Equalizer Taps | uint8 |
| 5.12 | DCC Support | uint8 |

#### DOCSIS 2.0 (5.13-5.16)
| Sub-TLV | Name | Type |
|---------|------|------|
| 5.13 | IP Filters Support | uint16 |
| 5.14 | LLC Filters Support | uint16 |
| 5.15 | Expanded Unicast SID Space | uint8 |
| 5.16 | Ranging Hold-Off Support | binary |

#### L2VPN (5.17-5.19)
| Sub-TLV | Name | Type |
|---------|------|------|
| 5.17 | L2VPN Capability | uint8 |
| 5.18 | L2VPN eSAFE Host Capability | binary |
| 5.19 | Downstream Unencrypted Traffic (DUT) Filtering | uint8 |

#### DOCSIS 3.0 (5.20-5.43)
| Sub-TLV | Name | Type |
|---------|------|------|
| 5.20 | Upstream Frequency Range Support | uint8 |
| 5.21 | Upstream SC-QAM Symbol Rate Support | uint8 |
| 5.22 | Selectable Active Code Mode 2 Support | uint8 |
| 5.23 | Code Hopping Mode 2 Support | uint8 |
| 5.24 | Multiple Transmit SC-QAM Channel Support | uint8 |
| 5.25 | 5.12 Msps Upstream Transmit SC-QAM Channel Support | uint8 |
| 5.26 | 2.56 Msps Upstream Transmit SC-QAM Channel Support | uint8 |
| 5.27 | Total SID Cluster Support | uint8 |
| 5.28 | SID Clusters per Service Flow Support | uint8 |
| 5.29 | Multiple Receive SC-QAM Channel Support | uint8 |
| 5.30 | Total Downstream Service ID (DSID) Support | uint8 |
| 5.31 | Resequencing Downstream Service ID (DSID) Support | uint8 |
| 5.32 | Multicast Downstream Service ID (DSID) Support | uint8 |
| 5.33 | Multicast DSID Forwarding | uint8 |
| 5.34 | Frame Control Type Forwarding Capability | uint8 |
| 5.35 | DPV Capability | uint8 |
| 5.36 | Unsolicited Grant Service/Upstream Service Flow Support | uint8 |
| 5.37 | MAP and UCD Receipt Support | uint8 |
| 5.38 | Upstream Drop Classifier Support | uint16 |
| 5.39 | IPv6 Support | uint8 |
| 5.40 | Extended Upstream Transmit Power Capability | uint8 |
| 5.41 | Optional 802.1ad, 802.1ah, MPLS Classification Support | binary |
| 5.42 | D-ONU Capabilities | compound |
| 5.43 | Reserved | binary |

#### DOCSIS 3.1 (5.44-5.62)
| Sub-TLV | Name | Type |
|---------|------|------|
| 5.44 | Energy Management Capabilities | binary |
| 5.45 | C-DOCSIS Capability Encoding | uint8 |
| 5.46 | CM-STATUS-ACK | uint8 |
| 5.47 | Energy Management Preferences | binary |
| 5.48 | Extended Packet Length Support Capability | uint8 |
| 5.49 | Multiple Receive OFDM Channel Support | uint8 |
| 5.50 | Multiple Transmit OFDMA Channel Support | uint8 |
| 5.51 | Downstream OFDM Profile Support | binary |
| 5.52 | Downstream OFDM Channel Subcarrier QAM Modulation Support | binary |
| 5.53 | Upstream OFDMA Channel Subcarrier QAM Modulation Support | binary |
| 5.54 | Downstream Lower Band Edge Configuration | uint8 |
| 5.55 | Downstream Upper Band Edge Configuration | uint8 |
| 5.56 | Diplexer Upstream Upper Band Edge Configuration | uint8 |
| 5.57 | DOCSIS Time Protocol Mode | uint8 |
| 5.58 | DOCSIS Time Protocol Performance Support | uint8 |
| 5.59 | Pmax | uint16 |
| 5.60 | Diplexer Downstream Lower Band Edge Options | binary |
| 5.61 | Diplexer Downstream Upper Band Edge Options | binary |
| 5.62 | Diplexer Upstream Upper Band Edge Options | binary |

#### DOCSIS 4.0 FDX (5.63-5.82)
| Sub-TLV | Name | Type |
|---------|------|------|
| 5.63 | Advanced Band Plan Capability | binary |
| 5.64 | FDX DS State Lock (Deprecated) | uint8 |
| 5.65 | FDX Switching Software Timing Uncertainty | uint8 |
| 5.66 | FDX DS to US Switching Time | uint8 |
| 5.67 | FDX US to DS Switching Time - CWT | uint8 |
| 5.68 | RxMER Measurement Convergence Time | uint8 |
| 5.69 | t-ds-reacquisition Capability CWT | uint8 |
| 5.70 | Simultaneous Data Transmission Capability | uint8 |
| 5.71 | Extended Service Flow SID Cluster Assignments Support | uint8 |
| 5.72 | Echo Cancelling RBA Sub-band Direction Sets Supported | uint8 |
| 5.73 | Low Latency Support | uint8 |
| 5.74 | Absolute Queue-Depth Request Support | uint8 |
| 5.75 | Distributed HQoS Support | uint8 |
| 5.76-5.82 | Advanced Diplexer/Band Edge Options | binary |

### TLV 17: Baseline Privacy Sub-TLVs

| Sub-TLV | Name | Type | Default |
|---------|------|------|---------|
| 17.1 | Authorize Wait Timeout | uint32 | 10s |
| 17.2 | Reauthorize Wait Timeout | uint32 | 10s |
| 17.3 | Authorization Grace Timeout | uint32 | 600s |
| 17.4 | Operational Wait Timeout | uint32 | 10s |
| 17.5 | Rekey Wait Timeout | uint32 | 10s |
| 17.6 | TEK Grace Timeout | uint32 | 600s |
| 17.7 | Authorize Reject Wait Timeout | uint32 | 60s |
| 17.8 | SA Map Wait Timeout | uint32 | 1s |
| 17.9 | SA Map Max Retries | uint32 | 4 |

### TLV 22/23/60: Packet Classification Sub-TLVs (CANN-I22 Section 11.1.4)

| Sub-TLV | Name | Type |
|---------|------|------|
| x.1 | Classifier Reference | uint8 |
| x.2 | Classifier Identifier | uint16 |
| x.3 | Service Flow Reference | uint16 |
| x.4 | Service Flow Identifier | uint32 |
| x.5 | Rule Priority | uint8 |
| x.6 | Classifier Activation State | uint8 |
| x.7 | Dynamic Service Change Action | uint8 |
| x.8 | Classifier Error Encodings | compound |
| x.9 | IPv4 Packet Classification Encodings | compound |
| x.10 | Ethernet LLC Packet Classification Encodings | compound |
| x.11 | IEEE 802.1P/Q Packet Classification Encodings | compound |
| x.12 | IPv6 Packet Classification Encodings | compound |
| x.13 | CM Interface Mask Encoding | binary |
| x.14 | IEEE 802.1ad S-VLAN Packet Classification | compound |
| x.15 | IEEE 802.1ah I-TAG Packet Classification | compound |
| x.43 | Vendor Specific Classifier Parameters | vendor |

### TLV 24/25/70/71: Service Flow Sub-TLVs (CANN-I22 Section 11.1.3)

#### Common Sub-TLVs (all service flows)
| Sub-TLV | Name | Type |
|---------|------|------|
| x.1 | Service Flow Reference | uint16 |
| x.2 | Service Flow Identifier | uint32 |
| x.3 | Service Identifier | uint16 |
| x.4 | Service Class Name | string |
| x.5 | Service Flow Error Encoding | compound |
| x.6 | QoS Parameter Set Type | uint8 |
| x.7 | Traffic Priority | uint8 |
| x.8 | Maximum Sustained Traffic Rate | uint32 |
| x.9 | Maximum Traffic Burst | uint32 |
| x.10 | Minimum Reserved Traffic Rate | uint32 |
| x.11 | Assumed Minimum Reserved Rate Packet Size | uint16 |
| x.12 | Timeout for Active QoS Parameters | uint16 |
| x.13 | Timeout for Admitted QoS Parameters | uint16 |
| x.23 | IP ToS Overwrite | uint16 |
| x.27 | Peak Traffic Rate | uint32 |
| x.31 | Required Attribute Mask | binary |
| x.32 | Forbidden Attribute Mask | binary |
| x.33 | Attribute Aggregation Rule Mask | binary |

#### Upstream-only (TLV 24/70)
| Sub-TLV | Name | Type |
|---------|------|------|
| 24.14 | Maximum Concatenated Burst | uint16 |
| 24.15 | Service Flow Scheduling Type | uint8 |
| 24.16 | Request/Transmission Policy | uint32 |
| 24.17 | Nominal Polling Interval | uint32 |
| 24.18 | Tolerated Poll Jitter | uint32 |
| 24.19 | Unsolicited Grant Size | uint16 |
| 24.20 | Nominal Grant Interval | uint32 |
| 24.21 | Tolerated Grant Jitter | uint32 |
| 24.22 | Grants Per Interval | uint8 |

#### Downstream-only (TLV 25/71)
| Sub-TLV | Name | Type |
|---------|------|------|
| 25.14 | Maximum Downstream Latency | uint32 |
| 25.17 | Downstream Resequencing | compound |

### TLV 34: SNMPv3 Kickstart Sub-TLVs

| Sub-TLV | Name | Type |
|---------|------|------|
| 34.1 | Security Name | string(16) |
| 34.2 | Manager Public Number | binary |

### TLV 38: SNMPv3 Notification Receiver Sub-TLVs

| Sub-TLV | Name | Type |
|---------|------|------|
| 38.1 | IPv4 Address | ipv4 |
| 38.2 | UDP Port | uint16 |
| 38.3 | Trap Type | uint16 |
| 38.4 | Timeout | uint16 |
| 38.5 | Retries | uint16 |
| 38.6 | Filter OID | binary |
| 38.7 | Security Name | string(16) |
| 38.8 | IPv6 Address | ipv6 |

### TLV 41: Downstream Channel List Sub-TLVs

| Sub-TLV | Name | Type |
|---------|------|------|
| 41.1 | Single Downstream Channel | compound |
| 41.2 | DS Channel Range | compound |
| 41.3 | Default Scanning Timeout | uint16 |

### TLV 43: Vendor Specific Sub-TLVs (MULPI Annex C.1.1.18.1)

| Sub-TLV | Name | Type |
|---------|------|------|
| 43.1 | CM Load Balancing Policy ID | uint32 |
| 43.2 | CM Load Balancing Priority | uint32 |
| 43.3 | CM Load Balancing Group ID | uint32 |
| 43.4 | CM Ranging Class ID Extension | uint32 |
| 43.5 | L2VPN Encoding | compound |

### TLV 46: Transmit Channel Configuration Sub-TLVs

| Sub-TLV | Name | Type |
|---------|------|------|
| 46.1 | Configuration Change Count | uint8 |
| 46.2 | Ranging SID | uint16 |
| 46.3 | US Channel Action | uint8 |
| 46.4 | US Channel | compound |

### TLV 48: Receive Channel Profile Sub-TLVs

| Sub-TLV | Name | Type |
|---------|------|------|
| 48.1 | RCP ID | binary(5) |
| 48.2 | RCP Name | string(16) |
| 48.3 | RCC Status | uint8 |

### TLV 50: DSID Encodings Sub-TLVs

| Sub-TLV | Name | Type |
|---------|------|------|
| 50.1 | DSID | uint24 |
| 50.2 | DSID Action | uint8 |
| 50.3 | DS Resequencing | compound |
| 50.4 | Multicast | compound |

---

## Value Type Reference

| Type | Size | Description |
|------|------|-------------|
| uint8 | 1 | Unsigned 8-bit integer |
| uint16 | 2 | Unsigned 16-bit integer (big-endian) |
| uint24 | 3 | Unsigned 24-bit integer (big-endian) |
| uint32 | 4 | Unsigned 32-bit integer (big-endian) |
| ipv4 | 4 | IPv4 address |
| ipv6 | 16 | IPv6 address |
| mac | 6 | MAC address |
| string | var | ASCII string |
| binary | var | Raw binary data |
| compound | var | Contains nested sub-TLVs |
| oid | var | ASN.1 OID |
| asn1_der | var | ASN.1 DER encoded data |

---

## References

- CableLabs CANN-I22-230308 (CL-SP-CANN-I22-230308.pdf)
- DOCSIS MULPI Specification
- docsis project: https://github.com/rlaager/docsis
- Wireshark DOCSIS TLV Reference: https://www.wireshark.org/docs/dfref/d/docsis_tlv.html
