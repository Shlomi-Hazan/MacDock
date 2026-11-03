# ADR 0003: QR-First Pairing and Explicit Peer Authentication

- Status: Proposed
- Date: 2026-11-03
- Issue: [#5](https://github.com/Shlomi-Hazan/MacDock/issues/5)

## Context

Bonjour proves discoverability, not identity. The TLS feasibility experiment proves that Network.framework can provide an encrypted channel and can reject a mismatched certificate fingerprint, but it does not define long-term trust, mutual device identity, revocation, or recovery.

MacDock needs a first-pairing flow for one Mac and one iPhone that is understandable to a user and defensible against same-network impersonation and active interception.

## Decision status

This ADR records a proposed design for review. It is not authorization to implement production pairing.

## Proposed decision

Use a QR-first, user-confirmed bootstrap combined with authenticated transport and long-term public-key binding:

- The Mac displays a short-lived QR record containing a pairing session, one-time token, recognizable Mac metadata, and a public identity binding.
- The iPhone scans the QR code, discovers the candidate Mac, and verifies the TLS peer against the QR binding.
- Both devices exchange fresh, signed transcript material and derive a Short Authentication String.
- The user compares the SAS on both devices and explicitly approves pairing on both sides.
- Only after both approvals are complete do the devices store each other's long-term public key in their pairing records.
- Neither device may enable trusted application-control operations while pairing is one-sided, pending, interrupted, or otherwise inconsistent; a staged trust record is not operational trust.
- Future sessions use fresh TLS keys plus stored peer-key authentication; a changed key requires explicit unpair/re-pair.

The QR code is an out-of-band bootstrap channel, not complete authentication. The short code is a human comparison value, not a standalone password.

## Alternatives

- Mutual TLS certificates: potentially strong, but certificate lifecycle and Network.framework integration require separate validation.
- Noise XX or another reviewed authenticated-handshake pattern: viable candidate, but would add a protocol implementation that needs independent review and test vectors.
- PAKE for short-code pairing: not selected for the MVP proposal because CryptoKit does not provide a directly usable SPAKE2+ API and a new implementation would add significant review and supply-chain risk.

## Consequences

Positive:

- Discovery is kept separate from trust.
- The user has a clear physical confirmation step.
- Long-term trust can be represented by public keys rather than bearer QR secrets.
- Wrong-key, replay, expiry, and unpair states have explicit handling.

Costs and limitations:

- Pairing requires user interaction on both devices.
- Relay and social-engineering attacks cannot be eliminated if the user approves a mismatched or unexpected session.
- SAS comparison and QR confirmation do not cryptographically guarantee relay resistance: a relay may forward a valid exchange without changing the SAS. Their benefit depends on the user confirming the intended physical display and comparing both values; this residual risk must remain explicit in the UX and Stage 2 tests.
- One-sided approval, interrupted final confirmation, duplicate final messages, and inconsistent local records must remain non-operational pending states and recover through expiry or explicit re-pairing.
- The transcript encoding and exact TLS-to-identity binding still require a Stage 2 protocol specification and implementation review.
- Key loss requires explicit re-pairing; no cloud recovery is assumed.

## Validation required before implementation is accepted

- Confirm peer-key access and verification behavior on supported macOS and iOS versions.
- Produce canonical transcript test vectors.
- Test wrong QR, wrong key, wrong SAS, replay, expiry, cancellation, relay, duplicate pairing, key replacement, and lost-device recovery.
- Review Keychain accessibility and deletion behavior on both platforms.
- Conduct an independent security review before enabling application-control commands.
