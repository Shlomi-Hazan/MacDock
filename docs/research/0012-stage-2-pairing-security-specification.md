# Stage 2 Pairing Security Specification

- Issue: [#38](https://github.com/Shlomi-Hazan/MacDock/issues/38)
- Status: Proposed specification for independent review
- Scope: one Mac and one iPhone, before production pairing implementation
- Related: [ADR 0003](../decisions/0003-qr-first-pairing-and-peer-authentication.md), [pairing threat model](0005-secure-pairing-threat-model.md), [ADR 0008](../decisions/0008-stage-1-integration-and-stage-2-readiness.md)

## Decision boundary

This document is a security specification proposal, not a cryptographic proof and not an implementation. It does not accept ADR 0003, generate keys, establish sessions, or authorize application control. Any construction described below requires independent security review, canonical test vectors, and maintainer approval before production code can use it.

## Security objectives and assets

The design must protect:

- Mac and iPhone long-term private identity keys.
- The binding between a device identity and its intended peer.
- Pairing-session freshness, one-time tokens, ephemeral keys, and user approvals.
- Confidentiality and integrity of authenticated sessions.
- Integrity and freshness of any future application-control request.
- Pairing state, revocation state, and the user's ability to recover safely.

The design must prevent or detect unauthorized trust establishment, wrong-peer acceptance, replayed pairing material, stale session requests, silent key replacement, and one-sided approval. It cannot restore integrity to a fully compromised endpoint or guarantee relay resistance against a user who approves a relayed exchange.

## Trust assumptions and boundaries

1. Bonjour and local-network reachability provide candidate discovery only.
2. The QR display and scan provide an out-of-band physical-origin hint, not complete authentication.
3. TLS provides an encrypted channel only when its peer-verification policy succeeds.
4. Keychain protects private material subject to platform security, device lock, endpoint compromise, and the selected accessibility class.
5. Both devices must independently approve the same pairing transcript before operational trust exists.
6. A pending, one-sided, interrupted, expired, or inconsistent record is never authorized for application control.
7. A fully compromised Mac or iPhone is outside the recoverable trust model and requires unpairing or replacement.

## Proposed pairing flow

### QR-first bootstrap

The Mac creates a short-lived pairing session and displays a versioned QR record containing:

- protocol version and supported algorithm-suite identifiers;
- random pairing-session identifier and one-time token;
- short expiration time;
- recognizable, user-selected Mac display name;
- Mac public identity binding and/or exact TLS peer-key binding;
- no private key, password, Keychain secret, provisioning data, personal path, or long-lived bearer credential.

The iPhone scans the QR, shows the recognized Mac name and expiry, discovers candidate services, and checks that the selected transport peer matches the QR binding. Discovery must not create trust. The token is invalidated on completion, cancellation, mismatch, or expiry.

### Short-code fallback

When scanning is unavailable, the Mac displays a short-lived code and the iPhone starts an explicitly user-initiated nearby pairing attempt. The code identifies a bounded session and is not a standalone password. Both devices still display a transcript-derived SAS and require explicit approval on both sides. Attempts are rate-limited and expire after repeated mismatch or timeout.

### Transcript and freshness proposal

The future protocol must define one canonical, versioned transcript that binds at least:

- protocol version and algorithm suite;
- pairing-session ID and one-time QR token;
- both long-term public identity keys;
- both ephemeral public keys and fresh nonces;
- roles and endpoint ordering;
- the TLS peer-key binding;
- transcript context and message sequence.

Each side must authenticate the transcript with its long-term identity. A signature without a trusted public-key binding is insufficient. Exact encoding, signature envelope, algorithm negotiation, and TLS exporter or equivalent binding remain open implementation decisions.

The implementation must reject expired sessions, reused tokens, duplicate nonce/session combinations, wrong roles, unexpected sequence numbers, old transcript messages, and messages from a superseded attempt.

## Pairing state and safety invariant

The required invariant is:

> Neither device may enable trusted application-control operations unless both devices have completed the required pairing confirmation protocol and each device has a verified durable peer binding.

Recommended states:

```text
Unpaired
  -> Discovering
  -> PairingInitiated
  -> VerifyingPeer
  -> AwaitingUserConfirmation
  -> PendingCommit
  -> Paired

Any active state -> Cancelled / Expired / AuthenticationFailed
Paired -> Reconnecting / Revoked / Unpaired
Pending or inconsistent records -> RecoveryRequired
```

Rules:

- One-sided approval remains pending and cannot authorize control.
- Interrupted final confirmation leaves pending state non-operational; ephemeral material and one-time state expire or are discarded.
- Duplicate completion messages are idempotent for the same valid session and cannot promote partial state.
- Retry uses fresh session IDs, tokens, nonces, and transcript material; stale approvals are rejected.
- A crash or storage failure that leaves only one local record enters recovery, never automatic trust.
- A changed peer key requires explicit unpair/re-pair or another separately reviewed replacement flow.
- Cancellation and expiry delete ephemeral secrets and do not create trust.

This is a safety invariant, not a claim that Stage 2 has a distributed transaction protocol. The implementation must choose an explicit pending/commit representation and test failure between each durable write.

## Identity and key lifecycle

Each device generates its own long-term identity locally. Candidate implementation choices include a CryptoKit signing identity stored in Keychain, subject to API and minimum-OS validation. Secure Enclave use is optional and must not be assumed until exportability, algorithm support, accessibility, migration, and parity are tested.

Required lifecycle:

1. Generate private identity material locally; never transmit or log it.
2. Store private material only through an approved Keychain adapter.
3. Exchange public keys only inside the reviewed pairing protocol.
4. Bind the peer public key only after transcript verification, SAS comparison, and both approvals.
5. Use fresh session keys and session binding for future connections.
6. Use unique request IDs, freshness data, or sequence protection for replay detection.
7. Rotate or replace keys only through an explicit authenticated and user-confirmed flow.
8. Revoke and delete trust explicitly; a lost device requires unpair/re-pair in the MVP.
9. Treat unexpected key change as `TrustChanged`, never as silent replacement.

No cloud backup of private pairing keys is assumed. Keychain accessibility and synchronizable settings require platform experiments before implementation acceptance.

## Authentication and authorization gates

The future system must keep these gates separate:

```text
Bonjour candidate
    -> encrypted transport
    -> authenticated peer
    -> committed pairing trust
    -> authorized session
    -> explicitly permitted request
```

No arrow may be skipped. In particular:

- Bonjour visibility is not identity.
- TLS completion is not peer authorization.
- A valid frame is not authentication.
- A pending pairing record is not trust.
- A trusted session is not permission for arbitrary commands.
- Future control requests must use validated logical application IDs, not paths or shell commands.

## Adversarial review and required negative vectors

| Scenario | Required defense | Residual risk | Required evidence |
| --- | --- | --- | --- |
| Rogue Bonjour service | QR binding, peer verification, transcript authentication, SAS | User can approve wrong physical display | Multiple candidates and wrong-peer rejection |
| Local MITM | Fail-closed TLS verification and transcript binding | Endpoint compromise | Certificate/key substitution test |
| QR substitution | Recognizable Mac identity, physical confirmation, SAS | Compromised display or social engineering | Wrong QR and mismatch UX |
| Replay | One-time expiry, fresh nonces, sequence/session IDs | Implementation/state-storage bugs | Replayed token, transcript, and request tests |
| Relay | Physical-origin check and SAS comparison | SAS/QR do not cryptographically guarantee relay resistance | Delayed/relayed exchange analysis and explicit UX warning |
| Wrong peer key | Stored/QR identity binding and explicit failure | User may approve re-pair | Changed-key and stale-trust tests |
| Partial confirmation | Pending non-authorizing state and two-sided commit | Availability or recovery burden | Crash/interruption/duplicate-final-message tests |
| Lost device | Explicit revoke/unpair and re-pair | Compromised unlocked endpoint | Revocation and replacement tests |
| Pairing flood | Expiry, cancellation, rate limits | Local denial of service | Repeated-attempt and cleanup tests |

This review identifies defenses and residual risks; it does not prove cryptographic security. Relay resistance must not be overstated: an attacker may forward a valid exchange without changing the SAS.

## Required implementation review gates

Before accepting production pairing, the implementation PRs must provide:

1. Canonical transcript specification and fixed test vectors.
2. Explicit algorithm and version negotiation behavior.
3. Keychain adapter tests and platform accessibility findings.
4. Positive and negative wrong-peer, wrong-SAS, expiry, replay, interruption, duplicate, revocation, and changed-key tests.
5. Evidence that pending state never reaches authorization.
6. Evidence that TLS configuration fails closed and is not an unconditional trust callback.
7. Physical Mac/iPhone tests for pairing approval, rejection, reconnect, and recovery.
8. Independent security review before any application-control endpoint is enabled.

## Unresolved decisions

These decisions remain explicitly open and must not be silently finalized by implementation:

- mutual TLS versus a reviewed Noise-family pattern versus signed transcript messages inside TLS;
- exact CryptoKit identity type and Secure Enclave applicability;
- canonical transcript encoding and TLS session binding mechanism;
- SAS length, display format, rate limit, and retry policy;
- Keychain accessibility, migration, and device replacement behavior;
- whether any recovery beyond explicit unpair/re-pair is acceptable for the one-device MVP.

ADR 0003 remains Proposed until these decisions are reviewed, test vectors exist, and the maintainer explicitly accepts the resulting design.

## References

- [Apple Network framework](https://developer.apple.com/documentation/network)
- [Apple Keychain Services](https://developer.apple.com/documentation/security/keychain_services)
- [Apple CryptoKit](https://developer.apple.com/documentation/cryptokit)
- [TLS 1.3, RFC 8446](https://datatracker.ietf.org/doc/html/rfc8446)
- [HKDF, RFC 5869](https://datatracker.ietf.org/doc/html/rfc5869)
- [EdDSA, RFC 8032](https://datatracker.ietf.org/doc/html/rfc8032)
- [Elliptic Curves for Security, RFC 7748](https://datatracker.ietf.org/doc/html/rfc7748)
- [Stage 0 pairing threat model](0005-secure-pairing-threat-model.md)
- [QR-first pairing ADR](../decisions/0003-qr-first-pairing-and-peer-authentication.md)
