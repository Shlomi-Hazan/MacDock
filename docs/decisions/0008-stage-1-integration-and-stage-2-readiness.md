# ADR 0008: Stage 1 Integration and Stage 2 Readiness

- Status: Proposed
- Date: 2026-11-04
- Issue: [#30](https://github.com/Shlomi-Hazan/MacDock/issues/30)
- Decision: CONDITIONAL GO to enter Stage 2

## Context

Stage 1 established the native macOS and iOS targets, the Foundation-only shared package, bounded protocol framing, pure connection lifecycle models, platform lifecycle shells, and reproducible CI. The foundation has not implemented production networking, pairing, trusted sessions, or application control.

## Decision

Recommend a **CONDITIONAL GO** for entering Stage 2 work. Stage 2 may add isolated discovery and transport foundations, but no transport-ready or TLS-ready state may grant application-control authorization.

Before trusted sessions or application-control capabilities are enabled, Stage 2 must specify and review the pairing construction, mutual identity binding, two-sided confirmation, Keychain lifecycle, revocation and recovery, transcript/session binding, replay resistance, and authorization boundary.

ADR 0003 remains Proposed. This ADR does not select or accept its cryptographic construction.

## Conditions

1. Discovery remains untrusted candidate information.
2. Transport connectivity remains distinct from authentication and authorization.
3. Partial or one-sided pairing cannot authorize control.
4. No arbitrary paths, shell commands, inventory endpoints, Dock synchronization, launch, or activation are exposed before the security gates pass.
5. Reconnection must resynchronize state and must not automatically replay potentially non-idempotent requests.

## Consequences

Stage 1 can be reviewed as a complete inert foundation, subject to maintainer acceptance. Stage 2 can proceed incrementally, but security review is a prerequisite for trusted sessions and Stage 3 control functionality. The Stage 1 milestone should remain open until the maintainer accepts this decision and the associated Issue #30 acceptance review.

## Evidence

See [Stage 1 Integration and Acceptance Review](../research/0011-stage-1-integration-review.md) for the Issue/PR matrix, validation matrix, security audit, and risk register.
