# Candidate A Cryptographic Construction Specification v0.1

- Issue: [#52](https://github.com/Shlomi-Hazan/MacDock/issues/52)
- Stage: Stage 2 — Connection & Pairing
- Status: Draft specification for independent review
- Related research: [Pairing construction review](0016-pairing-construction-review.md), [device identity and secure storage](0015-device-identity-and-secure-key-storage.md), [secure pairing threat model](0005-secure-pairing-threat-model.md)
- Related ADRs: [ADR 0003](../decisions/0003-qr-first-pairing-and-peer-authentication.md), [ADR 0005](../decisions/0005-network-transport-and-protocol-boundary.md), [ADR 0007](../decisions/0007-stage-0-feasibility-decision.md), [ADR 0008](../decisions/0008-stage-1-integration-and-stage-2-readiness.md)
- Review package: [Candidate A independent cryptographic review readiness](0018-candidate-a-independent-cryptographic-review-readiness.md)

> This document is a proposed construction specification. It is not a cryptographic proof, implementation authorization, or acceptance of ADR 0003. No production identity, pairing, trust persistence, or authorized session is implemented by this document.

## 1. Decision status and scope

Candidate A is the preferred construction family for formal review because it preserves the existing Network.framework TLS boundary and adds explicit application-level identity authentication. The proposed construction is:

1. TLS 1.3 provides the encrypted transport and fresh channel keys.
2. Each installation owns a long-term P-256 signing identity protected by a platform-specific Keychain boundary. Secure Enclave use is optional and remains subject to platform validation.
3. A Mac-created, short-lived QR bootstrap binds a pairing session, one-time token, suite, and Mac public signing key to the user-visible Mac display.
4. The devices exchange fresh, signed application messages over the exact TLS connection.
5. A TLS exporter-derived channel binding is included in the signed transcript.
6. Both devices display and compare a Short Authentication String (SAS), then explicitly approve.
7. Trust is committed only after both authenticated final confirmations and durable local writes succeed.

The construction claims only the properties stated in Section 11 and only under the assumptions in Section 4. It does not claim that QR scanning, SAS comparison, TLS encryption, or exporter equality alone authenticates a device.

### 1.1 Alternatives considered

| Candidate | Decision | Reason |
| --- | --- | --- |
| TLS 1.3 plus signed application transcript | Preferred for review | Fits the existing transport and experiment; keeps identity and authorization above TLS |
| Reviewed Noise pattern | Viable fallback | Strong explicit handshake model, but requires a reviewed implementation/library and a separate Network.framework integration boundary |
| SPAKE2 / SPAKE2+ | Not selected for v0.1 | Password-authenticated exchange does not match the primary device-identity model; exact RFC and parameter selection would still be required ([RFC 9382](https://www.rfc-editor.org/rfc/rfc9382.html), [RFC 9383](https://www.rfc-editor.org/rfc/rfc9383.html)) |
| Mutual TLS with device certificates | Deferred alternative | Could authenticate peers at TLS, but certificate issuance, rotation, revocation, and QR bootstrap become a miniature PKI |

This recommendation is provisional. The independent reviewer may reject it or require a different construction.

## 2. Security goals and assumptions

### 2.1 Goals

- Authenticate the intended Mac and iPhone identities before trust is committed.
- Bind both identities, roles, QR bootstrap, freshness, and the exact TLS channel into one transcript.
- Detect replay, duplicate, reordered, truncated, downgraded, or cross-session messages.
- Require explicit approval on both devices.
- Fail closed on identity changes, storage errors, verification errors, expiry, cancellation, and inconsistent trust state.
- Keep discovery, transport readiness, authentication, trust commitment, and authorization separate.

### 2.2 Assumptions

- The operating systems, Keychain/Secure Enclave boundary, and CryptoKit primitives used by the implementation are not compromised.
- The user can identify the intended Mac display and compare the SAS on both devices.
- The QR display is an out-of-band origin hint, not an unforgeable channel. An attacker may replace or relay it.
- TLS peer verification is correctly configured and exposes the exact peer key/certificate material for the active connection.
- The canonical serialization, signature verification, exporter binding, and state machine are implemented exactly as reviewed.
- A fully compromised endpoint cannot be protected by this protocol.

## 3. Algorithms and identity representation

### 3.1 Suite identifier

The only v0.1 suite identifier is the proposed value `0x0101`, named `P256-SHA256-HKDF-SHA256-TLS13-EXPORTER`. Unknown suites are rejected. Algorithm agility is versioned by a new suite identifier; implementations must not negotiate a weaker suite by silently falling back.

### 3.2 Long-term identity

Each device owns a P-256 ECDSA signing key. The public identity representation is the SEC1 uncompressed point:

```text
0x04 || X (32 bytes) || Y (32 bytes) = exactly 65 bytes
```

The signing input is a domain-separated SHA-256 digest, and the signature representation is strict DER-encoded ECDSA `(r, s)` with canonical DER integer encoding. The implementation must enforce the selected low-`s` policy before acceptance; the exact normalization and CryptoKit interoperability must be demonstrated in vectors before implementation approval.

P-256 is recommended over Curve25519 signing for v0.1 because Apple documents P-256 signing in CryptoKit and Secure Enclave. This does not prove Secure Enclave availability on every supported Mac. A non-Secure-Enclave Keychain fallback, if retained, requires the same protocol security and explicit platform review; it must not silently downgrade an established trust record.

### 3.3 Ephemeral key agreement

Each pairing attempt generates one fresh P-256 key-agreement key per device. The public representation uses the same 65-byte SEC1 uncompressed format. The ephemeral private keys are memory-only, discarded on terminal state, and never persisted or logged. The v0.1 transcript binds these values; the exact use of the ECDH result is intentionally limited to the reviewed derivation below and must be checked against the selected Apple APIs.

### 3.4 Key storage boundary

Long-term private keys are generated and used by platform-specific adapters. They do not enter `MacDockShared`, logs, QR payloads, diagnostic frames, UI, or CI. The candidate default is a Keychain item with device-local accessibility appropriate for a foreground pairing flow. `SecureEnclave.P256.Signing.PrivateKey` is an optional platform hardening path, not a required assumption. Issue #53 must validate creation, retrieval, locked-device behavior, replacement, deletion, crash recovery, and macOS/iOS parity before persistent trust is implemented.

## 4. TLS authentication and channel binding

### 4.1 TLS requirements

- TLS version is exactly 1.3 for the v0.1 suite.
- The Mac presents a certificate whose public-key representation is exactly the QR-advertised Mac identity key, or a reviewed certificate-to-identity binding that is cryptographically equivalent.
- The iPhone validates the certificate through a fail-closed pairing-session policy and compares the active certificate public key with the QR binding.
- A successful Bonjour lookup, TCP connection, TLS ready state, or certificate-chain validation without the QR/key comparison is insufficient for pairing.
- No permissive trust callback, trust-on-first-use, hostname bypass, or system-wide test anchor is permitted.
- Client certificate authentication is not assumed in v0.1; the iPhone proves possession through the signed application transcript. Mutual TLS remains a separately reviewed alternative.

The exact production certificate issuance and Network.framework peer-key extraction path remain platform gates. The isolated experiment used process-scoped test anchors and is not the production trust policy.

### 4.2 Exporter binding

For the active TLS connection, both endpoints derive exactly 32 bytes using the public Security/Network metadata for that connection:

```text
exporter-label   = "com.macdock.pairing.v1"
exporter-context  =
  SHA-256("MacDock-Channel-Binding-Context-v1" ||
          uint16_be(0x0101) ||
          uint16_be(protocol_version))
exporter-length   = 32
```

The exporter result is called `tls_binding`. It is included in the transcript and is never displayed, logged, persisted, or sent as a standalone diagnostic value. Missing metadata, exporter failure, connection replacement, TLS resumption policy mismatch, or an exporter mismatch terminates pairing.

The experiment demonstrated matching values on the tested physical pair, but did not validate macOS 14/iOS 17 minimum-runtime behavior or production certificate-to-identity binding. Those are required gates.

## 5. QR bootstrap record

The QR payload is an unsigned, canonical bootstrap record whose authenticity is established only by the subsequent TLS/key comparison, signed transcript, and human confirmation. It is not a bearer credential and not sufficient to authenticate a peer.

### 5.1 Canonical QR encoding

The record uses the same canonical field encoding as Section 6, with the following required fields in ascending numeric tag order:

| Tag | Field | Type | Constraints |
| --- | --- | --- | --- |
| 1 | `format_version` | `uint16_be` | `0x0001` |
| 2 | `suite` | `uint16_be` | `0x0101` |
| 3 | `pairing_session_id` | bytes | exactly 16 random bytes |
| 4 | `one_time_token` | bytes | exactly 32 random bytes |
| 5 | `expires_at` | `uint64_be` | UTC Unix milliseconds; bounded lifetime, proposed maximum 5 minutes |
| 6 | `mac_identity_public_key` | bytes | exactly 65 bytes |
| 7 | `display_name` | UTF-8 bytes | 1–128 bytes; non-sensitive user-recognition text |
| 8 | `qr_record_nonce` | bytes | exactly 32 random bytes |

The QR record contains no private key, password, Keychain reference, IP address, exporter, or application inventory. The Mac invalidates the session and token on completion, cancellation, expiry, or explicit replacement. Clock skew handling must use a bounded policy and must never extend a session indefinitely.

## 6. Canonical transcript format

All transcript messages use a deterministic field sequence:

```text
field := tag:uint16_be || length:uint32_be || value:bytes
message := magic:8 bytes || version:uint16_be || type:uint16_be || field_count:uint16_be || field*
```

`magic` is the ASCII bytes `MDBKTR01`. Fields must be strictly increasing by numeric tag, unique, and complete for the message type. Unknown fields are rejected for security-critical messages. Lengths are bounded before allocation; the complete message is limited to 64 KiB. Integers are unsigned big-endian. Text fields are UTF-8 and are never used for cryptographic identity comparison.

The transcript body is the canonical concatenation of the fields below, excluding the outer message header:

| Tag | Field | Type | Required |
| --- | --- | --- | --- |
| 1 | `protocol_version` | uint16 | all messages |
| 2 | `suite` | uint16 | all messages |
| 3 | `pairing_session_id` | 16 bytes | all messages |
| 4 | `qr_token` | 32 bytes | initial messages |
| 5 | `initiator_role` | one byte | exactly `0x01` iPhone |
| 6 | `responder_role` | one byte | exactly `0x02` Mac |
| 7 | `initiator_identity` | 65 bytes | signed messages |
| 8 | `responder_identity` | 65 bytes | signed messages |
| 9 | `initiator_ephemeral` | 65 bytes | hello messages |
| 10 | `responder_ephemeral` | 65 bytes | hello messages |
| 11 | `initiator_nonce` | 32 bytes | hello messages |
| 12 | `responder_nonce` | 32 bytes | hello messages |
| 13 | `tls_binding` | 32 bytes | post-TLS messages |
| 14 | `transcript_hash` | 32 bytes | proof/confirmation messages |
| 15 | `signature` | strict DER ECDSA | proof/confirmation messages |
| 16 | `approval` | one byte | confirmation only; `0x01` means approved |
| 17 | `confirmation_purpose` | UTF-8 bytes | fixed per message type |

### 6.1 Hashes and signatures

```text
transcript_hash = SHA-256(
  "MacDock-Pairing-Transcript-v1" ||
  canonical(QR fields) ||
  canonical(HELLO fields) ||
  canonical(HELLO_ACK fields) ||
  tls_binding
)

signature_input = SHA-256(
  "MacDock-Pairing-Signature-v1" ||
  uint16_be(suite) ||
  confirmation_purpose ||
  transcript_hash
)
```

The signer signs `signature_input` with its long-term P-256 signing key. The verifier checks the exact role, expected identity key, signature encoding, suite, session ID, and transcript hash before accepting the message.

### 6.2 SAS derivation

```text
sas_bytes = HKDF-SHA256(
  ikm = exporter_secret || ecdh_shared_secret,
  salt = transcript_hash,
  info = "MacDock-Pairing-SAS-v1" || uint16_be(suite),
  output_length = 4
)
sas_display = decimal_be_uint32(sas_bytes) mod 100000000, rendered as 8 digits
```

The SAS is a human comparison value, not a standalone password and not a cryptographic relay guarantee. Both devices display it only after all transcript signatures and channel checks pass. A mismatch or user rejection fails and invalidates the session.

The exact ECDH/KDF composition, ECDSA low-`s` policy, and SAS display encoding require independent review and test vectors. They are specified here as a candidate, not accepted production cryptography.

## 7. Message sequence and state machine

### 7.1 Sequence

```text
Mac                         iPhone
 |-- QR bootstrap ----------->|  (out of band)
 |<========= TLS 1.3 =========>|  (certificate/key checked)
 |<-- PairingHello ------------|  [iPhone identity, ephemeral, nonce, QR token]
 |--- PairingHelloAck -------->|  [Mac identity, ephemeral, nonce]
 |<-- IdentityProof -----------|  [iPhone signature]
 |--- IdentityProof ---------> |  [Mac signature]
 |<========= SAS display =====>|  (local UI only)
 |<-- UserConfirm -------------|  [iPhone approval signature]
 |--- UserConfirm ------------>|  [Mac approval signature]
 |<-- CommitAck ---------------|  [authenticated final confirmation]
 |--- CommitAck -------------->|  [authenticated final confirmation]
```

The diagram is logical; exact transport ordering and whether `CommitAck` is one or two messages require implementation review. No message after a failed, expired, cancelled, or committed session is accepted.

### 7.2 Message rules

| Message | Sender → receiver | Preconditions | Verification and transition | Failure behavior |
| --- | --- | --- | --- | --- |
| `PairingHello` | iPhone → Mac | Active QR session, TLS ready, no prior hello | Validate version, suite, session ID, token, role, lengths, fresh nonce/ephemeral; enter `HelloReceived` | Reject and invalidate on mismatch, expiry, duplicate, or malformed input |
| `PairingHelloAck` | Mac → iPhone | Valid hello, active session | Bind Mac identity, nonce, ephemeral, QR fields, and TLS binding; enter `TranscriptReady` | Fail closed; no trust write |
| `IdentityProof` | Both → peer | Canonical transcript ready | Verify peer signature and proof of possession; enter `SASReady` only after both proofs | Authentication failure; discard ephemeral state |
| `UserConfirm` | Both → peer | SAS displayed and local user approved | Verify approval signature over transcript hash and role; enter `ConfirmationPending` | User rejection or mismatch invalidates session |
| `CommitAck` | Both → peer | Local confirmation and verified peer confirmation | Verify final confirmation; atomically write pending peer record as committed; enter `Paired` only after local durable write | Remain unpaired/recovery-required; never infer commit from timeout |

All messages include the session ID and transcript hash once available. Duplicate messages with identical validated contents are idempotent within the active session. A duplicate with different contents is a protocol error. No non-idempotent application command is permitted in this protocol.

### 7.3 States

```text
Unpaired
  -> QRDisplayed -> TLSCandidate -> HelloReceived -> TranscriptReady
  -> SASReady -> ConfirmationPending -> CommitPending -> Paired

Any pending state -> Cancelled | Expired | Failed | RecoveryRequired
Paired -> Revoked | ReplacementRequired | AuthorizedSession (separate gate)
```

`TLSCandidate` is not authenticated trust. `Paired` requires both confirmations and durable local commit. `AuthorizedSession` is outside this specification and cannot be reached merely by pairing or TLS readiness.

## 8. Persistence, crash recovery, and revocation

- QR sessions are single-use and expire after the bounded lifetime.
- Ephemeral keys and pending transcript material are memory-only unless a reviewed crash-recovery design proves persistence necessary.
- A local trust record is written through `pending -> committed`; a crash leaves `pending`, `absent`, or `recoveryRequired`, never silently committed.
- The peer is considered trusted only after the local durable commit and authenticated final confirmation have both succeeded.
- A lost final acknowledgment does not prove that the peer committed. The next attempt uses a fresh QR/session ID and fresh nonces.
- Key replacement, unexpected public-key change, revocation, duplicate records, corrupt records, and inaccessible Keychain items fail closed and require explicit unpair/re-pair or recovery.
- A revoked key cannot be reintroduced automatically because a new certificate or QR record appears.

## 9. Threat analysis

| Threat | Attacker capability | Defense | Failure/residual risk | Required evidence |
| --- | --- | --- | --- | --- |
| Active local MITM | Injects and modifies LAN traffic | TLS verification, QR key binding, signed transcript, SAS | Endpoint compromise or user approval of mismatch remains outside protocol protection | Wrong-key, transcript mutation, physical tests |
| Rogue Bonjour | Publishes a candidate service | Discovery is untrusted; no trust transition from discovery | User may select a misleading display name | Candidate spoofing test |
| QR substitution | Replaces or relays displayed QR | User-recognized origin, signed transcript, SAS, two-sided approval | Physical-origin and social-engineering assumptions remain | Changed-QR and wrong-peer vectors |
| Unknown-key-share | Causes identities to be interpreted under different peers/roles | Ordered roles, both identities, session ID and transcript hash are signed | Encoding or role bug can defeat the property | Role/key swap vectors and review |
| Role confusion | Replays a valid message in the opposite role | Fixed role bytes and per-purpose signature domains | Implementation must reject swapped roles | Wrong-role vector |
| Transcript substitution | Reuses a valid signature over another context | Canonical transcript, QR fields, nonces, TLS binding and purpose | Canonicalization bug remains possible | Byte mutation vectors |
| TLS channel substitution | Uses a different valid TLS session | Exact exporter from active connection is signed into transcript | Exporter API/session semantics need platform review | Same/different session tests and API review |
| Replay/duplicate | Replays old messages or confirmations | Session ID, one-time token, expiry, nonces, transcript hash, idempotency rules | Clock and storage failures require bounded recovery | Replay/duplicate vectors |
| Downgrade | Offers older version or suite | Exact version/suite allow-list and no silent fallback | Future agility must preserve security | Unsupported-version/suite vectors |
| One-sided approval | Controls one device or drops final message | Both signed approvals and durable commit gate | User may approve the wrong visible peer | One-sided approval and lost-ack tests |
| Crash during trust write | Kills process during persistence | Pending/committed record protocol and fail-closed recovery | Keychain atomicity must be validated | Crash-injection tests |
| Key replacement/revocation | Presents a new key after pairing | Stored-key comparison, explicit unpair/re-pair and revocation state | Recovery can cause availability loss | Replacement/revocation tests |
| Relay | Forwards messages between legitimate endpoints | QR origin and SAS comparison bind human confirmation | QR/SAS do not cryptographically eliminate relays | Explicit residual-risk review |
| Malicious endpoint | Fully controls one device | No protocol can restore a compromised endpoint | Commands and private keys remain at risk | Threat-model boundary review |

## 10. Deterministic test-vector package

The proposed vector format is a versioned JSON manifest containing only public fixture values:

```json
{
  "vectorVersion": 1,
  "suite": "0x0101",
  "inputs": { "qr": "...", "messages": ["..."], "tlsBinding": "synthetic-only" },
  "expected": {
    "canonicalBytes": "...",
    "transcriptHash": "...",
    "signatureInputs": ["..."],
    "sasBytes": "...",
    "acceptance": "pass"
  }
}
```

Required vectors:

- Canonical field ordering and exact byte serialization.
- Signature verification with fixed non-production P-256 keys.
- Wrong role, wrong identity, wrong session, wrong QR token, and wrong suite.
- One-byte transcript mutation and exporter-binding mutation.
- Expired, reused, duplicated, truncated, reordered, and unknown-field messages.
- SAS mismatch, one-sided approval, duplicate confirmation, lost final acknowledgment.
- Pending/committed/revoked/replacement/recovery transitions.

No production cryptographic vectors are generated in this repository yet. The physical experiment's exporter values are not reusable vectors. A synthetic fixed `tlsBinding` may be used for serialization tests, but must be labelled synthetic and must never be presented as a real TLS exporter. A reference implementation must generate and independently reproduce the expected hashes, signatures, and SAS before the construction can be accepted.

## 11. Claimed properties and non-claims

Subject to the assumptions and review gates, the candidate intends to provide:

- Peer identity authentication bound to the user-selected QR session and exact TLS channel.
- Freshness and replay rejection within the pairing state machine.
- Explicit two-sided confirmation before durable trust.
- Fail-closed behavior for identity, transcript, certificate, storage, and state errors.

It does not claim:

- Relay prevention by QR or SAS alone.
- Security against a fully compromised endpoint or malicious user approval.
- Automatic recovery after key loss or device replacement.
- Authorization for application control.
- That the isolated exporter experiment proves the complete protocol secure.

## 12. Apple compatibility matrix

| Capability | macOS 14+ | iOS 17+ | Evidence status |
| --- | --- | --- | --- |
| CryptoKit P-256 signing | Documented API; runtime minimum-version test outstanding | Documented API; runtime minimum-version test outstanding | Documentation and current-SDK compilation only |
| Secure Enclave P-256 signing | Device/configuration dependent; exact Mac coverage outstanding | Device/configuration dependent; availability check required | Documentation; no production adapter |
| Keychain storage/accessibility | Platform-specific Data Protection behavior requires validation | Accessibility classes documented; physical behavior requires validation | Design baseline only |
| Network.framework TLS 1.3 | Isolated runtime demonstrated on current Mac environment | Isolated runtime demonstrated on tested iPhone environment | Maintainer-reported physical evidence; minimum OS unverified |
| TLS metadata/exporter API | Current SDK compilation and experiment evidence | Current SDK compilation and experiment evidence | Physical feasibility, not minimum-version proof |
| Local Network privacy | Not required for client identity itself | `NSLocalNetworkUsageDescription` and Bonjour configuration required for discovery | Existing production experiment configuration |

No row should be read as macOS 14 or iOS 17 runtime acceptance.

## 13. Independent review package

The reviewer should receive this specification, ADR 0003, Issue #38 requirements, Issue #41 identity baseline, the TLS experiment report, the threat model, the complete proposed vector manifest, and the implementation-independent state machine.

### Reviewer checklist

- Is the identity algorithm and public-key encoding precise and interoperable?
- Does the TLS certificate/key binding prevent unknown-key-share and channel substitution?
- Is the exporter API semantically sufficient for the claimed binding on both platforms?
- Are roles, QR fields, nonces, session IDs, and suite/version values bound canonically?
- Are ECDSA encoding and low-`s` requirements correct and implementable with CryptoKit/Secure Enclave?
- Is the SAS derivation and display policy appropriate and not overclaimed?
- Do replay, duplicate, downgrade, cancellation, crash and recovery rules fail closed?
- Can pending trust ever become committed after one-sided confirmation or lost acknowledgment?
- Are revocation and key replacement explicit and safe?
- Are residual relay and endpoint-compromise limitations accurately stated?
- Are the test vectors complete and independently reproducible?

### Acceptance and rejection criteria

Accept only if an independent reviewer confirms the exact construction, vectors, platform assumptions, and threat claims, and the maintainer separately approves the decision. Reject or revise if any cryptographic primitive, transcript field, trust transition, exporter assumption, or recovery property remains ambiguous. Until then, ADR 0003 remains Proposed and Issues #42/#43 must not implement production pairing or authorized sessions.

## 14. Recommendation

**CONDITIONAL — MISSING SPECIFICATION EVIDENCE.** The protocol shape and candidate parameters are sufficiently explicit for an independent cryptographic review, but the construction is not ready for implementation authorization. Missing evidence includes independently generated vectors, exact ECDSA canonicalization validation, production certificate-to-identity binding, Keychain/Secure Enclave adapter feasibility, minimum-OS runtime validation, and independent cryptographic review.
