# PKT-SP-EUE-DATA-C01-140314 - E-UE Provisioning Data Model Specification

## Document Information
- **Title**: E-UE Provisioning Data Model Specification
- **Document Control Number**: PKT-SP-EUE-DATA-C01-140314
- **Status**: Closed
- **Date**: March 14, 2014
- **Publisher**: Cable Television Laboratories, Inc. (CableLabs)
- **Version**: PacketCable 2.0

## Purpose
This specification defines the data elements (MIB objects) used for configuration and management of PacketCable 2.0 E-UEs and associated users. It provides the SNMP MIB modules that define the configuration file content and runtime management data.

## Scope
- MIB modules for eUE device configuration
- MIB modules for user configuration (IMPU/IMPI)
- MIB modules for provisioning and management
- Configuration file data element requirements
- Management event definitions

## Data Model Overview (Section 5.3)

The E-UE Provisioning Data Model has three logical layers:
```
eUE Data (device configuration)
    └── 1..* User Data (IMPU/IMPI)
            └── 1..* Application Data (SIP apps)
```

## MIB Framework (Section 6)

### eCM MIB Requirements
- DOCSIS MIB modules (per DOCSIS specs)
- eDOCSIS MIB modules (per eDOCSIS spec)
- Battery Backup UPS MIB (if supported)

### eUE MIB Requirements
| MIB Module | Purpose |
|------------|---------|
| CL-PKTC-EUE-TC-MIB | Textual Conventions |
| CL-PKTC-EUE-DEV-MIB | Device Configuration |
| CL-PKTC-EUE-USER-MIB | User Configuration |
| CL-PKTC-EUE-PROV-MGMT-MIB | Provisioning & Management |
| CL-PKTC-EUE-EVENT-MIB | Management Events |

## Key MIB Tables

### Device Configuration (Annex B.1 - CL-PKTC-EUE-DEV-MIB)

#### pktcEUEDevOpTable - Operator Configuration
| Object | Type | Description |
|--------|------|-------------|
| pktcEUEDevOpIndex | Unsigned32(1..16) | Row index |
| pktcEUEDevOpDomain | InetAddressDNS | Operator domain name ('.' = any) |
| pktcEUEDevOpSTUNAddr | InetAddress | STUN server address |
| pktcEUEDevOpSTUNAddrPort | InetPortNumber | STUN server port |
| pktcEUEDevOpTURNAddr | InetAddress | TURN server address |
| pktcEUEDevOpTURNAddrPort | InetPortNumber | TURN server port |
| pktcEUEDevOpRowStatus | RowStatus | Row status |

#### pktcEUEDevDnsTable - DNS Server Configuration
| Object | Type | Description |
|--------|------|-------------|
| pktcEUEDevDnsIndex | Unsigned32(1..16) | Row index |
| pktcEUEDevDnsAddrType | InetAddressType | ipv4 or ipv6 |
| pktcEUEDevDnsAddr | InetAddress | DNS server IP address |
| pktcEUEDevDnsRowStatus | RowStatus | Row status |

#### pktcEUEDevPCSCFTable - P-CSCF (SIP Proxy) Configuration
| Object | Type | Description |
|--------|------|-------------|
| pktcEUEDevPCSCFIndex | Unsigned32(1..16) | Row index |
| pktcEUEDevPCSCFAddrType | InetAddressType | ipv4 or ipv6 |
| pktcEUEDevPCSCFAddr | InetAddress | **P-CSCF IP address** |
| pktcEUEDevPCSCFSipPort | InetPortNumber | SIP port (5060 UDP/TCP, 5061 TLS) |
| pktcEUEDevPCSCFUsedProtocol | INTEGER | udp(2), tcp(3), tls(4) |
| pktcEUEDevPCSCFTimerT1 | Unsigned32 | SIP Timer T1 (ms), default 500 |
| pktcEUEDevPCSCFTimerT2 | Unsigned32 | SIP Timer T2 (ms), default 4000 |
| pktcEUEDevPCSCFTimerT4 | Unsigned32 | SIP Timer T4 (ms), default 5000 |
| pktcEUEDevPCSCFTimerTD | Unsigned32 | SIP Timer TD (ms), default 32000 |
| pktcEUEDevPCSCFRowStatus | RowStatus | Row status |

