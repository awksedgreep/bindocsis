# PKT-SP-MIBS1.5-I02-070412 - MIBs Framework Specification

## Document Information
- **Title**: MIBs Framework Specification
- **Document Control Number**: PKT-SP-MIBS1.5-I02-070412
- **Status**: Issued
- **Date**: April 12, 2007
- **Publisher**: Cable Television Laboratories, Inc. (CableLabs)

## Purpose
This specification describes the framework for PacketCable 1.5 MIB (Management Information Base) modules. It provides information on management requirements for PacketCable-compliant devices and how these are supported in MIB modules.

## Scope
- Framework for PacketCable MIB modules
- Management requirements for Embedded MTAs (E-MTAs)
- SNMPv3 and SNMPv2 compliance
- SMIv2 compliance

## Key Topics

### PacketCable Reference Architecture (Section 5.1)
- E-MTA (Embedded MTA)
- CMTS (Cable Modem Termination System)
- CMS (Call Management Server)
- PSTN Gateway components (SG, MGC, MG)
- OSS Backoffice (KDC, Provisioning, DHCP, DNS, TFTP, Syslog, RKS)

### General Requirements (Section 5.2)
- DOCSIS MIB compliance required
- Minimalist approach to MIB design
- Support for Embedded MTAs
- Functional partitioning of DOCSIS (data) and PacketCable (voice)
- SNMPv3 and SNMPv2 compliance
- SMIv2 compliance

### SNMP Considerations (Section 5.2.3)
- **USM Requirements**: User Security Model configuration
- **VACM Requirements**: View-based Access Control Model
  - vacmSecurityToGroup Table
  - vacmAccessTable
  - MIB View Requirements (FullAccessView, ReadOnlyView, NotifyView)

### Functional Requirements (Section 5.3)
- Device provisioning
- Security
- Voice interfaces
- Voice call signaling (NCS)
- Media packet transport
- Fault management
- Performance management
- Event management

### MIB Modules (Section 6)

| MIB Module | Description |
|------------|-------------|
| DOCSIS MIBs | DOCSIS 1.1/2.0/3.0 compliance |
| IF MIB (RFC 2863) | Interface definitions |
| MIB II | System, interfaces, IP, transmission objects |
| Ethernet MIB | Ethernet-like interfaces |
| PacketCable Signaling MIB | NCS call signaling configuration |
| PacketCable MTA MIB | MTA device provisioning data |
| Event Management MIB | Event definitions and distribution |
| SNMPv2 MIB | SNMP configuration |
| PacketCable Extension MIBs | MTA and Signaling extensions |
| eDOCSIS eSAFE MIB | eSAFE component configuration |
| Battery Backup UPS MIB | Battery backup functionality |

### ifTable Requirements (Section 6.3.3)
- Telephony endpoints start at ifIndex 9
- ifType = voiceOverCable (198)
- ifDescr = "Voice Over Cable Interface"

### MIB Layering Model (Section 7.2)
- Packet network side: IP, UDP, RTP/NCS, Voice connection
- Telephone side: Physical layer, telephone channel

## Key MIB Object Identifiers
- PacketCable Project: 1.3.6.1.4.1.4491.2.2
- MIB-II system group: 1.3.6.1.2.1.1
- MIB-II IF MIB: 1.3.6.1.2.1.2.2
- Notify MIB: 1.3.6.1.6.3.13
- USM MIB: 1.3.6.1.6.3.15
- VACM MIB: 1.3.6.1.6.3.16

## Referenced Standards
- IETF STD0062 (SNMPv3)
- IETF RFC 2669 (DOCSIS Device MIB)
- IETF RFC 2863 (IF MIB)
- IETF RFC 3410-3415 (SNMPv3 framework)
- IETF RFC 2578 (SMIv2)
