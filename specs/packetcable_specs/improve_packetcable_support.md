# PacketCable Support Improvements for bindocsis

## Overview

This document captures planned improvements to support PacketCable 2.0 E-UE provisioning in the bindocsis project. The goal is to enable a recertification lab to provision any vendor's eMTA/E-UE for off-hook testing with minimal configuration.

**Target Use Case:** Basic Provisioning Flow → SIP Registration → Dial Tone

---

## Feature 1: E-UE Configuration File Generation

### Description
Generate binary TLV-encoded configuration files for PacketCable 2.0 E-UEs per PKT-SP-PROV1.5 Section 9.

### TLV Types to Support

| Type | Name | Purpose |
|------|------|---------|
| 11 | SNMP MIB Object | Encodes MIB OID + value as BER VarBind |
| 254 | End of Data | Marks end of config file |
| 255 | Pad | Padding byte |

### Required MIB Objects (minimum viable)

```elixir
# Device enable
pktcMtaDevEnabled                    # 1.3.6.1.4.1.4491.2.2.1.1.1.9

# Interface enable (RFC 2863 IF-MIB)
ifAdminStatus.<ifIndex>              # 1.3.6.1.2.1.2.2.1.7.<ifIndex>

# PacketCable 2.0 E-UE Device MIB
pktcEUEDevOpDomain                   # Operator domain
pktcEUEDevOpRowStatus                # Row status
pktcEUEDevPCSCFAddrType              # P-CSCF address type
pktcEUEDevPCSCFAddr                  # P-CSCF IP address
pktcEUEDevPCSCFSipPort               # SIP port
pktcEUEDevPCSCFUsedProtocol          # UDP/TCP/TLS
pktcEUEDevPCSCFRowStatus             # Row status

# PacketCable 2.0 E-UE User MIB
pktcEUEUsrIMPUIdType                 # Public identity type
pktcEUEUsrIMPUId                     # SIP URI
pktcEUEUsrIMPUIMPIIndexRef           # Link to IMPI
pktcEUEUsrIMPUAdminStat              # Active/inactive
pktcEUEUsrIMPURowStatus              # Row status
pktcEUEUsrIMPIIdType                 # Private identity type
pktcEUEUsrIMPIId                     # Username
pktcEUEUsrIMPICredsType              # Credential type
pktcEUEUsrIMPICredentials            # Password
pktcEUEUsrIMPIRowStatus              # Row status
```

### Implementation Tasks

- [ ] Define OID constants for PacketCable 2.0 MIB objects
- [ ] Implement BER encoding for SNMP VarBinds
- [ ] Implement TLV Type 11 (SNMP MIB Object) encoder
- [ ] Implement TLV Type 254 (End of Data) encoder
- [ ] Create config file generator module
- [ ] Add tests with known-good config files

### References
- PKT-SP-PROV1.5 Section 9 (Configuration File Format)
- PKT-SP-EUE-DATA Annex B (MIB Definitions)

---

## Feature 2: OUI-Based Vendor Detection

### Description
Detect device vendor from MAC address OUI (first 3 bytes) to serve vendor-appropriate configuration.

### Implementation

```elixir
defmodule Bindocsis.PacketCable.VendorDetect do
  @oui_map %{
    "00:1A:2B" => {:arris, %{if_index_start: 9}},
    "00:1D:D1" => {:technicolor, %{if_index_start: 16}},
    "00:19:5B" => {:netgear, %{if_index_start: 9}},
    "00:1F:C4" => {:motorola, %{if_index_start: 9}},
    # ... more vendors
  }

  def detect(mac_address) do
    oui = mac_address |> normalize() |> String.slice(0, 8)
    Map.get(@oui_map, oui, {:unknown, %{if_index_start: 9}})
  end
end
```

### Implementation Tasks

- [ ] Create OUI database module
- [ ] Build OUI → vendor → ifIndex mapping
- [ ] Integrate with config file generation
- [ ] Add mechanism to update OUI database

### References
- IEEE OUI database
- PKT-SP-PROV1.5 Section 10.16 (ifIndex starting number)

---

## Feature 3: ifIndex Discovery and Caching

### Description
Query device capabilities to discover actual ifIndex values, cache for future provisioning.

### Device Capabilities String (TLV Type 5.16)
Per PKT-SP-PROV1.5 Section 10.16:
- Devices report their ifIndex starting number
- Default value: 9

### Implementation Tasks

- [ ] Parse device capabilities from DHCP/SNMP
- [ ] Extract ifIndex starting number (TLV 5.16)
- [ ] Cache ifIndex per MAC address
- [ ] Fallback to OUI-based lookup if not cached

### References
- PKT-SP-PROV1.5 Section 10 (MTA Device Capabilities)

---

## Feature 4: DHCP Option 122 Support

### Description
Generate and parse DHCP Option 122 (CableLabs Client Configuration) for E-UE provisioning.

### Sub-options to Support

| Sub-opt | Name | Purpose |
|---------|------|---------|
| 1 | Primary DHCP Server | eUE DHCP server address |
| 2 | Secondary DHCP Server | Backup DHCP server |
| 3 | Provisioning Server | SNMP entity FQDN |
| 6 | Kerberos Realm | Realm name |
| 7 | TGS Utilization | 0=Basic, 1=Hybrid, 2=Secure |
| 8 | Provisioning Timer | Timeout value |

