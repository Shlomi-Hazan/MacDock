# MacDock Roadmap

## Stage 0 — Discovery and feasibility

Purpose: validate platform assumptions before production implementation.

Deliverables:

- MVP requirements and constraints.
- Apple API research.
- Bonjour discovery experiment.
- Transport and TLS experiment.
- macOS launch and activation experiment.
- Pairing threat model.
- Platform limitation documentation.
- Initial ADRs.

Completion criteria:

- Experiments have recorded results and limitations.
- Pairing and transport decisions are justified.
- Stage 1 dependencies and acceptance criteria are documented.

## Stage 1 — Architecture and foundation

- Xcode workspace and targets.
- Minimal shared Swift module where justified.
- Protocol definitions.
- CI build and test workflows.
- Testing foundations.

## Stage 2 — Connection and pairing

- Bonjour discovery.
- Secure transport.
- User-confirmed pairing.
- Keychain-backed peer trust.
- Reconnection and error handling.

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
