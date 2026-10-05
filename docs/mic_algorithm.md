# DOCSIS Message Integrity Check (MIC) Algorithm

## Overview

DOCSIS configuration files carry two MIC TLVs, and they use **different**
algorithms (CM-SP-MULPI Annex D):

- **TLV 6 (CM MIC)**: plain (unkeyed) **MD5** digest — no shared secret involved
- **TLV 7 (CMTS MIC)**: **HMAC-MD5** keyed with the CMTS authentication string
  (shared secret)

Both digests are 16 bytes. Neither digest includes a zeroed placeholder for
the MIC TLV itself.

## References

- **CM-SP-MULPI** (DOCSIS MAC and Upper Layer Protocols Interface), Annex D:
  CM configuration file MIC calculation
- **RFC 2104**: HMAC: Keyed-Hashing for Message Authentication
- **RFC 1321**: The MD5 Message-Digest Algorithm
- Reference implementation: the open-source `docsis` tool
  (`add_cm_mic` / `add_cmts_mic`)

These algorithms are empirically verified against the fixture corpus in
`test/fixtures/`: every `.cm` file's CM MIC matches plain MD5, and the CMTS
MICs match HMAC-MD5 with the corpus shared secret `"DOCSIS"` (see
`test/crypto/mic_test.exs`, "known-good reference configs").

## CM MIC (TLV 6) Algorithm

Plain MD5 over all configuration-setting TLVs in file order, **excluding**
TLV 6, TLV 7, the End-of-Data marker (0xFF), and padding. Unkeyed — a CM MIC
can be computed and validated without any shared secret.

```elixir
tlvs_no_mic = Enum.reject(tlvs, &(&1.type in [6, 7]))
preimage = serialize_tlvs(tlvs_no_mic)   # no terminator, no placeholder
cm_mic = :crypto.hash(:md5, preimage)
```

## CMTS MIC (TLV 7) Algorithm

HMAC-MD5 keyed with the shared secret, computed over **only** the following
TLVs, in exactly this order:

```
1, 2, 3, 4, 17, 43, 6, 18, 19, 20, 22, 23, 24, 25, 28, 29, 26, 35, 36, 37, 40
```

For each listed type, every instance present in the file is included, in file
order, serialized as full type-length-value. TLV 6 (the CM MIC) is part of
the digest; TLV 7 itself is not (and no placeholder is appended). TLVs not in
the list (e.g. TLV 11 SNMP objects, TLV 202 eRouter) are **not** covered by
the CMTS MIC.

```elixir
@cmts_mic_tlv_order [1, 2, 3, 4, 17, 43, 6, 18, 19, 20, 22, 23, 24, 25, 28, 29, 26, 35, 36, 37, 40]

subset =
  Enum.flat_map(@cmts_mic_tlv_order, fn type ->
    Enum.filter(tlvs_with_cm_mic, &(&1.type == type))
  end)

cmts_mic = :crypto.mac(:hmac, :md5, shared_secret, serialize_tlvs(subset))
```

When generating a file, compute the CM MIC first, append it as TLV 6, then
compute the CMTS MIC over the subset (which picks up TLV 6) and append it as
TLV 7, followed by the 0xFF End-of-Data marker.

## Serialization

The preimage must match the bytes of the generated file exactly, so TLVs are
serialized with the same encoder the binary generator uses
(`Bindocsis.Generators.BinaryGenerator.encode_single_tlv/1`), including
multi-byte length encoding for long TLVs.

## Shared Secret Handling (CMTS MIC only)

1. **Binary as-is**: use the secret exactly as provided
2. **No normalization**: do NOT trim whitespace or change case
3. **No logging**: never log secrets — redact
4. **No storage**: accept transiently via API/CLI only

## Validation

- **CM MIC**: recompute plain MD5 and compare to the stored TLV 6 value.
  No secret required — `validate_cm_mic(tlvs)`.
- **CMTS MIC**: requires TLV 6 present; recompute HMAC-MD5 over the ordered
  subset and compare to the stored TLV 7 value — `validate_cmts_mic(tlvs, secret)`.
- Reject any TLV 6/7 whose length ≠ 16.
- Wrong secret is detectable **only** via the CMTS MIC (the CM MIC is unkeyed).
- Duplicates: validate against the last occurrence and warn.
- Bytes after the 0xFF terminator are ignored.

## Edge Cases

- **Missing MICs**: report as missing; unsigned configs (test files, drafts)
  are valid without them.
- **TLV order**: preserve file order exactly for the CM MIC preimage; the
  CMTS MIC preimage order is dictated by `@cmts_mic_tlv_order`, with
  instances of the same type kept in file order.
- **TLV 64 quirk**: legacy tools skip TLV 64 using a 2-byte length while
  scanning for CMTS MIC TLVs; files containing TLV 64 may carry CMTS MICs
  that reflect that tool-specific behavior.

## Common Pitfalls

1. Keying the CM MIC with the shared secret (it is unkeyed MD5) ❌
2. Appending a zeroed TLV 6/7 placeholder to either preimage ❌
3. Computing the CMTS MIC over all TLVs instead of the ordered subset ❌
4. Including the 0xFF terminator or padding in a preimage ❌
5. Logging or normalizing the shared secret ❌

---

**Last Updated**: September 7, 2026
**Status**: Implementation Specification (verified against reference fixtures)
**Version**: 2.0
