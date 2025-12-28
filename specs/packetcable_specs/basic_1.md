# PacketCable 2.0 Basic Provisioning Guide for E-UE Recertification Lab

## Overview

This guide describes the **Basic Provisioning Flow** for PacketCable 2.0 E-UE (Embedded User Equipment) devices. This is the simplest and fastest provisioning method, ideal for a recertification lab where:

- Speed is critical
- Security is not required
- Any vendor's eMTA/E-UE needs to come online
- Off-hook testing with dial tone is the goal

**Reference Specifications:**
- PKT-SP-EUE-PROV-C01-140314 (E-UE Provisioning Framework)
- PKT-SP-EUE-DATA-C01-140314 (E-UE Provisioning Data Model)
- PKT-SP-PROV1.5 (PacketCable 1.5 Device Provisioning)

---

## Provisioning Flow Overview

```
┌─────────────┐     ┌─────────────┐     ┌─────────────┐     ┌─────────────┐
│   E-UE      │     │   DHCP      │     │   TFTP      │     │  SIP/P-CSCF │
│  (Device)   │     │   Server    │     │   Server    │     │   Server    │
└──────┬──────┘     └──────┬──────┘     └──────┬──────┘     └──────┬──────┘
       │                   │                   │                   │
       │ 1. eCM DHCP       │                   │                   │
       │──────────────────>│                   │                   │
       │<──────────────────│                   │                   │
       │                   │                   │                   │
       │ 2. eCM DOCSIS Registration            │                   │
       │   (CMTS)                              │                   │
       │                   │                   │                   │
       │ 3. eUE DHCP       │                   │                   │
       │──────────────────>│                   │                   │
       │<──────────────────│                   │                   │
       │   (IP + Config File Location)         │                   │
       │                   │                   │                   │
       │ 4. Config File Download               │                   │
       │──────────────────────────────────────>│                   │
       │<──────────────────────────────────────│                   │
       │   (Binary TLV Config File)            │                   │
       │                   │                   │                   │
       │ 5. SIP REGISTER   │                   │                   │
       │──────────────────────────────────────────────────────────>│
       │<──────────────────────────────────────────────────────────│
       │   (200 OK)        │                   │                   │
       │                   │                   │                   │
       │ 6. OFF-HOOK → Dial Tone               │                   │
       │                   │                   │                   │
```

---

## Step 1: eCM (Cable Modem) DHCP Configuration

The eCM component provisions first per DOCSIS. Your DHCP server must include PacketCable-specific options in the eCM DHCP response to trigger eUE initialization.

### Required DHCP Options for eCM (IPv4)

Per PKT-SP-EUE-PROV Section 6.3.1, Table 2:

