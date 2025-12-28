# PKT-SP-SEC1.5-I03-090624 - Security Specification

## Document Information
- **Title**: Security
- **Document Control Number**: PKT-SP-SEC1.5-I03-090624
- **Status**: Issued
- **Date**: June 24, 2009
- **Publisher**: Cable Television Laboratories, Inc. (CableLabs)

## Purpose
This specification defines the PacketCable security architecture, protocols, algorithms, and requirements to protect the network. It ensures PacketCable networks are at least as secure as PSTN networks while addressing the unique challenges of shared HFC networks and IP backbones.

## Scope
- Security architecture for all PacketCable interfaces
- Authentication, access control, integrity, confidentiality
- Non-repudiation services
- Embedded MTAs (E-MTAs) and Standalone MTAs (S-MTAs)
- NCS call signaling security
- Single and multi-domain security

## Goals
- Secure network communications
- Reasonable implementation cost
- Multi-vendor interoperability
- Extensibility for future algorithms

## Key Topics

### Security Threats (Section 5.2)
- **Theft of Network Services**: Unauthorized service usage
- **Bearer Channel Threats**: Eavesdropping, modification of voice/video
- **Signaling Channel Threats**: Call setup manipulation
- **Service Disruption**: Denial of service attacks
- **Repudiation**: Denying service usage for billing

### Security Mechanisms (Section 6)

#### IPsec (Section 6.1)
- ESP Transport Mode
- Transform: 3DES-CBC or AES-CBC
- Authentication: HMAC-SHA1-96 or HMAC-MD5-96

#### Internet Key Exchange (Section 6.2)
- IKE Main Mode and Quick Mode
- Oakley Groups (1, 2, 14)
- Pre-shared keys or certificates

#### SNMPv3 (Section 6.3)
- USM authentication: HMAC-MD5-96, HMAC-SHA-96
- USM privacy: DES-CBC, 3DES-EDE, AES-CFB

#### Kerberos/PKINIT (Section 6.4)
- Public key initial authentication
- MTA certificate validation
- Symmetric key exchanges
- TGS Request/Reply for service tickets
- Server key versioning

#### Kerberized Key Management (Section 6.5)
- AP Request/AP Reply exchanges
- Rekey messages
- Kerberized IPsec for NCS
- Kerberized SNMPv3 for provisioning

#### Media Stream Security (Section 6.6-6.7)
- RTP encryption and authentication
- RTCP encryption and authentication
- MMH-MAC for integrity

#### BPI+ (Section 6.8)
- DOCSIS Baseline Privacy Plus
- Required for all E-MTAs

#### TLS (Section 6.9)
- TLS 1.0 for SIP signaling
- AES and 3DES ciphersuites

### Security Profiles (Section 7)

| Interface | Security Mechanism |
|-----------|-------------------|
| Device Provisioning | Kerberos/PKINIT, SNMPv3 |
| DQoS (CMS-CMTS) | IPsec ESP |
| Billing (RADIUS) | IPsec ESP |
| NCS Signaling | IPsec ESP (Kerberized) |
| PSTN Gateway | IPsec ESP |
| RTP/RTCP Media | PacketCable media encryption |
| Audio Server | IPsec ESP |
| Electronic Surveillance | IPsec ESP |
| CMS Provisioning | IPsec ESP |

### Certificate Hierarchy (Section 8)
- **MTA Certificate Chain**:
  - MTA Root CA
  - Manufacturer CA
  - MTA Device Certificate
- **Service Provider Chain**:
  - CableLabs Service Provider Root
  - Service Provider CA
  - Local System CA
  - Server Certificates (KDC, DF, etc.)

### Cryptographic Algorithms (Section 9)
- **AES**: 128-bit block cipher
- **DES/3DES**: Legacy encryption
- **RSA**: Digital signatures (1024-2048 bit keys)
- **HMAC-SHA1**: Message authentication
- **MMH-MAC**: High-speed media authentication
- **Key Derivation**: Session key generation

### Physical Security (Section 10)
- MTA key storage protection
- Key encapsulation requirements

### Secure Software Download (Section 11)
- Authenticated firmware updates
- Code signing requirements

## Key Concepts

### Security Association (SA)
A relationship between sender and receiver defining security services:
- Encryption algorithm
- Authentication algorithm
- Keys and key lifetimes

### Kerberos Realms
- MTA realm (provisioning domain)
- CMS realm (call signaling domain)
- Inter-realm trust for cross-domain calls

### Media Encryption
Two-tier approach:
1. **Signaling security**: IPsec protects SDP with keys
2. **Media security**: Per-packet encryption/authentication

## Referenced Standards
- IETF RFC 2401-2409 (IPsec suite)
- IETF RFC 2246 (TLS)
- IETF RFC 1889 (RTP)
- IETF RFC 3414 (SNMPv3 USM)
- ITU-T X.509 (Certificates)
- NIST FIPS 180-1 (SHA-1)
- NIST FIPS 197 (AES)
