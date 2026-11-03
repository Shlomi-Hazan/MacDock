# Bonjour Discovery Experiment Report

- Issue: [#3](https://github.com/Shlomi-Hazan/MacDock/issues/3)
- Status: Physical iPhone validation completed from user-reported observations; unresolved USB/Wi-Fi behavior remains documented
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
- Physical iPhone: physical validation performed by the maintainer; observations below are user-reported, not tool-executed
- Wi-Fi topology: not independently measured by the experiment runner

### Evidence labels

- **Verified by compilation:** the macOS Swift Package targets compiled successfully.
- **Verified on macOS runtime:** the advertiser/browser processes were run locally and their lifecycle/result observations were captured below.
- **Verified by simulator compilation:** the isolated iOS Xcode target built for iOS Simulator without signing.
- **Not run by the tool environment on hardware:** the tool environment did not install or execute the iOS target; physical results below are explicitly user-reported.
- **User-reported physical-device evidence:** the maintainer installed and ran the signed experiment on the physical iPhone and reported the observations in this report.
- **Documentation only:** platform permission and limitation statements linked to Apple documentation.
- **Not tested:** Mac sleep/wake, multiple services or duplicate-result behavior, and the cause of the Wi-Fi/USB anomaly.

## Bundle installation diagnosis

The first physical installation attempt failed because the generated `BonjourBrowser.app/Info.plist` did not contain `CFBundleIdentifier`. The target had `PRODUCT_BUNDLE_IDENTIFIER = com.macdock.experiment.bonjourbrowser`, but it also used `GENERATE_INFOPLIST_FILE = NO` with a manually supplied plist that omitted the corresponding key. Xcode therefore produced a bundle with the network privacy declarations but without an installable application identifier.

The minimal fix was to add `CFBundleIdentifier` with the value `$(PRODUCT_BUNDLE_IDENTIFIER)` to `Info.plist.example`. No signing identity, Team ID, provisioning profile, certificate, or device identifier was added.

After the fix, Debug and Release generic iOS device builds passed with signing disabled. The built plist was inspected and contained the resolved bundle identifier, `NSLocalNetworkUsageDescription`, and `NSBonjourServices` containing `_macdock._tcp`.

The final target uses one consistent metadata strategy: `GENERATE_INFOPLIST_FILE = NO` in both Debug and Release, with `INFOPLIST_FILE = Info.plist.example`. The checked-in plist explicitly supplies the application identity and version keys; Xcode supplies platform-derived keys. No generated and manual plist sources are mixed.

## Bundle validation matrix

| Validation | Result | Evidence |
| --- | --- | --- |
| Generic iOS device Debug build | Passed | `xcodebuild`, `CODE_SIGNING_ALLOWED=NO` |
| Generic iOS device Release build | Passed | `xcodebuild`, `CODE_SIGNING_ALLOWED=NO` |
| iOS Simulator Debug build | Passed | `xcodebuild`, `CODE_SIGNING_ALLOWED=NO` |
| Built plist syntax | Passed | `plutil -lint` for all three app bundles |
| Bundle identifier | Passed | Resolved to `com.macdock.experiment.bonjourbrowser` |
| Application name metadata | Passed | `CFBundleName=BonjourBrowser`, `CFBundleDisplayName=MacDock Bonjour Experiment` |
| Executable consistency | Passed | `CFBundleExecutable=BonjourBrowser`; matching executable exists in the app bundle |
| Version/package metadata | Passed | `APPL`, version `1`, short version `0.1.0`, `LSRequiresIPhoneOS=true` |
| Local Network declarations | Passed | Usage description present; `_macdock._tcp` present |
| Code-signature verification | Not applicable to these builds | Builds intentionally used `CODE_SIGNING_ALLOWED=NO`; signed device install remains a manual Xcode validation |

## Physical-device evidence

The following results were supplied by the maintainer after installing and running the experiment on the physical iPhone. They are recorded as user-reported observations; no screenshots, measurements, or additional results are inferred.

| Scenario | User-reported observation | Evidence classification |
| --- | --- | --- |
| Advertiser running | iPhone showed `State: Ready` and `Visible services: 1`. | User-reported physical device |
| Advertiser stopped | Visible service count changed from `1` to `0`. | User-reported physical device |
| Advertiser restarted | Visible service count changed from `0` to `1`. | User-reported physical device |
| Local Network permission disabled, browser restarted | State was `Waiting`, error was `PolicyDenied (-65570)`, and visible services were `0`. | User-reported physical device |
| Local Network permission re-enabled, browser restarted | State returned to `Ready` and visible services returned to `1`. | User-reported physical device |
| Wi-Fi disabled while USB remained connected | One service remained visible after restarting the browser. | User-reported physical device; unresolved behavior |
| Wi-Fi disabled, USB disconnected, advertiser stopped | State was `Ready` and visible services were `0`. | User-reported physical device |
| Wi-Fi disabled, USB disconnected, advertiser running | Visible services were `0`. | User-reported physical device |
| Wi-Fi restored to the Mac's local network, USB disconnected, advertiser running | State was `Ready` and visible services were `1`. | User-reported physical device |

The Wi-Fi-disabled/USB-connected result is not interpreted as proof of a USB-assisted Bonjour discovery path. It may reflect device state, cached results, routing, or another environmental factor. The experiment does not identify the cause.

## Acceptance criteria assessment

All Issue #3 acceptance criteria are satisfied based on the combined local evidence and the user-reported physical-device observations:

1. The iPhone discovered the intended Mac service on the target network.
2. Local Network denial produced an observable `Waiting`/`PolicyDenied (-65570)` state, while an advertiser-absent case produced `Ready` with zero visible services. This distinction is documented for the observed run and is not generalized to every OS/network condition.
3. The experiment logs and UI expose lifecycle state, error state, and service counts without device identifiers or secrets.
4. All experiment code remains isolated under `experiments/bonjour-discovery/` and is not part of a production target.

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

Type `q` and press Return to stop either command cleanly. Stop and restart the advertiser to exercise service disappearance and reappearance. For iOS, open the isolated `iOS/BonjourBrowser.xcodeproj`, select a local development team, and run on the physical device as documented in [README.md](README.md).

## Test matrix

| Scenario | Result in this run | Evidence level | Notes |
| --- | --- | --- | --- |
| Mac advertiser builds | Passed | Verified by compilation | `swift build` completed successfully for both executable targets. |
| Mac browser builds | Passed | Verified by compilation | `swift build` completed successfully for both executable targets. |
| macOS advertiser starts | Passed | Verified on macOS runtime | Listener reached `ready` and reported that the Bonjour service was advertised. |
| macOS browser observes advertiser | Passed | Verified on macOS runtime | Browser reached `ready` and observed visible service count `1`. |
| Advertiser stops | Passed | Verified on macOS runtime | Typing `q` cancelled the advertiser; browser observed visible service count `0`. |
| Advertiser restarts | Passed | Verified on macOS runtime | Restarted advertiser; browser observed visible service count `1`. |
| iPhone with Local Network allowed | Passed | User-reported physical device | Ready state and one visible service were observed. |
| iPhone with Local Network denied | Passed | User-reported physical device | Waiting with `PolicyDenied (-65570)` and zero services were observed. |
| Wi-Fi disconnect/reconnect | Partially observed | User-reported physical device | Wi-Fi-off/USB-connected behavior remains unresolved; Wi-Fi-off/USB-disconnected and restoration cases were recorded. |
| Mac sleep/wake | Not run | Not tested | Requires physical Mac sleep/wake while advertiser is active. |
| iOS browser restart after permission/network changes | Passed | User-reported physical device | Restart behavior was included in the reported permission and Wi-Fi scenarios. |
| Multiple services/duplicate events | Not run | Not tested | Requires multiple advertisers or controlled duplicate service publication. |

The Xcode project was validated with `xcodebuild -list` and built successfully for iOS Simulator and generic iOS devices with signing disabled. The maintainer subsequently installed and ran the signed app on the physical iPhone. No signing configuration or personal Team ID was committed.

## Execution log

The following observations were captured on the Apple Silicon macOS host on 2026-11-03:

1. `BonjourAdvertiser` started with service type `_macdock._tcp` and reached `listener state: ready`.
2. `BonjourBrowser` reached `browser state: ready` and reported `visible service count=1`.
3. The advertiser was stopped by entering `q`; the browser reported `visible service count=0`.
4. The advertiser was restarted; the browser reported `visible service count=1`.
5. Both processes were stopped by entering `q` and reported `shutdown requested`.

No service endpoint, MAC address, IP address, or device identifier was included in the experiment logs.

## Observations and limitations

- The combined experiment evidence demonstrates the API shape, local macOS behavior, and the reported physical iPhone discovery and permission behavior.
- The command-line macOS targets do not have an iOS app lifecycle, iOS Local Network prompt, or iOS signing profile.
- The iOS project is runnable after selecting a local development team in Xcode; signing configuration remains local and is not part of the public experiment source.
- The experiment reports service counts rather than service endpoint details to minimize identifier exposure. A later experiment may need stable, non-sensitive service metadata for user selection.
- Discovery does not imply a connection, authentication, authorization, or readiness to receive MacDock commands.
- The observed Local Network denial behavior was `Waiting` with `PolicyDenied (-65570)` on the tested physical device. This is evidence for that run, not a universal classifier for every OS or network failure.

## Conclusions

The minimal native API path is viable for a macOS advertiser and a physical iPhone browser. The reported permission and service lifecycle observations satisfy Issue #3's acceptance criteria. The Wi-Fi-disabled/USB-connected observation remains unexplained and should not be treated as an architectural capability or authentication signal.

## Recommendations

- Keep Bonjour discovery isolated from authentication and transport protocol decisions.
- Preserve the physical-device evidence matrix when evaluating future discovery or transport changes.
- Keep service type/name and metadata stable for the experiment, but do not treat them as a production identity scheme.
- Treat `PolicyDenied (-65570)` as evidence of a denied local-network policy in this observed case, not as a universal classifier for all discovery failures.
- Investigate the Wi-Fi/USB anomaly only if it affects supported connection behavior; do not build production discovery assumptions from this single observation.
- Feed TLS, connection lifecycle, and peer-trust questions into Issue #4 and Issue #5 rather than expanding this experiment.

## Remaining questions for Issue #4

- Which `NWConnection` parameters and framing strategy should carry a post-discovery experiment message?
- How should the system behave when discovery succeeds but connection fails or the network path changes?
- Which TLS identity and verification approach can be tested without bypassing trust evaluation?
