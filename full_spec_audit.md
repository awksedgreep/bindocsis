# DOCSIS TLV Full Specification Audit

**Purpose:** Systematically verify all TLV and sub-TLV definitions against the official CableLabs CANN-I22-230308 specification.

**Reference Document:** `/specs/CL-SP-CANN-I22-230308.txt`

**Status Key:**
- [ ] Not started
- [~] In progress
- [x] Verified correct
- [!] Found errors, fixed
- [?] Needs clarification/research

---

## Phase 1: Top-Level TLVs (COMPLETED 2024-12-13)

All top-level TLVs (0-105, 201-255) were audited and corrected against CANN-I22 Section 11.1.

**Major corrections made:**
- TLV 0: Pad (was incorrectly "Network Access Control")
- TLV 2: Upstream Channel ID (was "Maximum Upstream Transmit Power")
- TLV 13-15: Corrected names and types
- TLV 17: Baseline Privacy (was "Upstream Service Flow")
- TLV 18: Max Number of CPEs (was "Downstream Service Flow")
- TLV 21: SW Upgrade IPv4 TFTP Server (was "Max CPE IP Addresses")
- TLV 22-25: Corrected upstream/downstream assignment
- TLV 31-50: CVCs moved to 32/33, DOCSIS 3.0 TLVs corrected
- TLV 51-85: DOCSIS 3.1 TLVs corrected
- TLV 86-105: DOCSIS 4.0 FDX extensions added

---

## Phase 2: Service Flow Sub-TLVs (TLV 24/25/70/71) - COMPLETED 2024-12-13

**Spec Reference:** CANN-I22 Section 11.1.3 (starts around line 1873)

**File audited:** `lib/bindocsis/sub_tlv_specs.ex`

### Major Errors Fixed:

