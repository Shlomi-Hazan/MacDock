# TLS Channel-Binding Feasibility Experiment

- Issue: [#52](https://github.com/Shlomi-Hazan/MacDock/issues/52)
- Status: API compilation probe; no production pairing or trusted-session implementation
- Scope: Determine whether public Apple APIs expose connection-specific TLS-derived material suitable for a future authenticated transcript.

## Research question

Can MacDock obtain a value derived from the exact Network.framework TLS session on both macOS and iOS, while preserving normal fail-closed TLS verification, so that a future reviewed application transcript can bind itself to that session?

This experiment does not select a pairing construction, authenticate a device, create a trust record, or authorize application control.

## Environment

The tool environment reported:

- Xcode 26.3 (build 17C529)
- Swift 6.2.4
- macOS SDK 26.2
- iOS SDK 26.2
- Project provisional deployment targets: macOS 14 and iOS 17

The installed SDK is newer than the project's minimum runtime targets. Compilation against the installed SDK is not runtime validation on macOS 14 or iOS 17.

## Public APIs examined

The probe references only public APIs:

- `NWProtocolTLS.Metadata.securityProtocolMetadata`
- `sec_protocol_metadata_create_secret_with_context`
- `sec_protocol_metadata_create_secret`
- `sec_protocol_metadata_copy_peer_public_key`
- `sec_protocol_metadata_access_peer_certificate_chain`
- `sec_protocol_options_set_peer_authentication_required`
- `sec_protocol_options_set_verify_block`
- `sec_trust_copy_ref`
- `SecTrustSetAnchorCertificates`
- `SecTrustSetAnchorCertificatesOnly`
- `SecTrustEvaluateWithError`

Apple documents `create_secret` and `create_secret_with_context` as deriving an exported secret from TLS protocol metadata using a label, context, and requested length. Apple also documents peer public-key and certificate-chain access through the same metadata surface. These APIs are exporter-like and promising for a channel-binding design, but MacDock has not yet validated their semantics across physical endpoints or OS versions.

References:

- [NWProtocolTLS.Metadata](https://developer.apple.com/documentation/network/nwprotocoltls/metadata)
- [Security Options](https://developer.apple.com/documentation/network/security-options)
- [sec_protocol_metadata_create_secret](https://developer.apple.com/documentation/security/sec_protocol_metadata_create_secret(_:_:_:_:))
- [sec_protocol_metadata_create_secret_with_context](https://developer.apple.com/documentation/Security/sec_protocol_metadata_create_secret_with_context(_:_:_:_:_:_:))
- [RFC 8446 — TLS 1.3](https://www.rfc-editor.org/rfc/rfc8446.html)

## Isolated implementation

`Package.swift` declares macOS 14 and iOS 17 platform compatibility. `TLSChannelBindingProbe` contains a small compile harness that:

1. Reads TLS metadata from the exact `NWProtocolTLS.Metadata` instance passed to it.
2. Uses a fixed experimental label, context, and 32-byte output length.
3. Calls the public exporter-like API without printing or persisting the derived bytes.
4. References peer public-key and certificate-chain access.
5. Requires peer authentication in the constructed TLS options.

The probe is annotated and reviewed as a macOS 14/iOS 17-compatible source boundary. It does not claim that every referenced symbol has identical runtime behavior across those OS versions.

The `create_secret_with_context` result is an owned `dispatch_data_t` returned by a Create-rule API. The probe keeps it in memory, converts it only to an in-memory `Data` value for equality comparison, and never prints or persists the bytes. `sec_trust_copy_ref` returns a retained `SecTrustRef`; the probe consumes it with `takeRetainedValue()` and evaluates the explicitly scoped trust object.

Compile-only mode intentionally opens no listener or client connection. Runtime mode accepts only explicit temporary test files supplied by the operator; it does not include certificates, private keys, trust anchors, identities, or endpoints in the repository. This keeps the repository fail-closed and prevents a compile probe from being mistaken for a successful TLS exchange.

## Commands

From this directory:

```sh
swift build
swift run TLSChannelBindingProbe

# Typecheck the same source against the installed iOS Simulator SDK.
xcrun swiftc -typecheck -parse-as-library \
  -sdk "$(xcrun --sdk iphonesimulator --show-sdk-path)" \
  -target arm64-apple-ios17.0-simulator \
  -module-cache-path /private/tmp/macdock-tls-module-cache \
  Sources/TLSChannelBindingProbe/main.swift
```

The expected output states that the API probe compiled and that no network connection was opened.

An iOS app target is not included in this iteration. Running the same code on iOS requires a signed, isolated target and physical-device validation; a macOS SwiftPM build cannot establish iOS runtime behavior.

## Results

### Compilation

The public API signatures were compiled in the isolated macOS SwiftPM target using the installed Xcode toolchain. The executable also ran and reported that no network connection was opened. The same source passed direct `swiftc -typecheck` against the installed iOS Simulator SDK for an arm64 iOS 17 simulator target.

An attempted `swift build --triple arm64-apple-ios17.0` was rejected because this SwiftPM invocation selected the macOS sysroot while targeting iPhone. That is a build-command limitation, not evidence that the APIs are unavailable on iOS. The direct iOS SDK typecheck is the relevant compile result from this experiment.

### Runtime

The first local runtime attempt used a temporary self-signed certificate with SAN entries but without explicit `keyUsage` and `extendedKeyUsage=serverAuth` extensions. The listener reached `ready` and accepted TCP, but both TLS connections remained `preparing` until the bounded 8-second timeout. The verification callback was not invoked and no exporter value was derived.

This is a blocked runtime attempt, not a successful handshake. The diagnostic build reports listener readiness, accepted TCP connections, client/server state transitions, waiting/failure errors, whether the TLS verification callback ran, scoped trust-evaluation result codes, private-key lookup status, and the timeout phase. It never reports private-key material, passwords, certificate paths, trust objects, or exporter bytes.

Observed diagnostic output included:

```text
identity private-key lookup status: 0
identity private-key signing capability: available
listener state: ready
client connection state: preparing
listener accepted connection
server connection state: preparing
runtime timeout phase: TLS ready/exporter completion; verification callback invoked=no
runtime exchange failed: no verified exporter result
```

This evidence rejects a simple “PKCS#12 import returned no private key” explanation and shows that the client trust callback was not reached. The interactive reproduction means the result was not caused by the Codex sandbox or a missing Keychain prompt. The earlier Keychain authorization hypothesis is not supported by this evidence.

The temporary certificate fixture was checked outside the repository: its certificate and private-key public moduli matched, it contained `localhost` and `127.0.0.1` subject-alternative names, it was within its validity period during the run, and OpenSSL reported it usable for SSL server purpose. The missing explicit server-authentication extensions were the material difference in the corrected fixture.

The corrected temporary certificate explicitly contains:

- `subjectAltName=DNS:localhost,IP:127.0.0.1`
- `keyUsage=digitalSignature,keyEncipherment`
- `extendedKeyUsage=serverAuth`

With that fixture, the same runtime code completed the local TLS 1.3 exchange and invoked the scoped trust callback successfully. This verifies that the original fixture was unsuitable for this Network.framework server test; it does not isolate whether `keyUsage`, `extendedKeyUsage`, or their combination was required.

The corrected fixture produced:

```text
TLS verification callback: invoked
TLS verification result: success; anchorStatus=0; anchorOnlyStatus=0; policyStatus=0
client connection state: ready
server connection state: ready
TLS 1.3 local handshake: succeeded
same-session exporter equality: equal
different-session exporter inequality: different
different-label isolation: different
different-context isolation: different
peer identity: certificate verified against explicit process-scoped DER anchor
authorization: not established
```

For the corrected local Mac-to-Mac run:

- Same-session exporter equality: **demonstrated**.
- Cross-session inequality: **demonstrated**.
- Different-label and different-context separation: **demonstrated**.
- Rejected peer-certificate behavior: **not demonstrated by this probe**.
- Missing metadata and cancellation behavior: **not demonstrated**.

No physical-device result is claimed.

## Trust-anchor and verification handling

No test certificate or private key is stored in this repository. Runtime mode does not install a trust anchor; it accepts a temporary DER anchor supplied by the operator and configures a process-scoped verify callback with `SecTrustSetAnchorCertificatesOnly`. It never accepts arbitrary certificates or disables certificate validation. If the scoped policy cannot be evaluated successfully, the runtime experiment stops without producing exporter results.

## Required runtime experiment

Before Candidate A can proceed to formal specification, a follow-up isolated target must still:

1. Generate temporary test-only identities outside the repository.
2. Configure normal TLS verification against an explicitly scoped test trust anchor.
3. Retrieve metadata from the exact active connection on macOS and iOS.
4. Derive the same label/context/length on both endpoints and compare only equality.
5. Verify that separate sessions, labels, contexts, reconnects, wrong peers, missing metadata, cancellation, and rejected certificates fail or differ as expected.
6. Record whether the APIs behave consistently on the minimum supported OS versions.

The test must not use real MacDock identity material, persist trust, or expose a command endpoint.

The current local runtime command is:

```sh
swift run TLSChannelBindingProbe --runtime \
  --p12 /private/tmp/<temporary-directory>/server.p12 \
  --password-file /private/tmp/<temporary-directory>/password.txt \
  --ca-cert /private/tmp/<temporary-directory>/server.der
```

The temporary PKCS#12 identity and DER trust anchor must be generated outside Git, used only for the process, and removed after testing. If macOS presents a Keychain authorization prompt for the imported private key, the maintainer must authorize only this temporary experiment and record the observed result. No system-wide trust anchor or unrelated Keychain item should be changed.

The runtime currently performs server-certificate verification only: the client verifies the temporary server certificate against the supplied process-scoped DER anchor, while the server does not request client authentication. This is intentional for the feasibility probe and is not mutual device authentication.

## Negative trust results

The corrected local harness was exercised with temporary material outside the repository:

| Case | Observed result | Interpretation |
| --- | --- | --- |
| Correct server certificate and matching scoped anchor | TLS ready; trust succeeded; exporter comparisons passed | Positive transport/binding evidence only |
| Unrelated trust anchor | No TLS ready; no exporter result; bounded timeout | No success is reported; the run fails closed before comparison |
| Server certificate for `wronghost` while the client requires `localhost` | Verify callback ran and failed; client reported `-9808` and server `-9825`; no exporter result | Hostname/certificate identity rejection |
| Expired certificate | Not executed in this local run | Must be tested before treating the negative matrix as complete |

The negative cases distinguish handshake rejection from an application-level exporter mismatch. A failed handshake never reaches exporter comparison and cannot produce a successful diagnostic result. Timeout and cancellation remain bounded by the runtime harness. A new local exchange creates fresh Network.framework connections and the observed cross-session value differed; no exporter bytes are retained after the exchange.

## Isolated iOS target

The directly runnable iOS experiment is located at [`iOS/TLSChannelBindingClient.xcodeproj`](iOS/TLSChannelBindingClient.xcodeproj). It is independent of `MacDockiOS` and contains only a SwiftUI form with:

- Host/IP, port, and TLS server-name fields.
- A public test-certificate PEM field; no private key or password is accepted.
- Start and Cancel actions.
- A bounded 10-second timeout.
- TLS 1.3 verification against the supplied process-scoped certificate anchor.
- In-memory exporter derivation and comparison against the Mac response.
- No background modes, persistence, pairing, trust records, or control commands.

The target builds for the iOS Simulator and generic iOS device with signing disabled. A physical-device run still requires normal local signing and a public certificate matching the temporary Mac listener identity. The application does not embed a production or reusable trust root; the maintainer pastes only the public temporary certificate for the current experiment.

The Mac probe also provides a limited `--listen` mode. It accepts the fixed `MDCB` diagnostic request and returns only the in-memory exporter value over the already verified TLS channel, then closes the connection. It is not a general transport or command endpoint.

Example Mac listener command:

```sh
swift run TLSChannelBindingProbe --runtime --listen \
  --p12 /private/tmp/<temporary-directory>/server.p12 \
  --password-file /private/tmp/<temporary-directory>/password.txt \
  --ca-cert /private/tmp/<temporary-directory>/server.der \
  --port 4433 --duration 120
```

For a physical iPhone, use the Mac's local hostname or address in the app, set the TLS server name to the certificate SAN, paste the public certificate PEM, and grant Local Network permission if iOS requests it. No physical iPhone result is claimed by this report.

## Security interpretation

Even if a future runtime test produces equal values, that result would establish only a property of the same TLS session. It would not authenticate a MacDock device by itself, complete QR pairing, prove authorization, or replace identity signatures, SAS, two-sided confirmation, durable trust, revocation, and recovery.

The future design must still address wrong-peer verification, channel substitution, unknown-key-share, role confusion, downgrade, replay, duplicate messages, and relay limitations. Matching TLS-derived values cannot repair an unreviewed identity or transcript construction.

## Conclusion

**Candidate A local runtime feasibility is supported by executed Mac-to-Mac evidence, but cross-platform and security-design validation remain outstanding.** The corrected isolated fixture completed TLS 1.3, passed explicit scoped certificate verification, and produced matching same-session exporter values with different values across sessions, labels, and contexts. This does not establish device identity, pairing, authorization, mutual authentication, physical iPhone compatibility, macOS 14/iOS 17 runtime compatibility, or independent cryptographic approval.
