# Stage 2 Pairing Security Specification

- Issue: [#38](https://github.com/Shlomi-Hazan/MacDock/issues/38)
- Status: Proposed specification for independent review
- Scope: one Mac and one iPhone, before production pairing implementation
- Requirements baseline accepted by maintainer: 2026-11-04
- Related: [ADR 0003](../decisions/0003-qr-first-pairing-and-peer-authentication.md), [pairing threat model](0005-secure-pairing-threat-model.md), [ADR 0008](../decisions/0008-stage-1-integration-and-stage-2-readiness.md)

## Decision boundary

This document is a security specification proposal, not a cryptographic proof and not an implementation. It does not accept ADR 0003, generate keys, establish sessions, or authorize application control. Any construction described below requires independent security review, canonical test vectors, and maintainer approval before production code can use it.

The maintainer accepts this document as the Stage 2 security requirements baseline on 2026-11-04. That acceptance covers the security objectives, threat model, trust boundaries, negative-test requirements, and future implementation gates only. It does not approve ADR 0003, select a cryptographic construction, approve a pairing handshake or TLS peer-verification policy, establish production device trust, authorize trusted sessions, or enable remote application control.

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

### Short-code fallback (deferred)

The short-code fallback is **Deferred** for the MVP specification. A short code alone does not authenticate a device, establish a peer binding, or provide sufficient protection against an active man-in-the-middle attacker. SAS comparison alone is also not a substitute for authenticated identity.

It may be reconsidered only after a reviewed construction demonstrates all of the following:

- authenticated binding between the intended Mac and iPhone;
- protection against active MITM, not merely accidental peer selection errors;
- bounded lifetime, one-time use, and strict rate limiting;
- resistance to offline guessing where the construction exposes a verifier or derives secrets from the code;
- explicit confirmation on both devices over the same authenticated transcript;
- clear cancellation, mismatch, retry, and failure behavior.

Until those properties are demonstrated with a reviewed protocol and test vectors, the product should require QR-first pairing. The QR flow remains subject to the same independent construction review and must not treat the QR payload alone as complete authentication.

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

### Two-sided commit and crash consistency

Pairing may be treated as committed on a device only when that device has durable evidence of all of the following:

1. Its own local user approval for the exact transcript.
2. The peer's approval, authenticated and cryptographically bound to the same canonical transcript, roles, peer identities, and session context.
3. An authenticated final confirmation that is valid for the same pairing attempt and has not expired, been superseded, or already been consumed.
4. A successful durable write of the committed peer binding and the state needed to prevent reuse of the bootstrap material.

Local approval, an unauthenticated acknowledgment, or a peer claim that it has committed is insufficient. Neither side may authorize operational control until its own committed record satisfies these conditions.

The implementation must use an explicit pending-versus-committed representation. Pending records may contain temporary transcript material and local approval, but they are never eligible for authorization. If a crash occurs after one-sided persistence, after sending a final message, or during the committed-record write, recovery must fail closed into `Pending`, `RecoveryRequired`, or `TrustChanged` as appropriate. It must not infer success from message delivery, retry the old final message as a new pairing, or silently promote a partial record.

Duplicate or delayed final messages must be accepted only as idempotent references to the same still-valid attempt, and must never create a new trust record or alter a newer attempt. Reconnection during an inconsistent state requires an authenticated recovery exchange or explicit user cancellation and fresh pairing. Recovery after partial completion must discard or expire ephemeral material, preserve any existing committed trust, and require explicit user-visible action before retry.

This is a safety invariant and recovery requirement, not a claim that Stage 2 has a distributed transaction protocol. The implementation must test failure between each durable write and message boundary, including crash, timeout, duplicate, delayed, and reordered final messages.

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

## Decision maturity and approval gates

The project must distinguish these decisions explicitly:

1. Security requirements and threat model reviewed.
2. Exact pairing/handshake construction selected.
3. Canonical transcript encoding and fixed test vectors validated.
4. Cryptographic and platform security review completed.
5. Maintainer explicitly accepts the selected construction.
6. Implementation passes security and physical-device validation.
7. Trusted-session and authorization gates are enabled only after the required conditions above are verified.

Completion of Issue #38 may establish an accepted requirements baseline. It does not select a construction, accept ADR 0003, authorize production pairing, or permit trusted sessions. Issues #41–#43 must treat unresolved construction, transcript, and test-vector decisions as blocking dependencies rather than interpreting this document as blanket implementation authorization.

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

ADR 0003 remains Proposed until these decisions are reviewed, test vectors exist, and the maintainer explicitly accepts the resulting design. No implementation issue may change that status implicitly.

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