### User Configuration (Annex B.2 - CL-PKTC-EUE-USER-MIB)

#### pktcEUEUsrIMPUTable - Public User Identity
| Object | Type | Description |
|--------|------|-------------|
| pktcEUEUsrIMPUIndex | Unsigned32(1..24) | Row index |
| pktcEUEUsrIMPUIdType | INTEGER | publicIdentity(3), username(6) |
| pktcEUEUsrIMPUId | OCTET STRING | **SIP URI (e.g., sip:user@domain)** |
| pktcEUEUsrIMPUIMPIIndexRef | Unsigned32(0..24) | Reference to IMPI table (0=none) |
| pktcEUEUsrIMPUAdminStat | INTEGER | active(1), inactive(2) |
| pktcEUEUsrIMPUSigSecurity | INTEGER | Security requirements |
| pktcEUEUsrIMPURowStatus | RowStatus | Row status |

#### pktcEUEUsrIMPITable - Private User Identity (Credentials)
| Object | Type | Description |
|--------|------|-------------|
| pktcEUEUsrIMPIIndex | Unsigned32(1..24) | Row index |
| pktcEUEUsrIMPIIdType | INTEGER | privateIdentity(4), username(6) |
| pktcEUEUsrIMPIId | OCTET STRING | **Private identity (username)** |
| pktcEUEUsrIMPICredsType | INTEGER | none(2), password(3), preSharedKey(4) |
| pktcEUEUsrIMPICredentials | OCTET STRING | **Password/credentials** |
| pktcEUEUsrIMPIRowStatus | RowStatus | Row status |

## Configuration File Requirements (Section 6.3.1)

### Mandatory Elements (Table 6)
| MIB Object | Requirement | Notes |
|------------|-------------|-------|
| pktcMtaDevEnabled | **Mandatory** | Always required |
| pktcMtaDevRealmOrgName | Conditionally Mandatory | Required for Secure flow |
| pktcEUEDevOpTable | Conditionally Mandatory | Required if eUE has active users |
| pktcEUEDevDnsTable | Conditionally Mandatory | Falls back to DHCP DNS if absent |
| pktcEUEDevPCSCFTable | Conditionally Mandatory | **Required if eUE has active users** |
| pktcEUEUsrIMPUTable | Conditionally Mandatory | Required for SIP registration |
| pktcEUEUsrIMPITable | Conditionally Mandatory | Required for authenticated registration |
| pktcEUEUsrAppMapTable | Conditionally Mandatory | Required if user has applications |

## Credential Types (PktcEUETCCredsType)
| Value | Type | Description |
|-------|------|-------------|
| 1 | other | Unknown/vendor-specific |
| 2 | none | No credentials |
| 3 | password | ASCII password string |
| 4 | preSharedKey | Pre-shared key (octet string) |
| 5 | certificate | X.509 certificate with private key |

## Management Events (Section 6.4)

| Event | Severity | Description |
|-------|----------|-------------|
| EUE-EV-1 | error | Registration security mismatch |
| EUE-EV-2 | critical | Registration failed for user |
| EUE-EV-3 | info | Certificate Bootstrapping success |
| EUE-EV-4 | critical | Certificate Bootstrapping failure |
| EUE-EV-5 | critical | ToD unavailable (Secure flow) |
| EUE-EV-6 | warning | ToD unavailable (Basic/Hybrid flow) |
| EUE-EV-7 | warning | New ToD retrieved |

## SIP Protocol Configuration

### Transport Protocols (PktcEUEDevSipProtID)
| Value | Protocol |
|-------|----------|
| 1 | other |
| 2 | UDP |
| 3 | TCP |
| 4 | TLS |

### Default SIP Ports
- UDP/TCP: 5060
- TLS: 5061

## Configuration File Format
- Uses TLV (Type-Length-Value) binary encoding
- Same format as PacketCable 1.5 MTA configuration files
- MIB objects encoded per [PKT-SP-PROV1.5] specification
- Downloaded via TFTP or HTTP

## Referenced Standards
- PacketCable E-UE Provisioning [PKT-EUE-PROV]
- PacketCable 1.5 Device Provisioning [PKT-SP-PROV1.5]
- IETF RFC 2863 (IF MIB)
- IETF RFC 3411-3415 (SNMPv3)
- IETF RFC 4293 (IP MIB)
