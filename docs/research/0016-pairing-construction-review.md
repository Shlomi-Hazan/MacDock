# Stage 2 Pairing Construction Review

- Issue: [#52](https://github.com/Shlomi-Hazan/MacDock/issues/52)
- Stage: Stage 2 — Connection & Pairing
- Status: Draft security design; candidate comparison complete, no construction selected or approved
- Related: [Issue #38](https://github.com/Shlomi-Hazan/MacDock/issues/38), [Issue #41](https://github.com/Shlomi-Hazan/MacDock/issues/41), [ADR 0003](../decisions/0003-qr-first-pairing-and-peer-authentication.md), [ADR 0005](../decisions/0005-network-transport-and-protocol-boundary.md)

## Executive decision

This document establishes a security gate before production pairing implementation. It compares established construction families and records a provisional direction for review. It does not select a cryptographic wire protocol, accept ADR 0003, generate keys, implement pairing, or authorize trusted sessions.

The current recommendation is to investigate a TLS 1.3 transport combined with an application-layer, identity-signing transcript bound to the QR bootstrap and the authenticated TLS session. This is only a candidate architecture. The exact identity algorithm, certificate or public-key binding, transcript encoding, SAS derivation, and trust-commit protocol remain unresolved and require independent cryptographic review, test vectors, and maintainer approval.

## Evidence classification

| Claim | Classification |
| --- | --- |
| Network.framework can provide a TLS transport integration seam | Documentation-based; the Stage 0 transport experiment validated only a test transport and fingerprint check |
| Public Security APIs expose TLS-derived secrets, peer public-key material, and certificate-chain access from protocol metadata | Documentation-based and exercised in the isolated probe; minimum macOS 14/iOS 17 runtime behavior remains unverified |
| TLS 1.3 provides encrypted, integrity-protected records and a handshake transcript | Standards-based; see [RFC 8446](https://www.rfc-editor.org/rfc/rfc8446.html) |
| Apple platforms expose CryptoKit and device-dependent Secure Enclave APIs | Documentation-based; see [CryptoKit](https://developer.apple.com/documentation/cryptokit) and [SecureEnclave](https://developer.apple.com/documentation/cryptokit/secureenclave) |
| A concrete MacDock pairing construction is secure | Not established; requires design selection, review, implementation, vectors, and device tests |
| QR confirmation and SAS alone prevent relay attacks | Rejected; they improve human-origin verification but do not provide a general cryptographic relay guarantee |

## Security objectives and trust assumptions

The future protocol must provide mutual authentication of the intended Mac and iPhone, freshness, transcript integrity, resistance to replay and MITM substitution, explicit confirmation on both devices, crash-safe pending/committed pairing, and fail-closed recovery after key replacement or revocation.

Bonjour visibility, a service name, an IP address, a successful TCP connection, and TLS encryption are not identity or authorization. A QR code is a short-lived bootstrap channel whose security depends on how its contents are generated, displayed, bound to the handshake, expired, and confirmed. A human SAS comparison depends on the physical-origin assumption and leaves residual relay risk.

## Candidate comparison

### Candidate A — TLS 1.3 plus signed application transcript

Use Network.framework TLS for channel protection. Bind a reviewed long-term device public key to a canonical application transcript containing roles, both public identities, fresh ephemeral values, QR bootstrap data, protocol version, and a TLS binding value. Both devices sign or otherwise authenticate the transcript, compare a human-readable SAS, and commit trust only after both confirmations.

**Strengths:** native transport fit; reuses the existing bounded framing and lifecycle seams; separates channel encryption from application identity; can support explicit pending and committed trust states.

**Risks:** transcript design, key representation, TLS exporter or equivalent binding, algorithm selection, and signature semantics are security-critical. A superficially correct signature layer can still permit identity misbinding, role confusion, downgrade, or replay.

**Status:** preferred candidate for deeper review, not approved.

### Candidate B — Reviewed Noise pattern with application identity binding

Use a concrete, reviewed Noise pattern for ephemeral handshake and identity authentication, then bind QR data, roles, SAS, and trust state to the Noise handshake transcript. The [Noise Protocol Framework](https://noiseprotocol.org/noise_rev34.html) provides established patterns and testable state transitions.

**Strengths:** explicit handshake patterns and transcript model; forward-secrecy and authentication properties can be reasoned about per pattern; suitable for a small protocol when implemented from a reviewed library or carefully bounded implementation.

**Risks:** Network.framework does not provide Noise as a native application protocol; library selection and supply-chain review are required. CryptoKit and Secure Enclave capabilities do not automatically match every Noise key type. Implementing Noise primitives or patterns ad hoc would be unacceptable.

**Status:** viable alternative, not approved.

### Candidate C — SPAKE2, SPAKE2+, or another PAKE

SPAKE2 and SPAKE2+ are distinct standards and must not be conflated. [RFC 9382](https://www.rfc-editor.org/rfc/rfc9382.html) specifies SPAKE2, while [RFC 9383](https://www.rfc-editor.org/rfc/rfc9383.html) specifies SPAKE2+. Both are password-authenticated key exchanges, but their protocol messages, key derivation, security proofs/assumptions, and required implementation details differ. A MacDock design must select one exact standard and parameter set rather than referring generically to “SPAKE2+”.

Either candidate would use a short bootstrap secret or code and explicit transcript confirmation. It would not automatically provide a durable device identity or a complete trust lifecycle.

**Strengths:** a correctly parameterized PAKE can resist passive offline password guessing within its stated password model; each RFC specifies its own transcript and key-confirmation requirements.

**Risks:** MacDock starts from device identities and QR bootstrap, not a reusable user password. A short code has limited entropy and needs careful rate limiting and confirmation semantics. Apple has no direct SPAKE2 or SPAKE2+ API; a reviewed implementation, exact parameter selection, and independent test vectors would be required. Neither option removes the need for long-term identity, revocation, or recovery design.

**Status:** not preferred for the one-Mac/one-iPhone MVP unless a strong password/bootstrap requirement emerges.

### Candidate D — Mutual TLS with device certificates

Provision device certificates and a private trust anchor through the pairing flow, then use mutual TLS for peer authentication and channel protection.

**Strengths:** uses mature TLS authentication semantics and can integrate with Network.framework's TLS configuration.

**Risks:** certificate issuance, trust-anchor protection, rotation, revocation, replacement, and QR bootstrap become a miniature PKI. Local certificate lifecycle and failure recovery are substantial for a single-developer MVP. A certificate accepted by TLS still needs an application authorization decision.

**Status:** technically possible but operationally heavy; not selected.

## Approval maturity

The following maturity levels are tracked separately:

| Level | Current status |
| --- | --- |
| Candidate comparison completed | Achieved by this document |
| Candidate architecture provisionally preferred | Achieved: Candidate A is the leading direction for further review |
| Exact construction specified | Not achieved |
| Platform feasibility validated on macOS 14 and iOS 17 | Not achieved; documentation identifies APIs, but no targeted API compile/runtime experiment has been completed |
| Canonical cryptographic test vectors produced | Not achieved; only illustrative fixtures are proposed below |
| Independent cryptographic review completed | Not achieved |
| Maintainer approval recorded | Not achieved for a construction; the existing approval covers requirements and research only |

Issue #52 therefore remains open and In Progress. This PR does not satisfy the security gate for Issues #42 or #43.

## Provisional recommendation

Carry Candidate A into the next design review as the leading direction because it fits the existing Network.framework transport and keeps application authorization separate from channel establishment. The review must first decide whether the device identity is a signing identity, a certificate identity, or another established representation, and how it is stored and rotated.

Candidate A must not be implemented until the following are specified and independently reviewed:

1. Exact algorithms and supported Apple API/key-storage combinations on macOS 14 and iOS 17.
2. Canonical, versioned transcript encoding with domain separation and role binding.
3. TLS peer-key or exporter binding that prevents a second, unrelated authenticated channel from being substituted.
4. QR contents, expiry, one-time use, origin display, and bootstrap secrecy assumptions.
5. Freshness, replay handling, duplicate messages, and bounded retries.
6. SAS derivation, display, comparison, cancellation, and relay limitations.
7. Pending versus committed trust and crash-consistent two-sided confirmation.
8. Key replacement, revocation, lost-device recovery, and changed-peer behavior.
9. Negative test vectors and an independent cryptographic review.

## Apple TLS binding feasibility

Apple's public documentation exposes useful primitives, but it does not by itself prove that Candidate A is implementable with the intended identity and trust model.

### Publicly documented capabilities

`NWProtocolTLS.Metadata` exposes `securityProtocolMetadata`, which gives access to `sec_protocol_metadata_t` after the TLS handshake. Apple's public Security documentation lists:

- `sec_protocol_metadata_create_secret` and `sec_protocol_metadata_create_secret_with_context`, which derive an exported secret from protocol metadata using a label, optional context, and requested length.
- `sec_protocol_metadata_copy_peer_public_key`, which returns peer public-key material when available.
- `sec_protocol_metadata_access_peer_certificate_chain`, which exposes the peer certificate chain for certificate-based designs.
- Negotiated TLS version and cipher-suite accessors.
- Public TLS verification and identity configuration hooks through `sec_protocol_options`.

These APIs are documented at [Security Options](https://developer.apple.com/documentation/network/security-options), [sec_protocol_metadata_create_secret](https://developer.apple.com/documentation/security/sec_protocol_metadata_create_secret(_:_:_:_:)), [sec_protocol_metadata_create_secret_with_context](https://developer.apple.com/documentation/Security/sec_protocol_metadata_create_secret_with_context(_:_:_:_:_:_:)), and [NWProtocolTLS.Metadata](https://developer.apple.com/documentation/network/nwprotocoltls/metadata).

The `create_secret` functions are exporter-like public APIs and are the strongest documented candidate for a TLS-session binding value. The documentation does not establish that a MacDock transcript may safely use an exported value without deciding the exact label, context, exporter length, TLS resumption policy, early-data policy, and session lifecycle. The value must be obtained from the exact connection's metadata and must never be replaced with a service name, endpoint, certificate hash, or locally generated nonce.

### What remains unverified

- The repository has compiled and exercised an isolated adapter against the installed SDK interfaces for these functions.
- A maintainer-reported physical Mac/iPhone test compared exporter-derived values across the two ends of the same TLS session; this is not tool-executed evidence and does not establish production authentication.
- No test has established behavior across reconnect, TLS resumption, early data, listener restart, or certificate/key replacement.
- The relationship between an exporter-derived value and the selected long-term CryptoKit/Secure Enclave identity is not yet specified.
- The public API surface does not remove the need for a reviewed certificate/public-key verification policy.

### Binding alternatives

| Binding design | Security dependency | Current assessment |
| --- | --- | --- |
| TLS exporter-like secret plus signed transcript | Exact exporter label/context, same-session metadata, peer verification, identity signatures, and transcript domain separation | Promising but requires targeted API and protocol testing |
| Peer public-key/certificate bytes plus signed transcript | Correct peer verification and an unambiguous certificate/public-key representation; certificate bytes alone do not prove the session is the same channel | Viable only with reviewed identity and TLS verification policy |
| Mutual TLS device credentials | Certificate issuance, trust-anchor distribution, rotation, revocation, and recovery | Public APIs support the mechanics, but lifecycle is heavy and unreviewed |
| Alternative reviewed handshake such as a concrete Noise pattern | Reviewed implementation/library, identity binding, transcript vectors, and integration with Network.framework | Fallback if TLS binding cannot meet the required properties |

Candidate A therefore has **local Mac-to-Mac runtime feasibility evidence and one maintainer-reported physical Mac-to-iPhone runtime result**, but still requires negative physical trust tests, minimum-OS runtime validation, formal construction specification, and independent cryptographic review before any production implementation. No evidence justifies treating it as approved for production pairing.

## Issue #52 isolated API-feasibility evidence

The isolated probe in [`experiments/tls-channel-binding/`](../../experiments/tls-channel-binding/) compiled and ran its compile-only mode on the development Mac using Xcode 26.3, Swift 6.2.4, and the installed macOS 26.2 SDK. It references the public `NWProtocolTLS.Metadata` and `sec_protocol_metadata_*` APIs, uses an explicitly scoped trust callback for the runtime mode, and deliberately emits no secret material.

The same source passed direct `swiftc -typecheck` against the installed iOS Simulator SDK for an arm64 iOS 17 simulator target. This is source-level compatibility evidence against a newer installed SDK, not runtime evidence on iOS 17. A SwiftPM cross-compile attempt was rejected because the invocation selected a macOS sysroot for an iPhone target; it does not establish an API limitation.

The runtime extension was first executed with a temporary self-signed server certificate containing SAN entries but no explicit `keyUsage` or `extendedKeyUsage=serverAuth`; both endpoints remained in `preparing`, the verification callback was not invoked, and the run failed closed. This reproduced in an interactive Terminal, with private-key lookup and signing capability reported as available, so the earlier Keychain-prompt hypothesis is not supported.

The same experiment was then repeated with a temporary certificate explicitly containing `subjectAltName=DNS:localhost,IP:127.0.0.1`, `keyUsage=digitalSignature,keyEncipherment`, and `extendedKeyUsage=serverAuth`. The listener and both connections reached `ready`; scoped trust evaluation succeeded; same-session exporter values were equal; separate sessions, alternate labels, and alternate contexts produced different values. This is executed Mac-to-Mac feasibility evidence only. A subsequent maintainer-reported physical Mac–iPhone run using `Shlomis-MacBook-Pro-2.local` and a temporary certificate with a matching DNS SAN displayed `Diagnostic exchange complete (unverified)` on the iPhone and logged the following on the Mac:

```text
listener state: ready
listener accepted connection
server connection state: preparing
server connection state: ready
server TLS ready; retrieving connection metadata
server TLS metadata ready; diagnostic receive started
server exporter response sent
server diagnostic exchange complete
```

This physical result demonstrates the isolated exporter comparison across the tested endpoints, not device authentication, pairing, authorization, or independent cryptographic approval. Physical wrong-anchor/hostname and expired-certificate rejection are now demonstrated on the tested path; reconnection and cancellation, minimum-OS runtime compatibility, and independent cryptographic review remain outstanding. Candidate A is therefore supported for continued formal specification and review, not approved for production pairing.

The local negative matrix additionally exercised an unrelated trust anchor and a `wronghost` certificate. Both failed closed without exporter success; the hostname mismatch reached the verify callback and produced certificate errors. The maintainer then demonstrated physical wrong-anchor rejection (`-67843`), physical hostname rejection (`-67602`), and physical expired-server-leaf rejection (`-67818`) with no TLS-ready or exporter-success state. The physical results are maintainer-reported evidence only; compilation and successful negative tests do not establish minimum-OS compatibility or construction approval.

The maintainer subsequently performed two physical negative TLS tests. With the valid Mac certificate and an unrelated iPhone trust anchor, the iPhone verification callback reported `NSOSStatusErrorDomain` code `-67843` (`certificate unknown`) and the Mac reported `-9825` (`misc. bad certificate`). With the correct anchor but an expected hostname of `wronghost.local` while the certificate contained `DNS:Shlomis-MacBook-Pro-2.local`, the callback reported code `-67602` and the Mac again reported `-9825`. Neither test reached TLS ready or exporter exchange. These maintainer-reported results demonstrate fail-closed wrong-anchor and hostname rejection on the tested physical path; they do not establish identity authentication or pairing.

The isolated iOS diagnostic UI now preserves the distinction between an explicit verification rejection and an unclassified timeout. This is a reporting improvement only; it does not change the fail-closed trust policy. The experiment still returns exporter-derived bytes over its fixed diagnostic exchange solely for feasibility comparison. That exchange is not a production protocol and must not be promoted unchanged into pairing or authenticated-session code.

The maintainer repeated the wrong-trust-anchor test with the updated UI. The iPhone first displayed `Waiting: -9808: bad certificate format`, then reached `Failed: certificate verification rejected`, with Start enabled and Cancel disabled. This confirms physical UI propagation of an explicit trust rejection; the intermediate waiting code is not treated as the final certificate classification.

The expired-certificate test was executed using a valid temporary CA and a separately signed expired server leaf with the required `serverAuth`, key-usage, and DNS SAN extensions. The iPhone trusted only the public CA certificate and reported `-67818`; the Mac reported `-9825`; neither endpoint reached TLS ready. This structure is intentional because an expired certificate used directly as a trust anchor can be evaluated differently from an expired server leaf. The result is maintainer-reported physical evidence, not cryptographic construction approval.

For connection lifecycle validation, the maintainer reported two physical cancellation scenarios. In D.1, cancellation during TLS `preparing` produced a Mac-observed POSIX 54 connection reset followed by `cancelled`, with no diagnostic completion; this is a PASS for that observed timing window. In D.2, cancellation after TLS ready left the iPhone in terminal `Cancelled` with no late UI success, while the Mac later reported local send completion and `remote receipt unverified`; this is a PASS for iPhone terminal-state and late-success suppression, not proof of cancellation propagation or remote receipt. The listener cancels delayed responses when a terminal connection state is observed and does not infer peer cancellation from silence.

The maintainer then executed Test E by interrupting the Mac process with `Ctrl-C` during the eight-second diagnostic delay. The iPhone reached bounded terminal status `Timeout: no verified exchange`, re-enabled Start, and did not report diagnostic success. This is a PASS for bounded client failure, no false success, and UI recovery after server-process interruption. The supplied Mac output did not show an accepted-connection terminal state after `^C`, so explicit transport-close detection and graceful accepted-connection cleanup remain unverified.

Test F then failed on its second attempt: the first diagnostic exchange completed, the second iPhone attempt timed out, and the available Mac output contained only one accepted connection. Source inspection found that the listener used a session-completion semaphore and cancelled the listener as soon as the first session finished, despite accepting a duration parameter. The listener now uses the duration as its actual lifetime, tracks multiple accepted sessions independently, and emits opaque session-scoped state logs. The corrected Test F remains physical validation of two independent connections, not TLS session resumption or production pairing reconnection.

## Candidate transcript format

The following is an illustrative encoding proposal, not a cryptographic test vector or accepted wire format. It uses a length-delimited binary structure so concatenation is unambiguous. Every integer is unsigned big-endian; every byte string is prefixed by a four-byte length; text fields are UTF-8 and are only used where the field definition permits them.

```text
MACDOCK-PAIRING-TRANSCRIPT
format-version: uint16
construction-suite: length-prefixed ASCII
initiator-role: one fixed role code
responder-role: one fixed role code
initiator-identity: length-prefixed canonical public-key representation
responder-identity: length-prefixed canonical public-key representation
initiator-ephemeral: length-prefixed ephemeral public value
responder-ephemeral: length-prefixed ephemeral public value
qr-bootstrap-id: length-prefixed one-time opaque value
qr-expiry: uint64
initiator-nonce: exactly 32 bytes
responder-nonce: exactly 32 bytes
tls-binding: length-prefixed exporter-derived value or reviewed alternative
prior-transcript-hash: length-prefixed value, empty only for first pairing
```

The actual implementation must encode fields by numeric tag or a separately specified canonical schema, reject duplicate or unknown security-critical fields, enforce fixed lengths, bind the roles in a single canonical order, and domain-separate every signature and SAS derivation. The literal example above is useful for review only; it has not been independently tested or approved.

Illustrative signature input:

```text
signature-input = H(domain || transcript-bytes || confirmation-purpose)
```

The exact hash, signature algorithm, public-key encoding, domain string, and confirmation purpose remain unresolved. A signature over the transcript authenticates the transcript only if the key is already bound to the intended peer and the channel binding is from the exact authenticated session.

## Pairing confirmation and durable commitment

QR expiry and one-time use must be enforced by a bounded pairing-session record, not only by UI state. Each pairing session needs fresh nonces, a unique session identifier, a maximum lifetime, cancellation, and replay/duplicate handling. The Mac and iPhone must independently display and confirm the same derived SAS before either side can send a final confirmation.

Verifying the same transcript proves that both sides authenticated the same proposed exchange; it does not prove that both sides durably committed the pairing record. The future implementation therefore needs a pending record, an authenticated final-confirmation exchange, crash-safe commit semantics, and recovery rules for:

- one-sided approval;
- a lost final acknowledgment;
- duplicate final messages;
- a crash between local writes;
- a retry after one side committed and the other did not;
- changed or revoked identity material.

Only a fully committed record may be consumed by an authorized-session gate. A replacement key must enter recovery or require explicit re-pairing; it must never be silently substituted.

## Adversarial review

| Scenario | Required defense | Residual risk or evidence gap |
| --- | --- | --- |
| Active local MITM | TLS verification plus transcript identity signatures and exact channel binding | No construction or test vectors selected |
| Rogue Bonjour advertisement | Treat discovery as untrusted; require QR-bound peer verification | Candidate metadata can still be spoofed |
| QR substitution | Display origin and peer details; bind one-time QR data into the transcript; require two-sided confirmation | Physical-origin assumption and user error remain |
| Unknown-key-share | Bind both ordered roles, both identities, session values, and channel binding into the transcript | Requires formal review of role and identity encoding |
| Role confusion | Fixed initiator/responder roles and role bytes in every signed transcript | Not implemented or tested |
| Downgrade | Version and suite negotiation is authenticated; reject unsupported or conflicting values | Exact negotiation policy unresolved |
| Transcript substitution | Sign the canonical transcript and include QR, freshness, and TLS binding | Canonical encoding not accepted |
| TLS channel substitution | Derive the binding from the exact TLS metadata and include it in signed data | Exporter integration untested on target OS versions |
| Replay or duplicate messages | Fresh nonces, one-time session, expiry, request IDs, and idempotent finalization | Test vectors and persistence behavior pending |
| One-sided approval | Pending state and no authorization until both confirmations commit | Requires crash-consistent implementation |
| Lost final acknowledgment | Reconcile authenticated session state without replaying non-idempotent actions | Recovery protocol not specified |
| Crash during storage | Durable pending/committed records with fail-closed recovery | Keychain adapter not implemented |
| Key replacement/revocation | Explicit revocation marker and re-pairing; changed key fails closed | Lifecycle policy pending #53 and construction review |
| Relay attack | Explain physical-origin assumption; bind SAS and transcript, but do not claim cryptographic relay prevention | Residual relay risk remains |

## Required test-vector set

The eventual selected construction must publish deterministic, non-secret fixtures for:

1. Positive pairing with both roles and both confirmations.
2. Wrong Mac identity and wrong iPhone identity.
3. Swapped roles and swapped identity ordering.
4. Changed one byte of QR bootstrap, expiry, nonce, or TLS binding.
5. Replayed bootstrap and replayed final confirmation.
6. Duplicate final confirmation after commit and after cancellation.
7. Unsupported protocol version or suite.
8. Truncated, duplicated, reordered, or unknown transcript fields.
9. Exporter value from a different TLS session.
10. Revoked, replaced, missing, corrupt, or inaccessible identity record.
11. Crash/restart at each pending-to-committed transition.
12. SAS mismatch, user rejection, timeout, and relay-limitation documentation.

These are required artifacts, not evidence that has already been generated or validated.

## Pairing state and authorization gate

The future implementation must keep `candidate`, `peer identity observed`, `pairing pending`, `pairing committed`, `revoked`, and `authorized session` distinct. Neither device may enable application-control operations after only one approval, a QR scan, a TLS-ready event, a SAS display, or a persisted local record. A duplicate or late final message must be idempotent and must not commit trust unless both sides have verified the same transcript and confirmation state.

Issue #42 must consume this design only after the gate is explicitly accepted. Issue #43 must additionally consume the completed platform identity/Keychain adapters tracked by [Issue #53](https://github.com/Shlomi-Hazan/MacDock/issues/53). ADR 0003 remains Proposed.

## Apple feasibility questions

- Which CryptoKit signing and key-agreement types satisfy the selected construction and can be stored or used with the intended Keychain/Secure Enclave boundary?
- Can the needed TLS binding value be obtained through supported Network.framework APIs without depending on private APIs?
- What exact Keychain accessibility and device-lock behavior is required during pairing and reconnection?
- Which identity representations survive reinstall, backup/restore, device replacement, and explicit revocation as intended?
- Which APIs and libraries can be shipped without introducing an unacceptable supply-chain or maintenance burden?

These are documentation and design questions, not runtime claims. Physical-device validation remains required after a construction is selected.

## Required validation artifacts

Before acceptance, the design must include:

- Canonical transcript examples and fixed test vectors, including wrong-role, wrong-peer, changed-QR, replay, duplicate, truncation, and version-mismatch cases.
- Negative tests for one-sided approval, interrupted persistence, key replacement, revoked identity, relay limitations, and TLS/application binding mismatch.
- A macOS 14 and iOS 17 API feasibility matrix.
- Independent cryptographic review evidence; an agent or maintainer self-review alone is not sufficient.
- A physical Mac/iPhone test plan that distinguishes encryption, peer authentication, pairing commitment, and authorization.

## Explicit non-goals for this PR

No pairing code, QR UI, Keychain adapter, identity generation, TLS trust callback, persistent trust, authorized session, remote command, or application-control capability is introduced by this design review.
