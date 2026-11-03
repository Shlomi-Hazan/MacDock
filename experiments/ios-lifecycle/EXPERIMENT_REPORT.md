# Experiment Report: iOS Lifecycle and Keep Screen Awake

- Issue: [#8](https://github.com/Shlomi-Hazan/MacDock/issues/8)
- Status: Stage 0 feasibility experiment; physical-device validation pending
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

### Not tested yet

- Installation and launch on the physical iPhone.
- Actual screen remaining awake while the setting is ON.
- Manual lock/unlock behavior with the setting ON.
- Background, inactive, and rapid transition observations on the physical device.
- Preference restoration after returning to foreground on physical hardware.
- Battery or thermal measurements.
- Network connection survival or suspension during backgrounding.
- Unexpected process termination cleanup.

## Physical-device test plan

After installing the signed experiment on the target iPhone:

1. Launch with Keep Screen Awake OFF. Expected: lifecycle becomes `Foreground active`, preference OFF, idle timer currently disabled `NO`.
2. Enable the toggle. Expected: preference ON and applied state `YES` while foreground active. Observe the screen for a short controlled period only; record the actual result.
3. Disable the toggle. Expected: applied state returns to `NO` immediately while preference is OFF.
4. Enable it again, send the app to background, and return to foreground. Expected: background/inactive events show applied state `NO`; on return, preference remains ON and applied state becomes `YES`.
5. With the setting ON, manually lock and unlock the iPhone. Expected: manual locking remains possible; record actual lifecycle and applied-state events after unlock.
6. Repeat foreground/background transitions rapidly. Expected: no stale event should leave the applied state inconsistent with the latest lifecycle and preference.

Do not run unattended battery-drain tests. Do not claim screen-on duration, thermal, or network results without observing them on the device.

## UX recommendation

Keep Screen Awake should be an explicit, visible, reversible setting in the Dock experience. It should explain that it may increase battery use, display wear, and heat. It must default OFF, never activate silently, and show the distinction between the user's preference and the currently applied state.

The feature should not be used to imply background availability. The interactive Dock remains supported only while the iOS app is foreground active.

## Production acceptance criteria

Before production adoption:

1. Physical iPhone tests confirm correct toggle and lifecycle behavior.
2. The idle timer is restored on disable and applicable inactive/background transitions.
3. Returning foreground reapplies the explicit user preference without stale state.
4. Manual device locking remains possible.
5. No unsupported background mode or private API is required.
6. Battery and thermal messaging is reviewed against actual device observations.
7. Connection behavior remains truthful: background networking is not promised without a separate validated design.

## Conclusion

The experiment is directly buildable and the pure lifecycle policy is covered by automated tests. The target is prepared for physical installation, but Issue #8 remains Blocked until the maintainer performs the physical iPhone lifecycle and screen behavior tests. No production Dock UI, background execution, or networking implementation was added.
