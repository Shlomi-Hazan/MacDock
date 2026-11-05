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

The executable intentionally does not open a listener or client connection. No certificate, private key, trust anchor, identity, or network endpoint is included. This keeps the experiment fail-closed and prevents a compile probe from being mistaken for a successful TLS exchange.

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

The local runtime extension was built and started with temporary test-only material generated outside the repository. The listener reached `ready`, accepted a TCP connection, and both the client and server connection callbacks remained in `preparing` until the bounded 8-second timeout. No TLS `ready` state was observed, no exporter value was derived, and the run failed closed with `runtime exchange failed: no verified exporter result`.

This is a blocked runtime attempt, not a successful handshake. The exact cause was not established from the available state callbacks. A likely environment dependency requiring maintainer follow-up is authorization to use the imported private key for TLS signing, consistent with the Keychain prompt observed in the earlier transport experiment; this remains a hypothesis until the same command is run in an interactive normal macOS session and the prompt/result is observed.

Consequently:

- Same-session exporter equality: **not demonstrated**.
- Cross-session inequality: **not demonstrated**.
- Different-label and different-context separation: **not demonstrated**.
- Rejected peer-certificate behavior: **not demonstrated by this probe**.
- Missing metadata and cancellation behavior: **not demonstrated**.

No physical-device result is claimed.

## Trust-anchor and verification handling

No test certificate or private key is stored in this repository. The probe does not install a trust anchor, configure a verify callback, accept arbitrary certificates, or disable certificate validation. A future runtime experiment must use temporary generated test identities outside Git and an explicitly scoped, fail-closed trust-anchor policy. If that policy cannot be implemented without weakening TLS verification, the runtime experiment must stop.

## Required runtime experiment

Before Candidate A can proceed to formal specification, a follow-up isolated target must:

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

## Security interpretation

Even if a future runtime test produces equal values, that result would establish only a property of the same TLS session. It would not authenticate a MacDock device by itself, complete QR pairing, prove authorization, or replace identity signatures, SAS, two-sided confirmation, durable trust, revocation, and recovery.

The future design must still address wrong-peer verification, channel substitution, unknown-key-share, role confusion, downgrade, replay, duplicate messages, and relay limitations. Matching TLS-derived values cannot repair an unreviewed identity or transcript construction.

## Conclusion

**Candidate A runtime feasibility is currently inconclusive and requires further fail-closed platform testing.** Public APIs appear to expose the required categories of TLS metadata, including exporter-like secrets and peer material, and the source compiles for the installed macOS and iOS SDKs. The local runtime attempt did not reach TLS `ready`; matching endpoint values, cross-session separation, certificate rejection, and compatibility on macOS 14 and iOS 17 runtimes remain unverified.
