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

The isolated iOS app target is included under `iOS/` and requires normal local signing for a device run. A macOS SwiftPM build cannot establish iOS runtime behavior.

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

### Maintainer-reported physical Mac–iPhone result

The maintainer completed the first successful physical cross-platform run using an iPhone 14 Pro Max and the Mac host `Shlomis-MacBook-Pro-2.local`. The test used TLS 1.3, a temporary test certificate with a matching DNS SAN, process-scoped certificate verification, and no system-wide trust anchor. The iPhone displayed:

```text
Diagnostic exchange complete (unverified)
```

The Mac listener reported:

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

This is maintainer-reported physical-device evidence, not a tool-executed test result. It demonstrates that the isolated iOS client and Mac listener completed the experimental TLS exchange and compared matching exporter-derived values for that TLS session. It does not establish device authentication, mutual authentication, QR pairing, durable trust, authorization, or production identity.

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
| Expired server leaf, trusted CA only | Maintainer physical iPhone callback `-67818`; final UI reported certificate rejection; Mac reported `-9825`; no TLS ready or exporter result | Explicit fail-closed expiration rejection |

The negative cases distinguish handshake rejection from an application-level exporter mismatch. A failed handshake never reaches exporter comparison and cannot produce a successful diagnostic result. Timeout and cancellation remain bounded by the runtime harness. A new local exchange creates fresh Network.framework connections and the observed cross-session value differed; no exporter bytes are retained after the exchange.

### Physical validation matrix

The following results are maintainer-reported physical-device observations from an iPhone 14 Pro Max and the Mac listener. They are not independently executed CI evidence:

| Test | Result |
| --- | --- |
| Positive Mac–iPhone TLS and exporter comparison | PASS; iPhone reported `Diagnostic exchange complete (unverified)` |
| Wrong trust anchor | PASS; iOS verification error `-67843`; Mac error `-9825` |
| Wrong hostname | PASS; iOS verification error `-67602`; Mac error `-9825` |
| Expired server leaf signed by a valid temporary CA | PASS; iOS verification error `-67818`; Mac error `-9825` |
| Certificate-rejection UI reporting | PASS; final status `Failed: certificate verification rejected`, Start enabled, Cancel disabled |

All three negative trust cases reached explicit iOS verification failure and produced no TLS-ready or exporter-success state. This is evidence of certificate validation behavior, not device authentication, pairing, authorization, or cryptographic construction approval.

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

The diagnostic response currently transmits the exporter-derived bytes so the isolated client can compare them. This is intentionally experiment-only: the bytes are not displayed or persisted, but the response shape is not an acceptable production protocol because exporter material must remain an internal channel-binding input rather than an application payload. A future production design must replace this comparison exchange with a reviewed transcript-binding mechanism.

Example Mac listener command:

```sh
swift run TLSChannelBindingProbe --runtime --listen \
  --p12 /private/tmp/<temporary-directory>/server.p12 \
  --password-file /private/tmp/<temporary-directory>/password.txt \
  --ca-cert /private/tmp/<temporary-directory>/server.der \
  --port 4433 --duration 120
```

For a physical iPhone, use the Mac's local hostname or address in the app, set the TLS server name to the certificate SAN, paste the public certificate PEM, and grant Local Network permission if iOS requests it. The first successful physical result is recorded above; the remaining negative and compatibility cases are still outstanding.

### Maintainer-reported single-attempt physical failure

The maintainer performed one clean physical Mac-to-iPhone attempt on an iPhone 14 Pro Max running iOS 27.0.1. Bonjour discovery succeeded and the iOS app installed and launched, but the final UI state was `Cancelled`. The Mac listener reported that it was ready, accepted the TCP connection, and then observed the server connection fail with POSIX error 61 before TLS reached `ready`. No cross-device exporter comparison was observed. This does not establish the root cause; POSIX error 61 alone is not sufficient to classify the failure as certificate, trust, or transport configuration failure.

