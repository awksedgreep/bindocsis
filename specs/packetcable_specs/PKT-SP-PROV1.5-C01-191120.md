# PKT-SP-PROV1.5-C01-191120 - MTA Device Provisioning Specification

## Document Information
- **Title**: MTA Device Provisioning
- **Document Control Number**: PKT-SP-PROV1.5-C01-191120
- **Status**: Closed
- **Date**: November 20, 2019
- **Publisher**: Cable Television Laboratories, Inc. (CableLabs)

## Purpose
This specification describes PacketCable 1.5 embedded-MTA device initialization and provisioning. It enables vendors to build interoperable E-MTA devices for PacketCable 1.5 networks.

## Scope
- Provisioning of PacketCable 1.5 E-MTAs
- Single provisioning and network management provider
- MTA component provisioning (not eCM)

## Key Topics

### Components and Interfaces (Section 5.4)
- MTA
- Provisioning Server
- Telephony Syslog Server
- DHCP Server
- CMS (Call Management Server)
- Security Server (KDC)
- Configuration file access (TFTP/HTTP)
- DOCSIS extensions for MTA provisioning

### Provisioning Overview (Section 6)
- **Device Provisioning**: Hardware/software initialization
- **Endpoint Provisioning**: Per-line telephony service setup
- **Provisioning Flows**:
  - Secure Flow (Kerberos-based)
  - Basic Flow (simplified)
  - Hybrid Flow (combined approach)

### Provisioning Flows (Section 7)
- **Secure Flow** (IPv4 and IPv6):
  - Full Kerberos key exchange
  - SNMPv3 with authentication/privacy
  - Configuration file download
  - CMS registration
- **Basic Flow**: Simplified provisioning without full Kerberos
- **Hybrid Flow**: Combination of secure and basic methods

### Post-Initialization Provisioning
- Adding/enabling telephony services
- Deleting/disabling telephony services
- Modifying telephony services
- MTA replacement
- Temporary signal loss handling
- Hard reboot/soft reset scenarios

### DHCP Options (Section 8)
| Option | Purpose |
|--------|---------|
| Option 122 | CableLabs Client Configuration |
| Sub-option 1,2 | Service Provider DHCP Address |
| Sub-option 3 | Provisioning Entity Address |
| Sub-option 4 | AS-REQ/REP Backoff/Retry |
| Sub-option 5 | AP-REQ/REP Backoff/Retry |
| Sub-option 6 | Kerberos Realm |
| Sub-option 7 | TGS Usage |
| Sub-option 8 | Provisioning Timer |
| Sub-option 9 | Security Ticket Invalidation |
| Option 60 | Vendor Client Identifier |
| Option 43 | Vendor-Specific Information |

### MTA Configuration File (Section 9)
- **Device Level Configuration**: Basic device settings
- **Device Level Service Data**: Service-wide parameters
- **Per-Endpoint Configuration**: Line-specific settings
- **Per-Realm Configuration**: Kerberos realm settings
- **Per-CMS Configuration**: Call agent settings

### MTA Device Capabilities (Section 10)
- PacketCable version
- Number of telephony endpoints
- TGT support
- HTTP download support
- NCS service flow support
- Primary line support
- CODEC support (list of supported codecs)
- Silence suppression
- Echo cancellation
- RSVP support
- UGS-AD support
- T38 fax support
- RFC 2833 DTMF support
- Voice metrics support
- Multiple grants per interval support
- V.152 support

### TLV-38 SNMP Notification Receiver (Section 11)
- IP address
- UDP port number
- Receiver type
- Timeout and retries
- Filtering parameters
- SNMPv3 security name

### SNMPv2c Management (Section 12)
- Co-existence mode requirements
- Default SNMP entries

## Key Concepts

### Provisioning State Machine
States for E-MTA provisioning:
1. Power-on/Reset
2. DHCP Discovery
3. Security Association
4. Configuration Download
5. CMS Registration
6. Operational

### Configuration File TLVs
The MTA configuration file uses Type-Length-Value encoding for:
- Telephony configuration parameters
- Security settings
- Endpoint-specific settings
- SNMP notification targets

## Referenced Standards
- IETF RFC 2131 (DHCP)
- IETF RFC 3315 (DHCPv6)
- IETF RFC 3413-3415 (SNMPv3)
- PacketCable 1.5 MIB specifications
- eDOCSIS specification
