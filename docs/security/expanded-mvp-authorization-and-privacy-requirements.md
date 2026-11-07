# Expanded MVP Authorization and Privacy Requirements

Status: Proposed requirements addendum. This document does not approve ADR 0003, a pairing construction, or production control endpoints.

## Boundary

Discovery is untrusted. Transport readiness is not authentication. Peer authentication is not authorization. Every Mac Control Center operation must pass the authenticated-session gate and its own capability policy.

## Capability taxonomy

| Category | Examples | Default | Authorization boundary |
| --- | --- | --- | --- |
| Discovery | Candidate metadata | Visible but untrusted | No control permitted |
| Session status | Connection and availability state | Read-only after authentication | No OS mutation |
| Telemetry | Battery, supported audio/media/network state | Denied until negotiated | Minimize fields and freshness |
| Low-risk controls | Volume, supported media commands | Explicit capability grant | Validate current capability and target |
| Application control | Launch and activation | Explicit authenticated grant | Logical application IDs only |
| High-risk input | Pointer and constrained keyboard | Disabled by default | Short-lived visible grant; OS permission required |
| Sensitive data | One-shot clipboard transfer | Per-operation consent | Direction, type, size, expiry and revocation |

## Authorization rules

- Capabilities are denied by default and negotiated from an allow-listed protocol version and feature set.
- Session authentication does not grant every capability. High-risk and data-moving operations require separate policy checks.
- Grants are visible, bounded, revocable, and invalidated by disconnect, peer change, explicit revoke, or session replacement as defined by the reviewed design.
- A lost acknowledgment is not success. Non-idempotent operations must not be automatically replayed after reconnect.
- Duplicate requests require request correlation and an explicit idempotency policy; launch, pointer, keyboard, clipboard, and speed-test operations are not blindly replayed.
- OS permission denial, Secure Input, unsupported hardware, stale telemetry, and unavailable players fail closed and remain visible.

## Privacy rules

- Do not log private keys, exporter values, clipboard contents, typed text, raw input events, personal paths, or unnecessary device identifiers.
- Clipboard transfer is explicit and one-shot in the baseline MVP. Do not poll continuously or silently mirror content.
- Pointer and keyboard features must not monitor or record user input. Text insertion is constrained and must not bypass protected fields.
- Telemetry has a documented source, freshness, retention and precision policy. Speed tests disclose data use and require an explicit user action.
- Media metadata is exposed only for supported, authorized integrations.
- Diagnostics use opaque local correlation identifiers and redact sensitive payloads.

## Required adversarial validation

Tests must cover unauthorized capability requests, stale grants, disconnect during an operation, duplicate and replayed requests, changed/revoked peers, lost acknowledgments, malformed capability negotiation, permission denial, Secure Input, clipboard size/type rejection, and reconnect without non-idempotent replay.

## Open decisions

The final grant UX, capability token representation, expiration values, clipboard content policy, input permission distribution model, and interaction with the accepted pairing construction require Stage 2 security review. This addendum must not be used to infer cryptographic approval.
