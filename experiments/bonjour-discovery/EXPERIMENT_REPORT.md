# Bonjour Discovery Experiment Report

- Issue: [#3](https://github.com/Shlomi-Hazan/MacDock/issues/3)
- Status: Xcode target prepared; physical iPhone validation remains pending
- Date: 2026-11-03

## Research question

Can a minimal macOS service advertise a dedicated Bonjour service and can a native Apple client browse it while clearly distinguishing discovery state from connection and authentication?

## Hypotheses

1. `NWListener` can advertise `_macdock._tcp` from a macOS command-line target.
2. `NWBrowser` can observe service-count changes when the advertiser starts and stops.
3. An iOS app using `NWBrowser` and the required Info.plist declarations can represent ready, waiting, failed, cancelled, and result-count states.
4. Discovery alone will not establish a trusted or authenticated Mac peer.

## Environment

### Verified local environment

- Host: Apple Silicon Mac (the repository's development Mac)
- macOS: 26.5.2
- Architecture: arm64
- Swift toolchain: Swift 6.2.4
- Xcode: 26.3, build 17C529
- Physical iPhone: not connected to this execution environment
- Wi-Fi topology: not independently measured by the experiment runner

### Evidence labels

- **Verified by compilation:** the macOS Swift Package targets compiled successfully.
- **Verified on macOS runtime:** the advertiser/browser processes were run locally and their lifecycle/result observations were captured below.
- **Verified by simulator compilation:** the isolated iOS Xcode target built for iOS Simulator without signing.
- **Prepared but not run on hardware:** the iOS target was not installed or executed on the physical iPhone here because local Development Team selection is still required.
- **Documentation only:** platform permission and limitation statements linked to Apple documentation.
- **Not tested:** physical iPhone discovery, permission denial on iOS, Wi-Fi interruption, sleep/wake, and multi-device behavior.

## Implementation approach

The experiment contains two isolated macOS command-line targets:

- `BonjourAdvertiser`: creates an `NWListener` with service type `_macdock._tcp`, reports lifecycle state, and cancels incoming connections without authenticating or exchanging data.
- `BonjourBrowser`: creates an `NWBrowser` for `_macdock._tcp`, reports lifecycle state, and reports only the number of visible services.

It also contains an iOS SwiftUI source file using `NWBrowser`, plus an example `Info.plist` with `NSLocalNetworkUsageDescription` and `NSBonjourServices`.

The iOS source is now included in the isolated `iOS/BonjourBrowser.xcodeproj` target. The project deliberately contains no team identifier, provisioning profile, certificate, device identifier, or Apple account information.

## Reproduction

```sh
cd experiments/bonjour-discovery
swift build
swift run BonjourAdvertiser
```

In a second terminal:

```sh
cd experiments/bonjour-discovery
swift run BonjourBrowser
```

Type `q` and press Return to stop either command cleanly. Stop and restart the advertiser to exercise service disappearance and reappearance. The iOS procedure is documented in [README.md](README.md) and requires a manually created, signed Xcode iOS app target.

## Test matrix

| Scenario | Result in this run | Evidence level | Notes |
| --- | --- | --- | --- |
| Mac advertiser builds | Passed | Verified by compilation | `swift build` completed successfully for both executable targets. |
| Mac browser builds | Passed | Verified by compilation | `swift build` completed successfully for both executable targets. |
| macOS advertiser starts | Passed | Verified on macOS runtime | Listener reached `ready` and reported that the Bonjour service was advertised. |
| macOS browser observes advertiser | Passed | Verified on macOS runtime | Browser reached `ready` and observed visible service count `1`. |
| Advertiser stops | Passed | Verified on macOS runtime | Typing `q` cancelled the advertiser; browser observed visible service count `0`. |
| Advertiser restarts | Passed | Verified on macOS runtime | Restarted advertiser; browser observed visible service count `1`. |
| iPhone with Local Network allowed | Not run | Not tested | Requires manual signing/install and physical iPhone. |
| iPhone with Local Network denied | Not run | Not tested | Requires permission reset and physical iPhone interaction. |
| Wi-Fi disconnect/reconnect | Not run | Not tested | Requires coordinated physical network change. |
| Mac sleep/wake | Not run | Not tested | Requires physical Mac sleep/wake while advertiser is active. |
| iOS app relaunch | Not run | Not tested | Requires physical iPhone or simulator target. |
| Multiple services/duplicate events | Not run | Not tested | Requires multiple advertisers or controlled duplicate service publication. |

The Xcode project was validated with `xcodebuild -list` and built successfully for iOS Simulator with signing disabled. A normal device build was attempted and was blocked by Xcode's requirement for a locally selected Development Team; no signing configuration was committed.

## Execution log

The following observations were captured on the Apple Silicon macOS host on 2026-11-03:

1. `BonjourAdvertiser` started with service type `_macdock._tcp` and reached `listener state: ready`.
2. `BonjourBrowser` reached `browser state: ready` and reported `visible service count=1`.
3. The advertiser was stopped by entering `q`; the browser reported `visible service count=0`.
4. The advertiser was restarted; the browser reported `visible service count=1`.
5. Both processes were stopped by entering `q` and reported `shutdown requested`.

No service endpoint, MAC address, IP address, or device identifier was included in the experiment logs.

## Observations and limitations

- This experiment demonstrates the API shape and local macOS behavior only; it does not satisfy the physical iPhone discovery acceptance criterion by itself.
- The command-line macOS targets do not have an iOS app lifecycle, iOS Local Network prompt, or iOS signing profile.
- The iOS project is runnable after the user selects a local development team in Xcode; this is a signing prerequisite, not physical discovery evidence.
- The experiment reports service counts rather than service endpoint details to minimize identifier exposure. A later experiment may need stable, non-sensitive service metadata for user selection.
- Discovery does not imply a connection, authentication, authorization, or readiness to receive MacDock commands.
- The exact Local Network prompt and denial behavior must be observed from a signed app target on the relevant OS versions.

## Conclusions

The minimal native API path is viable for a macOS advertiser and a browser implementation, and the isolated sources are suitable for the next manual iOS build step. Runtime evidence is incomplete: no physical iPhone discovery, permission matrix, network interruption, sleep/wake, or duplicate-result validation was performed in this execution. Therefore Issue #3 must remain open until the target iPhone evidence is captured and reviewed.

## Recommendations

- Keep Bonjour discovery isolated from authentication and transport protocol decisions.
- Use the iOS physical-device run to record Local Network permission states and exact `NWBrowser` state transitions.
- Keep service type/name and metadata stable for the experiment, but do not treat them as a production identity scheme.
- Feed TLS, connection lifecycle, and peer-trust questions into Issue #4 and Issue #5 rather than expanding this experiment.

## Remaining questions for Issue #4

- Which `NWConnection` parameters and framing strategy should carry a post-discovery experiment message?
- How should the system behave when discovery succeeds but connection fails or the network path changes?
- Which TLS identity and verification approach can be tested without bypassing trust evaluation?