### Implementation Tasks

- [ ] Define Option 122 encoder/decoder
- [ ] Implement sub-option handling
- [ ] Integrate with existing DHCP server
- [ ] Add Basic flow trigger (sub-option 7 = 0x00)

### References
- PKT-SP-EUE-PROV Section 6.3 (DHCP Options)
- PKT-SP-PROV1.5 Section 8 (DHCP Options)

---

## Feature 5: Dynamic Config File Generation

### Description
Generate E-UE config files on-the-fly based on device MAC, vendor, and lab configuration.

### Config Template System

```elixir
defmodule Bindocsis.PacketCable.ConfigTemplate do
  defstruct [
    :sip_server_ip,
    :sip_server_port,
    :sip_protocol,        # :udp, :tcp, :tls
    :domain,
    :user_uri,
    :username,
    :password,
    :if_index_line1,
    :if_index_line2
  ]

  def generate(%__MODULE__{} = template, mac_address) do
    vendor_info = VendorDetect.detect(mac_address)

    template
    |> apply_vendor_defaults(vendor_info)
    |> build_tlvs()
    |> encode_config_file()
  end
end
```

### Implementation Tasks

- [ ] Define config template struct
- [ ] Implement template → TLV conversion
- [ ] Add MAC-based customization
- [ ] Create CLI/API for template management

---

## Feature 6: PacketCable 1.5 NCS Support (Future)

### Description
Support legacy PacketCable 1.5 devices that use NCS/MGCP instead of SIP.

### Additional MIB Objects

```elixir
# NCS Endpoint Configuration
pktcNcsEndPntConfigCallAgentId       # CMS FQDN
pktcNcsEndPntConfigCallAgentUdpPort  # CMS port
pktcNcsEndPntConfigStatus            # Row status
pktcNcsEndPntConfigPartialDialTO     # Partial dial timeout
pktcNcsEndPntConfigCriticalDialTO    # Critical dial timeout
# ... many more timeout/config values
```

### Implementation Tasks

- [ ] Define NCS-specific MIB objects
- [ ] Implement NCS config generation
- [ ] Add protocol detection (NCS vs SIP)
- [ ] Create NCS call agent interface

### References
- PKT-SP-PROV1.5 Section 9.1.3-9.1.5 (Per-Endpoint Configuration)
- PKT-SP-NCS1.5 (Network Call Signaling)

---

## Feature 7: Config File Validation

### Description
Validate generated config files against PacketCable requirements.

### Validation Rules

Per PKT-SP-EUE-DATA Section 6.3.1:

| MIB Object | Requirement |
|------------|-------------|
| pktcMtaDevEnabled | Mandatory |
| pktcEUEDevOpTable | Conditionally Mandatory (if active users) |
| pktcEUEDevPCSCFTable | Conditionally Mandatory (if active users) |
| pktcEUEUsrIMPUTable | Conditionally Mandatory (for registration) |
| pktcEUEUsrIMPITable | Conditionally Mandatory (for auth) |

### Implementation Tasks

- [ ] Define validation rules per spec
- [ ] Implement config file parser
- [ ] Add validation warnings/errors
- [ ] Create validation report generator

---

## Feature 8: Lab Provisioning Dashboard (Future)

### Description
Web interface for managing lab provisioning.

### Features

- Device inventory (MAC, vendor, status)
- Config template management
- Real-time provisioning status
- SIP registration monitoring
- OUI database management

### Implementation Tasks

- [ ] Design Phoenix LiveView interface
- [ ] Implement device tracking
- [ ] Add config file preview/download
- [ ] Create provisioning logs view

---

## Priority Order

1. **E-UE Config File Generation** - Core functionality
2. **OUI-Based Vendor Detection** - Essential for ifIndex
3. **DHCP Option 122 Support** - Required for provisioning flow
4. **Dynamic Config File Generation** - Lab automation
5. **ifIndex Discovery** - Nice to have
6. **Config File Validation** - Quality assurance
7. **PacketCable 1.5 NCS Support** - Legacy devices
8. **Lab Dashboard** - Future enhancement

---

## Test Strategy

### Unit Tests
- TLV encoding/decoding
- BER VarBind encoding
- OUI detection
- DHCP option parsing

### Integration Tests
- Generate config → parse back → verify
- Compare with known-good vendor config files
- End-to-end provisioning flow

### Test Fixtures Needed
- Sample config files from various vendors
- Known OUI → ifIndex mappings
- DHCP Option 122 examples

---

## Specification References

| Document | Key Sections |
|----------|--------------|
| PKT-SP-EUE-PROV | 6.3 (Provisioning Flows), 7 (DHCP) |
| PKT-SP-EUE-DATA | 6.3 (Config Requirements), Annex B (MIBs) |
| PKT-SP-PROV1.5 | 7 (Flows), 9 (Config File), 10 (Capabilities) |
| PKT-SP-MIBS1.5 | 6.3.3 (ifTable), 7.2 (MIB Layering) |
| RFC 2863 | IF-MIB (ifAdminStatus) |
