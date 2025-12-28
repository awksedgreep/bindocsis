# PKT-SP-DQOS1.5-C01-191120 - Dynamic Quality-of-Service Specification

## Document Information
- **Title**: Dynamic Quality-of-Service
- **Document Control Number**: PKT-SP-DQOS1.5-C01-191120
- **Status**: Closed
- **Date**: November 20, 2019
- **Publisher**: Cable Television Laboratories, Inc. (CableLabs)

## Purpose
This specification describes the dynamic Quality-of-Service (QoS) mechanism for PacketCable. It defines how client devices obtain access to PacketCable network resources and request specific QoS from the DOCSIS network.

## Scope
- QoS allocation between MTA and CMTS
- Control and delivery of QoS in PacketCable networks
- Support for embedded MTAs (E-MTAs)
- Network-based Call Signaling (NCS) support
- DOCSIS 1.1+ QoS mechanisms

## Key Topics

### PacketCable QoS Architecture (Section 5)
- **IP QoS Access Network Elements**:
  - Multimedia Terminal Adapter (MTA)
  - Cable Modem (CM)
  - Cable Modem Termination System (CMTS)
  - Call Management Server (CMS) / Gate Controller (GC)
  - Record Keeping Server (RKS)

### QoS Interfaces
- pkt-Q1: E-MTA to CM QoS protocol
- pkt-Q6: Authorization interface (CMS to CMTS)

### Resource Management Requirements
- Preventing theft of service
- Two-phase resource commitment (reserve/commit)
- Segmented resource assignment
- Resource changes during sessions
- Dynamic binding of resources
- Session class management
- V.152 support
- Multiple grants per interval (MGPI)

### Theory of Operation
- Basic session setup
- Gate coordination
- Packet classifiers management
- Admission control and session classes
- Resource renegotiations
- Billing support
- Backbone resource management
- DiffServ Code Point (DSCP) setting

### Embedded MTA to CM QoS Protocol (Section 6)
- RSVP FlowSpecs
- Mapping RSVP FlowSpecs to DOCSIS 1.1 QoS parameters
- CMTS authorization and behavior
- Two-phase QoS reservation/commit
- Payload header suppression handling
- DOCSIS 1.1 MAC Control Service Interface usage

### Authorization Interface (Section 7)
- **Gates**: Framework for QoS control
  - Classifier definitions
  - Gate identification
  - Gate state transitions (Allocated → Authorized → Reserved → Committed)
  - Gate coordination between endpoints
- **COPS Profile for PacketCable**
- **Gate Control Protocol Messages**:
  - Gate-Alloc, Gate-Set, Gate-Info
  - Gate-Open, Gate-Close, Gate-Delete

### Timer Definitions (Section 8)
- T0-T8 timers for various QoS operations

## Key Concepts

### Gate States
1. **Allocated**: Gate created, awaiting authorization
2. **Authorized**: Resources authorized by policy
3. **Reserved**: Resources reserved at CMTS
4. **Committed**: Resources active, traffic flowing

### COPS Messages
- Common Open Policy Service protocol for policy-based admission control
- REQ (Request), DEC (Decision), RPT (Report) message types

## Referenced Standards
- IETF RFC 2748 (COPS)
- IETF RFC 2753 (Policy-based Admission Control Framework)
- IETF RFC 3084 (COPS-PR)
- DOCSIS RFI v1.1+ specifications
