# Experiment Report: iOS Lifecycle and Keep Screen Awake

- Issue: [#8](https://github.com/Shlomi-Hazan/MacDock/issues/8)
- Status: Stage 0 feasibility experiment; maintainer-reported physical-device evidence recorded
- Scope: lifecycle state model and idle-timer policy only; no production Dock UI or networking

## Research question

Can MacDock express its foreground-only Dock constraint using supported SwiftUI/UIKit lifecycle APIs and provide an opt-in Keep Screen Awake setting that is applied only during the active foreground experience and restored on lifecycle changes?

## State model

The pure model contains three independent concepts:

| Concept | Values | Meaning |
| --- | --- | --- |
| Lifecycle state | active, inactive, background, unknown | Latest SwiftUI `scenePhase` mapping |
| User preference | ON/OFF | Explicit choice; defaults OFF and is never inferred |
| Applied idle-timer state | enabled/disabled | Current value applied to `UIApplication.isIdleTimerDisabled` |

The applied state is disabled unless both conditions are true:

```text
user preference == ON && lifecycle == foreground active
```

Inactive, background, and unknown states restore normal idle-timer behavior. Returning to foreground does not change the user's preference; it only reapplies the policy.

## Implementation

The isolated SwiftUI target contains:

- `LifecycleState.swift`: platform-independent state model.
- `LifecycleExperimentApp.swift`: SwiftUI view, `scenePhase` observation, `UIApplication.isIdleTimerDisabled` application, visible toggle, and bounded in-memory event history.
- `LifecycleExperiment.xcodeproj`: directly runnable iOS target with complete generated bundle metadata.

The target does not contain Network.framework, Bonjour, pairing, production Dock screens, background modes, or a connection implementation. Connection behavior is therefore intentionally documented as untested rather than inferred.

## Evidence classification

### Verified by automated tests

Four Swift tests passed:

- Default preference is OFF and does not disable the idle timer.
- ON applies only in foreground active and is restored in inactive state.
- Turning the preference OFF restores normal behavior immediately.
- Repeated transitions and repeated toggle operations are idempotent while preserving the user's preference.

These tests validate the pure state model only; they do not prove physical display behavior.

### Verified by maintainer on a physical iPhone

The following observations were reported by the maintainer after installing and running the experiment on a physical iPhone. They were not independently executed or observed by the tool environment:

- With the default setting, the app showed `Foreground active`, preference `OFF`, and idle timer currently disabled `NO`.
- Enabling the setting showed `Foreground active`, preference `ON`, and idle timer currently disabled `YES`.
- Disabling the setting showed `Foreground active`, preference `OFF`, and idle timer currently disabled `NO`.
- After enabling the setting, moving the app to the background, and returning to it, the preference remained `ON` and the applied idle-timer state returned to `YES`. No captured background-event screenshot is claimed.
- With the setting enabled, manual device locking and unlocking remained possible, and the expected foreground `ON`/`YES` state was restored.
- During a short foreground observation without screen interaction, the maintainer reported that the screen remained on. The exact duration was not recorded.

These observations provide physical-device evidence for the opt-in toggle, foreground application, restoration after return to foreground, manual lock/unlock compatibility, and short screen-on behavior. They do not establish a measured duration or long-term reliability.

### Verified by compilation and bundle inspection

The following passed with signing disabled:

- `xcodebuild -list`.
- iOS Simulator Debug build.
- Generic iOS device Debug build.
- Generic iOS device Release build.
- iOS Simulator Release build.

The generated device bundle was inspected with `plutil`. It contained:

- `CFBundleIdentifier`: `com.macdock.experiment.ioslifecycle`
- `CFBundleName`: `LifecycleExperiment`
- `CFBundleDisplayName`: `MacDock iOS Lifecycle Experiment`
- `CFBundleExecutable`: `LifecycleExperiment`
- `CFBundlePackageType`: `APPL`
- `CFBundleShortVersionString`: `0.1.0`
- `CFBundleVersion`: `1`
- `LSRequiresIPhoneOS`: `true`

The bundle was intentionally unsigned in these validation builds. No personal Team ID, provisioning profile, certificate, or device identifier is tracked.

### Based on Apple documentation

Apple documents SwiftUI scene phases and UIKit lifecycle transitions, but background execution may be suspended or terminated. Apple documents `UIApplication.isIdleTimerDisabled` as an app-controlled idle-timer setting and recommends restoring the default when it is no longer needed.

These platform facts support the foreground-only product boundary and the lifecycle-scoped policy. They do not establish physical screen-on duration, battery impact, thermal behavior, or continued network availability.

### Not tested or not measured

- A controlled rapid-transition stress test.
- Battery consumption or thermal measurements.
- Network connection survival or suspension during backgrounding; this experiment contains no networking implementation.
- Guaranteed cleanup after unexpected process termination.
- A precise screen-on observation duration or long-term screen-on reliability.

The physical-device observations above are maintainer-reported and are not independent tool verification. Background event capture was not provided, so the report does not claim a captured background event screenshot.

## Physical-device test plan

The following scenarios were used for physical validation; the results are recorded above:

1. Launch with Keep Screen Awake OFF.
2. Enable and disable the toggle in the foreground.
3. Enable it, send the app to background, and return to foreground.
4. With the setting ON, manually lock and unlock the iPhone.
5. Observe the screen for a short controlled period without interaction.
6. A rapid-transition stress test remains untested.

Do not run unattended battery-drain tests. Do not claim screen-on duration, thermal, or network results without observing them on the device.

## UX recommendation

Keep Screen Awake should be an explicit, visible, reversible setting in the Dock experience. It should explain that it may increase battery use, display wear, and heat. It must default OFF, never activate silently, and show the distinction between the user's preference and the currently applied state.

The feature should not be used to imply background availability. The interactive Dock remains supported only while the iOS app is foreground active.

## Production acceptance criteria

Before production adoption:

1. Physical iPhone tests confirm the remaining lifecycle and UI cases, including rapid transitions where required.
2. The idle timer is restored on disable and applicable inactive/background transitions.
3. Returning foreground reapplies the explicit user preference without stale state.
4. Manual device locking remains possible.
5. No unsupported background mode or private API is required.
6. Battery and thermal messaging is reviewed against actual device observations.
7. Connection behavior remains truthful: background networking is not promised without a separate validated design.

## Conclusion

The experiment is directly buildable, the pure lifecycle policy is covered by automated tests, and the maintainer-reported physical evidence confirms the core opt-in foreground behavior. Battery/thermal impact, background networking, rapid-transition stress, termination cleanup, and precise screen-on duration remain outside the verified evidence. No production Dock UI, background execution, or networking implementation was added.
