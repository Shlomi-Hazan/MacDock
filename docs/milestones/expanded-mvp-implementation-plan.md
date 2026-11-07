# Expanded MVP Implementation Plan

Status: Proposed planning document. The capabilities below are planned, not implemented. The approved GitHub tracking migration is complete, but it does not accept ADR 0003 or authorize production control.

## Boundary and sequencing

Stages 0 and 1 remain complete. Stage 2 remains in progress and retains its pairing, identity, trust, revocation, recovery, and independent-review gates. The expanded MVP adds an authorization/privacy planning dependency; it does not replace Candidate A research or alter ADR 0003.

```text
Stage 2 security work (in progress) -----------+
                                              |
Authorization/privacy review ------------------+----> production gate
                                              |
Non-authorizing feasibility spikes ------------+
  audio/media | network | battery | input/clipboard
                                              |
                                              v
                                  Stage 3 Core Dock
                                              |
                                  Stage 4 Control Center
                                              |
                              Stage 5 Interaction & Clipboard
                                              |
                                        Stage 6 Hardening
                                              |
                                        Stage 7 Release
```

The feasibility spikes may start while Stage 2 work continues. They do not depend on Issue #52 or pairing approval, do not expose production endpoints, and do not grant authorization. Production handlers remain blocked until the applicable Stage 2 security/authorization gate and the relevant feasibility evidence both pass.

## GitHub tracking

The approved tracking migration preserved Stage 0–2 history, renamed the Stage 3–5 milestones, created Stage 6 and Stage 7, and added the following dependency-linked planning records:

