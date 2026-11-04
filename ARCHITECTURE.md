# MacDock Technical Architecture

- Status: Stage 1 foundation implemented; Stage 2 readiness under review
- Issue: [#9](https://github.com/Shlomi-Hazan/MacDock/issues/9)
- Scope: one Mac companion, one foreground iPhone client, local-first MVP
- Last reviewed: 2026-11-04

## Purpose and evidence

This document turns the Stage 0 requirements, Apple API research, and isolated experiments into boundaries for Stage 1. It is not production implementation and does not finalize the cryptographic wire format.

Evidence is classified as follows:

- **Demonstrated:** Bonjour visibility, Network.framework TLS with certificate-fingerprint verification in the transport experiment, macOS application discovery observations, macOS launch/activation observations, and the iOS lifecycle/idle-timer observations recorded in the experiment reports.
- **Documentation-based:** Apple platform permissions, lifecycle constraints, Keychain capabilities, and API limitations described in the platform research.
- **Proposed:** production pairing, persistent identity registry, shared protocol models, and state ownership described below.
- **Deferred:** production cryptographic construction, final minimum OS versions, distribution choice, and multi-device behavior.

The experiment targets remain isolated. Their code and test identities are not production dependencies.

## System boundary

```text
+-----------------------------+       Network.framework        +------------------------------+
| iPhone foreground app       | <----------------------------> | macOS menu bar companion     |
|                             |   Bonjour discovery only       |                              |
| - discovery and pairing UX  |   authenticated TLS session   | - listener and pairing       |
| - Dock UI and local state   |                                | - app catalog and icons      |
| - authenticated commands    |                                | - launch/activation service  |
| - lifecycle and idle timer  |                                | - authorization and status   |
+-----------------------------+                                +------------------------------+
        iOS-owned Dock state                         Mac-owned app inventory
```

Bonjour identifies candidates only. It never creates a trusted peer. The Mac companion is the authority for Mac application inventory and launch/activation outcomes; the iPhone is the single writer for the user's Dock selection and ordering in the one-phone MVP.

## macOS companion boundary

The menu bar application owns:

- Bonjour service advertising and a local `NWListener`.
- Connection lifecycle, authenticated transport, and bounded reconnect handling.
- Pairing state, peer authentication, and Keychain-backed long-term trust material.
- A bounded application catalog built from supported Launch Services/`NSWorkspace` sources.
- Normalized display metadata and icon representations safe for an authenticated client.
- Read-only running-state observation and separate launch/activation operations.
- Validation of requests against the discovered local catalog.
- Local Dock configuration synchronization and connection/pairing status.

The Mac boundary must not expose arbitrary filesystem traversal, executable paths, shell commands, unrestricted process control, or raw personal directories. All remote application operations are by an authenticated logical application identifier resolved against the current local catalog.

## iOS client boundary

The foreground iPhone app owns:

- Candidate-Mac discovery and first-pairing UX.
- User-visible peer verification and connection lifecycle state.
- Dock rendering, selection, ordering, local persistence, and icon caching.
- Authenticated, user-initiated launch/activation requests.
- Rendering acknowledgments, observed outcomes, unavailable states, and recovery actions.
- The explicit Keep Screen Awake preference and its foreground-only application.

The MVP does not depend on iOS background execution. When the app is inactive or backgrounded, the interactive Dock is unavailable by product contract. The app may retain local state and reconnect when it returns to the foreground.

## Minimal production components

Start with two native app targets and one small shared Swift package only when Stage 1 needs it:

```text
MacDockShared (Foundation-only models, framing, pure state helpers)
        ^                         ^
        |                         |
MacDockMac (AppKit, Network,     MacDockiOS (SwiftUI/UIKit,
 NSWorkspace, Keychain)           Network, Keychain)
```

Permitted dependency direction is from each platform app to the shared package. The shared package must not import AppKit, UIKit, Network.framework, SwiftUI, or Keychain. Pairing orchestration, platform permissions, UI, and OS application control remain in their platform targets.

Do not create separate networking, security, persistence, or domain packages until an actual dependency boundary, independent test seam, or reuse case justifies it. Experiments under `experiments/` are not imported by production targets.

## Protocol boundary

The Stage 1 protocol now begins with explicit, versioned Foundation-only models rather than a broad remote-control abstraction. `MacDockShared` implements a bounded four-byte big-endian length prefix and UTF-8 JSON envelope for deterministic, incremental framing, plus a pure connection lifecycle reducer. A framed message carries at least:

- protocol version and message type;
- session identifier and unique request identifier where applicable;
- bounded payload and correlation information;
- explicit response/outcome type;
- freshness or sequence data selected by the reviewed security design (not implemented by the framing foundation).

The current frame limit is 64 KiB for the encoded JSON envelope and is authoritative on the wire. The raw `Data` input guard is also bounded, but Base64 expansion means the full raw limit cannot fit in every encoded frame. This bounds shared-package buffering for control-plane foundation messages; icon transfer sizing and any production wire schema remain deferred. Framing errors fail the current decoder until an explicit reset. Parsing, version matching, and serialization do not establish authentication or authorization.

The lifecycle reducer models only discovery and transport phases. Attempt generations reject stale callbacks; exhaustion is modeled explicitly and fails closed rather than reusing a generation. Scheduling and Network.framework integration remain platform-specific future work. The current `candidateDiscovered` event acknowledges an event without storing candidate details or changing phase; discovery and candidate selection remain platform responsibilities. Transport readiness is not authentication, pairing, trust, or authorization; no trusted state exists in the foundation model.

The framing pattern demonstrated by the transport experiment may inform Stage 1 tests, but its test certificate and fingerprint-entry UX are not production pairing. The final cryptographic construction and transcript binding require a separate Stage 2 security review.

Minimum logical message families:

1. discovery metadata (untrusted candidate information);
2. pairing bootstrap, confirmation, completion, rejection, and revocation;
3. authenticated session establishment and resynchronization;
4. application inventory and inventory revision;
5. Dock configuration read/update;
6. launch/activation request and result;
7. connection, authorization, unavailable, and error states.

Transport encryption and application authorization are separate gates. A successful TLS handshake is not proof that the peer is the intended Mac, and receipt of a command is not proof that the OS completed it.

### Command outcome semantics

Launch and activation results must preserve these distinctions:

| Outcome | Meaning |
| --- | --- |
| Submitted | The client sent a request with a fresh request ID. |
| Acknowledged | The Mac accepted and validated the request. |
| Process observed | The target process was observed running. |
| Activation requested | The platform activation API accepted or returned its result. |
| Frontmost observed | A separately defined observation confirms frontmost state, where measurable. |
| Failed/unsupported/unknown | The operation failed, is not supported for the target, or cannot be verified. |

Lost acknowledgments must not cause automatic replay of potentially non-idempotent control requests. Reconnection should resynchronize inventory and Dock state instead of replaying stale commands.

## State ownership and persistence

| State | Authority | Persistence/recovery rule |
| --- | --- | --- |
| Mac application inventory | Mac | Recompute and publish revisions; temporary discovery failure does not erase the iPhone Dock. |
| Running/launch/activation observations | Mac | Ephemeral; report only observed outcomes. |
| Paired peer trust | Each device's local secure store | Both sides must complete pairing; inconsistent records enter pending/recovery, never trusted control. |
| Dock membership and order | iPhone in MVP | Persist locally and synchronize explicitly; retain unknown/unavailable items. |
| Icon metadata/cache | Mac source, iPhone cache | Cache is derived and replaceable; do not use absolute paths as wire data. |
| Connection lifecycle | Both devices for their local view | Ephemeral; derive from current session and bounded timers. |
| Keep Screen Awake preference | iPhone | Explicit opt-in preference persists; applied idle-timer state is recomputed from foreground lifecycle. |

The initial persistence API is intentionally deferred to Stage 1. A small Codable-backed local store is sufficient for one phone and one Mac; introducing a database or sync engine requires evidence. Long-lived trust material belongs in Keychain, not in the Dock configuration store.

## Security boundaries

- Bonjour and local-network reachability are untrusted input.
- Pairing requires explicit confirmation on both devices and peer identity binding as proposed in [ADR 0003](docs/decisions/0003-qr-first-pairing-and-peer-authentication.md).
- A pending or one-sided pairing record cannot authorize application-control operations.
- Future sessions require encrypted transport plus authenticated peer identity and replay-resistant request handling.
- QR and SAS confirmation improve resistance to accidental peer selection and active impersonation, but do not cryptographically eliminate relay attacks; physical-origin assumptions and residual risk remain documented.
- Requests require authorization for the paired peer and a validated logical application ID. No arbitrary path, shell command, or unrestricted executable operation is permitted.
- Unpairing, lost-device recovery, key replacement, and trust changes require explicit user-visible transitions.

## Experiment-to-production transition

| Evidence | Reuse in Stage 1 | Do not copy directly | Consuming work |
| --- | --- | --- | --- |
| Apple API research | Platform boundaries and permission explanations | Treating documentation as runtime proof | Foundation/API validation |
| Bonjour experiment | `NWBrowser`/`NWListener` lifecycle seams and privacy UX | Prototype UI and discovery as trust | Connection foundation |
| TLS experiment | Bounded framing, lifecycle tests, fail-closed trust test shape | Test certificate, manual fingerprint entry, or unconditional trust | Transport and pairing |
| Pairing threat model | Two-sided confirmation invariant and recovery states | Unreviewed cryptographic wire format | Stage 2 pairing |
| App discovery experiment | Normalized metadata and safe catalog boundary | Path-hash as a privacy-safe wire ID; CLI as service | Core Dock |
| Launch/activation experiment | Separate request/accepted/running/frontmost outcomes | Assuming callback equals foreground success | Core Dock control |
| iOS lifecycle experiment | Foreground-only lifecycle model and opt-in idle timer | Background execution guarantees or measured battery claims | iOS foundation/UX |

## Stage 1 implementation blueprint

### Recommended order

The following phases are deliberately separated. They are guidance for later work, not additional Stage 1 acceptance criteria.

#### Stage 1 — Architecture and foundation

1. Confirm minimum macOS/iOS versions, distribution assumptions, and target structure.
2. Create the two app targets and the smallest Foundation-only shared package.
3. Define versioned models, bounded framing, serialization, and pure state machines with tests.
4. Add Mac menu bar lifecycle and iOS foreground lifecycle shells.
5. Establish CI build/test seams and protocol fixture coverage without enabling remote application control.

Stage 1 must stop short of trusted pairing, production control commands, and a final cryptographic protocol.

#### Stage 2 — Connection and pairing

6. Add Bonjour discovery and connection lifecycle behind the Stage 1 interfaces.
7. Specify, review, and test the authenticated pairing construction, key storage, revocation, and bounded reconnection behavior.
8. Enable authenticated sessions only after the security gates and test vectors pass.

#### Stage 3 — Core Dock MVP

9. Add revisioned Mac application inventory, normalized icons, and iPhone Dock persistence/synchronization.
10. Add launch and activation requests behind authenticated authorization, preserving observed-outcome semantics.

### Component blueprint

| Component | Responsibility | Test seam | Initial boundary |
| --- | --- | --- | --- |
| Shared models/framing | Versioned Codable models, bounded frame parser, pure validation | Unit tests with partial/invalid frames | Foundation-only package |
| Mac connection coordinator | Listener, sessions, reconnect and resync | Injected transport/session events | Mac target |
| iOS connection coordinator | Browser, connection states, foreground reconnect | Injected browser/connection events | iOS target |
| Pairing coordinator | Pending/confirmed/revoked state and user approvals | Pure state machine plus platform secure-store adapter | Platform targets; crypto deferred |
| Mac application catalog | Discovery, normalization, revisioned inventory | Fixture URLs and metadata tests | Mac target |
| Mac control service | Validate IDs, launch/activate, observe outcomes | Mock workspace/control adapter | Mac target |
| Dock store | iPhone membership/order and unavailable entries | Codable persistence tests | iOS target |
| iOS Dock presentation | Render state and user actions | SwiftUI UI tests later | iOS target |

## Rejected or deferred alternatives

- **Bonjour as authentication:** rejected; the experiments demonstrate visibility, not identity.
- **Cloud relay:** deferred/rejected for MVP; it conflicts with the local-first requirement and adds account/server scope.
- **Arbitrary path or shell commands:** rejected; they create an unnecessary remote code/process-control boundary.
- **Direct import of experiments into production:** rejected; experiments have intentionally weaker lifecycle, identity, and trust boundaries.
- **Path SHA-256 as a public application ID:** rejected as a production wire identity; it is deterministic but dictionaryable and unstable across moves/reinstalls.
- **A final cryptographic protocol selected in Stage 0:** deferred; ADR 0003 remains Proposed until Stage 2 specifies and reviews the construction.
- **Many Swift packages or a dependency-injection framework:** deferred; no current evidence justifies the maintenance cost.

## Open risks and decisions

- Final minimum OS versions and App Sandbox/distribution model remain open.
- Stage 2 must select and review a concrete mutual-authentication construction, transcript binding, key rotation, revocation, and test vectors.
- Application identity needs a local opaque registry or keyed identifier strategy with migration behavior; neither is yet a production wire decision.
- Icon encoding, size limits, cache invalidation, and accessibility metadata require protocol and UI validation.
- Reconnection must define resynchronization and stale-command handling without automatic replay.
- Physical-device and cross-application coverage remains necessary for release quality beyond the Stage 0 experiments.

## Traceability

- Product boundaries and MVP criteria: [PRD.md](PRD.md)
- Stage sequencing: [ROADMAP.md](ROADMAP.md)
- Security baseline: [SECURITY.md](SECURITY.md)
- Pairing proposal: [ADR 0003](docs/decisions/0003-qr-first-pairing-and-peer-authentication.md)
- Platform evidence: [Apple API research](docs/research/0002-apple-platform-api-feasibility.md) and the experiment reports under `experiments/`
