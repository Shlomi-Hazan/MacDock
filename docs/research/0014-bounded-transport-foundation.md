# Bounded Transport Foundation

- Issue: [#40](https://github.com/Shlomi-Hazan/MacDock/issues/40)
- Status: Non-authorizing transport foundation
- Depends on: [Issue #38](https://github.com/Shlomi-Hazan/MacDock/issues/38), [Issue #39](https://github.com/Shlomi-Hazan/MacDock/issues/39)

## Security boundary

This implementation provides a bounded Network.framework TCP path for a fixed, non-sensitive diagnostic exchange. It is not encrypted and it does not authenticate either endpoint. The UI labels the result `unverified`; no pairing, trust record, authorization state, application inventory, Dock synchronization, or control command is available.

TLS peer verification is intentionally not configured in this issue. ADR 0003 remains Proposed, and the exact identity binding and TLS/handshake construction require separate review, test vectors, and maintainer approval. There is no permissive trust callback and no trust-on-first-use behavior.

## Components

- `MacDockShared/TransportDiagnostic.swift` defines fixed Hello/Acknowledgment envelopes and a Foundation-only validator.
- `MacDockMac/MacDockMacApp.swift` extends the existing documented Bonjour listener to accept a diagnostic connection, decode bounded frames, return one fixed acknowledgment, and cancel the connection.
- `MacDockiOS/BonjourDiscoveryCoordinator.swift` retains selected untrusted `NWEndpoint` values, opens an explicitly selected `NWConnection`, sends one fixed diagnostic Hello, validates the acknowledgment, and exposes bounded lifecycle status.

The existing `ProtocolFrameCodec` and `ProtocolFrameDecoder` remain the only framing implementation. The four-byte big-endian length prefix and 64 KiB encoded-envelope limit are unchanged.

## Lifecycle and bounds

Incoming data is received with a maximum of header plus 64 KiB. Fragmented and concatenated frames are handled by `ProtocolFrameDecoder`; malformed, unsupported, oversized, or truncated input fails the connection. The iOS coordinator uses a generation identity, cancellation, and a ten-second bounded timeout. A stale callback cannot update a newer attempt. Lost acknowledgments are not replayed.

The Mac listener admits at most four diagnostic connections at once and applies a ten-second per-connection idle timeout. Each accepted connection owns its decoder and cleanup session; completion, failure, timeout, cancellation, and application termination release the connection slot idempotently. Additional connections are cancelled without processing data.

The diagnostic message contains only the fixed payload `macdock-foundation-diagnostic-v1`. It has no request identifier and cannot carry application data. The Mac listener intentionally cancels after sending the fixed acknowledgment; the iOS coordinator treats a fully validated acknowledgment followed by clean connection closure as a successful diagnostic exchange. Closure before a valid acknowledgment remains a failure, including malformed, truncated, timed-out, or cancelled attempts.

Each Mac-side diagnostic connection receives its own decoder session. Decoder state is not shared across concurrent connections. On iOS, the transport generation continues to reject callbacks from cancelled or superseded attempts.

## Physical-device validation evidence

The following observations were reported by the maintainer after testing on a physical Mac and iPhone on the same local Wi-Fi. They are not automated or independently tool-executed results:

1. Run `MacDockMac` on a physical Mac connected to the same Wi-Fi as the iPhone.
2. Run `MacDockiOS` on the physical iPhone and allow Local Network access.
3. Confirm an explicitly labeled `Untrusted candidate` appears.
4. Tap `Send diagnostic hello`; the iPhone displayed `Diagnostic exchange complete (unverified)`.
5. The completed status remained visible after the Mac intentionally closed its diagnostic TCP connection.
6. Tapping `Cancel diagnostic transport` changed the status to `Transport: Cancelled`.
7. Quitting MacDockMac removed the candidate from discovery; restarting it restored discovery and a new diagnostic exchange.
8. An attempt to interrupt the exchange before acknowledgment was inconclusive because the fixed exchange completed before the Mac could be stopped. The deterministic early-close test remains the evidence for that path; it was not passed on physical hardware.
9. After the Mac disappeared, the previously completed diagnostic status remained visible. This is a historical diagnostic result, not an indication that an active transport connection remains.
10. Do not interpret any result as authentication, pairing, trusted identity, encryption, or authorization.

The physical observations confirm the bounded diagnostic exchange and the clean-close UI fix only. They do not validate secure transport or peer identity.

## Physical-device validation plan

The following failure-path steps remain useful for future retesting:

1. Run `MacDockMac` on a physical Mac connected to the same Wi-Fi as the iPhone.
2. Run `MacDockiOS` on the physical iPhone and allow Local Network access.
3. Confirm an explicitly labeled `Untrusted candidate` appears.
4. Tap `Cancel diagnostic transport` immediately after starting an attempt and confirm the status becomes `Cancelled`.
5. Quit the Mac companion before a diagnostic acknowledgment can be sent, where timing permits, and confirm the attempt fails or times out without retrying.
6. Do not interpret any result as authentication, pairing, trusted identity, or authorization.

TLS rejection, authenticated peer tests, pairing approval, network interruption, and recovery of authorized sessions remain blocked until the reviewed security construction and its test vectors are accepted.

## Explicitly deferred

- TLS configuration and peer-verification policy.
- Long-term device identity and Keychain trust.
- QR pairing and two-sided confirmation.
- Authenticated or authorized session state.
- Remote application-control messages.
- Automatic reconnect and command replay.
- Physical proof of secure communication.