- [#58 — Expanded MVP authorization and privacy review](https://github.com/Shlomi-Hazan/MacDock/issues/58)
- [#59 — Audio and supported media feasibility](https://github.com/Shlomi-Hazan/MacDock/issues/59)
- [#60 — Network telemetry and bounded speed test feasibility](https://github.com/Shlomi-Hazan/MacDock/issues/60)
- [#61 — Battery telemetry feasibility](https://github.com/Shlomi-Hazan/MacDock/issues/61)
- [#62 — Pointer and constrained keyboard feasibility](https://github.com/Shlomi-Hazan/MacDock/issues/62)
- [#63 — Explicit clipboard feasibility](https://github.com/Shlomi-Hazan/MacDock/issues/63)
- [#64 — Stage 3 Core Dock tracking](https://github.com/Shlomi-Hazan/MacDock/issues/64)
- [#65 — Stage 4 Mac Control Center tracking](https://github.com/Shlomi-Hazan/MacDock/issues/65)
- [#66 — Stage 5 Remote Interaction and Clipboard tracking](https://github.com/Shlomi-Hazan/MacDock/issues/66)
- [#67 — Stage 6 hardening and quality tracking](https://github.com/Shlomi-Hazan/MacDock/issues/67)
- [#68 — Stage 7 distribution and release tracking](https://github.com/Shlomi-Hazan/MacDock/issues/68)

These records are planning and dependency-tracking artifacts. Research Issues may proceed independently, while production handlers remain gated by Stage 2 authentication, authorization, feasibility, and review requirements.

## Proposed workstreams and Issues

The planning records above are now the canonical GitHub Issues for these workstreams. Their completion states must not be inferred from their existence, milestone assignment, or Project status.

### Planning and security

- `product: approve expanded MVP scope and acceptance boundaries`: baseline the eight feature groups, exclusions, support matrices, and release decision.
- `security: review expanded MVP authorization and privacy requirements`: review deny-by-default capability taxonomy, operation-level grants, input/clipboard consent, telemetry minimization, replay rules, and revocation. Must precede production control handlers.

### Feasibility spikes

- `research: validate macOS audio and supported media integrations`: test Core Audio and documented media/player surfaces; define support matrix and fallback states. No private APIs.
- `research: validate network telemetry and bounded speed test`: distinguish MacDock traffic from whole-system statistics; measure permission, resource, endpoint, and privacy constraints.
- `research: validate battery telemetry coverage`: test Mac, iPhone, and representative peripherals; define unavailable/stale semantics.
- `research: validate pointer and constrained keyboard input`: test CGEvent/event injection, Accessibility/Input Monitoring, Secure Input, revocation, and distribution assumptions without recording input.
- `research: validate explicit clipboard transfer`: test one-shot text transfer, user intent, iOS/macOS privacy behavior, size/type limits, expiry, and cleanup.

Every spike must state its hypothesis, target OS versions, public APIs, permissions, physical procedure, positive/negative acceptance criteria, distribution implications, evidence, and fallback scope.

### Implementation stages

- `stage3: build Core Dock catalog and persistence`: normalized app identity, icons, iPhone Dock store, launch/activation boundary and truthful outcomes. Depends on Stage 2 authorization review.
- `stage4: add Mac Control Center capability handlers`: audio, supported media, telemetry, speed test if accepted, and battery. Each handler has an independent authorization and unavailable state.
- `stage5: add foreground interaction and clipboard`: pointer, constrained text input, and one-shot clipboard. Depends on the input/clipboard spikes and high-risk grant review.
- `stage6: perform expanded MVP hardening`: physical devices, denial/unsupported paths, reconnect/revocation, privacy, accessibility, localization, performance, and security review.
- `stage7: prepare distribution and release`: signing, entitlements, Sandbox, notarization/TestFlight, onboarding, uninstall/recovery, release notes, and supported-platform disclosures.

## Acceptance gates

### Stage 2 to Stage 3

Accepted peer authentication and identity lifecycle; reviewed construction and test vectors; authorization/privacy requirements reviewed; no control endpoint exposed by transport readiness; explicit request correlation and no unsafe replay.

### Stage 3 to Stage 4

Core Dock has catalog revisioning, logical IDs, persistence, truthful launch/activation outcomes, reconnect behavior, and no arbitrary path/shell boundary. Stage 4 feasibility results identify supported status/control sources.

### Stage 4 to Stage 5

Each control has a capability grant, denied/unsupported/stale state, privacy review, and resource limits. Speed testing is either validated and explicitly consented or deferred.

### Stage 5 to Stage 6

Input permissions and Secure Input behavior are physically tested; pointer/keyboard grants are short-lived and revocable; clipboard is one-shot, bounded, and explicit; disconnect and duplicate cases cannot repeat sensitive operations.

### Stage 6 to Stage 7

Security review, physical-device matrix, accessibility/localization, performance, permission denial, revocation, recovery, logging, and privacy evidence are complete.

### Stage 7 completion

Reproducible signed/distribution artifacts, install and recovery documentation, supported OS disclosure, and explicit verification that out-of-scope features remain unavailable.

## Risk register

| Risk | Severity | Evidence needed | Mitigation/owner | Stage |
| --- | --- | --- | --- | --- |
| Pairing construction or identity binding is not independently accepted | Critical | ADR 0003 review, vectors, adversarial analysis | Stage 2 security work | 2 |
| Accessibility/Secure Input blocks safe keyboard or pointer distribution | High | Physical permission and protected-app tests | Input feasibility owner; narrow or defer scope | 5 |
| Whole-system network telemetry is unavailable or misleading | Medium | API and measurement experiment | Label MacDock-only stats or defer | 4 |
| Media control is player-specific | Medium | Documented support matrix | Explicit integrations and Unsupported state | 4 |
| Peripheral battery APIs are incomplete | Medium | Representative device matrix | Unavailable/Stale semantics | 4 |
| Clipboard exposes sensitive data or is replayed | High | Privacy and duplicate/disconnect tests | One-shot consent, limits, no polling | 5 |
| Reconnect repeats non-idempotent operations | High | Lost-ack and stale-session tests | Request correlation and grant invalidation | 5/6 |
| Entitlements and distribution reject privileged features | High | Sandbox/signing/TestFlight/notarization validation | Release gate; defer unsupported feature | 7 |

## Tracking migration status

The approved tracking migration has been completed separately from this planning document. Existing Stage 0–2 milestones and history were preserved; Stage 3–5 were renamed and re-scoped; Stage 6 and Stage 7 were created; and Issues #58–#68 were added to the existing MacDock Development Project with dependency, stage, priority, work type, and status metadata. This synchronization does not change the planned-versus-implemented boundary or authorize production control.

## Planned versus implemented

Implemented baseline remains native inert shells, shared pure foundations, bounded framing, lifecycle models, and CI. The eight expanded-MVP feature groups, authorization addendum, feasibility spikes, and Stage 3–7 workstreams are planning artifacts only.
