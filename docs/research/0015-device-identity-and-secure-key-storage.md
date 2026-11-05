# Device Identity and Secure Key Storage

- Issue: [#41](https://github.com/Shlomi-Hazan/MacDock/issues/41)
- Stage: Stage 2 — Connection & Pairing
- Status: Proposed design; no production identity or persistent key implementation
- Depends on: [#38](https://github.com/Shlomi-Hazan/MacDock/issues/38)
- Related: [ADR 0003](../decisions/0003-qr-first-pairing-and-peer-authentication.md), [ADR 0007](../decisions/0007-stage-0-feasibility-decision.md), [ADR 0008](../decisions/0008-stage-1-conditional-go.md)

## Executive summary

MacDock needs a device-owned long-term identity before it can commit pairing trust. This document defines the boundary and failure behavior without selecting the final pairing construction, TLS identity binding, signing algorithm, transcript format, or authorization protocol.

The recommended direction is a platform-specific identity adapter backed by Keychain, with private material kept outside `MacDockShared`. A Secure Enclave-backed P-256 signing key is a candidate where the device supports it and the eventual reviewed protocol requires it. This is not an accepted cryptographic decision and does not authorize key generation in the application.

No identity is generated as an app-startup side effect. No identity is exposed through Bonjour, the current diagnostic transport, logs, UI, repository files, or CI output.

## Evidence classification

| Finding | Classification | Consequence |
| --- | --- | --- |
| CryptoKit provides P-256, Curve25519, key-agreement, signing, and Keychain conversion APIs | Apple documentation | Candidate primitives require protocol selection and review before use |
| `SecureEnclave.isAvailable` and Secure Enclave P-256 signing APIs exist | Apple documentation | Availability is device-dependent; implementation must handle absence |
| Keychain accessibility can be restricted with `ThisDeviceOnly` classes | Apple documentation | Storage policy can prevent migration to a replacement device |
| `WhenUnlockedThisDeviceOnly` is appropriate for foreground-only secrets when migration is not desired | Apple documentation and product inference | Candidate default; must be confirmed against the final lifecycle |
| macOS Keychain accessibility has Data Protection keychain conditions | Apple documentation | macOS adapter configuration needs a platform-specific validation pass |
| A public key can identify a keypair only after it is bound to a reviewed pairing transcript | Security requirement | Public-key possession alone never creates peer trust |
| Exact signing/key-agreement construction for MacDock | Unresolved | Blocked on ADR 0003 review and independent cryptographic review |

## Identity model

Each installation has a local identity record owned by its platform application. The record is conceptual at this stage:

```text
LocalIdentityRecord
├── schemaVersion
├── localKeyReference        // opaque platform storage reference, never private key bytes
├── publicKeyRepresentation  // exportable only when the reviewed protocol needs it
├── keyAlgorithm             // metadata, not an algorithm decision
├── creationMetadata         // non-sensitive lifecycle metadata only
└── revocationGeneration     // local marker used to prevent silent trust restoration
```

The private key remains in the platform security boundary. Shared models may carry a validated public-key representation only after the protocol has defined its encoding and exposure rules. They must not carry private key bytes, Keychain query dictionaries, access-control objects, or platform key handles.

The following are not trusted identities:

- Bonjour service name, service type, domain, or endpoint.
- IP address, interface, network path, or device name.
- Bundle identifier, hardware identifier, filesystem path, or path-derived digest.
- Successful TCP, TLS, or diagnostic exchange without approved peer binding.

An eventual pairing transcript must bind the peer public key to the exact user-confirmed exchange. The transcript format, signature inputs, freshness, and session-key derivation remain unresolved.

## Candidate Apple platform choices

### CryptoKit in memory

CryptoKit supports common signing, key-agreement, hashing, MAC, and symmetric-encryption operations. `P256.Signing`, `P256.KeyAgreement`, and `Curve25519` are documented candidates, but choosing among them is a protocol decision rather than a storage decision.

Advantages:

- Native Swift API and strong typing.
- Suitable test seams for public-key and signature operations.
- No third-party cryptography dependency.

Limitations:

- An in-memory private key is not persistent protection.
- The protocol must define canonical bytes, signatures, key roles, and freshness.
- A successful CryptoKit operation does not authenticate an intended peer by itself.

### Keychain-backed identity

Keychain Services is the baseline persistence boundary. The adapter should store either a platform-managed key reference or an explicitly reviewed key representation, never an application loggable copy of private material.

For a foreground-first product, `kSecAttrAccessibleWhenUnlockedThisDeviceOnly` is a candidate policy because Apple documents that it is available only while the device is unlocked and is not migrated to a different device during restore. `kSecAttrAccessibleWhenPasscodeSetThisDeviceOnly` is a stricter candidate when requiring a passcode is an accepted product decision. Neither is accepted yet; the final choice depends on the pairing lifecycle and recovery UX.

On macOS, Apple documents additional requirements around `kSecAttrAccessible` and the Data Protection keychain. The macOS adapter must be validated separately rather than assuming iOS Keychain behavior is identical.

### Secure Enclave

Apple documents Secure Enclave P-256 signing and key-agreement APIs, plus `SecureEnclave.isAvailable`. This is a candidate for non-exportable private identity operations where supported.

Secure Enclave is not a universal requirement for MacDock because:

- Availability is device and configuration dependent.
- The final protocol may require an operation or key representation with different constraints.
- Secure Enclave availability does not solve pairing, peer authentication, relay, replay, revocation, or recovery.
- A replacement device cannot silently inherit the old device's trust.

The implementation must either fail closed with a clear recovery path or use a separately reviewed non-Secure-Enclave fallback. It must never silently downgrade security.

## Proposed adapter boundary

No adapter is enabled in the application targets by this Issue. The future boundary should remain platform-specific:

```text
MacDockMac / MacDockiOS
        │
        ▼
PlatformIdentityStore
        │
        ├── Keychain / Secure Enclave APIs
        └── injected test store for deterministic tests

MacDockShared
        └── platform-neutral value types and pure validation only
```

The interface should expose operations such as:

- `loadLocalIdentity()` — return present, missing, unavailable, corrupt, or incompatible.
- `createLocalIdentity()` — explicit, idempotency-controlled operation; never app-startup implicit.
- `replaceLocalIdentity()` — requires an explicit recovery or unpair policy.
- `deleteLocalIdentity()` — destructive trust-boundary operation requiring caller policy.
- `readPublicIdentity()` — returns only reviewed public representation.

The adapter must not expose raw Keychain queries or private key bytes to shared models. The final signing operation may need a narrower capability than returning a private-key object; that decision belongs to the approved protocol implementation.

## Key lifecycle and failure behavior

### Creation

1. A future user-facing setup flow explicitly requests identity creation.
2. The platform adapter generates or imports only a reviewed key type.
3. The public representation is validated before persistence metadata is committed.
4. The record is written atomically or is marked incomplete.
5. No peer is trusted merely because local creation succeeded.

### Retrieval

- Missing item: return `missing`; do not generate a replacement automatically when a peer may already be paired.
- Locked device or access denial: return `temporarilyUnavailable` or `accessDenied`; do not treat it as an empty identity.
- Duplicate records: return `inconsistent`; require deterministic recovery rather than choosing one silently.
- Corrupt or unknown schema: return `incompatible`; preserve evidence needed for recovery without logging secrets.
- Unexpected public-key change: return `identityChanged`; existing peer trust remains invalid until explicit replacement and re-pairing.

### Replacement and revocation

Deleting or replacing local identity invalidates future sessions that depend on the previous key. A new key is not automatically trusted by an old peer. The product must require explicit unpair/recovery and a fresh reviewed pairing flow.

Revocation state must survive ordinary retries and must not be erased by a failed re-creation attempt. A revoked peer record cannot transition directly to committed trust because a new key happens to be present.

### Crash safety

The eventual implementation should use a small record state such as `absent`, `pendingWrite`, `committed`, and `revoked`. A crash during creation or replacement must leave the record either recoverably absent or explicitly incomplete; it must never produce a partially trusted peer.

No distributed transaction protocol is required here. The two-device confirmation invariant from Issue #38 remains a Stage 2 pairing requirement.

## Trust-state separation

The identity store and the future pairing subsystem must distinguish:

1. `localIdentityMissing`
2. `localIdentityAvailable`
3. `candidateDiscovered`
4. `peerPublicIdentityObserved`
5. `pairingPending`
6. `pairingCommitted`
7. `peerTrustRevoked`
8. `recoveryRequired`
9. `authorizedSession`

Only the reviewed pairing protocol may move from observed public identity to pending trust. Only successful two-sided confirmation and all approved cryptographic checks may commit trust. Only a separate authorization gate may create an authorized session. Issue #41 implements none of these transitions.

## Privacy and exposure policy

- Never expose private key bytes, Keychain references, access-control objects, or raw keychain errors in logs, frames, UI, Issues, or CI.
- Do not derive an identity from hardware serials, MAC addresses, filesystem paths, or personal names.
- A public key is still a stable identifier and must not be broadcast before the pairing design defines its exposure and correlation policy.
- Bonjour and the current diagnostic transport expose no identity material.
- Public identity comparison must use canonical protocol-defined bytes, not display strings or fingerprints chosen ad hoc.

## Test matrix

The future adapter implementation must use an injected in-memory store for deterministic tests and generated test material only:

| Scenario | Expected behavior |
| --- | --- |
| Missing identity | Explicit missing result; no silent generation |
| First creation | One committed local record; no peer trust |
| Duplicate creation | Existing record preserved or explicit conflict; never overwrite silently |
| Storage failure | Fail closed; no partial trust |
| Access denied / locked device | Report unavailable or denied; no replacement |
| Corrupt record | Report incompatible; preserve recovery path |
| Interrupted write | Pending/incomplete record cannot be trusted |
| Delete | Identity absent/revoked according to explicit policy |
| Replacement | New identity requires fresh pairing; old trust is not restored |
| Unexpected key change | Recovery required; no automatic re-trust |
| Revoked peer | Cannot return to committed trust without explicit re-pairing |
| Duplicate initialization | Deterministic single-writer behavior |
| Private-material inspection | No private bytes in shared models, logs, or diagnostics |

Real Keychain and Secure Enclave tests require isolated test accounts/identifiers, cleanup, and physical-device coverage. They are not claimed as executed by this design document.

## Manual validation plan

When a reviewed adapter exists, the maintainer should validate separately on macOS and iPhone:

1. Create identity explicitly and verify only a non-sensitive status is shown.
2. Relaunch and verify the same local identity is retrieved without displaying private material.
3. Lock the device and observe the documented accessibility behavior.
4. Delete/unpair and verify the identity is not silently recreated as trusted.
5. Simulate or induce a missing/corrupt record using an isolated test fixture, not personal Keychain entries.
6. Replace the identity and verify the old peer is not automatically trusted.
7. Remove or change the passcode only in a controlled test environment if the selected accessibility class requires it.

No physical Keychain behavior is claimed as verified in Issue #41 yet.

## Decisions and blockers

Accepted independently of the final pairing construction:

- Private identity material belongs in a platform-specific secure-storage boundary.
- `MacDockShared` must not import Keychain, Secure Enclave, AppKit, UIKit, or platform identity APIs.
- Missing, changed, revoked, corrupt, or inaccessible identity fails closed for future trusted sessions.
- Replacement identity is never silently trusted.
- No identity is generated implicitly at application startup.

Still blocked and left Proposed:

- Exact signing versus key-agreement roles.
- Exact CryptoKit/Secure Enclave key type and fallback policy.
- Canonical public-key encoding and transcript binding.
- TLS certificate/public-key binding.
- QR contents, SAS semantics, freshness, replay protection, and relay analysis.
- Two-sided pairing commit protocol.
- Authorization and session-key derivation.

ADR 0003 remains Proposed. This document does not accept a cryptographic construction and does not authorize pairing, trusted sessions, or application control.

## References

- [Apple CryptoKit](https://developer.apple.com/documentation/cryptokit)
- [SecureEnclave](https://developer.apple.com/documentation/cryptokit/secureenclave)
- [SecureEnclave.P256.Signing.PrivateKey](https://developer.apple.com/documentation/cryptokit/secureenclave/p256/signing/privatekey)
- [Keychain Services](https://developer.apple.com/documentation/security/keychain-services)
- [Item attribute keys and values](https://developer.apple.com/documentation/security/item-attribute-keys-and-values)
- [Restricting Keychain item accessibility](https://developer.apple.com/documentation/security/restricting-keychain-item-accessibility)
- [kSecAttrAccessibleWhenUnlockedThisDeviceOnly](https://developer.apple.com/documentation/security/ksecattraccessiblewhenunlockedthisdeviceonly)
- [Issue #38 security requirements](https://github.com/Shlomi-Hazan/MacDock/issues/38)
- [Stage 0 TLS experiment](../../experiments/transport-tls/EXPERIMENT_REPORT.md)