| Option | Sub-option | Value | Purpose |
|--------|------------|-------|---------|
| **122** (CableLabs Client Config) | 1 | eUE DHCP server IP | Primary DHCP server for eUE |
| 122 | 2 | (optional) | Secondary DHCP server for eUE |
| **125** (Vendor-Identifying) | | | Container for PacketCable options |
| 125 → CL_V4OPTION_IP_PREF (124) | | `0x01` (b'001) | IPv4-only mode |

**Special Values for Sub-option 1:**
- `255.255.255.255` = Accept any DHCP server (broadcast)
- `0.0.0.0` = Do NOT provision eUE (disabled)

For your lab, use `255.255.255.255` to accept any server.

---

## Step 2: eUE DHCP Configuration

After eCM completes DOCSIS registration, the eUE initializes and sends its own DHCP request.

### eUE DHCP DISCOVER (from device)

Per PKT-SP-EUE-PROV Section 6.3.3, the eUE sends:
- Option 60 (Vendor Class): Contains "pktc2.0"
- Option 55 (Parameter Request List): Requests options 122, etc.

### eUE DHCP OFFER/ACK (from your server)

Your DHCP server must respond with:

| Option | Value | Purpose |
|--------|-------|---------|
| Standard IP config | IP, subnet, gateway, DNS | Basic networking |
| **Option 122** | See sub-options below | PacketCable configuration |

#### Option 122 Sub-options for Basic Flow

Per PKT-SP-PROV1.5 and PKT-SP-EUE-PROV:

| Sub-option | Length | Value | Description |
|------------|--------|-------|-------------|
| 1 | 4 | DHCP server IP | Primary DHCP server (or 255.255.255.255) |
| 2 | 4 | (optional) | Secondary DHCP server |
| 3 | variable | FQDN string | SNMP entity (Provisioning Server) - **can be empty for Basic** |
| 6 | variable | Realm string | Kerberos realm - **triggers flow selection** |
| 7 | 1 | `0x00` | TGS Utilization: 0 = disabled (Basic flow) |
| 8 | 1-2 | Timer value | Provisioning timer |

**Key for Basic Flow:**
- Sub-option 6 (Realm): Can be any non-empty string for Basic flow
- Sub-option 7 (TGS): MUST be `0x00` to indicate Basic flow

### Triggering Basic vs Secure Flow

Per PKT-SP-PROV1.5 Section 7.2:

| Sub-option 7 Value | Flow |
|--------------------|------|
| `0x00` | **Basic Flow** - No Kerberos |
| `0x01` | Hybrid Flow |
| `0x02` | Secure Flow - Full Kerberos |

---

## Step 3: Configuration File

The eUE downloads a binary TLV-encoded configuration file via TFTP (or HTTP).

### Configuration File Location

Specified in DHCP Option 122 sub-option 3 (Provisioning Server FQDN) or via SNMP in Hybrid/Secure flows.

For **Basic Flow**, per PKT-SP-PROV1.5 Section 7.3:
- The config file URL can be provided via DHCP Option 67 (Boot File Name)
- Or via a well-known filename pattern

### Configuration File Format

The file uses TLV (Type-Length-Value) encoding per PKT-SP-PROV1.5 Section 9. Each TLV encodes a MIB object.

### Required MIB Objects for SIP Registration

Per PKT-SP-EUE-DATA Section 6.3.1, Table 6:

#### Mandatory
| MIB Object | OID | Value | Purpose |
|------------|-----|-------|---------|
| pktcMtaDevEnabled | 1.3.6.1.4.1.4491.2.2.1.1.1.9 | `true (1)` | Enable the eUE |

#### Conditionally Mandatory (for SIP registration)

**1. Operator Table Entry (pktcEUEDevOpTable)**
| MIB Object | Value | Purpose |
|------------|-------|---------|
| pktcEUEDevOpIndex | `1` | Row index |
| pktcEUEDevOpDomain | `.` (period) | Any domain |
| pktcEUEDevOpRowStatus | `4` (createAndGo) | Activate row |

**2. P-CSCF Table Entry (pktcEUEDevPCSCFTable)** - YOUR SIP SERVER
| MIB Object | Value | Purpose |
|------------|-------|---------|
| pktcEUEDevPCSCFIndex | `1` | Row index |
| pktcEUEDevPCSCFAddrType | `1` (ipv4) | Address type |
| pktcEUEDevPCSCFAddr | `<your SIP server IP>` | **P-CSCF/SIP server address** |
| pktcEUEDevPCSCFSipPort | `5060` | SIP port |
| pktcEUEDevPCSCFUsedProtocol | `2` (udp) | UDP transport |
| pktcEUEDevPCSCFRowStatus | `4` (createAndGo) | Activate row |

**3. User Public Identity (pktcEUEUsrIMPUTable)**
| MIB Object | Value | Purpose |
|------------|-------|---------|
| pktcEUEUsrIMPUIndex | `1` | Row index |
| pktcEUEUsrIMPUIdType | `3` (publicIdentity) | SIP URI type |
| pktcEUEUsrIMPUId | `sip:line1@yourdomain.local` | **SIP Address of Record (AoR)** |
| pktcEUEUsrIMPUIMPIIndexRef | `1` | Links to IMPI table |
| pktcEUEUsrIMPUAdminStat | `1` (active) | Enable user |
| pktcEUEUsrIMPURowStatus | `4` (createAndGo) | Activate row |

**4. User Private Identity/Credentials (pktcEUEUsrIMPITable)**
| MIB Object | Value | Purpose |
|------------|-------|---------|
| pktcEUEUsrIMPIIndex | `1` | Row index |
| pktcEUEUsrIMPIIdType | `6` (username) | Username type |
| pktcEUEUsrIMPIId | `line1` | **SIP username** |
| pktcEUEUsrIMPICredsType | `3` (password) | Password auth |
| pktcEUEUsrIMPICredentials | `password123` | **SIP password** |
| pktcEUEUsrIMPIRowStatus | `4` (createAndGo) | Activate row |

---

## Step 4: TLV Encoding

Per PKT-SP-PROV1.5 Section 9, the configuration file uses PacketCable TLV encoding:

### TLV Structure
```
┌──────────┬──────────┬──────────────────┐
│ Type (1) │ Len (1)  │ Value (variable) │
└──────────┴──────────┴──────────────────┘
```

### Key TLV Types (from PKT-SP-PROV1.5)

| Type | Description |
|------|-------------|
| 11 | SNMP MIB Object |
| 254 | End of Data Marker |
| 255 | Pad |

### TLV Type 11 (SNMP MIB Object) Structure
```
┌──────┬─────┬────────────────────────────────────────┐
│ 0x0B │ Len │ VarBind (BER-encoded OID + Value)      │
└──────┴─────┴────────────────────────────────────────┘
```

The VarBind is a BER-encoded SNMP SET varbind containing:
- OID of the MIB object
- Value in appropriate ASN.1 type

---

## Step 5: Enabling the Telephony Interface (CRITICAL)

**This is the step most commonly missed.** Per PKT-SP-PROV1.5 Section 7.6.2 and 7.7:

To enable telephony services on an endpoint, you MUST:
1. Set `ifAdminStatus` to `up(1)` for the endpoint's interface
2. Set `pktcNcsEndPntConfigStatus` to `active(1)` (for NCS/MGCP devices)

### The ifIndex Problem

Per PKT-SP-PROV1.5 Section 10.16:
> "This TLV contains the value of the 'ifIndex' for the first MTA Telephony Interface in 'ifTable' MIB Table."

**Default ifIndex = 9** (per spec), but **vendors vary widely**:

| Vendor | Model | Line 1 ifIndex | Line 2 ifIndex |
|--------|-------|----------------|----------------|
| Default (spec) | - | 9 | 10 |
| Arris | TM series | 9 | 10 |
| Motorola | SB series | 9 | 10 |
| Technicolor | various | 16 | 17 |
| Netgear | various | varies | varies |
| Some vendors | - | 1 | 2 |

**This is why vendor-specific config files are necessary.**

### MIB Objects for Interface Enable

**ifAdminStatus** (RFC 2863 IF-MIB):
| OID | Value | Meaning |
|-----|-------|---------|
| 1.3.6.1.2.1.2.2.1.7.`<ifIndex>` | 1 | up - enable interface |
| 1.3.6.1.2.1.2.2.1.7.`<ifIndex>` | 2 | down - disable interface |

Per PKT-SP-PROV1.5 Section 7.7:
> "Whenever an MTA reinitializes (following a reboot or a reset), it MUST immediately set the 'ifAdminStatus' entries corresponding to all available physical endpoints to a value of 'up (1)'. However, entries in the configuration file or the SNMP Management station can change this status."

### Required TLVs for Interface Enable

Add these to your configuration file:

```
# For Line 1 (assuming ifIndex=9):
TLV 11: ifAdminStatus.9 = up(1)

# For Line 2 (assuming ifIndex=10):
TLV 11: ifAdminStatus.10 = up(1)
```

### OUI-Based ifIndex Mapping (Your Custom Server)

Since ifIndex varies by vendor, your Elixir TFTP server should:

1. **Detect OUI** from MAC address
2. **Lookup ifIndex** for that vendor/model
3. **Generate config file** with correct ifIndex values

Example Elixir pseudocode:
```elixir
def get_if_index(mac_address) do
  oui = mac_address |> String.slice(0, 8) |> String.upcase()

  case oui do
    "00:1A:2B" -> {9, 10}   # Arris - lines 1,2
    "00:1D:D1" -> {16, 17}  # Technicolor
    "00:19:5B" -> {9, 10}   # Netgear (varies!)
    _ -> {9, 10}            # Default per spec
  end
end
```

### Device Capabilities Discovery

Per PKT-SP-PROV1.5 Section 10.16, devices report their ifIndex starting number in the **Capabilities String** (TLV Type 5.16).

Your provisioning system could:
1. First boot with minimal config
2. Query device capabilities via SNMP
3. Cache ifIndex mapping per MAC/model
4. Serve correct config on subsequent boots

---

## Step 6: OUI-Based Provisioning (Custom Enhancement)

Since you have custom Elixir DHCP/TFTP servers, you can implement OUI-based provisioning:

### Vendor Identification

The first 3 bytes of the MAC address identify the manufacturer (OUI):

| OUI | Manufacturer |
|-----|--------------|
| 00:1A:2B | Arris |
| 00:1D:D1 | Technicolor |
| 00:19:5B | Netgear |
| 00:1F:C4 | Motorola |
| ... | ... |

### Implementation Ideas

1. **DHCP Server**: Parse MAC address OUI, select vendor-specific config file
2. **TFTP Server**: Serve different config files based on MAC/OUI
3. **Dynamic Config Generation**: Generate config files on-the-fly with device-specific parameters

### Suggested Filename Convention
```
eue_config_<OUI>.bin       # Vendor-specific default
eue_config_<MAC>.bin       # Device-specific override
eue_config_default.bin     # Fallback for unknown devices
```

---

## Minimal Configuration File Example

For your lab, a minimal config file that works with any SIP server:

### Required TLVs (Conceptual)

```
# === DEVICE ENABLE ===
TLV 11: pktcMtaDevEnabled = true

# === INTERFACE ENABLE (CRITICAL - varies by vendor!) ===
# Default ifIndex=9 for line 1, ifIndex=10 for line 2
# MUST adjust per vendor/model
TLV 11: ifAdminStatus.9 = up(1)
TLV 11: ifAdminStatus.10 = up(1)

# === OPERATOR DOMAIN ===
TLV 11: pktcEUEDevOpDomain.1 = "."
TLV 11: pktcEUEDevOpRowStatus.1 = createAndGo(4)

# === P-CSCF / SIP SERVER ===
TLV 11: pktcEUEDevPCSCFAddrType.1.1 = ipv4(1)
TLV 11: pktcEUEDevPCSCFAddr.1.1 = <SIP_SERVER_IP>
TLV 11: pktcEUEDevPCSCFSipPort.1.1 = 5060
TLV 11: pktcEUEDevPCSCFUsedProtocol.1.1 = udp(2)
TLV 11: pktcEUEDevPCSCFRowStatus.1.1 = createAndGo(4)

# === USER PUBLIC IDENTITY (SIP URI) ===
TLV 11: pktcEUEUsrIMPUIdType.1 = publicIdentity(3)
TLV 11: pktcEUEUsrIMPUId.1 = "sip:test@lab.local"
TLV 11: pktcEUEUsrIMPUIMPIIndexRef.1 = 1
TLV 11: pktcEUEUsrIMPUAdminStat.1 = active(1)
TLV 11: pktcEUEUsrIMPURowStatus.1 = createAndGo(4)

# === USER PRIVATE IDENTITY (CREDENTIALS) ===
TLV 11: pktcEUEUsrIMPIIdType.1 = username(6)
TLV 11: pktcEUEUsrIMPIId.1 = "test"
TLV 11: pktcEUEUsrIMPICredsType.1 = password(3)
TLV 11: pktcEUEUsrIMPICredentials.1 = "password"
TLV 11: pktcEUEUsrIMPIRowStatus.1 = createAndGo(4)

# === END OF FILE ===
TLV 254: End of Data
```

### Vendor-Specific ifIndex Examples

| Config File | ifIndex Line 1 | ifIndex Line 2 | Vendors |
|-------------|----------------|----------------|---------|
| default.bin | 9 | 10 | Arris, Motorola, most |
| technicolor.bin | 16 | 17 | Technicolor |
| custom.bin | query device | query device | Unknown |

---

## Expected Behavior After Provisioning

1. **E-UE boots** → eCM gets DOCSIS config
2. **eUE initializes** → Gets IP via DHCP
3. **Config file downloaded** → Parses P-CSCF, user credentials
4. **SIP REGISTER sent** → To your SIP server
5. **Registration succeeds** → Your server accepts any credentials
6. **Off-hook** → eUE sends INVITE or requests dial tone
7. **Dial tone** → Your SIP server signals dial tone playback

---

## Troubleshooting

### eUE Not Initializing
- Check eCM DHCP response includes Option 122 with valid sub-options
- Verify sub-option 1 is not `0.0.0.0` (disabled)

### eUE Not Downloading Config
- Verify TFTP server is reachable
- Check config file path in DHCP response
- Ensure file permissions allow read

### SIP Registration Failing
- Verify pktcEUEDevPCSCFAddr points to your SIP server
- Check SIP port (5060 for UDP)
- Ensure pktcEUEUsrIMPUAdminStat is `active(1)`

### No Dial Tone
- **Check ifAdminStatus** - Most common issue! Interface may be down
- Verify ifIndex is correct for the vendor/model
- Confirm SIP REGISTER completed (check SIP server logs)
- Verify your SIP server sends appropriate signals on off-hook

### Interface Not Coming Up
- Query device via SNMP: `snmpget -v2c -c public <IP> 1.3.6.1.2.1.2.2.1.7.9`
- Try different ifIndex values (9, 10, 16, 17, 1, 2)
- Check device capabilities string for reported ifIndex start

---

## Summary: Minimum Requirements

| Component | Requirement |
|-----------|-------------|
| **DHCP (eCM)** | Option 122 with sub-option 1 (DHCP server) |
| **DHCP (eUE)** | Option 122 with sub-option 7 = 0x00 (Basic flow) |
| **TFTP** | Serve binary TLV config file |
| **Config File** | P-CSCF address, user IMPU/IMPI, credentials |
| **Config File** | **ifAdminStatus.`<ifIndex>` = up(1)** (CRITICAL!) |
| **SIP Server** | Accept any REGISTER, provide dial tone on off-hook |

### Config File Must Include (in order of importance):
1. `pktcMtaDevEnabled = true` - Enable the device
2. `ifAdminStatus.<ifIndex> = up(1)` - **Enable telephony interface** (vendor-specific ifIndex!)
3. `pktcEUEDevPCSCFAddr` - Your SIP server IP
4. `pktcEUEUsrIMPUId` - SIP URI for registration
5. `pktcEUEUsrIMPICredentials` - Password for SIP auth

This setup should allow any PacketCable 2.0 compliant E-UE to:
1. Boot and provision in seconds
2. Register with your SIP server
3. Go off-hook with dial tone

---

## References

- PKT-SP-EUE-PROV-C01-140314: Section 6.3 (Provisioning Flows), Section 7 (DHCP Options)
- PKT-SP-EUE-DATA-C01-140314: Section 6.3 (Configuration Requirements), Annex B (MIB Modules)
- PKT-SP-PROV1.5: Section 7 (Provisioning Flows), Section 9 (Configuration File)