The iOS client now keeps one attempt generation, rejects concurrent starts, preserves the first terminal failure or timeout, cancels its timeout task after terminal completion, ignores stale callbacks, logs non-sensitive connection and verification diagnostics, and checks all `SecTrust` configuration status values before completing verification. The Mac listener retains each accepted connection in a per-connection session, prevents duplicate receive setup, applies a bounded idle timeout, and performs deterministic cleanup. These changes improve diagnosis and lifecycle correctness but do not claim a successful physical TLS handshake.

### Follow-up physical handshake stall

After the Start/Cancel controls were separated, the maintainer repeated one clean attempt. The iPhone logged `starting transport attempt`, `connection state: preparing`, and `transport timeout`; no TLS verification callback, TLS-ready state, or exporter comparison was observed. The Mac listener logged `listener state: ready`, `listener accepted connection`, `server connection state: preparing`, followed by POSIX error 60 (`Operation timed out`). The earlier automatic-cancellation symptom was not reproduced. The post-timeout Network.framework metadata warning was recorded as a consequence of the unconnected state, not as a root-cause classification.

The supplied temporary certificate was inspected and contained an IP SAN for `192.168.1.200`, `serverAuth`, and digital-signature/key-encipherment usage. This rules out a missing IP SAN as an explanation, but does not establish that an IP literal supplied as both `NWEndpoint.Host` and TLS server name behaves as required on iOS. Remaining hypotheses include IP-literal SNI/policy behavior, iOS-specific TLS negotiation or trust handling, and an interface-specific listener path. The next discriminating test is a fresh temporary certificate with a DNS SAN matching the Mac's mDNS hostname (for example, `MacName.local`), with that same hostname used for both the iOS host and TLS server name; verification must remain scoped to the supplied certificate and must not be disabled.

### Maintainer-reported physical negative trust validation

The maintainer then ran two isolated negative tests on the same physical iPhone 14 Pro Max and Mac listener, using TLS 1.3 and process-scoped certificate verification.

**Wrong trust anchor:** the Mac presented the valid temporary server certificate while the iPhone trusted an unrelated temporary public certificate. The iPhone reported:

```text
TLS verification callback invoked
TLS verification failed: domain=NSOSStatusErrorDomain code=-67843
CERTIFICATE_VERIFY_FAILED
fatal, description: certificate unknown
```

The Mac reported:

```text
server connection state: failed(-9825: misc. bad certificate)
```

No TLS-ready state or exporter exchange occurred. This is explicit fail-closed trust-anchor rejection.

**Wrong hostname:** the Mac presented a certificate containing `DNS:Shlomis-MacBook-Pro-2.local`; the iPhone used the correct public trust anchor but required `wronghost.local`. The iPhone reported:

```text
TLS verification callback invoked
TLS verification failed: domain=NSOSStatusErrorDomain code=-67602
CERTIFICATE_VERIFY_FAILED
fatal, description: certificate unknown
```

The Mac again reported:

```text
server connection state: failed(-9825: misc. bad certificate)
```

No TLS-ready state or exporter exchange occurred. This is explicit fail-closed hostname-mismatch rejection.

These are maintainer-reported physical-device observations, not independently executed CI results. They distinguish certificate rejection from an inconclusive timeout because the iPhone verification callback ran and reported explicit Security.framework errors.

The iOS UI previously reduced some verification failures to the generic `Timeout: no verified exchange` state when Network.framework did not emit a failure before the bounded timeout. The isolated client now records an explicit rejection flag for the active attempt when the verification callback fails or trust configuration cannot be applied, and reports `Failed: certificate verification rejected` at the terminal failure/timeout boundary. It does not infer certificate failure when the callback did not report one, and the flag is cleared between attempts. This is diagnostic reporting only and does not alter trust evaluation.

