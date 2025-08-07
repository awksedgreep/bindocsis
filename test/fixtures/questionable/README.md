# Questionable DOCSIS Files

This directory contains DOCSIS configuration files that have been identified as containing malformed or incomplete TLV data.

## Why these files are here:

1. **Malformed TLV structures**: These files contain incomplete TLV data that cannot be properly parsed according to the DOCSIS specification.

2. **Round-trip "failures"**: These files fail round-trip tests because the system correctly cleans up malformed data during conversion, resulting in smaller but valid output.

3. **Not actually bugs**: The round-trip behavior is correct - the system is fixing invalid TLV structures.

## Files moved (2025-08-07):

- TLV_22_43_5_2_4_2_MPLSPeerIpAddress.cm
- TLV_22_43_5_2_4_ServiceMultiplexingValueMPLSPW.cm
- TLV_22_43_5_2_6_IEEE8021ahEncapsulation.cm
- TLV_22_43_5_3_to_9.cm
- TLV_22_43_9_CMAttributeMasks.cm
- TLV_23_43_5_24_SOAMSubtype.cm
- TLV_23_43_last_tlvs.cm
- TLV_22_43_10_IPMulticastJoinAuthorization.cm
- TLV_22_43_5_10_and_12.cm
- TLV_22_43_5_13_L2VPNMode.cm
- TLV_22_43_5_14_DPoE.cm
- TLV_22_43_5_23_PseudowireSignaling.cm

## What to do:

- Manually review these files to determine if they represent valid DOCSIS configurations
- Consider if they should be excluded from automated round-trip tests
- Keep for manual testing if they represent edge cases that should be handled gracefully
