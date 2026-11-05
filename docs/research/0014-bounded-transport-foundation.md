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

The diagnostic message contains only the fixed payload `macdock-foundation-diagnostic-v1`. It has no request identifier and cannot carry application data. The Mac listener cancels after sending the fixed acknowledgment.

## Physical-device validation plan

The following steps are prepared but not claimed as executed:

1. Run `MacDockMac` on a physical Mac connected to the same Wi-Fi as the iPhone.
2. Run `MacDockiOS` on the physical iPhone and allow Local Network access.
3. Confirm an explicitly labeled `Untrusted candidate` appears.
4. Tap `Send diagnostic hello` and observe `Diagnostic connecting`, followed by `Diagnostic exchange complete (unverified)` if the bounded exchange succeeds.
5. Tap `Cancel diagnostic transport` during an attempt and confirm the status becomes `Cancelled`.
6. Quit the Mac companion and confirm the diagnostic attempt fails or times out without retrying.
7. Relaunch the Mac companion, rediscover it, and repeat the diagnostic attempt.
8. Do not interpret any result as authentication, pairing, trusted identity, or authorization.

TLS rejection, authenticated peer tests, pairing approval, network interruption, and recovery of authorized sessions remain blocked until the reviewed security construction and its test vectors are accepted.

## Explicitly deferred

- TLS configuration and peer-verification policy.
- Long-term device identity and Keychain trust.
- QR pairing and two-sided confirmation.
- Authenticated or authorized session state.
- Remote application-control messages.
- Automatic reconnect and command replay.
- Physical proof of secure communication.