The maintainer repeated the wrong-trust-anchor test with this updated UI. The iPhone first displayed `Waiting: -9808: bad certificate format`, then transitioned to the terminal status `Failed: certificate verification rejected`; Start became enabled again and Cancel became disabled. This is maintainer-reported physical evidence that the explicit rejection survives to the final UI state instead of being replaced by a generic timeout. The intermediate `-9808` status is not treated as the certificate error classification; the verification callback and final rejection state are the relevant evidence.

### Expired-certificate physical validation and reproducible procedure

The expired-certificate test used an expired server leaf signed by a separate, currently valid temporary CA. This avoids the ambiguity that can arise when the expired self-signed certificate is itself supplied as a trust anchor. The iPhone trusted only the public CA certificate; normal chain, hostname, and validity evaluation remained enabled.

The maintainer executed the procedure on a physical iPhone 14 Pro Max. The iPhone verification callback reported `NSOSStatusErrorDomain` code `-67818`, the final UI reported `Failed: certificate verification rejected`, and the Mac reported `server connection state: failed(-9825: misc. bad certificate)`. No TLS-ready state or exporter exchange occurred. This is maintainer-reported physical evidence of explicit expiration rejection.

The following procedure creates all temporary material under `/private/tmp` and does not change either device clock or install a system trust root. The dates are deliberately historical and must remain in the past during execution:

```sh
set -eu
TLS_EXPIRED_DIR="$(mktemp -d /private/tmp/macdock-tls-expired.XXXXXX)"
chmod 700 "$TLS_EXPIRED_DIR"
mkdir "$TLS_EXPIRED_DIR/newcerts"
: > "$TLS_EXPIRED_DIR/index.txt"
printf '1000\n' > "$TLS_EXPIRED_DIR/serial"
openssl rand -hex 24 > "$TLS_EXPIRED_DIR/password.txt"

cat > "$TLS_EXPIRED_DIR/ca.cnf" <<EOF
[ca]
default_ca = CA_default
[CA_default]
dir = $TLS_EXPIRED_DIR
database = $TLS_EXPIRED_DIR/index.txt
new_certs_dir = $TLS_EXPIRED_DIR/newcerts
serial = $TLS_EXPIRED_DIR/serial
private_key = $TLS_EXPIRED_DIR/ca.key
certificate = $TLS_EXPIRED_DIR/ca.pem
default_md = sha256
policy = policy_any
x509_extensions = v3_ca
[policy_any]
commonName = supplied
[req]
prompt = no
distinguished_name = req_dn
x509_extensions = v3_ca
[req_dn]
CN = MacDock Expired Test CA
[v3_ca]
basicConstraints = critical,CA:true,pathlen:0
keyUsage = critical,keyCertSign,cRLSign
subjectKeyIdentifier = hash
[server_ext]
basicConstraints = critical,CA:false
keyUsage = critical,digitalSignature,keyEncipherment
extendedKeyUsage = serverAuth
subjectAltName = DNS:Shlomis-MacBook-Pro-2.local
subjectKeyIdentifier = hash
authorityKeyIdentifier = keyid,issuer
EOF

openssl req -x509 -newkey rsa:2048 -nodes \
  -keyout "$TLS_EXPIRED_DIR/ca.key" \
  -out "$TLS_EXPIRED_DIR/ca.pem" \
  -days 365 \
  -config "$TLS_EXPIRED_DIR/ca.cnf"

cat > "$TLS_EXPIRED_DIR/server.cnf" <<EOF
[req]
prompt = no
distinguished_name = req_dn
[req_dn]
CN = Shlomis-MacBook-Pro-2.local
EOF

openssl req -newkey rsa:2048 -nodes \
  -keyout "$TLS_EXPIRED_DIR/server.key" \
  -out "$TLS_EXPIRED_DIR/server.csr" \
  -config "$TLS_EXPIRED_DIR/server.cnf"

openssl ca -batch \
  -config "$TLS_EXPIRED_DIR/ca.cnf" \
  -in "$TLS_EXPIRED_DIR/server.csr" \
  -out "$TLS_EXPIRED_DIR/server.pem" \
  -extfile "$TLS_EXPIRED_DIR/ca.cnf" \
  -extensions server_ext \
  -startdate 251101000000Z \
  -enddate 251102000000Z

openssl x509 -in "$TLS_EXPIRED_DIR/ca.pem" -outform der -out "$TLS_EXPIRED_DIR/ca.der"
openssl pkcs12 -export \
  -out "$TLS_EXPIRED_DIR/server.p12" \
  -inkey "$TLS_EXPIRED_DIR/server.key" \
  -in "$TLS_EXPIRED_DIR/server.pem" \
  -certfile "$TLS_EXPIRED_DIR/ca.pem" \
  -passout file:"$TLS_EXPIRED_DIR/password.txt"
```

