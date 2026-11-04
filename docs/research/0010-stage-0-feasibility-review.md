# Stage 0 Feasibility Review

- Issue: [#10](https://github.com/Shlomi-Hazan/MacDock/issues/10)
- Milestone: Stage 0 — Discovery & Feasibility
- Status: Ready for maintainer review; Stage 0 remains open
- Recommendation: **CONDITIONAL GO** for Stage 1
- Review date: 2026-11-04

## Executive decision

MacDock is feasible enough to begin Stage 1 foundations, but not ready to enable production pairing or remote application control. The recommendation is **CONDITIONAL GO**: Stage 1 may build targets, pure models, protocol/test seams, lifecycle shells, and CI, provided its acceptance criteria explicitly prevent trusted control. Stage 2 security gates must be satisfied before authenticated sessions are enabled, and Stage 3 gates must be satisfied before application-control commands are exposed.

This is not a declaration that the MVP is implemented or that pairing is cryptographically complete. The Stage 0 milestone must remain open until the maintainer reviews this recommendation and the milestone completion criteria are explicitly accepted.

## Evidence classification

- **Physical-device evidence reported by the maintainer:** Bonjour discovery, Local Network denial/recovery, TLS success with expected certificate fingerprint and receipt acknowledgment, incorrect-fingerprint rejection, and iOS Keep Screen Awake behavior. These observations are recorded as maintainer-reported, not independently tool-executed.
- **Mac runtime evidence executed in the development environment:** Bonjour advertiser/browser lifecycle, application discovery aggregate, Calculator/Chess launch and activation behavior, and transport listener/TLS setup.
- **Automated evidence:** transport framing/lifecycle tests, application discovery fixtures, lifecycle state-model tests, and Xcode/package/build validation.
- **Documentation-based evidence:** Apple lifecycle, permission, API, Keychain, App Sandbox, and distribution constraints as cited by the platform research.
- **Proposed design:** pairing protocol family, production identity registry, shared protocol schema, persistence choices, and Stage 1 boundaries.
- **Not demonstrated:** production pairing, mutual long-term trust, sandboxed or Mac App Store discovery, universal activation behavior, background networking, and production protocol compatibility.

## Stage 0 Issue audit

The actual Stage 0 milestone contains Issues #1–#10. Issues #1–#9 are closed; Issue #10 is the current review. There are no additional Stage 0 milestone issues beyond this set at the time of review. The milestone remains open with one open issue.

| Issue | Objective and verified result | Merged PR / evidence | Remaining limitations or blocker |
| --- | --- | --- | --- |
| #1 | Product requirements and MVP scope were refined with foreground-only, one-Mac/one-iPhone boundaries and testable acceptance criteria. | PR #14, merge `5e640623a47db273ff1ed5d668c457d176bbba3b` | Minimum OS versions, accessibility release bar, and some recovery UX remain open product decisions. |
| #2 | Native API feasibility research documented Network.framework, Bonjour, macOS control APIs, Keychain/CryptoKit, iOS lifecycle, permissions, and limitations. | PR #15, merge verified in repository history | Documentation is not runtime proof; physical experiments own the runtime questions. |
| #3 | Bonjour advertiser/browser experiment demonstrated macOS lifecycle and maintainer-reported physical iPhone discovery, denial, disappearance, restart, and recovery behavior. | PR #16, merge `6f36f56022b1d0afe87eaabc87cc4380323c6903` | Mac sleep/wake, multiple services, and the Wi-Fi/USB anomaly cause remain untested/unresolved. |
| #4 | Transport experiment demonstrated Network.framework TLS and framed exchange with maintainer-reported physical success and incorrect-fingerprint rejection. | PR #17, merge `22910236037e0c34be58d61a11c9ba7f399c4067` | Production pairing, mutual identity lifecycle, physical network-failure matrix, and final error taxonomy remain open. |
| #5 | Threat model and QR-first, two-sided confirmation UX proposal were documented; relay and partial-pairing limitations were made explicit. | PR #18, merge `e8bc0ff7cbc801b5b42f13df1183af3c99c522e4` | No production cryptographic construction or implementation has been selected or reviewed. |
| #6 | macOS application discovery experiment demonstrated bounded discovery and normalized metadata on the development Mac; fixtures cover identity edge cases. | PR #19, merge `a451f8d1d8a36e0aded154ac118ba884aaab525f` | Sandboxed/distribution behavior, real inaccessible/duplicate/stale registrations, and icon transfer remain untested. |
| #7 | Launch/activation experiment demonstrated asynchronous launch and activation with Calculator and Chess, missing-target error reporting, and observed frontmost outcomes. | PR #20, merge `e172be58c02911b5e18c9d4a4983753cbe9eb5c1` | Restricted application classes, forced disappearance races, sandbox/distribution behavior, and universal foreground guarantees remain open. |
| #8 | iOS lifecycle/idle-timer experiment passed pure tests and has maintainer-reported physical evidence for opt-in behavior, restoration, locking, and short screen-on observation. | PR #21, merge `179e5925182d3e422c7a9954fcb66225ffab1df7` | No battery/thermal measurements, background networking, rapid-transition stress, termination cleanup, or precise duration measurement. |
| #9 | Architecture synthesis established platform boundaries, state ownership, protocol layers, stage gates, and proposed ADRs. | PR #22, merge `e22f2d50a342da1364662ea624ae3b2ce5dffdbc` | The architecture is a proposal; Stage 1 and Stage 2 must validate its seams and security gates. |
| #10 | This document performs the cross-cutting review and recommendation. | Current PR | Requires maintainer review before Stage 0 can be declared complete. |

## Feasibility findings

### Product and scope

The planned MVP remains coherent with `PRD.md`: one Mac, one iPhone, local-first communication, a foreground iOS Dock, secure pairing, an application catalog, Dock customization, launch/activation, and explicit connection/error states. Touchpad, keyboard, media, clipboard, cloud, multi-Mac, and always-on background behavior remain excluded.

### Platform and networking

The native API path is feasible for a foreground client and menu-bar companion. Bonjour can discover a candidate service, and Network.framework can provide the transport foundation. Local Network permission behavior must remain user-visible and is not an authentication mechanism. The physical results demonstrate the tested paths only; they do not establish universal behavior across networks, OS versions, sleep/wake, or USB/routing configurations.

### Transport and security

The TLS experiment proves an encrypted physical exchange and fail-closed rejection for the tested incorrect fingerprint. It does not prove production peer identity, authorization, revocation, recovery, or relay resistance. The pairing proposal is directionally defensible but remains Proposed. No Stage 1 change may expose application-control commands before the Stage 2 security gates pass.

### Application control

Discovery, launch, and activation are feasible through native macOS APIs for the tested applications and environment. The results also demonstrate asynchronous startup and the difference between API acceptance and observed foreground state. The future product must report unknown or unsupported outcomes rather than universal success.

### iOS lifecycle

The foreground-only Dock boundary is consistent with the lifecycle experiment and product requirements. Keep Screen Awake is technically expressible as explicit opt-in idle-timer policy, but battery, thermal, duration, and background-network behavior remain non-guarantees.

## Prioritized risk register

Severity and likelihood are qualitative Stage 0 assessments, not production measurements.

| Priority | Risk | Severity / likelihood | Current evidence | Mitigation and closure criterion | Workstream / target |
| --- | --- | --- | --- | --- | --- |
| P0 | Pairing protocol is insufficient against impersonation, replay, or partial trust | Critical / medium | Threat model and QR/SAS proposal only; no production protocol | Select a reviewed construction, bind identities/transcripts, test negative cases, and prove that one-sided state cannot authorize control | Security / Stage 2; Issue #5 follow-up |
| P0 | Long-term key loss, replacement, or revocation creates unsafe recovery | Critical / medium | Keychain is recommended; lifecycle is not implemented | Define secure-store schema, rotation/revocation, explicit unpair/re-pair, and recovery tests | Security / Stage 2 |
| P1 | App Sandbox/distribution changes discovery or control capabilities | High / medium | Unsandboxed macOS experiments only | Decide distribution target; run sandboxed/signing validation and document entitlements before release architecture is fixed | Distribution / Stage 1–5; Issue #9 follow-up |
| P1 | Application identity breaks across moves, reinstalls, duplicates, or stale registrations | High / high | Fixtures and unsandboxed inventory evidence; path hash rejected as public ID | Choose opaque registry or keyed identifier with migration/unavailable-item behavior and protocol tests | App catalog / Stage 3; Issue #6 follow-up |
| P1 | Local network interruptions cause stale state or unsafe command replay | High / medium | Discovery/transport lifecycle experiments; production resync not implemented | Define revisioned resync, bounded reconnect, request freshness, and no automatic replay; integration-test network transitions | Connection / Stage 2–3; Issues #3/#4 |
| P1 | Launch/activation varies by application class and timing | High / high | Calculator and Chess runtime evidence; missing target tested | Keep outcome taxonomy, add controlled representative classes, and require truthful unknown/unsupported states | App control / Stage 3; Issue #7 |
| P1 | iOS suspension/backgrounding conflicts with perceived availability | High / high | Foreground behavior and idle-timer evidence; no networking in lifecycle experiment | Communicate foreground-only behavior, reconnect on return, and avoid background guarantees | iOS lifecycle / Stage 1–3; Issue #8 |
| P1 | Protocol compatibility or malformed messages causes desynchronization | High / medium | Framing tests and proposed versioned envelope | Add bounded parser, version negotiation, request IDs, schema fixtures, and negative tests before connections are enabled | Protocol / Stage 1–2 |
| P2 | Accessibility and metadata exposure are insufficient | Medium / medium | Requirements and privacy boundaries documented; UI not implemented | Define accessible names/states, minimize catalog fields, and run accessibility/privacy review before MVP | UX/privacy / Stage 3–4 |
| P2 | CI does not cover Xcode targets or secret content deeply enough | Medium / medium | Repository Integrity passes; dedicated scanner/build workflow not complete | Add pinned secret scanning and platform build/test workflows when targets exist; review token permissions | Governance / Stage 1; Issue #12 follow-up |
| P2 | Development signing/device setup is not reproducible for contributors | Medium / medium | Maintainer physical device available; signing remains local | Document local team selection, keep signing data untracked, and validate clean generic builds in CI where feasible | Foundation/distribution / Stage 1–5 |

## Stage 1 entry criteria

| Criterion | Status | Classification / required action |
| --- | --- | --- |
| Two-target native architecture | Sufficient for entry | Proposed in `ARCHITECTURE.md`; Stage 1 must validate target structure. |
| Minimal module boundaries | Sufficient for entry | Shared package is conditional and Foundation-only; no production control yet. |
| Development environment and signing knowledge | Partially satisfied | Maintainer Mac/iPhone/Xcode path is known; contributor and distribution signing remain Stage 1/5 work. |
| Physical Mac and iPhone capability | Satisfied for feasibility | Maintainer reported physical results; tool environment also ran Mac experiments. |
| Initial protocol/testability requirements | Sufficient for entry | Framing and state seams are defined; final crypto is intentionally deferred. |
| Security gates before control | Sufficient as a constraint | Must be encoded as Stage 1/2 acceptance criteria; no control endpoint may be enabled yet. |
| Stage separation | Satisfied | Architecture explicitly separates Stage 1 foundation, Stage 2 connection/pairing, and Stage 3 Dock control. |
| Test and CI strategy | Partially satisfied | Repository Integrity exists; Xcode/package workflow and dedicated secret scanning remain Stage 1 governance work. |
| Actionable Stage 1 work and dependencies | Partially satisfied | Blueprint is actionable; GitHub Issues for Stage 1 implementation tasks should be created only after maintainer accepts this review. |

### Must be resolved before Stage 1 starts

- Maintainer accepts the CONDITIONAL GO boundary and prohibits trusted control in Stage 1.
- Stage 1 issue breakdown identifies the target/module/protocol/test seams and their dependencies.
- The first implementation PR includes no pairing or application-control capability.

### May be resolved during Stage 1

- Minimum OS and distribution assumptions needed for target configuration.
- Xcode target structure, shared package shape, serialization, framing, and CI build/test workflows.
- Persistence adapter selection and test fixtures.
- Pinned secret-scanning workflow and documentation checks.

### Deliberately deferred

- Stage 2 pairing construction, trust lifecycle, and authenticated sessions.
- Stage 3 application catalog, Dock synchronization, launch, and activation.
- Stage 4 accessibility, reliability, performance, and broader compatibility hardening.
- Stage 5 packaging, notarization, TestFlight, and release preparation.

## Mandatory security gates

Before Stage 2/3 functionality becomes operational:

1. Bonjour visibility must not create trust.
2. Test self-signed identity/fingerprint entry must not be used as production pairing.
3. TLS connectivity must not authorize commands by itself.
4. Pairing must use a reviewed, explicit, two-sided trust flow with replay/freshness and recovery rules.
5. No arbitrary executable paths, shell commands, or unrestricted process control may cross the protocol.
6. Path-derived digests must not be presented as privacy-safe public application IDs.
7. No launch/activation endpoint may be reachable without authenticated and authorized session state.

## Scope exclusions

This review does not implement or authorize touchpad, keyboard, media, volume, clipboard, cloud relay, remote internet access, multi-Mac synchronization, always-on iOS background networking, production pairing, or production application control.

## Adversarial self-review

- **Most dangerous false assumption:** that the proposed pairing flow can be implemented securely without a concrete reviewed construction and recovery protocol. This is why the recommendation is conditional.
- **What was tested physically:** maintainer-reported Bonjour discovery/permission behavior, TLS success and incorrect-fingerprint rejection, and Keep Screen Awake/lifecycle behavior. No physical production pairing or command control was tested.
- **Essential research-only feature:** secure pairing and long-term peer trust remain proposals, not implementation evidence.
- **Strongest reason not to proceed:** enabling control before pairing is reviewed would create a security boundary failure. Stage 1 remains useful because it can build inert foundations without enabling control.
- **If pairing changes:** the Stage 1 target, framing, pure state, and test seams remain useful if they keep security/provider boundaries explicit.
- **Circular dependencies:** Stage 1 must not depend on a finished Stage 3 Dock model; protocol foundations can use fixtures. Stage 2 must not depend on UI polish, and Stage 3 must not bypass Stage 2 authorization.

## Conclusion

**Recommendation: CONDITIONAL GO.** Proceed to Stage 1 foundations only after maintainer acceptance of the explicit gates above. Do not close the Stage 0 milestone or claim production feasibility complete until this review is accepted and the remaining Stage 1 prerequisite Issues are actionable.

## References

- [PRD.md](../../PRD.md)
- [ROADMAP.md](../../ROADMAP.md)
- [SECURITY.md](../../SECURITY.md)
- [ARCHITECTURE.md](../../ARCHITECTURE.md)
- [Apple API feasibility research](0002-apple-platform-api-feasibility.md)
- [Stage 0 experiment reports](../../experiments/)
- [ADR 0003: QR-first pairing](../decisions/0003-qr-first-pairing-and-peer-authentication.md)
- [ADR 0004: application identity](../decisions/0004-application-discovery-and-identity-boundary.md)
- [ADR 0005: transport boundary](../decisions/0005-network-transport-and-protocol-boundary.md)
- [ADR 0006: modules and state ownership](../decisions/0006-minimal-modules-and-state-ownership.md)
