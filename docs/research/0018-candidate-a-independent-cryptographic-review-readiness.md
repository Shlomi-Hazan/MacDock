# Candidate A Independent Cryptographic Review Readiness

- Issue: [#52](https://github.com/Shlomi-Hazan/MacDock/issues/52)
- Related specification: [Candidate A Cryptographic Construction Specification v0.1](0017-candidate-a-cryptographic-construction-specification-v0.1.md)
- Related requirements: [Issue #38](https://github.com/Shlomi-Hazan/MacDock/issues/38), [Issue #41](https://github.com/Shlomi-Hazan/MacDock/issues/41), [Issue #53](https://github.com/Shlomi-Hazan/MacDock/issues/53), and [Issue #58](https://github.com/Shlomi-Hazan/MacDock/issues/58)
- Decision records: [ADR 0003](../decisions/0003-qr-first-pairing-and-peer-authentication.md), [ADR 0005](../decisions/0005-network-transport-and-protocol-boundary.md), [ADR 0007](../decisions/0007-stage-0-feasibility-decision.md), and [ADR 0008](../decisions/0008-stage-1-integration-and-stage-2-readiness.md)
- Status: Conditional — missing specification evidence

> This is a reviewer-facing readiness package, not an independent cryptographic review and not an approval of Candidate A. It does not authorize production pairing, identity persistence, trusted sessions, authorization, or remote control. ADR 0003 remains Proposed.

## 1. Executive summary

Candidate A proposes TLS 1.3 for the encrypted transport and a signed application transcript for long-term device identity, QR bootstrap, freshness, role binding, and explicit two-sided confirmation. A TLS exporter-derived value is proposed as a binding to the exact active TLS connection. P-256 signing and key agreement are proposed because they are documented Apple-platform candidates, with Keychain and optional Secure Enclave protection.

The repository contains useful feasibility evidence:

- The bounded Network.framework transport and TLS metadata probe compile against the installed SDK.
- An isolated Mac-to-Mac runtime experiment reached TLS 1.3 ready, performed scoped certificate verification, and compared exporter-derived values.
- Maintainer-reported physical Mac–iPhone tests demonstrated positive exporter comparison and fail-closed wrong-anchor, hostname, and expired-certificate rejection on the tested environment.
- The evidence does not validate macOS 14 or iOS 17 runtime compatibility, production certificate-to-identity binding, long-term identity storage, or pairing security.

The construction is detailed enough for an external reviewer to challenge the design and identify required changes, but it is not complete enough for a security approval or implementation gate. The recommendation of this package is:

> **CONDITIONAL — MISSING SPECIFICATION EVIDENCE**

An external reviewer may perform a gap review now, but should not be asked to approve the construction until the P0 ambiguities and required vectors below are resolved or explicitly accepted as design changes.

## 2. Review scope and evidence classification

The reviewer should classify every claim using these categories:

| Category | Meaning |
| --- | --- |
| Experimentally demonstrated | Observed in an isolated test or explicitly identified maintainer-reported physical evidence; limited to the tested environment and configuration. |
| Specified proposal | Written protocol behavior that has not been implemented or independently validated. |
| Platform evidence required | Depends on API, OS, Keychain, Secure Enclave, or Network.framework behavior not established on the minimum supported runtimes. |
| Independent review required | Requires an external cryptographic protocol judgment rather than repository self-review. |
| Not claimed | Deliberately outside the construction, including authorization and protection of compromised endpoints. |

The physical TLS experiment is evidence for channel-binding feasibility only. It is not evidence of device authentication, durable pairing, authorized sessions, or cryptographic approval.

## 3. Security goals and explicit non-goals

### 3.1 Proposed goals

The construction should, under its stated assumptions:

1. Authenticate the intended long-term public identities before trust commitment.
2. Bind the identities to fixed roles, one QR bootstrap, one fresh session, and one exact TLS channel.
3. Reject replay, duplicate-with-different-content, role-swapped, downgraded, malformed, expired, and cross-session messages.
4. Require proof of possession and explicit user confirmation on both devices.
5. Keep pending, committed, revoked, replaced, and recovery-required states distinct.
6. Fail closed on verification, storage, cancellation, timeout, identity-change, and protocol errors.

### 3.2 Non-goals

Candidate A does not by itself:

- authorize Dock, audio, media, telemetry, pointer, keyboard, clipboard, or other operations;
- protect a compromised Mac, iPhone, operating system, or user interface;
- prevent all relay or social-engineering attacks when a user confirms the wrong physical session;
- prove that both devices durably committed merely because they verified the same transcript;
- replace Issue #58's capability authorization and privacy requirements;
- establish production TLS certificate issuance, revocation infrastructure, or recovery policy.

## 4. Specification completeness matrix

The following matrix is the current review baseline. “Fully specified” means that an independent implementer can derive one unambiguous behavior without selecting an unstated security decision. No row below is currently sufficient by itself for production approval.

| Topic | Current status | Evidence in repository | Blocking ambiguity or evidence required |
| --- | --- | --- | --- |
| Long-term device identity and key representation | Partially specified; independent review required | 0017 proposes P-256 and 65-byte SEC1 uncompressed public keys | Confirm whether the certificate key and long-term identity key are the same key, or define a signed certificate-to-identity binding. Define replacement identity semantics before trust. |
| P-256 signature encoding and canonicalization | Partially specified; vectors and independent review required | 0017 proposes strict DER ECDSA and a low-`s` policy | Fix low-`s` acceptance/normalization, DER rejection rules, signature length bounds, and CryptoKit interoperability. Produce positive and mutation vectors. |
| Secure Enclave and Keychain assumptions | Unresolved; platform validation required | 0015 documents candidates and failure boundaries; Issue #53 remains open | Validate macOS 14/iOS 17 availability, accessibility while locked, signing behavior, deletion, replacement, crash consistency, and non-Secure-Enclave policy. |
| TLS 1.3 certificate-to-identity binding | Unresolved; independent review and platform validation required | Physical TLS verification and exporter experiments exist | Specify certificate key ownership, QR binding, peer-key extraction, hostname/SAN policy, rotation, and rejection behavior. A verified certificate is not automatically the intended device identity. |
| Exporter label, context, length, and usage | Proposed but not accepted; platform and independent review required | 0017 proposes a 32-byte exporter with a domain-separated label/context | Confirm the public API's semantics, TLS 1.3 resumption/early-data policy, session replacement behavior, and whether the exporter is included in the signature transcript exactly once. |
| Canonical transcript encoding and validation | Partially specified; vectors required | 0017 defines a tagged length-delimited format and field ordering | Freeze message-specific required/forbidden fields, unknown-field policy, duplicate handling, Unicode rules, integer bounds, and canonical byte fixtures. |
| Proof of possession and role binding | Partially specified; independent review required | 0017 binds identities, roles, purposes, and transcript hash to signatures | Define exact proof message order and whether each signature covers the complete peer-observed transcript. Reject all role/key permutations in vectors. |
| QR bootstrap, expiry, freshness, and replay prevention | Partially specified; implementation and review evidence required | 0017 proposes a session ID, one-time token, expiry, nonce, and identity key | Decide QR authenticity/origin assumptions, clock-skew policy, token invalidation persistence, duplicate scans, replacement, and relay limitations. |
| SAS derivation and two-sided confirmation | Unresolved; critical independent review required | 0017 proposes HKDF over exporter and ECDH material | Confirm the exact KDF inputs, entropy and independence assumptions, display encoding, truncation, comparison UX, rate limits, and relay residual risk. |
| Pending/committed trust transitions | Partially specified; platform validation required | 0017 proposes pending/committed/recovery-required states | Define atomicity boundaries, record contents, idempotent retries, lost acknowledgments, and what each side may do before durable commit. |
| Crash consistency and lost acknowledgment | Partially specified; implementation and failure-injection evidence required | 0017 states that timeout does not prove remote commit | Define recovery after every message boundary and prove that a retry cannot silently convert a one-sided commit into trust. |
| Revocation, device replacement, and recovery | Partially specified; Issue #53 and independent review required | 0015 and 0017 require fail-closed changed-key behavior | Define local revocation records, replacement authorization, lost-device recovery, stale certificate rejection, and re-pairing requirements. |
| Session establishment and authorization separation | Specified as a boundary; authorization policy remains a separate gate | 0017 and Issue #58 separate pairing from authorization | Define the exact handoff predicate to an authorized session without granting any capability by TLS readiness, pairing, or reconnect alone. |

## 5. Critical unresolved decisions

These are P0 review blockers, not implementation details:

1. **Identity-to-certificate binding:** whether the Mac certificate public key is the long-term identity key, and how the iPhone binds the QR identity to the verified peer without accepting a certificate merely because it chains to the temporary/session trust policy.
2. **Exporter semantics:** whether `sec_protocol_metadata_create_secret_with_context` has the required semantics for this transcript, including TLS resumption, early data, connection replacement, and context/label domain separation on every supported runtime.
3. **Signature canonicalization:** exact ECDSA DER acceptance, low-`s` policy, CryptoKit behavior, and rejection of malleable or non-canonical encodings.
4. **Key agreement and SAS:** exact relationship among the exporter-derived value, ephemeral P-256 ECDH value, HKDF salt/info, output length, and display encoding. The current combination must not be accepted because each primitive is familiar; the composition needs review.
5. **Transcript finalization:** complete message-specific schemas, ordering, signature coverage, and whether the two `CommitAck` messages are required and how they produce durable commitment.
6. **QR origin and replay policy:** what the user is assumed to recognize, how QR replacement/relay is represented, how expiry survives clock changes, and how one-time use is durably invalidated.
7. **Persistent trust and replacement:** exact pending/committed record format and recovery behavior for crashes, lost acknowledgments, Keychain denial, key deletion, and changed peer keys.
8. **Authorization handoff:** exact condition that allows a future authorized session, and proof that no transport, pairing, or reconnect callback can bypass Issue #58.

## 6. Reviewer-facing protocol overview

The proposed logical sequence is:

```text
Mac displays QR(session, one-time token, suite, Mac identity binding)
        |
iPhone scans and selects an untrusted candidate
        |
TLS 1.3 is established with fail-closed peer verification
        |
Both derive a binding from the exact TLS metadata
        |
iPhone -> Mac: PairingHello(session, token, role, identity, ephemeral, nonce)
Mac -> iPhone: PairingHelloAck(identity, ephemeral, nonce, transcript context)
Both -> peer: IdentityProof(signature over canonical transcript and role purpose)
Both display SAS and require explicit local approval
Both -> peer: UserConfirm(signature over transcript and approval)
Both -> peer: final confirmation with durable pending/committed transition
Only a committed record may be considered paired
Only a separate authorization gate may produce an authorized session
```

The sequence is not an implementation authorization. Before approval, the reviewer must resolve exact message ordering, all fields, signatures, failure behavior, and persistence boundaries.

### 6.1 State invariants for review

- Discovery never creates identity or trust.
- TLS `ready` never creates identity, pairing, or authorization.
- A verified certificate never substitutes for the QR/key binding.
- A verified transcript never proves durable peer commit.
- One-sided approval never creates operational trust.
- A changed or revoked public key never silently becomes trusted.
- Reconnect uses fresh session material and never replays non-idempotent operations.
- Any missing, duplicate-conflicting, malformed, stale, or unverifiable message terminates the pending session.

## 7. Deterministic test-vector readiness

### 7.1 Vector manifest

The implementation package should provide a machine-readable manifest with:

```text
vector_id
construction_version
suite
input_encoding_hex
expected_output_hex_or_rejection
expected_state_transition
negative_reason
```

Private keys in vectors must be fixed non-production fixtures generated solely for the vector package. They must never be reused as application credentials or copied from physical experiments.

### 7.2 Vector categories

| Category | Can be deterministic now? | Required fixture or outcome |
| --- | --- | --- |
| Canonical field encoding | Yes, once schema is frozen | Byte-for-byte encodings, length boundaries, field-order and duplicate rejection |
| Public-key representation | Yes | Fixed P-256 public keys, compressed/uncompressed rejection cases, invalid point cases |
| ECDSA signatures | Yes, after low-`s` and DER policy is fixed | Fixed non-production private keys, signatures, mutation and malleability rejection |
| Transcript hash | Yes, after message schemas are frozen | Full canonical transcript bytes and expected SHA-256 digest |
| Exporter binding | Synthetic only until a reviewed fixture API exists | Fixed synthetic `tls_binding` input; label/context mutation outcomes. Must be labeled “synthetic exporter fixture,” not a TLS-session exporter |
| ECDH/HKDF/SAS | Yes, after exact composition is accepted | Fixed ephemeral keys, shared-secret derivation, salt/info, SAS bytes, display value, wrong-role and wrong-session rejection |
| QR expiry and one-time use | Yes | Fixed timestamps, skew bounds, duplicate scans, token reuse, cancellation and replacement outcomes |
| Signature/transcript mutation | Yes | One-field-at-a-time mutations for role, identity, session, nonce, TLS binding, purpose, and approval |
| Trust-state transitions | Yes | Deterministic event tables for pending, committed, revoked, replacement, crash, lost acknowledgment, and recovery |

No cryptographic expected-value vector is generated by this package yet. The missing vectors are an explicit review gate, not evidence that the construction is secure. A real TLS exporter vector must be produced by a controlled implementation or a reviewed test harness; a synthetic exporter input must not be presented as runtime TLS evidence.

### 7.3 Required negative vector set

At minimum, the independent implementation must reject:

- unknown protocol version and suite;
- role-swapped identities and key-swapped signatures;
- duplicate, reordered, missing, unknown, overlong, and non-canonical fields;
- malformed SEC1 public keys and non-canonical DER signatures;
- high-`s` or otherwise malleable signatures under the selected policy;
- QR token reuse, expiry, clock-skew violation, and session mismatch;
- changed nonce, ephemeral, identity, exporter label/context, or TLS binding;
- replayed proof, confirmation, and commit messages from another session;
- one-sided confirmation and lost final acknowledgment;
- revoked, replaced, missing, corrupt, or inaccessible trust records.

## 8. Apple platform feasibility dependencies

The following references describe candidate capabilities, not completed minimum-OS validation:

- [Apple CryptoKit](https://developer.apple.com/documentation/cryptokit)
- [Secure Enclave](https://developer.apple.com/documentation/cryptokit/secureenclave)
- [SecureEnclave.P256.Signing.PrivateKey](https://developer.apple.com/documentation/cryptokit/secureenclave/p256/signing/privatekey)
- [Keychain Services](https://developer.apple.com/documentation/security/keychain-services)
- [Network security options](https://developer.apple.com/documentation/network/security-options)
- [NWProtocolTLS.Metadata](https://developer.apple.com/documentation/network/nwprotocoltls/metadata)
- [sec_protocol_metadata_create_secret](https://developer.apple.com/documentation/security/sec_protocol_metadata_create_secret(_:_:_:_:))
- [sec_protocol_metadata_create_secret_with_context](https://developer.apple.com/documentation/Security/sec_protocol_metadata_create_secret_with_context(_:_:_:_:_:_:))

| Dependency | Current evidence | Required gate |
| --- | --- | --- |
| P-256 signing and key agreement | Candidate APIs documented; isolated feasibility work exists | Compile and run on macOS 14 and iOS 17; verify key representation and error behavior |
| Secure Enclave signing | Device-dependent documented candidate | Test availability, non-exportability, signing, deletion, locked state, and fallback policy on supported hardware |
| Keychain persistence | Design boundary documented in 0015 | Implement and test isolated adapters only after construction review; validate crash, denial, replacement, and revocation behavior |
| TLS metadata/exporter access | Mac-to-Mac and maintainer-reported physical experiment evidence | Verify exact semantics, ownership, session lifecycle, resumption, early-data policy, and minimum-OS runtime behavior |
| Certificate/public-key binding | Not production validated | Define issuance, identity matching, hostname/SAN policy, rotation, and wrong-peer rejection |
| Privacy and permissions | Requirements exist in Issue #58 | Review capability authorization separately; no pairing success may grant control |

## 9. Threat-review checklist

The external reviewer must explicitly address:

| Threat | Required question | Minimum evidence |
| --- | --- | --- |
| Active local MITM | Does the exact certificate/key, transcript, and SAS binding prevent identity substitution? | Wrong-key, changed-QR, transcript mutation, and role-swap vectors |
| Rogue Bonjour | Can a discovered service cause trust or an identity selection shortcut? | Discovery-to-trust boundary review and negative tests |
| QR substitution | What user and cryptographic assumptions remain if the QR is replaced or relayed? | Expiry, token reuse, wrong-peer, and UX confirmation analysis |
| Unknown-key-share | Are both identities and roles covered in one canonical signed transcript? | Key/role permutation vectors and proof-of-possession review |
| Replay and duplicate messages | Can old proofs or confirmations affect a new session or commit? | Session, nonce, token, and duplicate state vectors |
| Downgrade | Can a peer select an older version, suite, or weaker binding? | Unsupported-version/suite and negotiation tests |
| TLS channel substitution | Is the binding from this exact TLS connection and not merely its certificate? | Exporter semantics, resumption, reconnect, and replacement analysis |
| One-sided approval | Can one device become trusted after the other cancels or crashes? | Lost-ack, crash-boundary, and durable-state tests |
| Relay | What relay attacks remain possible even with QR and SAS? | Explicit residual-risk statement and user-confirmation review |
| Key replacement/revocation | Can a changed key be silently re-trusted? | Replacement, revocation, deletion, and recovery vectors |
| Compromised endpoint | Which properties are intentionally lost if one endpoint is compromised? | Explicit scope limitation and authorization isolation |

## 10. Independent review process recommendation

For a small open-source project, use a staged external review rather than treating a single pull-request comment as approval:

1. Freeze a review candidate commit containing 0017, this package, the threat model, the identity/storage design, and the vector manifest format. Do not include production pairing code.
2. Select an external reviewer with demonstrated experience in authenticated key exchange, TLS/channel binding, device pairing, replay/recovery protocols, and Apple platform security. The reviewer must not be the protocol author, implementer, or an AI assistant involved in the design.
3. Provide the reviewer with the exact assumptions, unresolved-decision list, source references, and requested acceptance/rejection criteria. Ask for written findings mapped to P0/P1/P2 severity.
4. Require the reviewer to challenge the construction against identity misbinding, UKS, role confusion, downgrade, replay, relay, crash consistency, key replacement, and authorization-boundary failures.
5. Resolve or explicitly reject every P0/P1 finding. Any construction change requires updated transcript diagrams, vectors, and a second review of the changed security claims.
6. Obtain maintainer approval only after the external findings and implementation/platform evidence are recorded. Update ADR 0003 from Proposed only through the repository's explicit ADR acceptance workflow.
7. Keep Issue #52 open and keep production pairing prohibited until the gate is satisfied.

The review should be time-boxed and scoped to the construction. A broader code audit, Apple entitlement review, and implementation review are separate activities and must not be implied by a protocol review.

## 11. Reviewer questions prioritized by impact

### P0 — Must be answered before construction approval

- What exact public key is the device identity, and how is it cryptographically bound to the TLS peer certificate and QR record?
- Does the proposed exporter API provide the required same-session binding under all supported TLS lifecycle cases?
- Is the ECDH/exporter/HKDF SAS composition sound, with no missing context or unknown-key-share path?
- Is the transcript fully canonical, complete, role-bound, and signed in the exact order claimed?
- Can any crash, lost acknowledgment, duplicate, or Keychain failure create unilateral trust or a silent replacement?
- What exact event enables an authorized session, and how is Issue #58 enforced independently?

### P1 — Must be answered before implementation starts

- What are the exact ECDSA DER and low-`s` rules interoperable with CryptoKit?
- Which macOS 14 and iOS 17 APIs and runtime behaviors are actually validated?
- What is the production certificate issuance, hostname/SAN, rotation, and revocation policy?
- What is the clock-skew and QR one-time-use policy under restart and clock changes?
- What are the exact message retransmission and idempotency rules?

### P2 — Must be documented before release

- What user-facing recovery text is used for revoked, replaced, locked, unavailable, and stale identity states?
- Which diagnostic metadata is safe to retain, and how are pairing failures rate-limited and logged?
- Which unsupported platform and accessory cases are disclosed in release documentation?

## 12. Acceptance and rejection criteria

### Accept Candidate A for implementation review only if

- every P0 decision has one explicit, internally consistent answer;
- the exact wire format, message ordering, signatures, KDF, SAS, and durable state transitions are frozen;
- independent reproducible vectors cover all positive and negative cryptographic cases;
- macOS 14 and iOS 17 platform/key-storage/TLS behavior is validated or the minimum targets are changed explicitly;
- the external reviewer provides written findings and no unresolved P0/P1 blocker remains;
- Issue #58's authorization boundary is reviewed separately;
- ADR 0003 is explicitly accepted by the maintainer through the repository workflow.

### Reject or return Candidate A for revision if

- certificate-to-identity binding remains implicit;
- exporter semantics are inferred from API names or a newer OS experiment;
- the KDF/SAS composition is not independently justified;
- transcript canonicalization or message ordering leaves choices to implementers;
- vectors are illustrative only or cannot be reproduced independently;
- crash, revocation, replacement, or lost-ack behavior can silently promote trust;
- pairing or transport readiness can bypass capability authorization;
- a reviewer cannot reproduce the claimed evidence from the supplied package.

## 13. Current recommendation

**CONDITIONAL — MISSING SPECIFICATION EVIDENCE.**

The package is suitable for sending to a qualified external reviewer for a structured gap review and for receiving a provisional feasibility critique. It is not ready for cryptographic approval, ADR 0003 acceptance, production pairing implementation, persistent trust, or authorized sessions.

The single highest-value next action is to resolve the P0 identity-to-certificate binding and exporter/KDF/SAS semantics, then generate the corresponding deterministic positive and negative vectors before requesting formal external approval.