Before starting the listener, validate the generated material:

```sh
openssl x509 -in "$TLS_EXPIRED_DIR/server.pem" -noout -dates -subject -issuer
openssl x509 -in "$TLS_EXPIRED_DIR/server.pem" -text -noout | \
  rg -n "Subject Alternative Name|Extended Key Usage|Key Usage|Shlomis-MacBook-Pro-2.local|TLS Web Server Authentication|Digital Signature|Key Encipherment"
openssl verify -verbose -purpose sslserver -CAfile "$TLS_EXPIRED_DIR/ca.pem" \
  "$TLS_EXPIRED_DIR/server.pem" || true
openssl x509 -in "$TLS_EXPIRED_DIR/server.pem" -pubkey -noout > "$TLS_EXPIRED_DIR/server.pub"
openssl pkey -in "$TLS_EXPIRED_DIR/server.key" -pubout > "$TLS_EXPIRED_DIR/key.pub"
cmp "$TLS_EXPIRED_DIR/server.pub" "$TLS_EXPIRED_DIR/key.pub"
```

The expected certificate inspection must show `notAfter=Nov 2 00:00:00 2025 GMT` (or the equivalent local rendering), the required DNS SAN, `serverAuth`, and digital-signature/key-encipherment usage. On the installed macOS LibreSSL, `openssl verify` does not provide a hostname option; `-purpose sslserver` checks the server-auth purpose and the explicit SAN inspection verifies the intended name. The command is expected to report `certificate has expired`; an error is expected for this negative fixture. The iPhone performs the actual hostname and validity evaluation during the physical test. The public-key comparison must succeed. Do not paste `server.key`, `ca.key`, `server.p12`, or `password.txt` into chat or logs.

Start the isolated Mac listener with the expired server identity and the valid CA DER anchor:

```sh
swift run TLSChannelBindingProbe --runtime --listen \
  --p12 "$TLS_EXPIRED_DIR/server.p12" \
  --password-file "$TLS_EXPIRED_DIR/password.txt" \
  --ca-cert "$TLS_EXPIRED_DIR/ca.der" \
  --port 4433 --duration 120
```

Copy only the public CA certificate to the iPhone, for example with `pbcopy < "$TLS_EXPIRED_DIR/ca.pem"`. Configure the iOS experiment with host `Shlomis-MacBook-Pro-2.local`, port `4433`, TLS server name `Shlomis-MacBook-Pro-2.local`, and the CA PEM. Tap Start exactly once. The expected result is an explicit certificate-validity failure, no TLS-ready state, no exporter response, and no diagnostic completion. A timeout without a verification callback or explicit validity error is inconclusive.

After the run, stop the listener and remove the entire temporary directory with `rm -rf -- "$TLS_EXPIRED_DIR"`. This path is a narrow generated fixture directory under `/private/tmp`; it contains only temporary experiment material and must never be committed.

### Physical connection-lifecycle test preparation and evidence

The following procedures test transport lifecycle only; they do not test pairing or trusted-session resumption. Test D has the maintainer-reported evidence below; Tests E/F remain outstanding.

