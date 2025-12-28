# PKT-SP-CODEC1.5-C01-191120 - Audio/Video Codecs Specification

## Document Information
- **Title**: Audio/Video Codecs
- **Document Control Number**: PKT-SP-CODEC1.5-C01-191120
- **Status**: Closed
- **Date**: November 20, 2019
- **Publisher**: Cable Television Laboratories, Inc. (CableLabs)

## Purpose
This specification defines the audio and video codecs necessary to provide high-quality and resource-efficient service delivery for PacketCable client devices. It establishes cost-effective performance envelopes for network and device capabilities while allowing upgrades as technology evolves.

## Scope
- Interfaces between PacketCable client devices for audio and video communication
- Audio and video codec identification and requirements
- Client device performance requirements for codec support
- Network support methodology for codecs

## Key Topics

### Network Preparation for Codec Support (Section 5)
- **Packet Loss Control**: Managing packet loss for voice quality
- **Latency Control**: Ensuring acceptable delay for real-time communications
- **Codec Transcoding Minimization**: Reducing unnecessary codec conversions
- **Bandwidth Minimization**: Efficient use of network resources

### Device Requirements (Section 6)
- Dynamic update capability
- Maximum service outage specifications
- Minimum processing capability for MTAs
- Minimum audio codec storage capability

### Audio Codec Specifications (Section 7)
- **Mandatory Codecs**: G.711
- **Recommended Codecs**: iLBC, BV16
- **Optional Codecs**: G.728, G.729 Annex E, G.722
- **Feature Support**:
  - DTMF support and relay (RFC 2833)
  - Fax and modem support
  - Echo compensation (G.165, G.168)
  - Asymmetrical services
  - Hearing-impaired services
  - A-law and μ-law support
  - Packet loss concealment
  - Fax relay (T.38)
  - V.152 transmission

### Video Requirements (Section 8)
- Video encoder requirements
- Video format requirements (CIF, QCIF)
- H.263 annexes applicability
- Multipoint conferencing support
- Signaling messages (H.245)

### RTP and RTCP Usage (Section 9)
- RTP requirements for media transport
- RTCP requirements including extended reports (RFC 3611)
- Voice quality metrics

## Key Tables
- Frame sizes of codecs
- MTA processing capability
- Session description parameter mapping
- H.263 annexes applicability
- Codec comparison tables (ITU, IETF, wireless codecs)
- Bandwidth attributes of codecs

## Referenced Standards
- ITU-T G.711, G.722, G.728, G.729
- ITU-T T.38 (fax relay)
- ITU-T V.152 (voice-band data)
- IETF RFC 3551 (RTP profile)
- IETF RFC 2833 (DTMF relay)
- IETF RFC 3611 (RTCP XR)
