# ADR 0006: Minimal Modules and State Ownership

- Status: Proposed
- Date: 2026-11-04
- Issue: [#9](https://github.com/Shlomi-Hazan/MacDock/issues/9)

## Context

MacDock has two platform applications with different frameworks and permissions. Stage 0 does not justify a multi-package or service architecture, but shared protocol models and pure state machines benefit from independent tests and platform isolation.

## Proposed decision

Stage 1 begins with two native app targets and, when needed, one Foundation-only shared Swift package. Platform services remain in their owning targets. The iPhone is the single writer for Dock membership/order in the one-phone MVP; the Mac is authoritative for application inventory and OS operation outcomes. Connection state is ephemeral, while trust material is stored in platform secure storage.

Dock synchronization is bounded replication, not shared authority. Updates carry an iPhone-owned revision. On reconnect, the Mac reports its last synchronized revision and the iPhone resends the current configuration when needed. A stale Mac revision cannot overwrite a newer iPhone revision. Temporary inventory failure marks selected items unavailable without deleting them, and an ambiguous revision conflict requires deterministic recovery rather than a silent merge.

## Consequences

- AppKit/UIKit imports cannot leak into shared models.
- State ownership is explicit and reconnect behavior is testable.
- A temporary inventory failure cannot erase user Dock configuration.
- More packages, databases, or dependency-injection frameworks require a concrete boundary or testability justification.

## Alternatives

- One shared cross-platform application module: rejected because platform permissions and OS APIs differ materially.
- Separate networking/security/domain packages from day one: deferred until dependency boundaries emerge.
- Server-like microservices: rejected for a one-Mac/one-iPhone local MVP.
