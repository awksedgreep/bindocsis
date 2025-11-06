# Complete DOCSIS TLV Reference for Bindocsis Project

This document provides a comprehensive reference of ALL DOCSIS TLVs from the CableLabs specification (CL-SP-CANN-I22-230308) that Bindocsis must support.

## Overview

The Bindocsis project handles DOCSIS configuration files using TLV (Type-Length-Value) encoding. Since bootfiles can contain ANY valid DOCSIS TLV depending on the service provider's configuration requirements, Bindocsis must be capable of parsing and generating ALL TLV types defined in the specification.

## Complete TLV Registry (Types 0-255)

### Core DOCSIS TLVs (Types 1-30)

- **TLV 1**: Downstream Frequency - Center frequency of the downstream channel in Hz
- **TLV 2**: Upstream Channel ID - Upstream channel identifier  
- **TLV 3**: Network Access Control - Enable/disable network access
- **TLV 4**: Class of Service - Service class configuration (supports sub-TLVs)
- **TLV 5**: Modem Capabilities - Cable modem capability parameters (supports sub-TLVs)
- **TLV 6**: CM Message Integrity Check - Cable modem MIC for configuration integrity
- **TLV 7**: CMTS Message Integrity Check - CMTS MIC for configuration integrity
- **TLV 8**: Vendor ID - Vendor identification
- **TLV 9**: Software Upgrade Filename - Filename for software upgrade
- **TLV 10**: SNMP Write Access Control - SNMP write access configuration (supports sub-TLVs)
- **TLV 11**: SNMP MIB Object - SNMP MIB object configuration (supports sub-TLVs)
- **TLV 12**: Modem IP Address - IPv4 address for the cable modem
- **TLV 13**: Service Provider Name - Name of the service provider
- **TLV 14**: Software Upgrade Server - Software upgrade server address
- **TLV 15**: Upstream Packet Classification - Upstream packet classification rules (supports sub-TLVs)
- **TLV 16**: Downstream Packet Classification - Downstream packet classification rules (supports sub-TLVs)
- **TLV 17**: Upstream Service Flow - Upstream service flow configuration (supports sub-TLVs)
- **TLV 18**: Downstream Service Flow - Downstream service flow configuration (supports sub-TLVs)
- **TLV 19**: PHS Rule - Payload Header Suppression rule (supports sub-TLVs)
- **TLV 20**: HMac Digest - HMAC digest for authentication
- **TLV 21**: Max CPE IP Addresses - Maximum number of CPE IP addresses
- **TLV 22**: TFTP Server Timestamp - TFTP server timestamp
- **TLV 23**: TFTP Server Address - TFTP server IP address
- **TLV 24**: Downstream Service Flow - QoS parameters for downstream traffic (supports sub-TLVs)
- **TLV 25**: Upstream Service Flow - QoS parameters for upstream traffic (supports sub-TLVs)
- **TLV 26**: Upstream Service Flow Reference - Reference to upstream service flow
- **TLV 27**: Software Upgrade Log Server - Software upgrade log server address
- **TLV 28**: Software Upgrade Log Filename - Software upgrade log filename
- **TLV 29**: DHCP Option Code - DHCP option code configuration
- **TLV 30**: Baseline Privacy Config - Baseline privacy configuration (supports sub-TLVs)

### Security and Privacy TLVs (Types 31-42)

- **TLV 31**: Baseline Privacy Key Management - BPI key management configuration (supports sub-TLVs)
- **TLV 32**: Max Classifiers - Maximum number of classifiers
- **TLV 33**: Privacy Enable - Enable/disable privacy
- **TLV 34**: Authorization Block - Authorization block configuration
- **TLV 35**: Key Sequence Number - Key sequence number
- **TLV 36**: Manufacturer CVC - Manufacturer code verification certificate
- **TLV 37**: CoSign CVC - Co-signer code verification certificate
- **TLV 38**: SnmpV3 Kickstart - SNMPv3 kickstart configuration (supports sub-TLVs)
- **TLV 39**: Subscriber Management Control - Subscriber management control parameters (supports sub-TLVs)
- **TLV 40**: Subscriber Management CPE IP List - Subscriber management CPE IP list (supports sub-TLVs)
- **TLV 41**: Subscriber Management Filter Groups - Subscriber management filter groups (supports sub-TLVs)
- **TLV 42**: SNMPv3 Notification Receiver - SNMPv3 notification receiver configuration (supports sub-TLVs)

