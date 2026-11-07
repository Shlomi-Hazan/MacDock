# MacDock Roadmap

This roadmap describes approved product planning. A capability listed below is not implemented merely because it appears in the roadmap. The approved GitHub tracking migration is complete; tracking state does not represent technical implementation or security approval.

## Stage 0 — Discovery & Feasibility

Completed. Historical scope and evidence are preserved, including platform research, Bonjour and TLS experiments, application discovery/activation experiments, the pairing threat model, and documented limitations.

## Stage 1 — Architecture & Foundation

Completed. The native targets, Foundation-only shared package, bounded framing, pure lifecycle models, application shells, CI, and acceptance review are preserved. ADR 0008 records the accepted Conditional Go boundary. No trusted session or application-control capability was enabled.

## Stage 2 — Connection & Secure Pairing

In progress. See [Stage 2 implementation plan](docs/milestones/stage-2-implementation-plan.md).

Deliverables are untrusted Bonjour discovery, bounded Network.framework transport, device identity and secure storage, QR-first pairing, two-sided confirmation, mutually authenticated sessions, persistent trust, revocation/recovery, reconnection/resynchronization, and independent security review.

Stage 2 must not expose Dock, application, audio, media, network-control, battery-control, pointer, keyboard, clipboard, or other remote-control endpoints before authentication and the relevant capability authorization gates pass. ADR 0003 remains Proposed.

## Stage 3 — Product Design & Core Dock

GitHub milestone: [Stage 3 — Product Design & Core Dock](https://github.com/Shlomi-Hazan/MacDock/milestone/4). Parent tracking Issue: [#64](https://github.com/Shlomi-Hazan/MacDock/issues/64).

Workstreams: design system and information architecture; Mac application catalog and identity; iPhone Dock presentation; persistence and customization; launch/activation outcome semantics; accessibility baseline.

Dependencies: accepted Stage 2 peer authentication and the proposed expanded-MVP authorization/privacy requirements. Completion requires no arbitrary paths or shell operations, truthful outcomes, persistence/reconnection tests, and a reviewed capability boundary.

## Stage 4 — Mac Control Center

GitHub milestone: [Stage 4 — Mac Control Center](https://github.com/Shlomi-Hazan/MacDock/milestone/5). Parent tracking Issue: [#65](https://github.com/Shlomi-Hazan/MacDock/issues/65). Feasibility Issues: [#59](https://github.com/Shlomi-Hazan/MacDock/issues/59), [#60](https://github.com/Shlomi-Hazan/MacDock/issues/60), and [#61](https://github.com/Shlomi-Hazan/MacDock/issues/61).

Workstreams: supported audio volume/mute; validated media-player integrations; network telemetry and optional bounded speed test; Mac/iPhone/peripheral battery information; per-capability authorization and error states.

Dependencies: focused feasibility spikes, public API evidence, permission/distribution findings, and operation-level authorization. Unsupported or unavailable platform behavior must remain visible rather than simulated.

## Stage 5 — Remote Interaction & Clipboard

GitHub milestone: [Stage 5 — Remote Interaction & Clipboard](https://github.com/Shlomi-Hazan/MacDock/milestone/6). Parent tracking Issue: [#66](https://github.com/Shlomi-Hazan/MacDock/issues/66). Feasibility Issues: [#62](https://github.com/Shlomi-Hazan/MacDock/issues/62) and [#63](https://github.com/Shlomi-Hazan/MacDock/issues/63).

Workstreams: foreground touchpad/pointer movement; constrained keyboard text insertion; explicit one-shot clipboard transfer; permission UX; short-lived high-risk grants; disconnect, cancellation, and replay safeguards.

Dependencies: Accessibility/Input Monitoring and Secure Input validation, clipboard privacy review, explicit consent design, and stricter non-idempotent operation handling. No background iOS dependency is allowed.

## Stage 6 — Hardening & Quality

GitHub milestone: [Stage 6 — Hardening & Quality](https://github.com/Shlomi-Hazan/MacDock/milestone/7). Parent tracking Issue: [#67](https://github.com/Shlomi-Hazan/MacDock/issues/67).

Security/privacy review; unit, integration and UI tests; physical-device compatibility; accessibility/localization; performance and resource usage; reconnect/revocation regression; permission-denial and unsupported-hardware scenarios; safe logging review.

Completion requires evidence across positive, negative, interrupted, stale, revoked, and unavailable states.

## Stage 7 — Release Preparation

GitHub milestone: [Stage 7 — Release Preparation](https://github.com/Shlomi-Hazan/MacDock/milestone/8). Parent tracking Issue: [#68](https://github.com/Shlomi-Hazan/MacDock/issues/68).

Code signing, packaging, notarization and TestFlight preparation; Sandbox/entitlement validation; installation/onboarding/recovery/uninstall documentation; supported-platform disclosures and release notes.

Completion requires reproducible release artifacts, documented permissions, clean privacy review, and explicit exclusions for cloud access, shell execution, hidden input, and unsupported APIs.

## Cross-stage gates and dependencies

```text
Stage 2 security requirements + identity + pairing approval
                 |
                 v
Stage 3 Core Dock ----+----> Stage 4 Control Center
                     |                 |
                     +----------------> Stage 5 Interaction & Clipboard
                                      |
                                      v
                              Stage 6 Hardening
                                      |
                                      v
                              Stage 7 Release
```

Feasibility spikes for audio/media, network telemetry/speed testing, battery, input permissions, and clipboard may run as isolated research while Stage 2 is completed. They do not authorize production endpoints or alter ADR 0003.

## Current GitHub tracking

The expanded MVP authorization and privacy review is tracked by [Issue #58](https://github.com/Shlomi-Hazan/MacDock/issues/58) in [Stage 2](https://github.com/Shlomi-Hazan/MacDock/milestone/3). The Stage 4 and Stage 5 feasibility work is tracked by Issues [#59](https://github.com/Shlomi-Hazan/MacDock/issues/59), [#60](https://github.com/Shlomi-Hazan/MacDock/issues/60), [#61](https://github.com/Shlomi-Hazan/MacDock/issues/61), [#62](https://github.com/Shlomi-Hazan/MacDock/issues/62), and [#63](https://github.com/Shlomi-Hazan/MacDock/issues/63). The parent tracking Issues are [#64](https://github.com/Shlomi-Hazan/MacDock/issues/64), [#65](https://github.com/Shlomi-Hazan/MacDock/issues/65), [#66](https://github.com/Shlomi-Hazan/MacDock/issues/66), [#67](https://github.com/Shlomi-Hazan/MacDock/issues/67), and [#68](https://github.com/Shlomi-Hazan/MacDock/issues/68). These records describe planned work and dependencies; none claims implementation completion.