#### Test D — Explicit cancellation

The maintainer reported two physical cancellation scenarios using the valid temporary server certificate. These are maintainer-reported observations, not automated test results.

**D.1 — Cancellation during TLS preparing: PASS for the observed scenario.** The iPhone logged `starting transport attempt`, `connection state: preparing`, and `user cancelled transport attempt`. The Mac logged `server connection state: preparing`, then `failed(POSIXErrorCode(rawValue: 54): Connection reset by peer)`, `server connection failed before diagnostic completion: POSIXErrorCode(rawValue: 54): Connection reset by peer`, and `server connection state: cancelled`. No diagnostic exchange completed. This demonstrates an observed peer reset and deterministic iPhone cancellation state for this timing window; it does not prove every cancellation race is identical.

**D.2 — Cancellation after TLS ready: PASS for iPhone terminal-state and late-success suppression; Mac cancellation propagation remains unproven.** With `--diagnostic-delay 8`, the Mac reached TLS ready, started the diagnostic delay, and later logged `server exporter response send completed locally; remote receipt unverified` and `server diagnostic response send completed locally; remote receipt unverified`. The maintainer confirmed that the iPhone was cancelled during the delay, remained in terminal status `Cancelled`, and showed no late success. A local send completion does not prove remote receipt, and no transport termination was observed in the supplied log. Full cancellation propagation and cleanup in every race remain unproven.

The original harness sent the diagnostic response immediately after receiving `MDCB`, so physical cancellation before completion depended on timing. It now supports an experiment-only, opt-in server delay before sending that response. The delay is disabled by default, is bounded to 30 seconds, does not affect TLS negotiation, verification, or exporter derivation, and is cancelled with the per-connection session.

Start the valid listener in a normal interactive Terminal:

```sh
swift run TLSChannelBindingProbe --runtime --listen \
  --p12 /private/tmp/<valid-fixture>/server.p12 \
  --password-file /private/tmp/<valid-fixture>/password.txt \
  --ca-cert /private/tmp/<valid-fixture>/server.der \
  --port 4433 --duration 120 --diagnostic-delay 8
```

On the iPhone, configure the valid host, port, matching TLS server name, and public certificate anchor. Tap `Start experiment` once. After the Mac reports `server diagnostic response delayed: 8.0s`, tap `Cancel` once. Record the final status and every subsequent Mac connection-state and send-completion line. Expected invariants: final status `Cancelled`, no iOS success, and Start enabled with Cancel disabled. A Mac line stating that a send completed locally is not evidence of remote receipt; only an observed transport failure/cancellation before the send, or an explicit application-level acknowledgment (not implemented by this experiment), can establish more. Repeat only after the first attempt is terminal; do not start concurrent attempts.

#### Test E — Unexpected listener closure

Start the valid listener command above with `--diagnostic-delay 8`. Configure the iPhone with the valid certificate and tap `Start experiment` once. Wait for `server diagnostic response delayed: 8.0s`, then press `Ctrl-C` in the Mac Terminal before the delay expires. Record the iPhone terminal state, Xcode logs, and all Mac output after the interrupt.

Interpret the result carefully: `Ctrl-C` definitely stops the listener, but it does not by itself prove that an already accepted connection was terminated. The test is valid only if the accepted connection subsequently reports `failed` or `cancelled`, or the iPhone reports a bounded transport failure/timeout with no later diagnostic completion. If the listener exits while the accepted connection remains alive and no terminal state is observed, classify the run as inconclusive. Do not assume a graceful listener stop is equivalent to abrupt process termination. No certificate-verification callback should be claimed unless it is actually logged.

Expected invariants for a valid closure observation: no diagnostic completion after interruption, no indefinite waiting, deterministic cleanup, and a fresh attempt remains possible. If graceful stop does not terminate the accepted connection reliably, record the limitation first; an experiment-only abort-after-acceptance fault injection may then be considered as a separate focused change, but is not added preemptively.

