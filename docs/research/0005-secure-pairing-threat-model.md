# Stage 0 Research: Secure Pairing Threat Model and UX

- Status: Proposed design for review
- Issue: [#5](https://github.com/Shlomi-Hazan/MacDock/issues/5)
- Scope: One iPhone and one Mac, before production pairing implementation

## Executive summary

MacDock must not treat Bonjour visibility, local-network reachability, a QR payload, or TLS encryption alone as proof that the intended Mac is present. The proposed design is a QR-first, user-confirmed pairing flow:

1. The Mac creates a short-lived pairing session and displays a QR code containing a session-specific bootstrap record and the Mac's public identity binding.
2. The iPhone scans the QR code, discovers the Mac, and establishes a TLS 1.3 connection whose peer key is checked against the QR binding.
3. Both devices exchange signed, fresh transcript material and derive a short authentication string (SAS) from that transcript.
4. The same SAS is displayed on both devices. The user confirms the match on both devices before either device stores the peer as trusted.
5. Each device stores the other device's long-term public identity and uses it to authenticate future sessions.

The QR code is an out-of-band bootstrap and origin hint. It is not complete authentication. The design depends on the user scanning the intended Mac's display, comparing the SAS, and approving both sides.

This document is a threat model and design proposal. It is not a cryptographic proof and does not implement pairing.

## Evidence and design classification

- **Documented:** Apple documents the relevant Keychain, CryptoKit, Network.framework, and TLS capabilities.
- **Proposed:** a design choice recommended for Stage 2, subject to review and implementation experiments.
- **Requires validation:** behavior that must be tested in a signed app on the target Mac and iPhone.
- **Not claimed:** this document does not claim that pairing, mutual authentication, or recovery has been implemented.

## Assets

| Asset | Security property | Consequence of compromise |
| --- | --- | --- |
| Mac long-term identity private key | Confidentiality and integrity | Attacker can impersonate the paired Mac until trust is revoked |
| iPhone long-term identity private key | Confidentiality and integrity | Attacker can impersonate the paired iPhone until trust is revoked |
| Peer public-key binding | Integrity | Wrong peer may be trusted or a legitimate peer may be rejected |
| Pairing session token and ephemeral keys | Confidentiality, freshness, bounded lifetime | Pairing confusion or replay within the active window |
| TLS session keys | Confidentiality and integrity | Current session disclosure or tampering |
| Dock configuration | Integrity and local privacy | Wrong applications may be shown, launched, or reordered |
| Launch and activation requests | Integrity, freshness, authorization | Unauthorized Mac actions |
| User approval decisions | Integrity and auditability | Silent or unintended trust establishment |

## Trust boundaries

1. The MacDock iPhone app and Mac companion are separate trust domains until pairing completes.
2. Bonjour and the local network are untrusted discovery and transport paths.
3. The QR display and camera scan form an out-of-band channel with a human-in-the-loop origin assumption; the code is not trusted merely because it was decoded.
4. The TLS stack provides an encrypted channel only after its peer-verification policy succeeds.
5. The Keychain protects long-term private material on each device, subject to device compromise and platform policy.
6. Production application commands cross the authenticated session boundary only after pairing and per-session authentication succeed.

## Attacker capabilities and assumptions

The threat model assumes an attacker may:

- Observe, inject, drop, reorder, and replay local-network packets.
- Publish malicious Bonjour services or answer discovery first.
- Run a rogue Mac or iPhone on the same network.
- Attempt TLS interception with an untrusted certificate.
- Relay messages between a legitimate device and a victim.
- Present a substituted QR code if they control the display, the physical environment, or the user's scan target.
- Observe a short code from a distance, or socially persuade the user to approve a mismatch.
- Attempt repeated pairing sessions and replay old pairing messages.
- Obtain a lost or replaced device, subject to its lock state and Keychain protections.

The baseline attacker does not control the operating system, Secure Enclave/Keychain, or the user's trusted display and input on both devices. If either endpoint is fully compromised, pairing cannot restore its integrity.

## Proposed cryptographic and protocol construction

The proposal uses standard primitives exposed by Apple platforms rather than inventing a primitive:

- TLS 1.3 through Network.framework for the encrypted transport and fresh session keys.
- A long-term Curve25519 signing identity for each device, using Ed25519 signatures as exposed by CryptoKit.
- Ephemeral X25519 material where the Stage 2 protocol needs an explicit ephemeral binding.
- HKDF for domain-separated derivation of SAS and protocol-specific confirmation material.
- CryptoKit authenticated encryption only if Stage 2 identifies a need beyond the TLS channel; do not add a second encryption layer by default.

The transcript must be canonical and versioned. At minimum it binds protocol version, pairing session identifier, QR token, both device identity public keys, both ephemeral public keys, the TLS peer-key hash, both nonces, and the negotiated role. Each side signs the transcript with its long-term signing key. A signature without a trusted public-key binding is not sufficient; the QR binding, SAS comparison, or an already trusted peer must establish that binding.

The exact wire encoding, signature envelope, key labels, and algorithm identifiers are Stage 2 implementation requirements. They must be specified before code is written and reviewed with test vectors.

### Why not make the QR code the authentication mechanism?

A QR code can be copied, replaced, photographed, relayed, or displayed by the wrong Mac. It is useful for transferring a short-lived session record and a candidate public-key binding, but it does not prove that the scanned display belongs to the intended Mac. The two-sided SAS comparison and explicit approvals provide the human confirmation needed for the first trust decision.

### Why not use the short code as a password?

A six-digit value has insufficient entropy for a standalone network password and is vulnerable to guessing and relay. In the proposal it is a Short Authentication String derived from the authenticated transcript and used only for human comparison. A future implementation must rate-limit pairing attempts and expire the session.

## QR bootstrap record

The QR payload should contain a versioned, canonical record with:

- Protocol version and algorithm suite identifier.
- Pairing session identifier and random one-time token.
- Expiration timestamp or short validity window.
- Mac display name chosen for user recognition.
- Mac long-term public signing key and/or the exact TLS peer-key binding.
- Optional non-sensitive display metadata needed for the onboarding screen.

It must not contain a private key, Keychain secret, password, provisioning profile, personal identifier, or long-lived bearer credential. The token is single-use, invalidated on completion/cancellation/expiry, and rejected outside its intended pairing session.

## Pairing flow

### QR-first flow

1. The Mac companion enters `Pairing available`, creates a fresh session, and displays the QR record and a recognizable Mac name.
2. The iPhone scans the QR code and shows the Mac name, a short validity notice, and a confirmation that the user is pairing with the Mac currently in front of them.
3. The iPhone discovers the advertised service. Discovery only selects a candidate endpoint; it does not mark the Mac trusted.
4. The iPhone connects using TLS and checks the presented peer key against the QR binding. A mismatch fails closed.
5. The devices exchange signed transcript messages containing fresh nonces and ephemeral keys. Both reject duplicate session IDs, expired tokens, wrong roles, and reused nonces.
6. Both derive and display the same SAS. The Mac and iPhone show the SAS with explicit instructions to compare the values physically.
7. The user approves the matching SAS on the Mac and then on the iPhone. A mismatch must expose `Pairing rejected`, not offer a silent retry with the same session.
8. Only after both approvals do the devices store the peer public key and mark the relationship `Paired`.
9. The devices discard the QR token, ephemeral private keys, and unfinished session state.

### Short-code fallback

If QR scanning is unavailable, the Mac displays a short-lived pairing code and the iPhone starts pairing through an explicit nearby-device action. The code is used to identify the intended session and derive/display the SAS; it is not treated as a high-entropy secret or sole authentication factor. The user must compare the SAS on both screens and approve both sides. Attempts are rate-limited, expire quickly, and are cancelled after repeated mismatch.

If the product cannot provide a trustworthy out-of-band comparison in a particular setup, it must refuse automatic pairing and require the user to retry with the QR or a different physical confirmation path.

## Pairing state machine

| State | Entry condition | Allowed transitions | User approval |
| --- | --- | --- | --- |
| `Unpaired` | No trusted peer exists | `Discovering`, `Pairing initiated` | No |
| `Discovering` | User starts setup or recovery | `Pairing initiated`, `Unpaired`, `Authentication failed` | No |
| `Pairing initiated` | QR/code accepted and session created | `Awaiting user confirmation`, `Authentication failed`, `Expired`, `Unpaired` | No |
| `Awaiting user confirmation` | TLS and signed transcript verified; SAS displayed | `Paired`, `Authentication failed`, `Cancelled`, `Expired` | Yes, both devices |
| `Verifying peer` | Existing peer key or new transcript is being checked | `Paired`, `Authentication failed`, `Revoked` | Existing trust: no; first pairing: yes |
| `Paired` | Both approvals and peer key storage completed | `Reconnecting`, `Revoked`, `Unpaired` | Unpair/replacement only |
| `Reconnecting` | Existing trusted session lost | `Paired`, `Authentication failed`, `Revoked` | No for bounded retry |
| `Authentication failed` | Signature, key, token, SAS, or TLS verification failed | `Pairing initiated`, `Unpaired`, `Expired` | New attempt may require approval |
| `Expired` | Session timeout or token expiry | `Pairing initiated`, `Unpaired` | New attempt |
| `Revoked` | User removed trust or identity changed unexpectedly | `Pairing initiated`, `Unpaired` | New pairing required |
| `Unpaired` | Trust explicitly removed | `Discovering`, `Pairing initiated` | No |

Rules:

- Pairing sessions expire after a short bounded interval and are single-use.
- Cancellation deletes ephemeral state and never creates trust.
- Duplicate scans attach only to the same active session; a completed or expired session is rejected.
- A changed peer key never silently replaces a stored key. The user must unpair and explicitly pair again.
- Reconnection may use existing trust but must establish fresh TLS session keys and reject replayed application requests.
- Lost-device recovery requires explicit unpair/re-pair on the surviving device; no cloud recovery is assumed for the MVP.

## Key lifecycle

### Generation and storage

- Each device generates its own long-term signing key locally during first pairing setup.
- Private keys are stored in the platform Keychain as protected generic key material, with accessibility chosen to support the foreground app and avoid unnecessary background access.
- Secure Enclave use is an optional hardening path that requires validating algorithm availability, exportability, backup behavior, and macOS/iOS parity. It is not assumed for the MVP.
- Public keys, peer metadata, protocol version, and trust status may be stored as non-secret pairing records, integrity-protected by the platform storage boundary where appropriate.

### Binding and sessions

- The Mac and iPhone bind each other's public signing key only after the signed transcript, SAS comparison, and both approvals complete.
- TLS session keys are ephemeral and are not stored as long-term pairing credentials.
- A future application session must authenticate the stored peer key and bind the session to a fresh challenge before accepting a launch or activation request.
- Session sequence numbers or unique request IDs are required for replay detection; a reconnect must not replay an old request automatically.

### Rotation, revocation, and replacement

- Key rotation is explicit and authenticated by the currently trusted peer plus user confirmation. A new key is not accepted merely because it appears during reconnect.
- Unpairing deletes local private trust material and the peer record on the initiating device, and sends a best-effort revocation notification to the peer. The peer must still require explicit re-pairing if the notification is lost.
- Unexpected key change is shown as `Trust changed`; the user must inspect and re-pair rather than accept automatically.
- Device replacement and lost-device recovery use explicit unpair/re-pair. The MVP assumes no cloud backup of private pairing keys.

## Adversarial review

| Scenario | Attacker objective and path | Defense | Residual risk / Stage 2 validation |
| --- | --- | --- | --- |
| Malicious Bonjour advertisement | Present a rogue Mac first | Discovery is untrusted; QR key binding, TLS pinning, signed transcript, and SAS comparison | User can approve the wrong screen; test multiple rogue services and wrong-key rejection |
| Local MITM | Intercept and alter handshake | TLS verification plus transcript signatures and SAS | Endpoint compromise or user-approved mismatch remains possible; test certificate/key substitution |
| Peer impersonation | Claim to be a previously paired peer | Stored public-key verification and explicit key-change failure | Private-key compromise defeats identity; test changed-key recovery |
| Replay | Reuse QR, transcript, hello, or launch request | Expiring single-use token, fresh nonces, session IDs, sequence/request IDs | Storage or implementation bugs; test duplicate and delayed messages |
| Relay | Forward messages between legitimate endpoints and a victim | Physical QR origin check, transcript-bound SAS, both-side approval | Users may approve a relayed session; document relay limits and test delayed relay |
| QR substitution | Make the user scan an attacker's record | Mac name confirmation, physical screen check, TLS key binding, SAS comparison | A compromised display or social engineering is outside endpoint crypto |
| Short-code guessing | Guess a low-entropy code | Code is not the sole secret; expiry, rate limits, SAS comparison, lockout | DoS remains possible; test attempt limits |
| Lost iPhone | Use the device to control the Mac | Keychain/device lock assumptions, explicit unpair, revocation, fresh session auth | Fully compromised unlocked device cannot be protected by pairing alone |
| Unauthorized pairing attempt | Create repeated sessions or exhaust prompts | User approval on both devices, bounded sessions, cancellation and rate limits | Availability impact; test prompt flooding and cleanup |
| Mac reinstall or key loss | Cause unexpected trust change | `Trust changed` state and explicit re-pair | User burden and possible DoS; validate recovery UX |

The review identifies mitigations and detection points; it does not prove cryptographic security. Stage 2 must include negative tests and, before release, an independent security review.

## Stage 2 security requirements

1. Specify canonical encodings, version negotiation, algorithm identifiers, transcript construction, and test vectors before implementation.
2. Use TLS peer verification that fails closed and never accepts arbitrary certificates.
3. Implement one-time, expiring pairing sessions and reject replayed identifiers/nonces/tokens.
4. Require signatures from both long-term device identities and explicit approval on both devices.
5. Display and compare an SAS derived from the complete transcript; define mismatch behavior and rate limits.
6. Store private keys only in Keychain-backed storage; never log or persist private material in application files.
7. Authenticate every post-pairing session and bind application requests to fresh session state and unique request IDs.
8. Define unpair, revoke, key-change, reinstall, lost-device, and failed-recovery behavior before launch/activation code is enabled.
9. Add unit, integration, physical-device, replay, wrong-key, wrong-SAS, timeout, cancellation, and network-interruption tests.
10. Review logs and user-visible errors for secret, identifier, and topology leakage.

## Accepted proposal, alternatives, and open questions

### Proposed for Stage 2 review

- QR-first bootstrap with short-code fallback.
- TLS 1.3 as the transport encryption layer.
- Curve25519/Ed25519 identities through CryptoKit where supported, stored via Keychain.
- Signed canonical transcript, SAS comparison, and two-sided approval before trust storage.
- Explicit unpair/re-pair for key replacement in the one-Mac/one-iPhone MVP.

### Alternatives not selected yet

- Mutual TLS client certificates: strong identity binding but requires validating certificate provisioning, rotation, and Network.framework integration on both platforms.
- A complete Noise protocol pattern: attractive for a self-contained authenticated handshake, but adding a protocol implementation increases review and maintenance cost; it requires a separate decision and test vectors.
- SPAKE2+/PAKE for the short-code path: would provide a password-authenticated exchange, but CryptoKit does not establish a ready-to-use SPAKE2+ API; adding an implementation or dependency requires separate feasibility and supply-chain review.

Open questions:

- Can the chosen Network.framework TLS configuration expose the exact peer-key binding needed consistently on the minimum supported OS versions?
- Which Keychain accessibility and synchronizable settings are appropriate for a local-only pairing key on iPhone and Mac?
- Should the production pairing use signed transcript messages inside TLS, mutual TLS, or a reviewed Noise pattern?
- What user-facing Mac UI can display the SAS and approval prompt without relying on insecure notifications?
- What is the acceptable retry/rate-limit policy for a local-only setup flow?

## References

- [Apple: Network framework](https://developer.apple.com/documentation/network)
- [Apple: Keychain Services](https://developer.apple.com/documentation/security/keychain_services)
- [Apple: CryptoKit](https://developer.apple.com/documentation/cryptokit)
- [Apple: Curve25519](https://developer.apple.com/documentation/cryptokit/curve25519)
- [Apple: Storing CryptoKit keys in the Keychain](https://developer.apple.com/documentation/cryptokit/storing-cryptokit-keys-in-the-keychain)
- [IETF RFC 8446: TLS 1.3](https://datatracker.ietf.org/doc/html/rfc8446)
- [IETF RFC 5869: HKDF](https://datatracker.ietf.org/doc/html/rfc5869)
- [IETF RFC 8032: EdDSA / Ed25519](https://datatracker.ietf.org/doc/html/rfc8032)
- [IETF RFC 7748: Elliptic Curves for Security](https://datatracker.ietf.org/doc/html/rfc7748)
