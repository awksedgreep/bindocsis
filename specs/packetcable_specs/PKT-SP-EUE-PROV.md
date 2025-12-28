# PKT-SP-EUE-PROV-C01-140314 - E-UE Provisioning Framework Specification

## Document Information
- **Title**: E-UE Provisioning Framework Specification
- **Document Control Number**: PKT-SP-EUE-PROV-C01-140314
- **Status**: Closed
- **Date**: March 14, 2014
- **Publisher**: Cable Television Laboratories, Inc. (CableLabs)
- **Version**: PacketCable 2.0

## Purpose
This specification describes the provisioning mechanism for PacketCable 2.0 Embedded User Equipment (E-UE). It specifies network and protocol requirements to configure and manage E-UEs, along with associated users and applications. PacketCable 2.0 is based on **SIP and IMS** (unlike PacketCable 1.5 which used NCS/MGCP).

## Scope
- Provisioning of PacketCable 2.0 E-UEs (embedded with eDOCSIS cable modems)
- IPv4, IPv6, and Dual-Stack support
- Reuse of PacketCable 1.5 Device Provisioning framework with enhancements
- Non-embedded UEs (software clients) and network elements (CSCFs, HSS) are out of scope

## Key Differences from PacketCable 1.5
| Aspect | PacketCable 1.5 | PacketCable 2.0 |
|--------|-----------------|-----------------|
| Call Signaling | NCS/MGCP | **SIP** |
| Architecture | CMS-based | **IMS-based (P-CSCF)** |
| IP Support | IPv4 only | **IPv4, IPv6, Dual-Stack** |
| Device Term | E-MTA (eMTA) | **E-UE (eUE)** |

## E-UE Architecture (Section 5)

### Components
- **E-UE**: Single physical device containing:
  - **eCM**: Embedded DOCSIS Cable Modem (logical component)
  - **eUE**: Embedded User Equipment (logical PacketCable component)

### Provisioning Model
- Static configuration (pre-established parameters)
- Dynamic configuration (runtime configuration for unknown devices)
- Three provisioning flows: **Basic, Hybrid, and Secure**

## Provisioning Interfaces (Section 6.1)

| Interface | Protocol | Purpose |
|-----------|----------|---------|
| pkt-eue-1 | DHCP | IP configuration, provisioning flow selection |
| pkt-eue-2 | DNS | Name resolution (FQDNs to IP addresses) |
| pkt-eue-3 | Kerberos | Mutual authentication (Secure flow only) |
| pkt-eue-4 | SNMP | Configuration retrieval (Hybrid/Secure flows) |
| pkt-eue-5 | TFTP/HTTP | Configuration file download |
| pkt-eue-6 | Syslog | Management event reporting |
| pkt-eue-7 | Kerberos | KDC to Provisioning Server communication |

## Provisioning Components (Section 6.2)

### Required Servers
- **DHCP Server**: IP configuration and PacketCable-specific options
- **DNS Server**: FQDN resolution, SRV records
- **KDC**: Key Distribution Center for Secure flow authentication
- **Provisioning Server**: SNMP-based configuration management
- **Configuration Server**: TFTP/HTTP file server
- **Syslog Server**: Management event collection

### E-UE Requirements
- Must have separate MAC address from eCM
- Must have separate IP address(es) from eCM
- Must support Dual-Stack (IPv4 + IPv6)
- Must support all three provisioning flows (Basic, Hybrid, Secure)
- Must support TLV-formatted binary configuration files

## Provisioning Flows (Section 6.3)

### Flow Selection
The provisioning flow is determined by DHCP options during eCM provisioning:
- **DHCP Option 122** (CL_OPTION_CCC): IPv4 eUE DHCP server addresses
- **CL_OPTION_CCCV6**: IPv6 eUE DHCP server DSS_IDs
- **CL_OPTION_IP_PREF**: IP addressing mode preference

### Basic Provisioning Flow
1. eCM completes DOCSIS provisioning
2. eUE receives DHCP configuration
3. eUE downloads configuration file via TFTP/HTTP
4. Optional: SNMP status notification

**Characteristics:**
- Simplest flow
- No Kerberos authentication
- SNMPv2c for management
- Optional provisioning status reporting

