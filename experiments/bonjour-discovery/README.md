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

1. In Xcode, create a temporary iOS App project for this experiment; do not add it to a production MacDock target.
2. Add `iOS/BonjourBrowserApp.swift` to the app target.
3. Add the keys from `iOS/Info.plist.example` to the target's `Info.plist`.
4. Set the iOS deployment target according to the experiment device and installed SDK; no project-wide minimum is selected by this repository yet.
5. Build and run on the target iPhone while the macOS advertiser is running on the same local network.
6. Grant or deny Local Network access deliberately and record the resulting browser state.

The iOS source is prepared in this repository, but this checkout does not yet contain an Xcode project or signing configuration. A physical-device result must be recorded separately from compilation or simulator behavior.

## Boundaries

This experiment deliberately does not implement:

- Pairing or peer authentication.
- TLS or an application protocol.
- Application discovery, launch, activation, or icons.
- Background execution or Keep Screen Awake.
- Production logging, persistence, or UI design.
