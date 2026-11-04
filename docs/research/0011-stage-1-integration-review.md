# Stage 1 Integration and Acceptance Review

- Issue: [#30](https://github.com/Shlomi-Hazan/MacDock/issues/30)
- Scope: Stage 1 foundation integration and readiness to enter Stage 2
- Review status: Proposed for maintainer acceptance
- Recommendation: **CONDITIONAL GO**
- Reviewed: 2026-11-04

## Executive decision

MacDock has a sufficient inert foundation to begin Stage 2 work in isolated, security-gated increments. The recommendation is **CONDITIONAL GO**, not an authorization to expose production connections or application-control commands.

The conditions are:

1. Bonjour and Network.framework work must begin as non-authorizing discovery and transport foundations.
2. ADR 0003 remains Proposed until a concrete pairing construction, transcript binding, key lifecycle, recovery model, and test vectors receive a separate security review.
3. No trusted session or application-control capability may be enabled until both-sided pairing confirmation, peer authentication, session authorization, replay protection, and revocation/recovery gates are implemented and validated.
4. Stage 2 must preserve the distinction among discovery, transport readiness, authentication, and authorization.

This document records evidence and a readiness recommendation. It does not mark Stage 1 complete without maintainer acceptance.

## Stage 1 Issue and PR evidence matrix

| Issue | Deliverable | State | Merged PR / SHA | Evidence | Remaining limitation |
| --- | --- | --- | --- | --- | --- |
| [#24](https://github.com/Shlomi-Hazan/MacDock/issues/24) | Native workspace and macOS/iOS targets | Closed | [#31](https://github.com/Shlomi-Hazan/MacDock/pull/31) / `12531ada4a190347622027a56c1166e4ecef19bf` | Local and hosted builds; maintainer-reported macOS and physical-iPhone shell observations | No production networking or control behavior |
| [#25](https://github.com/Shlomi-Hazan/MacDock/issues/25) | Minimal Foundation-only shared package | Closed | [#32](https://github.com/Shlomi-Hazan/MacDock/pull/32) / `e083cf38578e61052f9d96ad1a1c05818d2aa23c` | Shared metadata consumed by both targets; deterministic package tests and integration builds | No persistence, transport, or security services |
| [#26](https://github.com/Shlomi-Hazan/MacDock/issues/26) | Versioned envelope and bounded framing | Closed | [#33](https://github.com/Shlomi-Hazan/MacDock/pull/33) / `8dd12cf70684063833edc27756da99f27ef783f1` | 29 package tests cover framing, limits, fragmentation, malformed data, truncation, and reset | Wire message families and security binding remain deferred |
| [#27](https://github.com/Shlomi-Hazan/MacDock/issues/27) | Pure connection lifecycle reducer | Closed | [#34](https://github.com/Shlomi-Hazan/MacDock/pull/34) / `5303f782611d13086ce782b11149955cb5870b4c` | Deterministic tests cover stale callbacks, retry, timeout, cancellation, and generation exhaustion | No actual scheduler or Network.framework integration |
| [#28](https://github.com/Shlomi-Hazan/MacDock/issues/28) | Platform lifecycle shells | Closed | [#35](https://github.com/Shlomi-Hazan/MacDock/pull/35) / `708fe36ee506b52742e2fbd05143267def002f77` | Hosted builds; maintainer-reported menu-bar, quit, iPhone launch, and foreground restoration observations | Background execution and network survival are intentionally untested |
| [#29](https://github.com/Shlomi-Hazan/MacDock/issues/29) | CI and testing infrastructure | Closed | [#36](https://github.com/Shlomi-Hazan/MacDock/pull/36) / `c0812c5d8da5de9ebdf40039fe781fa5978f76e0` | Repository Integrity, package tests, six native builds, and Gitleaks passed on PR head | Hosted runner and action-runtime maintenance warnings remain |
| [#30](https://github.com/Shlomi-Hazan/MacDock/issues/30) | Integration and acceptance review | Open | This review | Evidence and readiness assessment in this document | Requires maintainer decision; Stage 1 milestone remains open |

All seven Issues are members of milestone `Stage 1 — Architecture & Foundation`. Issues #24–#29 are closed; Issue #30 is the only remaining open milestone Issue.

## Validation matrix

### Automated and build evidence

| Validation | Result | Evidence classification |
| --- | --- | --- |
| `swift test --package-path MacDockShared` | Passed, 29 tests | Tool-executed local and GitHub-hosted |
| macOS Debug build | Passed | Tool-executed local and GitHub-hosted |
| macOS Release build | Passed | Tool-executed local and GitHub-hosted |
| iOS Simulator Debug build | Passed | Tool-executed local and GitHub-hosted |
| iOS Simulator Release build | Passed | Tool-executed local and GitHub-hosted |
| generic iOS device Debug build | Passed with signing disabled | Tool-executed local and GitHub-hosted |
| generic iOS device Release build | Passed with signing disabled | Tool-executed local and GitHub-hosted |
| Repository Integrity | Passed on PR #36 | GitHub-hosted |
| Gitleaks history scan | Passed on PR #36 | GitHub-hosted |
| `git diff --check` | Passed on reviewed changes | Tool-executed |

The CI workflow uses read-only `contents` permissions. `actions/checkout` and Gitleaks are pinned to reviewed immutable commit SHAs. Hosted runs reported non-blocking Node.js 20/runtime and macOS runner-capacity warnings; these are maintenance risks, not current acceptance failures.

### Manual platform evidence

The following observations are maintainer-reported and are not automated or independently tool-executed tests:

- macOS `MacDockMac` launched from Xcode, displayed a menu-bar item and foundation status, and terminated through `Quit MacDock`.
- iOS `MacDockiOS` launched on a physical iPhone, displayed the MacDock foundation placeholder and active lifecycle state, and restored the active state after returning from the Home Screen.

These observations do not demonstrate background execution, connection survival, pairing, Keep Screen Awake behavior, persistence, application inventory, launch, activation, or Dock synchronization.

## Architecture and dependency review

The current production dependency direction is intentionally small:

```text
MacDockShared (Foundation-only)
        ^                    ^
        |                    |
MacDockMac (AppKit/SwiftUI)  MacDockiOS (SwiftUI/UIKit)
```

`MacDockShared` contains Foundation-compatible models, bounded framing, and a pure lifecycle reducer. It does not import AppKit, UIKit, SwiftUI, Network.framework, or Keychain. The native targets consume the package; experiments remain outside production targets.

Provisional deployment targets are macOS 14 and iOS 17, recorded in `MacDockShared/Package.swift` and the Xcode target settings. They are development baselines, not final distribution commitments. App Sandbox, distribution channel, notarization, and App Store constraints remain open decisions.

The current shells are inert. No production target contains Bonjour, `NWListener`, `NWConnection`, TLS session management, pairing, persistent peer identity, application inventory, Dock synchronization, launch/activation endpoints, shell execution, or background execution modes.

## Protocol and lifecycle foundation review

The framing implementation provides:

- a versioned `ProtocolEnvelope`;
- a four-byte big-endian length prefix;
- a 64 KiB authoritative encoded JSON envelope limit;
- incremental header and payload handling;
- multiple-frame decoding from one input;
- rejection of invalid, oversized, malformed, unsupported, and truncated input;
- fail-until-reset behavior after decoder errors;
- deterministic round-trip tests.

The raw `Data` guard is separate from the encoded wire limit because JSON Base64 expansion means a raw 64 KiB payload cannot always fit in a 64 KiB encoded envelope. Authentication, authorization, replay protection, transcript binding, and final message families are not implemented here.

The lifecycle reducer models discovery and transport phases only. Attempt generations reject stale callbacks and fail closed at exhaustion; `reset` cannot reuse exhausted generations. Scheduling remains outside the reducer. `transportConnected` is not authenticated, paired, trusted, or authorized. `candidateDiscovered` currently acknowledges an event without storing candidate details or changing the phase.

## Security boundary audit

The Stage 1 implementation passes the required negative checks:

- No production Bonjour advertising or browsing.
- No production `NWListener`, `NWConnection`, or TLS configuration.
- No pairing, Keychain trust, or persistent peer identity.
- No authorization shortcut or trusted-session state.
- No remote inventory, Dock synchronization, or launch/activation endpoint.
- No arbitrary filesystem path, shell command, or process-control surface.
- No unsupported iOS background mode.
- No automatic Keep Screen Awake behavior.
- No committed Team IDs, profiles, certificates, credentials, device identifiers, or private paths.

Stage 0 experiments contain intentionally isolated prototypes and test identities. They are not production dependencies.

## Stage 2 readiness and gates

### Ready now

- Native macOS and iOS target foundations.
- Foundation-only shared package.
- Versioned bounded framing and deterministic tests.
- Pure transport lifecycle state model.
- Reproducible signing-independent CI and secret scanning.
- Maintainer-reported shell validation evidence.

### Not implemented

- Bonjour discovery integration in production.
- Network.framework transport coordinator.
- Production TLS identity and peer authentication.
- QR-first pairing and two-sided confirmation.
- Keychain-backed long-term trust.
- Session authorization, revocation, and recovery.
- Reconnection and state resynchronization.

### Stage 2 entry gates

Stage 2 may implement isolated discovery and transport components only when they remain non-authorizing. Before any trusted session or application-control capability is enabled, the following gates are mandatory:

1. A concrete pairing construction is specified and separately security-reviewed; ADR 0003 remains Proposed until then.
2. Both devices verify the intended peer and complete explicit confirmation; one-sided or partial pairing cannot authorize control.
3. Long-term identity storage, replacement, revocation, and lost-device recovery are defined for Keychain-backed implementation.
4. Session establishment binds the authenticated identities to the session and includes replay-resistant request handling.
5. Authorization is separate from TLS connectivity and is enforced before any future application-control request.
6. Negative tests cover wrong-peer material, replay, interrupted pairing, stale trust, revocation, and reconnect without command replay.
7. No arbitrary path or shell execution is introduced; future control requests use validated logical application identities.

Permitted before these gates: discovery visibility, non-authorizing transport lifecycle, bounded framing, diagnostics that avoid sensitive identifiers, and isolated test fixtures. Not permitted: trusted-session claims, remote inventory, Dock synchronization, launch, activation, or any command endpoint.

## Prioritized risk register

| Risk | Severity / likelihood | Evidence and impact | Mitigation and closure criterion | Owner / stage |
| --- | --- | --- | --- | --- |
| Pairing construction and mutual identity binding remain unresolved | Critical / medium | ADR 0003 is Proposed; TLS experiment used test fingerprint trust only | Security-reviewed construction, test vectors, two-sided confirmation, and negative tests accepted before trusted sessions | Security workstream / Stage 2 |
| Long-term trust, revocation, and recovery are unspecified | High / medium | Stage 1 stores no identity | Define Keychain lifecycle, replacement, loss, and recovery tests before persistent trust | Pairing workstream / Stage 2 |
| Replay and relay resistance may be overstated | High / medium | SAS/QR improve peer selection but do not eliminate relay attacks | Document physical-origin assumptions and validate freshness/transcript binding; no claim of cryptographic relay prevention | Security workstream / Stage 2 |
| Network interruption and reconnect may cause stale commands | High / high | Reducer models stale callbacks but no real transport exists | Add integration tests for resync, request IDs, acknowledgments, and no automatic replay before control features | Transport workstream / Stage 2 |
| Protocol compatibility and schema evolution are incomplete | High / medium | Framing version exists; message families are deferred | Define reviewed message schemas, compatibility rules, size budgets, and fixture tests before production endpoints | Protocol workstream / Stage 2/3 |
| Application Sandbox and distribution assumptions remain open | Medium / medium | Stage 0 experiments were not sandboxed distribution proof | Decide distribution path and validate required entitlements before application-control release | Distribution workstream / Stage 4/5 |
| Launch/activation behavior varies by application | Medium / medium | Stage 0 tested representative macOS behavior only | Preserve accepted-vs-observed outcomes and expand controlled compatibility tests before Dock release | Control workstream / Stage 3/4 |
| Xcode/runner maintenance drift | Medium / high | Hosted runs warn about Node.js 20 and runner capacity | Review action/runtime pins and runner labels during maintenance; keep local/hosted matrix visible | Build workstream / Stage 1/4 |
| Physical-device coverage is limited | Medium / medium | Shell and earlier experiments have maintainer-reported iPhone evidence | Repeat physical validation when production networking/lifecycle behavior changes; do not treat generic builds as device proof | Validation workstream / Stage 2/4 |

## Acceptance recommendation

**Recommendation: CONDITIONAL GO to enter Stage 2.**

Stage 1 foundations are internally consistent and satisfy the implementation-level acceptance criteria supported by the available evidence. The recommendation is conditional because the essential security capability—authenticated pairing and authorized sessions—remains deliberately unimplemented.

This review does not close Issue #30, mark the Stage 1 milestone complete, accept ADR 0003, or authorize Stage 2 production control. Those actions require maintainer review and the explicit gates above.

## Traceability

- [Architecture](../../ARCHITECTURE.md)
- [Roadmap](../../ROADMAP.md)
- [Security policy](../../SECURITY.md)
- [Stage 0 decision](../decisions/0007-stage-0-feasibility-decision.md)
- [Pairing ADR](../decisions/0003-qr-first-pairing-and-peer-authentication.md)
- [Foundation validation evidence](../testing/foundation-validation.md)
- Stage 1 Issues [#24](https://github.com/Shlomi-Hazan/MacDock/issues/24) through [#30](https://github.com/Shlomi-Hazan/MacDock/issues/30)
