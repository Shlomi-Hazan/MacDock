# Mutual TLS and Peer-Pinning Feasibility Experiment

## Status

This is an isolated feasibility experiment for Issue #52. It is not production pairing, an identity adapter, a trust store, an authorization layer, or a cryptographic approval. ADR 0003 remains Proposed and Issue #52 remains open.

## Question

Can public Network.framework and Security.framework APIs establish a TLS 1.3 connection in which both endpoints present identities, both endpoints require peer authentication, and both endpoints additionally verify an explicitly expected peer certificate fingerprint?

## Experimental architecture

The macOS Swift package contains:

- `MTLSPeerPinningProbe`: a loopback listener and client in one process.
- `MTLSPeerPinningCore`: pure test-only trust-state transitions.
- `generate-test-identities.sh`: local-only RSA test identities with `serverAuth,clientAuth` extensions and `localhost` SAN.

The listener uses `sec_protocol_options_set_local_identity` and requires peer authentication. The client also presents a local identity and requires peer authentication. Both verify callbacks install only the explicitly supplied process-scoped certificate anchor, evaluate `SecTrust`, and compare the leaf SHA-256 fingerprint. No certificate is accepted solely because it is presented by TLS.

Private keys, passwords, PKCS#12 files, and generated certificates must remain under `/private/tmp` or another ignored temporary directory. No production MacDock target is changed.

## Public APIs used

- `NWListener`, `NWConnection`, `NWParameters`, and `NWProtocolTLS.Options`.
- `sec_protocol_options_set_local_identity`.
- `sec_protocol_options_set_peer_authentication_required`.
- `sec_protocol_options_set_verify_block`.
- `sec_protocol_options_set_min_tls_protocol_version` and `sec_protocol_options_set_max_tls_protocol_version`.
- `sec_identity_create` and `SecPKCS12Import` for test-only fixture loading.
- `SecTrustSetAnchorCertificates`, `SecTrustSetAnchorCertificatesOnly`, `SecTrustSetPolicies`, and `SecTrustEvaluateWithError`.
- `SecTrustGetCertificateAtIndex` and `SecCertificateCopyData` for public leaf-certificate pin comparison.

Compilation against the current SDK is not minimum-runtime evidence. macOS 14 and iOS 17 physical runtime validation remain separate gates.

## Results

The results below must be filled only from actual local or maintainer execution. A successful TLS state is not a trust commitment or authorization.

| Scenario | Expected | Observed | Evidence class |
| --- | --- | --- | --- |
| Both identities, matching anchors and pins | Both TLS endpoints ready; both pins accepted | PASS: both endpoints reached `ready`; trust and pins were accepted on both callbacks | Tool-executed local macOS run |
| Wrong server pin | Client fails closed; no authenticated peer | PASS: client reported `trust=true pin=false`; server failed `-9825`; no TLS-ready result | Tool-executed local macOS run |
| Wrong client pin | Server fails closed; no authenticated peer | PASS: server reported `trust=false pin=true`; server failed `-9825`; no TLS-ready result | Tool-executed local macOS run |
| Wrong trust anchor | Trust evaluation fails | PASS: client reported `trust=false pin=false`; server failed `-9825`; no TLS-ready result | Tool-executed local macOS run |
| Missing client identity | Required client authentication fails | Not run by this probe; the CLI requires an identity fixture | Not demonstrated |
| Expired or invalid certificate | Trust evaluation fails | Not run in this initial fixture set | Not demonstrated |
| Replacement with unchanged public key | Certificate-policy result documented separately from key pin | Pending design test | Not yet demonstrated |
| Replacement with changed public key | Pin mismatch and fail closed | Pending design test | Not yet demonstrated |
| Cancellation/interruption/reconnect | Bounded failure; no trust transition | Pure state tests only | Partial |

## Pinning and rotation findings

Certificate pinning and public-key pinning are different policies. Certificate pinning rejects certificate replacement even when the public key is retained. Public-key pinning permits certificate renewal with the same key, but requires explicit rules for key replacement, revocation, and recovery. Neither policy by itself establishes that the QR was displayed by the intended physical Mac.

The experiment therefore treats pin acceptance as a verification result, not as a committed trust record. A future pairing design must bind the expected public identity to the one-time QR session and require explicit confirmation before committing it.

## QR bootstrap assessment

No QR UI is implemented here. A simulated test-only payload may contain a version, one-time session identifier, expiry, nonce, expected Mac certificate/public-key fingerprint, and non-sensitive display metadata. Scanning that payload would not authenticate the iPhone or prove that the user scanned the intended Mac. The future design must define how the Mac learns and verifies the iPhone identity, how both sides confirm the same session, and how a pending record becomes committed.

## Trust state boundary

The pure test state machine covers `Untrusted`, `Pending`, `Committed`, `Revoked`, and `Recovery required`. TLS readiness never transitions to `Committed`. Interrupted pairing, identity change, and revocation fail closed. This is test logic only; no Keychain record or production grant is created.

## Resumption and early data

The probe sends no application command and does not configure 0-RTT. TLS 1.3 early data has weaker replay properties than ordinary 1-RTT data, so future MacDock operations must not be accepted before full handshake, peer validation, and capability authorization. Network.framework controls for resumption and early data require a dedicated API/runtime investigation; no assumption is made here.

## Runtime and signing limitations

This initial experiment targets macOS and is designed to answer the API question with a local Mac-to-Mac control. An iOS target and physical Mac–iPhone run are not claimed unless separately built and executed. Current-SDK compilation, simulator execution, and a newer physical OS do not establish macOS 14/iOS 17 minimum-runtime compatibility. iOS signing, Local Network permission, and certificate fixture distribution remain outstanding.

## Comparison with Candidate A

mTLS can remove the need for Candidate A's custom exporter/ECDH/HKDF/signature/SAS composition if the project accepts certificate/public-key pinning plus a reviewed QR/trust lifecycle. It does not remove first-pairing MITM assumptions, pending/committed storage, rotation, revocation, recovery, authorization, or replay policy.

Noise is not evaluated by this experiment. The official Noise site describes a framework and lists implementations in several languages, but not an Apple-provided Swift implementation. A specific maintained Swift dependency would require a separate source, maintenance, audit, and platform review.

## Environment

The local run used the installed Xcode toolchain and macOS SDK, targeting macOS 14. The exact installed SDK/runtime is evidence for this development Mac only; no macOS 14 minimum-runtime claim is made for other machines, and no iOS 17 runtime result was produced.

## Recommendation

Do not approve or implement pairing from this experiment. If the positive and negative runs below are reproduced, mTLS is a lower-complexity direction than Candidate A and is suitable for a bounded architecture decision study. It remains conditional on Apple minimum-runtime evidence, identity storage validation, QR bootstrap design, trust recovery, and maintainer acceptance.