### Extended DOCSIS TLVs (Types 43-85)

- **TLV 43**: L2VPN Encoding - Layer 2 VPN configuration (supports sub-TLVs)
- **TLV 44**: Software Upgrade HTTP Server - HTTP server for software upgrades
- **TLV 45**: IPv4 Multicast Join Authorization - IPv4 multicast join authorization (supports sub-TLVs)
- **TLV 46**: IPv6 Multicast Join Authorization - IPv6 multicast join authorization (supports sub-TLVs)
- **TLV 47**: Upstream Drop Packet Classification - Upstream drop packet classification (supports sub-TLVs)
- **TLV 48**: Subscriber Management Event Control - Subscriber management event control (supports sub-TLVs)
- **TLV 49**: Test Mode Configuration - Test mode configuration parameters (supports sub-TLVs)
- **TLV 50**: Transmit Pre-Equalizer - Transmit pre-equalizer configuration (supports sub-TLVs)
- **TLV 51**: Downstream Channel List Override - Override downstream channel list (supports sub-TLVs)
- **TLV 52**: Diplexer Upstream Upper Band Edge Configuration - Diplexer upstream upper band edge
- **TLV 53**: Diplexer Downstream Lower Band Edge Configuration - Diplexer downstream lower band edge
- **TLV 54**: Diplexer Downstream Upper Band Edge Configuration - Diplexer downstream upper band edge
- **TLV 55**: Diplexer Upstream Upper Band Edge Override - Override diplexer upstream upper band edge
- **TLV 56**: Extended Upstream Transmit Power - Extended upstream transmit power
- **TLV 57**: Optional RFI Mitigation Override - Optional RFI mitigation override
- **TLV 58**: Energy Management 1x1 Mode - Energy management 1x1 mode configuration
- **TLV 59**: Extended Power Mode - Extended power mode configuration
- **TLV 60**: IPv6 Packet Classification - IPv6 packet classification rules (supports sub-TLVs)
- **TLV 61**: Subscriber Management CPE IPv6 Prefix List - IPv6 prefix management (supports sub-TLVs)
- **TLV 62**: Downstream OFDM Profile - DOCSIS 3.1 OFDM channel profile configuration (supports sub-TLVs)
- **TLV 63**: Downstream OFDMA Profile - DOCSIS 3.1 OFDMA channel profile configuration (supports sub-TLVs)
- **TLV 64**: PacketCable Configuration - PacketCable configuration parameters (supports sub-TLVs)
- **TLV 65**: L2VPN MAC Aging - L2VPN MAC aging configuration
- **TLV 66**: Management Event Control - Management event control configuration (supports sub-TLVs)
- **TLV 67**: Subscriber Management CPE IPv6 Table - Subscriber management CPE IPv6 table (supports sub-TLVs)
- **TLV 68**: Default Upstream Target Buffer - Default upstream target buffer size
- **TLV 69**: MAC Address Learning Control - MAC address learning control
- **TLV 70**: Aggregate Service Flow Encoding - Aggregate service flow encoding (supports sub-TLVs)
- **TLV 71**: Aggregate Service Flow Reference - Aggregate service flow reference
- **TLV 72**: Metro Ethernet Service Profile - Metro Ethernet service profile (supports sub-TLVs)
- **TLV 73**: Network Timing Profile - Network timing profile configuration (supports sub-TLVs)
- **TLV 74**: Energy Parameters - Energy management parameters (supports sub-TLVs)
- **TLV 75**: CM Upstream AQM Disable - CM upstream AQM disable configuration
- **TLV 76**: CMTS Upstream AQM Disable - CMTS upstream AQM disable configuration
- **TLV 77**: DLS Encoding - Downstream Service (DLS) encoding (supports sub-TLVs)
- **TLV 78**: DLS Reference - Downstream Service (DLS) reference
- **TLV 79**: UNI Control Encodings - User Network Interface control encodings (supports sub-TLVs)
- **TLV 80**: Downstream Resequencing - Downstream resequencing configuration (supports sub-TLVs)
- **TLV 81**: Multicast DSID Forward - Multicast DSID forwarding configuration (supports sub-TLVs)
- **TLV 82**: Symmetric Service Flow - Symmetric service flow configuration (supports sub-TLVs)
- **TLV 83**: DBC Request - Dynamic Bonding Change request (supports sub-TLVs)
- **TLV 84**: DBC Response - Dynamic Bonding Change response (supports sub-TLVs)
- **TLV 85**: DBC Acknowledge - Dynamic Bonding Change acknowledge (supports sub-TLVs)

