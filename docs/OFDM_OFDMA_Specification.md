# DOCSIS 3.1 OFDM/OFDMA Profile Specifications

**Date:** November 6, 2025  
**Status:** Phase 1 Research  
**Version:** 1.0 (Initial Implementation)

---

## Overview

DOCSIS 3.1 introduces **OFDM (Orthogonal Frequency Division Multiplexing)** for downstream channels and **OFDMA (OFDM Access)** for upstream channels. These technologies enable:

- **Higher spectral efficiency** - Better use of available bandwidth
- **Improved noise immunity** - Better performance in noisy RF environments
- **Channel bonding** - Combining multiple channels for higher throughput
- **Flexible channel widths** - Support for various bandwidth configurations
- **Advanced modulation** - Support for up to 4096-QAM

### Key Differences: OFDM vs OFDMA

- **OFDM (Downstream/TLV 62)**: Full channel access, optimized for point-to-multipoint broadcast
- **OFDMA (Upstream/TLV 63)**: Shared channel access with time/frequency scheduling, optimized for multipoint-to-point

---

## TLV 62: Downstream OFDM Profile

### Description
Defines configuration parameters for downstream OFDM channels in DOCSIS 3.1 systems. OFDM profiles control how data is transmitted from the CMTS to cable modems.

### Sub-TLV Specifications

**Note:** This is an initial implementation based on DOCSIS 3.1 standards and common OFDM parameters.

#### Sub-TLV 1: Profile ID
- **Type:** 1
- **Value Type:** `uint8`
- **Length:** 1 byte
- **Purpose:** Unique OFDM profile identifier

#### Sub-TLV 2: Channel ID
- **Type:** 2
- **Value Type:** `uint8`
- **Length:** 1 byte
- **Purpose:** OFDM channel identifier

#### Sub-TLV 3: Configuration Change Count
- **Type:** 3
- **Value Type:** `uint8`
- **Length:** 1 byte
- **Purpose:** Detects configuration updates

#### Sub-TLV 4: Subcarrier Spacing
- **Type:** 4
- **Value Type:** `uint8`
- **Enum Values:**
  - `0` = "25 kHz"
  - `1` = "50 kHz"

#### Sub-TLV 5: Cyclic Prefix
- **Type:** 5
- **Value Type:** `uint8`
- **Enum Values:**
  - `0` = "192 samples"
  - `1` = "256 samples"
  - `2` = "384 samples"
  - `3` = "512 samples"
  - `4` = "640 samples"
  - `5` = "768 samples"
  - `6` = "896 samples"
  - `7` = "1024 samples"

[... Full specification continues ...]

---

**Document Status:** Phase 1 Research Complete  
**Next Step:** Proceed to Phase 2 Implementation
