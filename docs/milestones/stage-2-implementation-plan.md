# Stage 2 — Connection and Pairing Implementation Plan

- Milestone: [Stage 2 — Connection & Pairing](https://github.com/Shlomi-Hazan/MacDock/milestone/3)
- Status: In progress; no production Stage 2 capability is enabled
- Security baseline: [ADR 0007](../decisions/0007-stage-0-feasibility-decision.md), [ADR 0008](../decisions/0008-stage-1-integration-and-stage-2-readiness.md)

## Scope and boundary

Stage 2 establishes local discovery, bounded transport, secure pairing, peer trust, authorized sessions, and recovery. Discovery is untrusted. Transport connectivity is not authentication. TLS encryption is not authorization. No product operation may be exposed until the security gates in this plan and the proposed [expanded MVP authorization and privacy requirements](../security/expanded-mvp-authorization-and-privacy-requirements.md) pass.

The plan is intentionally incremental for a single developer. Each Issue has a reviewable boundary and may use isolated test fixtures without enabling remote control.

## Dependency order

```text
Issue #38  Security specification and trust gates
   ├── Issue #39  Bonjour candidate discovery
   ├── Issue #40  Network.framework transport ──┐
   └── Issue #41  Device identity and Keychain  │
                    └── Issue #42  QR pairing ──┤
                                      └── Issue #43  Authenticated sessions
                                                        ├── Issue #44  Trust recovery
Issue #40 ──────────────────────────────────────────────┘
Issue #43 + #44 ── Issue #45  Reconnect and resynchronization
Issues #38–#45 ── Issue #46  Stage 2 integration review
```

Issue #39 may prototype untrusted discovery after the security boundary is understood. Issue #40 may implement non-authorizing transport seams. Issues #42–#45 must not create trusted sessions or control endpoints until the preceding security decisions are reviewed.

## Current tracking state

As of this review, Issues #38–#41 are closed. Issues #42–#46, #52, and #53 remain open. This reflects the current GitHub state; no open work is treated as complete by this plan.

| Issues | Current state |
| --- | --- |
| #38–#41 | Closed; their reviewed deliverables remain historical evidence for the current Stage 2 work |
| #42–#46 | Open; pairing, authenticated sessions, recovery, reconnection, and Stage 2 acceptance remain incomplete |
| #52–#53 | Open; construction review and platform identity/secure-storage dependencies remain incomplete |

## Workstreams

The status column below records the initial planning state and is retained for historical traceability; it is not the current GitHub state.

| Issue | Workstream | Historical initial status | Gate |
| --- | --- | --- | --- |
| [#38](https://github.com/Shlomi-Hazan/MacDock/issues/38) | Pairing security specification and trust gates | Ready | First security review; ADR 0003 remains Proposed |
| [#39](https://github.com/Shlomi-Hazan/MacDock/issues/39) | Production Bonjour candidate discovery | Backlog | Visibility only; no identity or trust |
| [#40](https://github.com/Shlomi-Hazan/MacDock/issues/40) | Bounded Network.framework transport | Backlog | Transport-only state; no authorization |
| [#41](https://github.com/Shlomi-Hazan/MacDock/issues/41) | Device identity and secure key storage | Backlog | Key lifecycle and recovery design |
| [#42](https://github.com/Shlomi-Hazan/MacDock/issues/42) | QR-first pairing and two-sided confirmation | Backlog | Requires reviewed specification and identity lifecycle |
| [#43](https://github.com/Shlomi-Hazan/MacDock/issues/43) | Mutual authentication and authorized sessions | Backlog | Requires committed pairing and security review |
| [#44](https://github.com/Shlomi-Hazan/MacDock/issues/44) | Trust persistence, revocation, and recovery | Backlog | Fail-closed changed-peer and lost-device behavior |
| [#45](https://github.com/Shlomi-Hazan/MacDock/issues/45) | Reconnection and state resynchronization | Backlog | No stale-command replay; preserve authorization |
| [#46](https://github.com/Shlomi-Hazan/MacDock/issues/46) | Integration, physical testing, and acceptance review | Backlog | Stage 2 decision before Stage 3 |

## Mandatory security gates

Before trusted sessions:

1. Pairing has explicit approval on both devices.
2. QR bootstrap is short-lived, one-time, and bound to the intended peer; QR alone is not treated as authentication.
3. The canonical transcript, freshness, SAS semantics, and identity binding are specified and reviewed.
4. Pending, interrupted, duplicate, or one-sided pairing cannot authorize control.
5. Long-term identity and private material use an approved Keychain lifecycle.
6. Revocation, replacement, changed-peer detection, and lost-device recovery fail closed.
7. Authenticated sessions bind peer identity to the session and use replay-resistant request correlation.
8. Authorization is a separate gate from TLS and transport readiness.
9. Negative tests cover wrong peer, replay, stale trust, interruption, duplicate messages, and reconnect without replay.

Until these gates pass, permitted work is limited to discovery, transport lifecycle, bounded framing, diagnostics, isolated test exchanges, and separately documented feasibility spikes. Inventory, Dock synchronization, launch, activation, audio, media, telemetry, battery, pointer, keyboard, clipboard, arbitrary paths, and shell commands remain prohibited.

## Expanded MVP authorization dependency

The expanded MVP adds capabilities with different risk levels. Before any production control handler is implemented, the project must review capability negotiation, deny-by-default policy, session-level versus operation-level authorization, explicit consent for input and clipboard operations, grant expiry/revocation, telemetry minimization, and no-replay behavior. The addendum is a requirements dependency, not an implementation or cryptographic decision.

The implementation order is: complete the Issue #52 construction gate and Issue #53 identity work; review the authorization/privacy addendum; complete isolated platform feasibility spikes; then implement Core Dock and capability handlers one category at a time. Reconnection must invalidate sensitive grants and resynchronize state rather than replaying non-idempotent operations.

## Reuse and non-reuse of Stage 0 evidence

- Reuse the Bonjour experiment's lifecycle and permission observations, but not its prototype UI as a trust boundary.
- Reuse the TLS experiment's framing and fail-closed test shape, but not its manual fingerprint-entry UX or test certificate as production pairing.
- Reuse the pairing threat model's two-sided confirmation invariant and recovery states.
- Reuse Stage 1's bounded framing and pure lifecycle reducer; keep scheduling and platform effects outside pure logic.
- Do not treat successful compilation or TLS negotiation as proof of identity or authorization.

## Completion criteria

Stage 2 may be proposed for closure only when Issue #46 verifies:

- production discovery, transport, pairing, identity, authorization, revocation, and reconnection behavior separately;
- physical Mac/iPhone evidence for the required positive and negative scenarios;
- security review of the accepted construction and test vectors;
- no unauthorized application-control surface;
- bounded errors, privacy-safe diagnostics, and no automatic replay of non-idempotent requests;
- CI, documentation, Issues, Project, and milestone state match verified reality.

The Stage 2 review must recommend `GO`, `CONDITIONAL GO`, `REVISE`, or `STOP`. It must not authorize Stage 3 merely because a connection succeeds.