### Vendor Specific and Special TLVs (Types 200-255)

- **TLVs 200-253**: Vendor Specific - Vendor-defined extensions (all support sub-TLVs)
- **TLV 254**: Pad - Padding TLV for alignment
- **TLV 255**: End-of-Data Marker - Configuration end marker

## Critical Sub-TLV Categories

### Service Flow Sub-TLVs (for TLVs 24, 25, 17, 18)
These define QoS parameters and service characteristics:
- **Sub-TLV 1**: Service Flow Reference - Unique identifier
- **Sub-TLV 2**: Service Flow ID - CMTS-assigned identifier  
- **Sub-TLV 3**: Service Identifier - Provisioning system identifier
- **Sub-TLV 4**: Service Class Name - Name of the service class
- **Sub-TLV 7**: QoS Parameter Set Type - Type of QoS parameters
- **Sub-TLV 8**: Traffic Priority - Traffic priority (0-7)
- **Sub-TLV 9**: Maximum Sustained Traffic Rate - Maximum sustained rate in bps
- **Sub-TLV 10**: Maximum Traffic Burst - Maximum traffic burst in bytes
- **Sub-TLV 11**: Minimum Reserved Traffic Rate - Minimum reserved rate in bps
- **Sub-TLV 12**: Minimum Packet Size - Minimum packet size in bytes
- **Sub-TLV 13**: Maximum Packet Size - Maximum packet size in bytes
- **Sub-TLV 14**: Maximum Concatenated Burst - Maximum concatenated burst
- **Sub-TLV 15**: Service Flow Scheduling Type - Scheduling algorithm type
- **Sub-TLV 16**: Request/Transmission Policy - Request and transmission policy
- **Sub-TLV 17**: Tolerated Jitter - Maximum delay variation in microseconds
- **Sub-TLV 18**: Maximum Latency - Maximum latency in microseconds
- **Sub-TLV 19**: Grants Per Interval - Number of grants per interval (upstream only)
- **Sub-TLV 20**: Nominal Polling Interval - Nominal polling interval (upstream only)
- **Sub-TLV 21**: Unsolicited Grant Size - Unsolicited grant size (upstream only)
- **Sub-TLV 22**: Nominal Grant Interval - Nominal grant interval (upstream only)
- **Sub-TLV 23**: Tolerated Grant Jitter - Tolerated grant jitter (upstream only)

### Classification Sub-TLVs (for TLVs 22, 23, 15, 16, 60)
These define packet classification and filtering rules:
- **Sub-TLV 1**: Classifier Reference - Unique classifier identifier
- **Sub-TLV 2**: Classifier ID - CMTS-assigned classifier ID
- **Sub-TLV 3**: Service Flow Reference - Associated service flow
- **Sub-TLV 4**: Service Flow ID - Associated service flow ID
- **Sub-TLV 5**: Classifier Priority - Classification priority
- **Sub-TLV 6**: Classifier Activation State - Activation state
- **Sub-TLV 7**: Dynamic Service Change Action - DSC action
- **Sub-TLV 8**: DSC Error Encodings - DSC error codes
- **Sub-TLV 9**: IP Packet Classification Encodings - IP classification rules
- **Sub-TLV 10**: Ethernet Packet Classification Encodings - Ethernet classification
- **Sub-TLV 11**: Ethernet LLC Packet Classification - LLC frame classification
- **Sub-TLV 12**: IEEE 802.1Q Packet Classification - VLAN classification
- **Sub-TLV 13**: IPv6 Traffic Class Range and Mask - IPv6 traffic class
- **Sub-TLV 14**: IPv6 Flow Label - IPv6 flow label
- **Sub-TLV 15**: IPv6 Next Header Type - IPv6 next header
- **Sub-TLV 16**: IPv6 Source Prefix - IPv6 source prefix
- **Sub-TLV 17**: IPv6 Destination Prefix - IPv6 destination prefix
- **Sub-TLV 43**: L2VPN Encoding - L2VPN-specific classification

