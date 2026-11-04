# iOS Lifecycle and Keep Screen Awake Experiment

This isolated Stage 0 experiment evaluates SwiftUI scene lifecycle reporting and an explicit, user-controlled Keep Screen Awake setting. It is not production MacDock UI and does not add background execution modes or networking.

## Requirements

- Xcode 26.3 or compatible Xcode.
- iOS 17.0 or later for the experiment target.
- A simulator or a signed physical iPhone for runtime testing.

## Project and tests

Open `LifecycleExperiment.xcodeproj` in Xcode and select the `LifecycleExperiment` scheme.

Pure state-model tests can run without signing:

```sh
swift test
```

The Xcode target can be validated without signing:

```sh
xcodebuild -project LifecycleExperiment.xcodeproj -scheme LifecycleExperiment \
  -sdk iphonesimulator -configuration Debug CODE_SIGNING_ALLOWED=NO build

xcodebuild -project LifecycleExperiment.xcodeproj -scheme LifecycleExperiment \
  -sdk iphoneos -destination 'generic/platform=iOS' \
  -configuration Debug CODE_SIGNING_ALLOWED=NO build
```

The experiment uses automatic signing settings without committing a Team ID, provisioning profile, certificate, or device identifier.

## Behavior

- Keep Screen Awake defaults OFF.
- The preference is changed only by the visible toggle.
- The app disables `UIApplication.isIdleTimerDisabled` only when the user preference is ON and the scene is foreground active.
- Inactive, background, and unknown states restore the idle timer to normal behavior.
- Returning to foreground reapplies the user's preference.
- A short in-memory event history records lifecycle and applied-state transitions without identifiers or network data.

Manual device locking remains available even when the idle timer is disabled. Unexpected process termination must not be described as guaranteed cleanup; the operating system owns the final process cleanup.