### Hybrid Provisioning Flow
1. eCM completes DOCSIS provisioning
2. eUE receives DHCP configuration
3. DNS resolution for Provisioning Server
4. SNMP exchange for configuration file info
5. Configuration file download via TFTP/HTTP
6. Optional: SNMP status notification

**Characteristics:**
- No Kerberos authentication
- SNMP used to obtain configuration file location/authentication
- More control than Basic flow

### Secure Provisioning Flow
1. eCM completes DOCSIS provisioning (including ToD)
2. eUE receives DHCP configuration
3. DNS resolution for KDC
4. Kerberos AS Request/Reply (mutual authentication)
5. Kerberos TGS Request/Reply (service ticket)
6. Kerberos AP Request/Reply (Provisioning Server auth)
7. SNMPv3 exchange for secure configuration
8. Configuration file download via TFTP/HTTP
9. SNMP status notification

**Characteristics:**
- Full Kerberos PKINIT authentication
- SNMPv3 with authentication/privacy
- Requires Time of Day (ToD) synchronization
- Most secure option

## IP Addressing Modes (Section 6.3.2)

### Single-Stack Mode (SSM)
- eUE operates with either IPv4 OR IPv6 address
- One IP address for all operations

### Dual-Stack Mode (DSM)
- eUE operates with BOTH IPv4 AND IPv6 addresses
- Two IP addresses (one per protocol family)
- IP_PREF option determines which stack for provisioning operations

### IP Preference Values (CL_OPTION_IP_PREF)
| Value | Meaning |
|-------|---------|
| b'001 | IPv4 only |
| b'010 | IPv6 only |
| b'101 | Dual-stack, prefer IPv4 for provisioning |
| b'110 | Dual-stack, prefer IPv6 for provisioning |
| b'111 | Used by eCM to indicate dual-stack support |

## DHCP Options Summary

### IPv4 (DHCPv4)
- **Option 122**: CableLabs Client Configuration (CCC)
  - Sub-option 1: Primary DHCP server address
  - Sub-option 2: Secondary DHCP server address
  - Sub-option 6: Kerberos Realm
- **Option 125**: Vendor-Identifying Vendor Options
  - CL_V4OPTION_CCCV6 (123): IPv6 DHCP server DSS_IDs
  - CL_V4OPTION_IP_PREF (124): IP preference

### IPv6 (DHCPv6)
- **Option 17** (OPTION_VENDOR_OPTS):
  - CL_OPTION_CCC (2170): CableLabs Client Configuration
  - CL_OPTION_CCCV6 (2171): IPv6 configuration
  - CL_OPTION_IP_PREF (39): IP preference

## Configuration File (Section 6.4)
- TLV (Type-Length-Value) formatted binary file
- Separate from eCM configuration file
- Data elements defined in [PKT-EUE-DATA] specification
- Downloaded via TFTP or HTTP

## Additional Features (Section 6.6)
- **eUE Capabilities Reporting**: Device feature advertisement
- **P-CSCF Discovery**: Obtaining SIP proxy information
- **Battery Backup**: Power management
- **Certificate Bootstrapping**: Initial certificate provisioning

## Key Concepts

### DSS_ID (DHCP Server Selector ID)
- Used for DHCPv6 server selection (replaces IP addresses)
- 4-byte identifier
- 0xFFFFFFFF = accept any server
- 0x00000000 = do not provision

### Time of Day (ToD) Requirements
- Critical for Secure Provisioning Flow
- eCM obtains ToD before eUE initialization
- Required for Kerberos ticket validation
- eUE must wait for ToD if using Secure flow

## Referenced Standards
- IETF RFC 2131 (DHCPv4)
- IETF RFC 3315 (DHCPv6)
- IETF RFC 4861 (IPv6 Neighbor Discovery)
- IETF RFC 4862 (IPv6 SLAAC)
- PacketCable 1.5 Provisioning [PKT-PROV1.5]
- PacketCable 1.5 Security [PKT-SEC1.5]
- PacketCable E-UE Data Models [PKT-EUE-DATA]
- eDOCSIS Specification
- DOCSIS 3.0 MULPI Specification