### L2VPN Sub-TLVs (for TLV 43)
These define Layer 2 VPN configurations:
- **Sub-TLV 1**: CM Load Balancing Policy ID - Load balancing policy
- **Sub-TLV 2**: CM Load Balancing Priority - Load balancing priority  
- **Sub-TLV 3**: CM Load Balancing Group ID - Load balancing group
- **Sub-TLV 4**: CM Range Class ID Override - Range class override
- **Sub-TLV 5**: L2VPN Encoding - L2VPN configuration (nested sub-TLVs)
- **Sub-TLV 6**: Extended CMTS MIC Configuration - Extended MIC config
- **Sub-TLV 7**: SAV Authorization Encoding - Source Address Verification
- **Sub-TLV 8**: Vendor Specific Encoding - Vendor-specific L2VPN data
- **Sub-TLV 9**: CM Attribute Masks - Cable modem attribute masks
- **Sub-TLV 10**: IP Multicast Join Authorization - Multicast authorization
- **Sub-TLV 11**: IP Multicast Leave Authorization - Multicast leave authorization
- **Sub-TLV 12**: DEMARC Auto Configuration - DEMARC configuration

### DOCSIS 3.1 OFDM Profile Sub-TLVs (for TLV 62)
These define downstream OFDM channel profile parameters:
- **Sub-TLV 1**: Profile ID - OFDM profile identifier (uint8)
- **Sub-TLV 2**: Channel ID - Downstream OFDM channel ID (uint8)
- **Sub-TLV 3**: Configuration Change Count - Configuration version counter (uint8)
- **Sub-TLV 4**: Subcarrier Spacing - Subcarrier spacing selection (uint8, enum: 0="25 kHz", 1="50 kHz")
- **Sub-TLV 5**: Cyclic Prefix - Cyclic prefix option per DOCSIS 3.1 PHY spec (uint8, 8 enumerated options: 0=192 samples, 1=256 samples, 2=384 samples, 3=512 samples, 4=640 samples, 5=768 samples, 6=896 samples, 7=1024 samples)
- **Sub-TLV 6**: Roll-off Period - Roll-off period parameter (uint8, 5 enumerated options: 0=0 samples, 1=64 samples, 2=128 samples, 3=192 samples, 4=256 samples)
- **Sub-TLV 7**: Interleaver Depth - Time interleaver depth (uint8, 6 enumerated options: 0=1, 1=2, 2=4, 3=8, 4=16, 5=32)
- **Sub-TLV 8**: Modulation Profile - Modulation and bit-loading profile (compound, may contain vendor-specific extensions)
- **Sub-TLV 9**: Start Frequency - Channel start frequency in Hz (uint32)
- **Sub-TLV 10**: End Frequency - Channel end frequency in Hz (uint32)
- **Sub-TLV 11**: Number of Subcarriers - Number of active subcarriers (uint16)
- **Sub-TLV 12**: Pilot Pattern - Pilot subcarrier pattern selection (uint8, enum: 0="Scattered", 1="Continuous", 2="Mixed")

### DOCSIS 3.1 OFDMA Profile Sub-TLVs (for TLV 63)
These define downstream OFDMA channel profile parameters (includes all OFDM sub-TLVs plus):
- **Sub-TLV 1-10**: Same as TLV 62 (Profile ID through End Frequency)
- **Sub-TLV 11**: Mini-slot Size - OFDMA mini-slot size in symbols or time units (uint8, OFDMA-specific)
- **Sub-TLV 12**: Pilot Pattern - Same as TLV 62 sub-TLV 12 (uint8, enum: 0="Scattered", 1="Continuous", 2="Mixed")
- **Sub-TLV 13**: Power Control - Power control parameter in dB steps (int8, signed, OFDMA-specific)

**Note**: TLV 62 and 63 are DOCSIS 3.1 specific and critical for OFDM/OFDMA channel configuration. When compound TLV parsing fails, the system provides hex string formatted_value for human editing per the round-trip architecture.

