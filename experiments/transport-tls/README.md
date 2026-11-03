# Transport and TLS Feasibility Experiment

This isolated Stage 0 experiment tests a native Network.framework TLS connection between a macOS Bonjour advertiser and an iOS browser. It is not production MacDock networking or pairing code.

## Prerequisites

- macOS with Xcode and Swift installed.
- An iPhone running iOS 17 or later for device testing.
- Both devices on the same local network for the baseline test.
- OpenSSL for generating a local-only test identity.

## Generate the local test identity

From this directory:

```sh
sh generate-test-identity.sh
```

The script creates `.local/server.identity.p12`, `.local/password.txt`, and `.local/fingerprint.txt`. These files are ignored and must never be committed. The displayed SHA-256 certificate fingerprint is entered into the iOS test app. The identity is self-signed and intentionally limited to this experiment.

## Run the macOS advertiser

```sh
swift run --package-path . TransportTLSAdvertiser \
  --p12 .local/server.identity.p12 \
  --password-file .local/password.txt
```

The advertiser must reach `listener state: ready`. It advertises `_macdock-tls._tcp` and logs the assigned port without logging addresses or device identifiers. Type `q` and press Return to stop it.

## Build the iOS browser

Open `iOS/TransportTLSBrowser.xcodeproj` in Xcode. Select the `TransportTLSBrowser` scheme, choose a simulator or a connected iPhone, and run the target. Automatic signing remains enabled; any personal Team selection is local Xcode state and must not be committed.

On the iPhone:

1. Grant Local Network access when prompted.
2. Tap `Browse` if browsing is not already active.
3. Enter the fingerprint from `.local/fingerprint.txt`.
4. Select `Connect` after one TLS service is visible.
5. A successful test requires `TLS Ready — peer fingerprint verified`, followed by `Receipt acknowledgment verified`.

An incorrect fingerprint must not produce a trusted state or verified acknowledgment. The current experiment reports the TLS or peer-verification failure separately from user cancellation; exact OS error causes are not inferred beyond what Network.framework reports.

The experiment distinguishes TLS encryption and certificate pinning from production pairing. Discovery does not establish trust. No application-control command is sent.

## Protocol

Messages use a four-byte, big-endian unsigned length prefix followed by a UTF-8 payload. Payloads are limited to 1,024 bytes. The iOS client sends `IPHONE-HELLO/1`; the macOS advertiser accepts only that message and replies with `MAC-ACK/1`. A connection that does not complete the bounded exchange is cancelled; outdated requests are not replayed after reconnect.

## References

- [Network framework](https://developer.apple.com/documentation/network)
- [NWConnection](https://developer.apple.com/documentation/network/nwconnection)
- [NWListener](https://developer.apple.com/documentation/network/nwlistener)
- [Network privacy](https://developer.apple.com/documentation/bundleresources/information_property_list/nslocalnetworkusagedescription)
