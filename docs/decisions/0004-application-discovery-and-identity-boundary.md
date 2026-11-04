# ADR 0004: Application Discovery and Identity Boundary

- Status: Proposed
- Date: 2026-11-04
- Issue: [#9](https://github.com/Shlomi-Hazan/MacDock/issues/9)

## Context

The macOS discovery experiment showed that `NSWorkspace`/Launch Services can provide useful application references and metadata, but a running-application list is not an installed-app inventory. Bundle identifiers may be absent or duplicated, paths can change, and a plain SHA-256 digest of a predictable path is not a privacy-safe network identifier.

## Proposed decision

Keep discovery and Dock state separate. The Mac owns a revisioned, normalized catalog of launchable applications. The iPhone stores Dock selections by a logical application ID and retains selected entries when inventory is temporarily unavailable.

For the production wire protocol, use an authenticated opaque ID backed by a Mac-local mapping. A locally keyed HMAC-based identifier is a candidate when its key lifecycle and migration rules are specified; a random opaque registry is the simpler alternative. Stage 1 must compare these choices before implementation. Bundle identifier and canonical URL remain Mac-local diagnostic/disambiguation fields unless explicitly approved for exposure.

## Consequences

- Display names are never identities.
- Discovery can refresh or fail without silently deleting the Dock.
- Moving/reinstalling an app requires explicit migration or an unavailable-item state.
- Icon data is transferred as bounded normalized metadata or bytes, never as an absolute path.
- The experiment's path digest remains internal evidence only and is not an approved wire identifier.

## Alternatives

- Bundle identifier alone: insufficient for duplicates, missing IDs, and multiple installations.
- Canonical path alone: unstable across moves and potentially privacy-sensitive.
- Unsalted path hash: deterministic but dictionaryable and not stable across path changes.
