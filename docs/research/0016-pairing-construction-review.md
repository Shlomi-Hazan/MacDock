# Stage 2 Pairing Construction Review

- Issue: [#52](https://github.com/Shlomi-Hazan/MacDock/issues/52)
- Stage: Stage 2 — Connection & Pairing
- Status: Draft security design; no construction selected or approved
- Related: [Issue #38](https://github.com/Shlomi-Hazan/MacDock/issues/38), [Issue #41](https://github.com/Shlomi-Hazan/MacDock/issues/41), [ADR 0003](../decisions/0003-qr-first-pairing-and-peer-authentication.md), [ADR 0005](../decisions/0005-local-transport-and-protocol-boundaries.md)

## Executive decision

This document establishes a security gate before production pairing implementation. It compares established construction families and records a provisional direction for review. It does not select a cryptographic wire protocol, accept ADR 0003, generate keys, implement pairing, or authorize trusted sessions.

The current recommendation is to investigate a TLS 1.3 transport combined with an application-layer, identity-signing transcript bound to the QR bootstrap and the authenticated TLS session. This is only a candidate architecture. The exact identity algorithm, certificate or public-key binding, transcript encoding, SAS derivation, and trust-commit protocol remain unresolved and require independent cryptographic review, test vectors, and maintainer approval.

## Evidence classification

| Claim | Classification |
| --- | --- |
| Network.framework can provide a TLS transport integration seam | Documentation-based; the Stage 0 transport experiment validated only a test transport and fingerprint check |
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

### Candidate C — SPAKE2+ or another PAKE

Use a standardized password-authenticated key exchange such as [SPAKE2](https://www.rfc-editor.org/rfc/rfc9382.html), with a short bootstrap secret or code and explicit transcript confirmation.

**Strengths:** can resist passive offline password guessing when the password model and parameters are correct; the standard specifies transcript-related key confirmation requirements.

**Risks:** MacDock starts from device identities and QR bootstrap, not a user password. A short code has limited entropy and needs careful rate limiting and confirmation semantics. Apple has no direct SPAKE2 API; a reviewed implementation and test vectors would be required. It does not remove the need for long-term identity, revocation, or recovery design.

**Status:** not preferred for the one-Mac/one-iPhone MVP unless a strong password/bootstrap requirement emerges.

### Candidate D — Mutual TLS with device certificates

Provision device certificates and a private trust anchor through the pairing flow, then use mutual TLS for peer authentication and channel protection.

**Strengths:** uses mature TLS authentication semantics and can integrate with Network.framework's TLS configuration.

**Risks:** certificate issuance, trust-anchor protection, rotation, revocation, replacement, and QR bootstrap become a miniature PKI. Local certificate lifecycle and failure recovery are substantial for a single-developer MVP. A certificate accepted by TLS still needs an application authorization decision.

**Status:** technically possible but operationally heavy; not selected.

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