#### Test F — Reconnection after a completed exchange

Start the valid listener with a duration long enough for two attempts, for example `--duration 180`. On the iPhone, perform one valid Start and wait for `Diagnostic exchange complete (unverified)`. After Start is enabled again, tap Start once more. Record two separate `listener accepted connection` and `server diagnostic exchange complete` sequences. Expected invariants: the second attempt succeeds independently, no stale state affects it, no exporter value is displayed or persisted, and the first attempt does not authorize the second one.

For an interrupted-then-recovered variant, stop the listener during an active attempt, wait for the iPhone to reach its terminal failure/timeout state, restart the same valid listener, and start a new attempt only after the previous attempt is terminal. The new exchange must be a fresh connection; no automatic replay is expected.

### Queue assertion investigation

The physical debugger stopped in `__dispatch_assert_queue_fail` while Network.framework callbacks were active. Source inspection found that the iOS TLS verification callback was scheduled on the experiment's serial Network.framework queue, while the callback directly accessed the `@MainActor` model's `Logger` property. That is an application-side executor mismatch and can trigger a libdispatch queue assertion before the verification log is emitted. The logger is now a process-scoped, non-actor-isolated value; the callback performs Security.framework verification on its configured callback queue and dispatches only the UI status update to the main queue. State, send, receive, timeout, and cancellation callbacks retain their existing MainActor guards.

The maintainer's physical LLDB capture confirmed this application-side violation: `__dispatch_assert_queue_fail` led through Swift Concurrency executor checks to the application-owned verification closure, which was called from BoringSSL's asynchronous trust evaluation callback. The fix creates that closure in a top-level, non-actor-isolated helper and removes all model captures from it. The subsequent successful physical run followed this correction. This confirms the executor violation as a cause of the debugger-stopped run; it does not establish that every earlier `preparing` timeout or connection failure had the same cause. If a different assertion recurs, capture the first application-owned frame with the LLDB procedure below before making further queue changes.

For a repeatable debugger capture, pause on the assertion and run:

```text
breakpoint set --name __dispatch_assert_queue_fail
continue
thread backtrace all
expr -l objc++ -- (const char *)dispatch_queue_get_label(NULL)
```

The required evidence is the first application-owned frame, its source line, and the current queue label. Do not continue past the assertion and infer the cause from the Network.framework frame alone.

## Security interpretation

Even if a future runtime test produces equal values, that result would establish only a property of the same TLS session. It would not authenticate a MacDock device by itself, complete QR pairing, prove authorization, or replace identity signatures, SAS, two-sided confirmation, durable trust, revocation, and recovery.

The future design must still address wrong-peer verification, channel substitution, unknown-key-share, role confusion, downgrade, replay, duplicate messages, and relay limitations. Matching TLS-derived values cannot repair an unreviewed identity or transcript construction.

### Remaining cross-platform validation

The following remain required before Candidate A can be treated as ready for formal construction approval:

- Physical reconnection, cancellation, and unexpected-closure tests.
- Runtime validation on the provisional macOS 14 and iOS 17 minimum versions; the successful run used a newer environment and does not establish minimum-OS compatibility.
- Independent cryptographic review of the exact identity, transcript, channel-binding, SAS, and trust-commit construction.

## Conclusion

**Candidate A runtime feasibility is partially supported by executed Mac-to-Mac evidence and one maintainer-reported physical Mac–iPhone result, but construction and security approval remain outstanding.** The corrected isolated fixture completed TLS 1.3, passed explicit scoped certificate verification, and produced matching same-session exporter values with different values across sessions, labels, and contexts. The physical result extends feasibility evidence to the tested Mac/iPhone pair and temporary certificate configuration only. It does not establish device identity, pairing, authorization, mutual authentication, minimum-OS compatibility, or independent cryptographic approval.