### Modem Capabilities Sub-TLVs (for TLV 5)
These define cable modem capabilities:
- **Sub-TLV 1**: Concatenation Support - Concatenation capability
- **Sub-TLV 2**: Modem DOCSIS Version - DOCSIS version supported
- **Sub-TLV 3**: Fragmentation Support - Fragmentation capability
- **Sub-TLV 4**: PHS Support - Payload Header Suppression
- **Sub-TLV 5**: IGMP Support - IGMP capability
- **Sub-TLV 6**: Privacy Support - Baseline Privacy support
- **Sub-TLV 7**: Downstream SAV Support - Downstream SAV capability
- **Sub-TLV 8**: Upstream SID Support - Upstream SID capability
- **Sub-TLV 9**: Optional Filtering Support - Optional filtering
- **Sub-TLV 10**: Transmit Pre-Equalizer Taps - Pre-equalizer taps
- **Sub-TLV 11**: Number of Transmit Equalizer Taps - Equalizer taps
- **Sub-TLV 12**: DCC Support - Dynamic Channel Change
- **Sub-TLV 13**: IP Filters Support - IP filtering capability
- **Sub-TLV 14**: LLC Filters Support - LLC filtering capability
- **Sub-TLV 15**: Expanded Unicast SID Space - Extended SID space
- **Sub-TLV 16**: Ranging Hold-Off Support - Ranging hold-off
- **Sub-TLV 17**: L2VPN Capability - L2VPN support
- **Sub-TLV 18**: L2VPN eSAFE Host Capability - eSAFE L2VPN support
- **Sub-TLV 19**: DUT Filtering Support - DUT filtering
- **Sub-TLV 20**: Upstream Frequency Range Support - Frequency range
- **Sub-TLV 21**: Upstream Symbol Rate Support - Symbol rate support
- **Sub-TLV 22**: Selectable Active Code Mode 2 Support - Code mode support
- **Sub-TLV 23**: Code Hopping Mode 2 Support - Code hopping
- **Sub-TLV 24**: Multiple Transmit Channel Support - Multi-channel TX
- **Sub-TLV 25**: 512 SAID Support - Extended SAID support
- **Sub-TLV 26**: Satellite Backhaul Support - Satellite support
- **Sub-TLV 27**: Multiple Receive Module Support - Multi-RX module
- **Sub-TLV 28**: Total SID Cluster Support - SID clustering
- **Sub-TLV 29**: SID Clusters per Service Flow Support - SID per SF
- **Sub-TLV 30**: Multiple Receive Channel Support - Multi-channel RX
- **Sub-TLV 31**: Total Downstream Service ID Support - Total DS SID
- **Sub-TLV 32**: Resequencing Downstream Service ID Support - Resequencing
- **Sub-TLV 33**: Multicast Downstream Service ID Support - Multicast DSID
- **Sub-TLV 34**: Multicast DSID Forwarding - DSID forwarding
- **Sub-TLV 35**: Frame Control Type Forwarding Capability - Frame control
- **Sub-TLV 36**: DPV Capability - DOCSIS Path Verify
- **Sub-TLV 37**: UGS-AD Support - UGS with Activity Detection
- **Sub-TLV 38**: MAP and UCD Receipt Support - MAP/UCD receipt
- **Sub-TLV 39**: Upstream Drop Classifier Support - Drop classifier
- **Sub-TLV 40**: IPv6 Support - IPv6 capability
- **Sub-TLV 41**: Extended Upstream Power Support - Extended power
- **Sub-TLV 42**: C-DOCSIS Capability - C-DOCSIS support
- **Sub-TLV 43**: Energy Management Capability - Energy management

## PacketCable ASN.1 Support

**TLV 64** (PacketCable Configuration) contains ASN.1-encoded provisioning data for:
- VoIP services (MTA provisioning)
- Video services  
- Multimedia applications
- PacketCable 1.x and 2.0 applications

This TLV requires special ASN.1 parsing, which Bindocsis already supports via the ASN.1 parser.

## Implementation Notes for Bindocsis

### Current Support Status
- ✅ All basic TLVs (1-85) are defined in `lib/bindocsis/docsis_specs.ex`
- ✅ Service Flow sub-TLVs are fully specified
- ✅ PacketCable ASN.1 parsing is implemented
- ✅ Extensive test fixtures exist for most TLV combinations
- ✅ Multi-byte length encoding is supported
- ✅ Vendor-specific TLVs (200-253) are handled

### Key Implementation Considerations
1. **ALL TLVs must be supported** - Any valid DOCSIS TLV can appear in bootfiles
2. **Sub-TLV parsing** - Many TLVs contain nested sub-TLVs that must be recursively parsed
3. **Length encoding** - Support for single-byte and multi-byte length encoding
4. **Value formatting** - Context-aware formatting based on TLV type and specification
5. **Error handling** - Graceful handling of malformed or unknown TLVs
6. **Version compatibility** - Different DOCSIS versions support different TLV sets

## References

- CableLabs Specification: CL-SP-CANN-I22-230308 "CableLabs' Assigned Names and Numbers"
- DOCSIS 3.0/3.1 MAC and Upper Layer Protocols Interface Specification
- Existing Bindocsis implementation in `lib/bindocsis/docsis_specs.ex`