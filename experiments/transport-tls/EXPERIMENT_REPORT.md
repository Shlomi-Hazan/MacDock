# Transport and TLS Feasibility Experiment Report

## Status

This report records Stage 0 feasibility work. It must not be read as evidence that production pairing, authorization, or application control has been implemented.

## Research question and hypotheses

Can a physical iPhone and Mac use Network.framework to establish an encrypted local connection, verify the expected Mac identity, exchange a bounded test message, and reject incorrect trust material?

Hypotheses:

1. Bonjour discovery can provide an endpoint, but does not authenticate the peer.
2. TLS can encrypt the connection when the macOS listener presents a local identity.
3. Explicit certificate fingerprint pinning can reject an unexpected certificate in this controlled experiment.
4. Transport success, message receipt, and application-level completion are separate states.

## Environment and implementation

The experiment contains a macOS Swift Package executable and an isolated SwiftUI iOS Xcode target. It uses Network.framework, Security, CryptoKit, and Bonjour service type `_macdock-tls._tcp`; it has no third-party dependencies.

The macOS advertiser loads a locally generated PKCS#12 identity, starts an `NWListener` with TLS over TCP, and reports lifecycle states. The iOS browser uses `NWBrowser`, creates an `NWConnection`, and verifies the leaf certificate's SHA-256 fingerprint against a user-entered value before completing the TLS verification callback.

The test identity is a locally generated, self-signed RSA identity. An initial EC identity attempt exposed a runtime compatibility failure in `SecPKCS12Import` on this macOS environment, so the generator uses RSA for reproducibility. Private key, PKCS#12, password, and fingerprint files are ignored by Git. This is an experiment trust model, not a production certificate distribution or pairing protocol.

## Trust and security model

The following distinctions are intentional:

- **Encrypted channel:** the connection reaches `ready` after TLS setup.
- **TLS negotiation:** Network.framework completes the TLS handshake.
- **Peer verification:** the iOS verification callback accepts only the exact configured certificate fingerprint.
- **Intended-peer authentication:** remains bounded by possession and safe distribution of the expected fingerprint; it is not solved by Bonjour or TLS alone.
- **Long-term pairing:** deferred to Issue #5 and must define identity enrollment, rotation, revocation, and recovery.

The client does not use an unconditional trust callback. A mismatch or unavailable certificate causes verification failure. The self-signed test certificate is deliberately not a production trust anchor.

## Connection and message state machine

`Not started → Browsing → Service visible → Connecting → TLS Ready / peer verified → Request sent → Receipt acknowledgment verified`.

Failure states include waiting, browser failure, TLS or transport failure, invalid frame, timeout, cancellation, and unexpected acknowledgment. The client does not automatically replay an old request after reconnection.

The message protocol is a four-byte big-endian length prefix plus UTF-8 payload, capped at 1,024 bytes. The only accepted request is `IPHONE-HELLO/1`; the only response is `MAC-ACK/1`. A request being transmitted is not proof of receipt, and receipt acknowledgment is not proof of any future MacDock action.

## Reproduction

Follow `README.md` in this directory. Generate the identity locally, run the advertiser, open the isolated Xcode project, grant Local Network access, enter the displayed certificate fingerprint, and connect. No personal signing configuration belongs in the repository.

## Test matrix and evidence classification

| Scenario | Evidence | Result |
| --- | --- | --- |
| Swift package compilation | Verified by tool execution | Passed |
| Frame encoding and invalid-length tests | Verified by tool execution | Passed |
| iOS Xcode project listing | Verified by tool execution | Passed |
| iOS Debug generic-device build | Verified by tool execution | Passed |
| iOS Release generic-device build | Pending in this report revision | Not tested |
| iOS Simulator build | Pending in this report revision | Not tested |
| macOS identity loading and listener startup | Verified on Mac runtime | Passed with locally generated RSA identity; listener reached ready and advertised a dynamic port |
| Mac TLS handshake with self-signed identity | Verified on Mac runtime | Passed at the listener; OpenSSL correctly reported the certificate as self-signed |
| Mac framed hello/ACK exchange | Requires a protocol client | Not tested |
| Physical iPhone TLS success and acknowledgment | Requires user-run device test | Not tested |
| Incorrect fingerprint rejection on physical iPhone | Requires user-run device test | Not tested |
| Listener unavailable, timeout, and cancellation | Partially represented in code; runtime evidence pending | Not tested |
| Wi-Fi/USB path behavior | Follow-up from Issue #3; interface cause is unknown | Not tested |

Compilation and static inspection do not prove TLS runtime behavior. No physical-device result is claimed here.

The Mac runtime check also showed the bounded failure path: a TLS-ready client that sent no framed hello was closed after the eight-second message timeout. The OpenSSL check was an encryption/handshake check only; it was not a peer-authentication success.

## Security limitations and rejected shortcuts

- Certificate fingerprint entry is suitable only for a controlled experiment and does not provide a polished pairing UX.
- Bonjour visibility is not peer authentication.
- The experiment does not implement pairing, identity enrollment, key rotation, revocation, or multi-Mac trust management.
- It does not accept arbitrary certificates and does not disable certificate validation globally.
- It does not send sensitive data or Mac application commands.
- It does not infer that a Wi-Fi-disabled, USB-connected discovery result was caused by USB. Network.framework path evidence must be collected separately and without publishing addresses or device identifiers.

## Recommendations and dependencies

Issue #5 should define the threat model and pairing UX before production transport is selected. It must decide how the user confirms the intended Mac, how trust is stored and revoked, how reconnects are handled, and how identity changes are presented.

The production design should preserve the explicit distinction among discovery, encrypted transport, peer authentication, request acknowledgment, and confirmed operating-system state. This experiment is evidence for feasibility only, not an architecture commitment.

## Official references

- [Network framework](https://developer.apple.com/documentation/network)
- [NWBrowser](https://developer.apple.com/documentation/network/nwbrowser)
- [NWConnection](https://developer.apple.com/documentation/network/nwconnection)
- [NWListener](https://developer.apple.com/documentation/network/nwlistener)
- [SecTrust](https://developer.apple.com/documentation/security/sectrust)
- [CryptoKit](https://developer.apple.com/documentation/cryptokit)
- [Local network privacy](https://developer.apple.com/documentation/bundleresources/information_property_list/nslocalnetworkusagedescription)
