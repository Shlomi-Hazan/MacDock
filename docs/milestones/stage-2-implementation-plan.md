# Stage 2 — Connection and Pairing Implementation Plan

- Milestone: [Stage 2 — Connection & Pairing](https://github.com/Shlomi-Hazan/MacDock/milestone/3)
- Status: Planned; no production Stage 2 capability is enabled
- Security baseline: [ADR 0007](../decisions/0007-stage-0-feasibility-decision.md), [ADR 0008](../decisions/0008-stage-1-integration-and-stage-2-readiness.md)

## Scope and boundary

Stage 2 establishes local discovery, bounded transport, secure pairing, peer trust, authorized sessions, and recovery. Discovery is untrusted. Transport connectivity is not authentication. TLS encryption is not authorization. No application-control operation may be exposed until the security gates in this plan pass.

The plan is intentionally incremental for a single developer. Each Issue has a reviewable boundary and may use isolated test fixtures without enabling remote control.

## Dependency order

```text
Issue #38  Security requirements baseline
   ├── Issue #39  Bonjour candidate discovery
   ├── Issue #40  Network.framework transport ───────────────┐
   └── Issue #41  Identity and secure-storage design          │
                         └── Issue #52  Pairing construction gate
                                      └── Issue #53  Identity/Keychain adapters
                                                   └── Issue #42  QR pairing
                                                                    └── Issue #43  Authenticated sessions
                                                                                  ├── Issue #44  Trust recovery
Issue #40 ─────────────────────────────────────────────────────────────────────────┘
Issue #43 + #44 ── Issue #45  Reconnect and resynchronization
Issues #38–#45, #52, #53 ── Issue #46  Stage 2 integration review
```

Issue #39 may prototype untrusted discovery after the security boundary is understood. Issue #40 may implement non-authorizing transport seams. Issues #42–#45 must not create trusted sessions or control endpoints until the preceding security decisions are reviewed.

## Workstreams

| Issue | Workstream | Initial status | Gate |
| --- | --- | --- | --- |
| [#38](https://github.com/Shlomi-Hazan/MacDock/issues/38) | Pairing security specification and trust gates | Ready | First security review; ADR 0003 remains Proposed |
| [#39](https://github.com/Shlomi-Hazan/MacDock/issues/39) | Production Bonjour candidate discovery | Backlog | Visibility only; no identity or trust |
| [#40](https://github.com/Shlomi-Hazan/MacDock/issues/40) | Bounded Network.framework transport | Backlog | Transport-only state; no authorization |
| [#41](https://github.com/Shlomi-Hazan/MacDock/issues/41) | Device identity and secure key storage design | Done | Design baseline; implementation is tracked separately |
| [#52](https://github.com/Shlomi-Hazan/MacDock/issues/52) | Pairing construction selection and review gate | In Progress | Must be explicitly accepted before pairing implementation |
| [#53](https://github.com/Shlomi-Hazan/MacDock/issues/53) | Platform identity and Keychain adapters | Backlog | Requires #41 and the approved #52 construction |
| [#42](https://github.com/Shlomi-Hazan/MacDock/issues/42) | QR-first pairing and two-sided confirmation | Backlog | Requires accepted #52 and completed #53 |
| [#43](https://github.com/Shlomi-Hazan/MacDock/issues/43) | Mutual authentication and authorized sessions | Backlog | Requires #42, accepted #52, and completed #53 |
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

Until these gates pass, permitted work is limited to discovery, transport lifecycle, bounded framing, diagnostics, and isolated test exchanges. Inventory, Dock synchronization, launch, activation, arbitrary paths, and shell commands remain prohibited.

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
