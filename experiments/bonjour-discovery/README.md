# Bonjour Discovery Experiment

This isolated Stage 0 experiment validates the shape of a native Bonjour advertiser and browser. It is not production MacDock code, does not authenticate peers, and does not exchange application-control data.

## Service definition

- Service type: `_macdock._tcp`
- Service name: `MacDock Bonjour Experiment`
- Transport: TCP listener configuration for the advertiser; no application protocol is implemented.
- Privacy: logs contain lifecycle state and service counts only. They do not print IP addresses, hardware identifiers, credentials, or payloads.

## macOS command-line experiment

From this directory:

```sh
swift build
swift run BonjourAdvertiser
```

In a second terminal:

```sh
swift run BonjourBrowser
```

Type `q` and press Return to stop the advertiser cleanly, then observe the browser's visible service count change. Restart it and observe a new result update. Type `q` in the browser to stop it; cancellation is expected and does not represent a network failure.

The command-line targets are macOS-only and are intentionally separate from future Xcode application targets.

## iOS setup

The isolated Xcode project is at `iOS/BonjourBrowser.xcodeproj`. Open it directly in Xcode; do not add it to a production MacDock target.

1. Open `iOS/BonjourBrowser.xcodeproj`.
2. Select the `BonjourBrowser` target and choose your Apple development team under Signing & Capabilities. This setting is local to the Xcode project/user environment and must not be committed.
3. Select the connected iPhone as the run destination.
4. Build and run while the macOS advertiser is running on the same local network.
5. Grant or deny Local Network access deliberately and record the resulting browser state.

The committed target contains no Team ID, provisioning profile, certificate, device identifier, or Apple account information. `Info.plist.example` supplies `NSLocalNetworkUsageDescription` and `_macdock._tcp` under `NSBonjourServices`.

For a no-signing validation, run:

```sh
xcodebuild -project iOS/BonjourBrowser.xcodeproj \
  -scheme BonjourBrowser \
  -sdk iphonesimulator \
  CODE_SIGNING_ALLOWED=NO build
```

Compilation or simulator execution is not evidence of physical-device discovery. A physical-device result must be recorded separately.

## Boundaries

This experiment deliberately does not implement:

- Pairing or peer authentication.
- TLS or an application protocol.
- Application discovery, launch, activation, or icons.
- Background execution or Keep Screen Awake.
- Production logging, persistence, or UI design.