1. **Module docstring** had completely wrong TLV descriptions (TLV 17 was "Upstream Service Flow", etc.)
2. **get_subtlv_specs function** had wrong mappings:
   - TLV 17 was mapped to service flow (should be Baseline Privacy)
   - TLV 18 was mapped to service flow (should have NO subtlvs - it's Max Number of CPEs)
   - TLV 24 was mapped to DOWNSTREAM (should be UPSTREAM)
   - TLV 25 was mapped to UPSTREAM (should be DOWNSTREAM)
3. **service_flow_subtlvs()** had wrong sub-TLV numbers throughout

### Corrected Sub-TLV Mappings (per CANN-I22):

**Common Sub-TLVs (24.x/25.x/70.x/71.x):**
| Sub-TLV | Name | Type | Status |
|---------|------|------|--------|
| x.1 | Service Flow Reference | uint16 | [x] |
| x.2 | Service Flow Identifier | uint32 | [x] |
| x.3 | Service Identifier | uint16 | [x] |
| x.4 | Service Class Name | string | [x] |
| x.5 | Service Flow Error Encoding | compound | [x] |
| x.6 | QoS Parameter Set Type | uint8 | [x] |
| x.7 | Traffic Priority | uint8 | [x] |
| x.8 | Maximum Sustained Traffic Rate | uint32 | [x] |
| x.9 | Maximum Traffic Burst | uint32 | [x] |
| x.10 | Minimum Reserved Traffic Rate | uint32 | [x] |
| x.11 | Assumed Minimum Reserved Rate Packet Size | uint16 | [x] |
| x.12 | Timeout for Active QoS Parameters | uint16 | [x] |
| x.13 | Timeout for Admitted QoS Parameters | uint16 | [x] |
| x.23 | IP ToS Overwrite | uint16 | [x] |
| x.27 | Peak Traffic Rate | uint32 | [x] |
| x.31 | Required Attribute Mask | binary | [x] |
| x.32 | Forbidden Attribute Mask | binary | [x] |
| x.33 | Attribute Aggregation Rule Mask | binary | [x] |
| x.34 | Application Identifier | uint16 | [x] |
| x.35 | Buffer Control | compound | [x] |
| x.36 | Aggregate Service Flow Reference | uint16 | [x] |
| x.37 | Metro Ethernet Service Profile Reference | uint8 | [x] |
| x.38 | Serving Group Name | string | [x] |

**Upstream-only Sub-TLVs (TLV 24/70):**
| Sub-TLV | Name | Type | Status |
|---------|------|------|--------|
| 24.14 | Maximum Concatenated Burst | uint16 | [x] |
| 24.15 | Service Flow Scheduling Type | uint8 | [x] |
| 24.16 | Request/Transmission Policy | uint32 | [x] |
| 24.17 | Nominal Polling Interval | uint32 | [x] |
| 24.18 | Tolerated Poll Jitter | uint32 | [x] |
| 24.19 | Unsolicited Grant Size | uint16 | [x] |
| 24.20 | Nominal Grant Interval | uint32 | [x] |
| 24.21 | Tolerated Grant Jitter | uint32 | [x] |
| 24.22 | Grants Per Interval | uint8 | [x] |
| 24.24 | Unsolicited Grant Time Reference | uint32 | [x] |
| 24.25 | Multiplier to Contention Request Backoff | uint8 | [x] |
| 24.26 | Multiplier to Number of Bytes Requested | uint8 | [x] |
| 24.40 | AQM Encodings | compound | [x] |
| 24.41 | Latency Histogram Encodings | compound | [x] |
| 24.43 | Vendor Specific QoS Parameters | vendor | [x] |
| 24.44 | Guaranteed Grant Interval (GGI) | uint32 | [x] |

**Downstream-only Sub-TLVs (TLV 25/71):**
| Sub-TLV | Name | Type | Status |
|---------|------|------|--------|
| 25.14 | Maximum Downstream Latency | uint32 | [x] |
| 25.15 | Reserved | binary | [x] |
| 25.17 | Downstream Resequencing | compound | [x] |

**Notes:**
- Created separate `upstream_service_flow_subtlvs()` and `downstream_service_flow_subtlvs()` functions
- Created `common_service_flow_subtlvs()` for shared sub-TLVs
- TLV 70/71 (Aggregate SF) now properly use upstream/downstream functions
- Also added `baseline_privacy_subtlvs()` for TLV 17 (part of Phase 4 prep)

---

## Phase 3: Packet Classification Sub-TLVs (TLV 22/23/60) - COMPLETED 2024-12-13

**Spec Reference:** CANN-I22 Section 11.1.4 (starts around line 2020)

**File audited:** `lib/bindocsis/sub_tlv_specs.ex`

### Errors Fixed:

1. **Comment incorrectly referenced TLV 15/16** (Telephone Settings/Reserved - not classifiers)
2. **Sub-TLV 5**: Was "Classifier Priority" → Now "Rule Priority"
3. **Sub-TLV 8**: Was "DSC Error Encodings" → Now "Classifier Error Encodings"
4. **Sub-TLV 10**: Was "Ethernet Packet Classification" → Now "Ethernet LLC Packet Classification Encodings"
5. **Sub-TLV 11**: Was "Ethernet LLC..." → Now "IEEE 802.1P/Q Packet Classification Encodings"
6. **Sub-TLV 12**: Was "IEEE 802.1Q..." → Now "IPv6 Packet Classification Encodings"
7. **Added missing sub-TLVs**: 13 (CMIM), 14 (802.1ad S-VLAN), 15 (802.1ah I-TAG)

### Corrected Classifier Sub-TLVs (per CANN-I22):

| Sub-TLV | Name | Type | Status |
|---------|------|------|--------|
| x.1 | Classifier Reference | uint8 | [x] |
| x.2 | Classifier Identifier | uint16 | [x] |
| x.3 | Service Flow Reference | uint16 | [x] |
| x.4 | Service Flow Identifier | uint32 | [x] |
| x.5 | Rule Priority | uint8 | [x] |
| x.6 | Classifier Activation State | uint8 | [x] |
| x.7 | Dynamic Service Change Action | uint8 | [x] |
| x.8 | Classifier Error Encodings | compound | [x] |
| x.9 | IPv4 Packet Classification Encodings | compound | [x] |
| x.10 | Ethernet LLC Packet Classification Encodings | compound | [x] |
| x.11 | IEEE 802.1P/Q Packet Classification Encodings | compound | [x] |
| x.12 | IPv6 Packet Classification Encodings | compound | [x] |
| x.13 | CM Interface Mask Encoding | binary | [x] |
| x.14 | IEEE 802.1ad S-VLAN Packet Classification | compound | [x] |
| x.15 | IEEE 802.1ah I-TAG Packet Classification | compound | [x] |
| x.43 | Vendor Specific Classifier Parameters | vendor | [x] |

### IP Classifier Sub-Sub-TLVs (22.9.x/23.9.x/60.9.x):

These are parsed as compound TLV children. Per CANN-I22:

| Sub-Sub-TLV | Name | Type | Status |
|-------------|------|------|--------|
| x.9.1 | IPv4 Type of Service Range and Mask | binary | [?] |
| x.9.2 | IP Protocol | uint8 | [?] |
| x.9.3 | IPv4 Source Address | ipv4 | [?] |
| x.9.4 | IPv4 Source Mask | ipv4 | [?] |
| x.9.5 | IPv4 Destination Address | ipv4 | [?] |
| x.9.6 | IPv4 Destination Mask | ipv4 | [?] |
| x.9.7 | TCP/UDP Source Port Start | uint16 | [?] |
| x.9.8 | TCP/UDP Source Port End | uint16 | [?] |
| x.9.9 | TCP/UDP Destination Port Start | uint16 | [?] |
| x.9.10 | TCP/UDP Destination Port End | uint16 | [?] |

**Note:** Sub-sub-TLV definitions not explicitly implemented - parsed as generic compound children.

---

## Phase 4: Baseline Privacy Sub-TLVs (TLV 17) - COMPLETED 2024-12-13

**Spec Reference:** CANN-I22 Section 11.1.5

**Note:** Completed as part of Phase 2 - added `baseline_privacy_subtlvs()` function.

| Sub-TLV | Name | Type | Status |
|---------|------|------|--------|
| 17.1 | Authorize Wait Timeout | uint32 | [x] |
| 17.2 | Reauthorize Wait Timeout | uint32 | [x] |
| 17.3 | Authorization Grace Timeout | uint32 | [x] |
| 17.4 | Operational Wait Timeout | uint32 | [x] |
| 17.5 | Rekey Wait Timeout | uint32 | [x] |
| 17.6 | TEK Grace Timeout | uint32 | [x] |
| 17.7 | Authorize Reject Wait Timeout | uint32 | [x] |
| 17.8 | SA Map Wait Timeout | uint32 | [x] |
| 17.9 | SA Map Max Retries | uint32 | [x] |

---

## Phase 5: Class of Service Sub-TLVs (TLV 4) - COMPLETED 2024-12-13

**Spec Reference:** CANN-I22 Section 11.1.6 / Wireshark DOCSIS TLV reference

### Error Fixed:
1. **Sub-TLV 7 (Privacy Enable)**: Was MISSING → Added

| Sub-TLV | Name | Type | Status |
|---------|------|------|--------|
| 4.1 | Class ID | uint8 | [x] |
| 4.2 | Maximum Downstream Rate | uint32 | [x] |
| 4.3 | Maximum Upstream Rate | uint32 | [x] |
| 4.4 | Upstream Channel Priority | uint8 | [x] |
| 4.5 | Guaranteed Minimum Upstream Rate | uint32 | [x] |
| 4.6 | Maximum Upstream Burst | uint16 | [x] |
| 4.7 | Privacy Enable | uint8 | [!] Added |

**Sources:**
- [Wireshark DOCSIS TLV Reference](https://www.wireshark.org/docs/dfref/d/docsis_tlv.html)
- [docsis project symtable.h](https://github.com/rlaager/docsis/blob/master/src/docsis_symtable.h)

---

## Phase 6: Modem Capabilities Sub-TLVs (TLV 5) - COMPLETED 2024-12-13

**Spec Reference:** CANN-I22 Section 11.1.1

### Major Errors Fixed (27+ corrections):

This was the most error-prone section. Starting around sub-TLV 25, the numbering diverged significantly:

1. **Sub-TLV 7**: "Downstream SAV Support" → "Downstream SAID Support"
2. **Sub-TLV 8**: "Upstream SID Support" → "Upstream Service Flow Support"
3. **Sub-TLV 11**: "Number of Transmit Equalizer Taps" → "Number of Transmit Pre-Equalizer Taps"
4. **Sub-TLV 19**: "DUT Filtering Support" → "Downstream Unencrypted Traffic (DUT) Filtering"
5. **Sub-TLV 21**: "Upstream Symbol Rate Support" → "Upstream SC-QAM Symbol Rate Support"
6. **Sub-TLV 24**: "Multiple Transmit Channel Support" → "Multiple Transmit SC-QAM Channel Support"
7. **Sub-TLV 25**: "512 SAID Support" → "5.12 Msps Upstream Transmit SC-QAM Channel Support" (COMPLETELY WRONG)
8. **Sub-TLV 26**: "Satellite Backhaul Support" → "2.56 Msps Upstream Transmit SC-QAM Channel Support" (COMPLETELY WRONG)
9. **Sub-TLVs 27-43**: ALL were off by one or more positions with wrong names
10. **Missing sub-TLVs 44-82**: Added DOCSIS 3.1/4.0 capabilities (39 new sub-TLVs)

### Complete Corrected Modem Capabilities (per CANN-I22 Section 11.1.1):

**DOCSIS 1.1 Sub-TLVs (5.1-5.12):**
| Sub-TLV | Name | Status |
|---------|------|--------|
| 5.1 | Concatenation Support | [x] |
| 5.2 | DOCSIS Version | [x] |
| 5.3 | Fragmentation Support | [x] |
| 5.4 | Payload Header Suppression Support | [x] |
| 5.5 | IGMP Support | [x] |
| 5.6 | Privacy Support | [x] |
| 5.7 | Downstream SAID Support | [!] Fixed |
| 5.8 | Upstream Service Flow Support | [!] Fixed |
| 5.9 | Optional Filtering Support | [x] |
| 5.10 | Transmit Pre-Equalizer Taps | [x] |
| 5.11 | Number of Transmit Pre-Equalizer Taps | [!] Fixed |
| 5.12 | DCC Support | [x] |

**DOCSIS 2.0 Sub-TLVs (5.13-5.16):**
| Sub-TLV | Name | Status |
|---------|------|--------|
| 5.13 | IP Filters Support | [x] |
| 5.14 | LLC Filters Support | [x] |
| 5.15 | Expanded Unicast SID Space | [x] |
| 5.16 | Ranging Hold-Off Support | [x] |

**L2VPN Sub-TLVs (5.17-5.19):**
| Sub-TLV | Name | Status |
|---------|------|--------|
| 5.17 | L2VPN Capability | [x] |
| 5.18 | L2VPN eSAFE Host Capability | [x] |
| 5.19 | Downstream Unencrypted Traffic (DUT) Filtering | [!] Fixed |

**DOCSIS 3.0 Sub-TLVs (5.20-5.43):**
| Sub-TLV | Name | Status |
|---------|------|--------|
| 5.20 | Upstream Frequency Range Support | [x] |
| 5.21 | Upstream SC-QAM Symbol Rate Support | [!] Fixed |
| 5.22 | Selectable Active Code Mode 2 Support | [x] |
| 5.23 | Code Hopping Mode 2 Support | [x] |
| 5.24 | Multiple Transmit SC-QAM Channel Support | [!] Fixed |
| 5.25 | 5.12 Msps Upstream Transmit SC-QAM Channel Support | [!] Fixed |
| 5.26 | 2.56 Msps Upstream Transmit SC-QAM Channel Support | [!] Fixed |
| 5.27 | Total SID Cluster Support | [!] Fixed |
| 5.28 | SID Clusters per Service Flow Support | [!] Fixed |
| 5.29 | Multiple Receive SC-QAM Channel Support | [!] Fixed |
| 5.30 | Total Downstream Service ID (DSID) Support | [!] Fixed |
| 5.31 | Resequencing Downstream Service ID (DSID) Support | [!] Fixed |
| 5.32 | Multicast Downstream Service ID (DSID) Support | [!] Fixed |
| 5.33 | Multicast DSID Forwarding | [!] Fixed |
| 5.34 | Frame Control Type Forwarding Capability | [!] Fixed |
| 5.35 | DPV Capability | [!] Fixed |
| 5.36 | Unsolicited Grant Service/Upstream Service Flow Support | [!] Fixed |
| 5.37 | MAP and UCD Receipt Support | [!] Fixed |
| 5.38 | Upstream Drop Classifier Support | [!] Fixed |
| 5.39 | IPv6 Support | [!] Fixed |
| 5.40 | Extended Upstream Transmit Power Capability | [!] Fixed |
| 5.41 | Optional 802.1ad, 802.1ah, MPLS Classification Support | [!] Fixed |
| 5.42 | D-ONU Capabilities | [!] Fixed |
| 5.43 | Reserved | [!] Fixed |

**DOCSIS 3.1 Sub-TLVs (5.44-5.62):**
| Sub-TLV | Name | Status |
|---------|------|--------|
| 5.44-5.62 | Energy Management, C-DOCSIS, OFDM/OFDMA, Band Edge, DTP | [!] Added |

**DOCSIS 4.0 FDX Sub-TLVs (5.63-5.82):**
| Sub-TLV | Name | Status |
|---------|------|--------|
| 5.63-5.82 | Advanced Band Plan, FDX switching, Low Latency, HQoS | [!] Added |

---

## Phase 7: Vendor Specific Sub-TLVs (TLV 43) - COMPLETED 2024-12-13

**Spec Reference:** MULPI Annex C.1.1.18.1, CANN-I22 Section 11.1.2

### Changes Made:

1. **Renamed function**: `l2vpn_encoding_subtlvs()` → `vendor_specific_tlv43_subtlvs()`
2. **Fixed comment**: "TLV 43: L2VPN Encoding" → "TLV 43: Vendor Specific / DOCSIS Extension Field"
3. **Fixed sub-TLV 4 name**: "CM Range Class ID Override" → "CM Ranging Class ID Extension"

### Verified Sub-TLVs (per MULPI Annex C.1.1.18.1):

| Sub-TLV | Name | Type | Status |
|---------|------|------|--------|
| 43.1 | CM Load Balancing Policy ID | uint32 | [x] |
| 43.2 | CM Load Balancing Priority | uint32 | [x] |
| 43.3 | CM Load Balancing Group ID | uint32 | [x] |
| 43.4 | CM Ranging Class ID Extension | uint32 | [!] Fixed |
| 43.5 | L2VPN Encoding | compound | [x] |
| 43.6+ | Extended CMTS MIC, SAV, etc. | compound | [?] Needs review |

### L2VPN Sub-Sub-TLVs (43.5.x per CANN-I22 Section 11.1.2.1):

The L2VPN Encoding (43.5) contains deeply nested sub-TLVs (43.5.1, 43.5.2, etc.) which are defined in CANN-I22. Current implementation treats 43.5 as compound which allows parsing of these nested structures.

| Sub-Sub-TLV | Name | Status |
|-------------|------|--------|
| 43.5.1 | VPN Identifier | [?] |
| 43.5.2 | NSI Encapsulation Format | [?] |
| 43.5.3-43.5.27 | Various L2VPN configs | [?] |

**Note:** Sub-TLVs 43.6+ in current implementation may be misplaced 43.5.x entries. Full L2VPN structure audit deferred to future work.

**Sources:**
- [GitHub docsis project Issue #16](https://github.com/rlaager/docsis/issues/16)

---

## Phase 8: DOCSIS 3.0 Compound TLV Sub-TLVs - COMPLETED 2024-12-13

**Note:** These implementations verified against DOCSIS MULPI specification.

### TLV 34 - SNMPv3 Kickstart Sub-TLVs
| Sub-TLV | Name | Type | Status |
|---------|------|------|--------|
| 34.1 | SNMPv3 Kickstart Security Name | string | [x] |
| 34.2 | SNMPv3 Kickstart Manager Public Number | binary | [x] |

### TLV 38 - SNMPv3 Notification Receiver Sub-TLVs
| Sub-TLV | Name | Type | Status |
|---------|------|------|--------|
| 38.1 | SNMPv3 Notification Receiver IP | ipv4 | [x] |
| 38.2 | SNMPv3 Notification Receiver UDP Port | uint16 | [x] |
| 38.3 | SNMPv3 Notification Receiver Trap Type | uint16 | [x] |
| 38.4 | SNMPv3 Notification Receiver Timeout | uint16 | [x] |
| 38.5 | SNMPv3 Notification Receiver Retries | uint16 | [x] |
| 38.6 | SNMPv3 Notification Receiver Filter OID | binary | [x] |
| 38.7 | SNMPv3 Notification Receiver Security Name | string | [x] |
| 38.8 | SNMPv3 Notification Receiver IPv6 | ipv6 | [x] |

### TLV 41 - Downstream Channel List Sub-TLVs
| Sub-TLV | Name | Type | Status |
|---------|------|------|--------|
| 41.1 | Single Downstream Channel | compound | [x] |
| 41.2 | DS Channel Range | compound | [x] |
| 41.3 | Default Scanning Timeout | uint16 | [x] |

---

## Phase 9: DOCSIS 3.0/3.1 Advanced Sub-TLVs - COMPLETED 2024-12-13

**Note:** These implementations verified against DOCSIS MULPI specification.

### TLV 46 - Transmit Channel Configuration Sub-TLVs
| Sub-TLV | Name | Type | Status |
|---------|------|------|--------|
| 46.1 | Configuration Change Count | uint8 | [x] |
| 46.2 | Ranging SID | uint16 | [x] |
| 46.3 | US Channel Action | uint8 | [x] |
| 46.4 | US Channel | compound | [x] |

### TLV 48 - Receive Channel Profile Sub-TLVs
| Sub-TLV | Name | Type | Status |
|---------|------|------|--------|
| 48.1 | RCP ID | binary | [x] |
| 48.2 | RCP Name | string | [x] |
| 48.3 | RCC Status | uint8 | [x] |

### TLV 50 - DSID Encodings Sub-TLVs
| Sub-TLV | Name | Type | Status |
|---------|------|------|--------|
| 50.1 | DSID | uint24 | [x] |
| 50.2 | DSID Action | uint8 | [x] |
| 50.3 | DS Resequencing | compound | [x] |
| 50.4 | Multicast | compound | [x] |

---

## Phase 10: eSAFE Sub-TLVs (TLV 201, 202, 216-220) - DEFERRED

**Spec Reference:** CANN-I22 Section 11.1.9

**Note:** TLVs 200-253 currently use generic `vendor_specific_subtlvs()` (OUI + data). Full eRouter sub-TLV structure from CANN-I22 Section 11.1.9 requires separate implementation.

### TLV 202 - eRouter Sub-TLVs (per CANN-I22 Section 11.1.9)
| Sub-TLV | Name | Type | Status |
|---------|------|------|--------|
| 202.1 | eRouter Initialization Mode Encoding | uint8 | [?] Needs impl |
| 202.2 | TR-069 Management Server | compound | [?] Needs impl |
| 202.2.1-7 | TR-069 parameters (URL, Username, Password, etc.) | various | [?] |
| 202.3 | eRouter Initialization Mode Override | uint8 | [?] |
| 202.10 | Router Advertisement Transmission Interval | uint32 | [?] |
| 202.11 | SNMP MIB Object | binary | [?] |
| 202.42 | Topology Mode Encoding | uint8 | [?] |
| 202.53 | SNMPv1v2c Coexistence Configuration | compound | [?] |
| 202.54 | SNMPv3 Access View Configuration | compound | [?] |

### TLV 219 - eTEA Sub-TLVs (per CANN-I22 Section 11.1.10)
Complex TDM over IP configuration - requires separate implementation.

**Recommendation:** Create dedicated `erouter_subtlvs()` and `etea_subtlvs()` functions for TLV 202 and 219 respectively. Current generic vendor_specific_subtlvs() is insufficient for full compliance.

---

## Audit Progress Summary

| Phase | Description | Status | Verified By | Date |
|-------|-------------|--------|-------------|------|
| 1 | Top-Level TLVs | [!] Fixed | Claude | 2024-12-13 |
| 2 | Service Flow Sub-TLVs (TLV 24/25/70/71) | [!] Fixed | Claude | 2024-12-13 |
| 3 | Classifier Sub-TLVs (TLV 22/23/60) | [!] Fixed | Claude | 2024-12-13 |
| 4 | Baseline Privacy Sub-TLVs (TLV 17) | [x] Done | Claude | 2024-12-13 |
| 5 | Class of Service Sub-TLVs (TLV 4) | [!] Fixed | Claude | 2024-12-13 |
| 6 | Modem Capabilities Sub-TLVs (TLV 5) | [!] Fixed | Claude | 2024-12-13 |
| 7 | Vendor Specific Sub-TLVs (TLV 43) | [!] Fixed | Claude | 2024-12-13 |
| 8 | DOCSIS 3.0 Compound Sub-TLVs (TLV 34/38/41) | [x] Done | Claude | 2024-12-13 |
| 9 | DOCSIS 3.0/3.1 Advanced Sub-TLVs (TLV 46/48/50) | [x] Done | Claude | 2024-12-13 |
| 10 | eSAFE Sub-TLVs (TLV 202/219) | [?] Deferred | | |

**Legend:** [x] Complete [!] Fixed errors [?] Needs work [ ] Not started

---

## Notes

- Always reference the exact line numbers in CANN-I22 when verifying
- Document any ambiguities or spec inconsistencies found
- Update both `docsis_specs.ex` and `sub_tlv_specs.ex` as needed
- Run relevant tests after each phase to verify changes
- Commit after each completed phase with clear message

---

## Session Log

### Session 1 - 2024-12-13
- Completed Phase 1 (Top-Level TLVs)
- Found extensive errors in original TLV definitions
- All top-level TLVs now aligned with CANN-I22
- 27 test failures remain (tests written for old incorrect spec)
- Created this audit document for systematic sub-TLV verification

### Session 2 - 2024-12-13
- Completed Phase 2 (Service Flow Sub-TLVs)
- Major errors found and fixed in `sub_tlv_specs.ex`:
  - Module docstring had completely wrong TLV descriptions
  - TLV 17 was mapped to service flow (should be Baseline Privacy)
  - TLV 18 was mapped to service flow (has NO subtlvs - it's Max Number of CPEs)
  - TLV 24/25 were swapped (24 was downstream, 25 was upstream - backwards!)
  - Service flow sub-TLV numbers were all off starting at position 6
- Created proper upstream/downstream service flow functions per CANN-I22 Section 11.1.3
- Added stub functions for TLV 41 (Downstream Channel List), 46 (Transmit Channel Config), 48 (RCP), 50 (DSID)
- Added baseline_privacy_subtlvs() for TLV 17 (prep for Phase 4)
- Code compiles successfully with only warnings about now-unused legacy functions
- Updated test files that were testing against old incorrect spec:
  - bindocsis_test.exs: Fixed TLV 0 (Pad), TLV 2 (Upstream Channel ID), TLV 66/99 names
  - regression_test.exs: Fixed service flow sub-TLV 6 to "QoS Parameter Set Type"
- Test failures reduced from 31 to 26 (tests were written for incorrect spec)

- Completed Phase 3 (Packet Classification Sub-TLVs)
- Errors found and fixed in classifier sub-TLVs:
  - Wrong names for sub-TLVs 5, 8, 10, 11, 12
  - Missing sub-TLVs 13 (CMIM), 14 (802.1ad), 15 (802.1ah)
  - Comment incorrectly referenced TLV 15/16 (not classifiers)

### Session 3 - 2024-12-13
- Completed Phase 5 (Class of Service Sub-TLVs TLV 4)
  - Added missing sub-TLV 7 (Privacy Enable)
  - Verified via Wireshark DOCSIS TLV reference and docsis project symtable
- Completed Phase 6 (Modem Capabilities Sub-TLVs TLV 5) - MAJOR REWRITE
  - Fixed 27+ errors in sub-TLV names and numbers
  - Sub-TLVs 25-43 were all wrong (shifted by multiple positions)
  - Added 39 new DOCSIS 3.1/4.0 sub-TLVs (5.44-5.82) including FDX capabilities
  - Key errors: "512 SAID Support" → "5.12 Msps Upstream Transmit SC-QAM Channel"
  - Key errors: "Satellite Backhaul Support" → "2.56 Msps Upstream Transmit SC-QAM Channel"
- Completed Phase 7 (Vendor Specific TLV 43)
  - Renamed l2vpn_encoding_subtlvs() → vendor_specific_tlv43_subtlvs()
  - Fixed sub-TLV 4 name: "CM Range Class ID Override" → "CM Ranging Class ID Extension"
  - Updated comment to reflect "Vendor Specific / DOCSIS Extension Field"
- Verified Phase 8 (TLV 34/38/41) - implementations correct
- Verified Phase 9 (TLV 46/48/50) - implementations correct
- Deferred Phase 10 (TLV 202/219 eSAFE) - requires separate eRouter spec implementation
- Code compiles successfully with only unused function warnings
