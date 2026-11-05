# MacDock Roadmap

## Stage 0 — Discovery and feasibility

Purpose: validate platform assumptions before production implementation.

Deliverables:

- MVP requirements and constraints.
- Product journey, use cases, state glossary, and testable MVP acceptance criteria.
- Apple API research.
- Bonjour discovery experiment.
- Transport and TLS experiment.
- macOS launch and activation experiment.
- Pairing threat model.
- Platform limitation documentation.
- Initial ADRs.

Completion criteria:

- Product requirements distinguish user-facing requirements from technical assumptions.
- MVP boundaries, error states, and unresolved product decisions are documented.
- Experiments have recorded results and limitations.
- Pairing and transport decisions are justified.
- Stage 1 dependencies and acceptance criteria are documented.

## Stage 1 — Architecture and foundation

- Xcode workspace and targets.
- Minimal shared Swift module where justified.
- Protocol definitions.
- CI build and test workflows.
- Testing foundations.

Stage 1 foundation implementation and acceptance review are complete. ADR 0008 records the maintainer-approved Conditional Go boundary. The Stage 1 milestone is closed; no trusted session or application-control capability was enabled.

## Stage 2 — Connection and pairing

- [Stage 2 implementation plan](docs/milestones/stage-2-implementation-plan.md)
- [Issue #38 — Pairing security specification](https://github.com/Shlomi-Hazan/MacDock/issues/38)
- [Issue #39 — Bonjour candidate discovery](https://github.com/Shlomi-Hazan/MacDock/issues/39)
- [Issue #40 — Network.framework transport](https://github.com/Shlomi-Hazan/MacDock/issues/40)
- [Issue #41 — Device identity and secure storage](https://github.com/Shlomi-Hazan/MacDock/issues/41)
- [Issue #52 — Pairing construction selection and review gate](https://github.com/Shlomi-Hazan/MacDock/issues/52)
- [Issue #53 — Platform identity and Keychain adapters](https://github.com/Shlomi-Hazan/MacDock/issues/53)
- [Issue #42 — QR-first pairing](https://github.com/Shlomi-Hazan/MacDock/issues/42)
- [Issue #43 — Authenticated sessions](https://github.com/Shlomi-Hazan/MacDock/issues/43)
- [Issue #44 — Trust revocation and recovery](https://github.com/Shlomi-Hazan/MacDock/issues/44)
- [Issue #45 — Reconnection and resynchronization](https://github.com/Shlomi-Hazan/MacDock/issues/45)
- [Issue #46 — Stage 2 integration review](https://github.com/Shlomi-Hazan/MacDock/issues/46)

Ordering and gates:

1. The Issue #52 pairing-construction gate must be selected, specified, independently reviewed, and explicitly accepted before pairing implementation.
2. Discovery and transport may be implemented as non-authorizing foundations.
3. Issue #53 identity and Keychain adapters must be implemented and validated before persistent trust or authorized sessions.
4. Two-sided pairing, identity binding, Keychain trust, revocation, and recovery must pass security review before trusted sessions.
5. Reconnection must preserve authorization and never replay non-idempotent commands automatically.
6. Stage 2 completion requires physical-device evidence, negative security tests, and a separate acceptance review.

Stage 2 does not authorize application inventory, Dock synchronization, launch, activation, cloud connectivity, or unsupported iOS background execution.

## Stage 3 — Core Dock MVP

- Mac application discovery.
- iPhone Dock persistence and customization.
- Application launch and activation.
- State synchronization.

## Stage 4 — Hardening and quality

- Unit, integration, and UI tests.
- Security review.
- Reliability and performance validation.
- Accessibility and onboarding.

## Stage 5 — Release preparation

- Signing and packaging.
- Notarization research.
- TestFlight preparation.
- Installation documentation.
- Public release notes.

Advanced controls remain candidates for later milestones and require separate scope decisions.
