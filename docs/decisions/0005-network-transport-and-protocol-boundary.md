# ADR 0005: Network Transport and Protocol Boundary

- Status: Proposed
- Date: 2026-11-04
- Issue: [#9](https://github.com/Shlomi-Hazan/MacDock/issues/9)

## Context

The Bonjour experiment demonstrated local service visibility, and the transport experiment demonstrated a physical iPhone-to-Mac encrypted exchange with expected certificate-fingerprint verification plus rejection of an incorrect fingerprint. Neither experiment defines production pairing or authorization.

## Proposed decision

Use Network.framework with Bonjour for local candidate discovery and a bounded framed session transport. Treat discovery, encryption, peer authentication, and application authorization as separate layers. Keep versioned message models and pure framing/validation in a small Foundation-only shared package when Stage 1 creates it.

The production protocol must distinguish request submission, Mac acknowledgment, OS/process observation, activation result, and frontmost observation. Reconnection resynchronizes state and does not automatically replay stale control commands.

## Consequences

- The transport can be tested independently from AppKit and SwiftUI.
- A TLS-ready state cannot be presented as a trusted-pair state.
- The final cryptographic construction, transcript binding, and request freshness scheme remain Stage 2 work.
- The experiment's self-signed certificate and manual fingerprint entry are test-only mechanisms.

## Alternatives

- HTTP/WebSocket dependency: not justified for the local MVP; it adds a server abstraction without a demonstrated need.
- Bonjour as trust: rejected because visibility is not authentication.
- Unbounded JSON or shell-style commands: rejected because they weaken framing, authorization, and input validation boundaries.
