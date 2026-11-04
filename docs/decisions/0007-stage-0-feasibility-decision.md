# ADR 0007: Stage 0 Feasibility Decision

- Status: Proposed
- Date: 2026-11-04
- Issue: [#10](https://github.com/Shlomi-Hazan/MacDock/issues/10)
- Decision: CONDITIONAL GO

## Context

Stage 0 validated the native platform path through research, isolated macOS runtime experiments, automated tests, and maintainer-reported physical iPhone observations. It did not implement production pairing, long-term trust, or application control.

## Decision

Recommend a **CONDITIONAL GO** for Stage 1 foundation work. Stage 1 may establish Xcode targets, minimal shared models, framing and state-machine tests, lifecycle shells, and CI. It must not enable trusted application control or claim that a final pairing protocol exists.

Stage 2 must resolve and review the authenticated pairing construction, key lifecycle, recovery, and session authorization before production connections are trusted. Stage 3 must consume those gates before exposing inventory, Dock synchronization, launch, or activation commands.

The Stage 0 milestone remains open until the maintainer accepts this decision and the remaining prerequisites are represented by actionable Issues.

## Rationale

- Bonjour and Network.framework are feasible foundations on the tested platforms.
- macOS application discovery and control are feasible for tested classes but have important distribution and application-variability limits.
- iOS foreground lifecycle and opt-in idle-timer behavior are feasible within the stated product boundary.
- The security design is not yet an implementation-ready cryptographic protocol; treating it as complete would be unsafe.

## Rejected decisions

- Unconditional GO: rejected because secure pairing and authorization remain unimplemented and unreviewed.
- STOP: rejected because inert Stage 1 foundations remain valuable and can be built without exposing the unresolved security boundary.

## Completion gate

This ADR can move from Proposed to Accepted only after maintainer review of `docs/research/0010-stage-0-feasibility-review.md`, explicit confirmation of the Stage 1 security boundary, and creation or confirmation of the required Stage 1 tracking Issues.
