# Stage 1 Foundation Validation

- Issue: [#24](https://github.com/Shlomi-Hazan/MacDock/issues/24)
- PR: [#31](https://github.com/Shlomi-Hazan/MacDock/pull/31)
- Scope: native application shells only

## Automated validation

- `xcodebuild -workspace MacDock.xcworkspace -list`: passed.
- macOS Debug and Release builds with signing disabled: passed.
- iOS Simulator Debug and Release builds with signing disabled: passed.
- Generic iOS device Debug and Release builds with signing disabled: passed.
- Built bundle metadata was inspected with `plutil`.
- `git diff --check` and Repository Integrity CI passed.

The build matrix validates project parsing, compilation, bundle generation, and metadata. It does not prove graphical runtime behavior.

## Maintainer-reported manual validation

The following observations were reported by the maintainer after running the targets from Xcode. They were not automated tests:

### macOS

- The application launched successfully from Xcode.
- The MacDock icon appeared in the menu bar.
- The menu displayed `MacDock Foundation` and `Companion shell ready`.
- `Quit MacDock` terminated the application successfully.

### iOS

- The application launched successfully on a physical iPhone.
- The expected MacDock icon, title, and `Foreground foundation shell` placeholder appeared.
- No visible runtime error was observed.

These observations do not validate networking, pairing, authentication, persistence, Dock behavior, application inventory, launch/activation, or security functionality.

## Issue #28 lifecycle-shell manual validation plan

The following checks are prepared for maintainer execution and are not claimed as completed by automated builds:

### macOS

1. Run `MacDockMac` from Xcode on `My Mac`.
2. Verify that the MacDock menu bar item appears.
3. Open the menu and verify the local foundation status remains visible.
4. Select `Quit MacDock` and verify that the application exits.

### iOS

1. Run `MacDockiOS` in a simulator or on a locally signed development iPhone.
2. Verify the placeholder screen shows `Lifecycle: Active` while the app is foregrounded.
3. Move the app to the Home Screen and verify that the displayed state can become `Inactive` or `Background`.
4. Return to MacDock and verify that `Lifecycle: Active` is restored.
5. On a physical iPhone, optionally lock and unlock the device and verify the observed lifecycle state after returning.

These checks validate presentation of the application lifecycle only. They do not validate network connection survival, background execution, pairing, Keep Screen Awake, or any application-control behavior.

### Maintainer-reported Issue #28 observations

The maintainer later completed the graphical checks above. These are manual observations, not tool-executed tests:

- macOS: `MacDockMac` launched, the menu bar item appeared, the foundation status remained visible, and `Quit MacDock` terminated the application.
- iOS: `MacDockiOS` launched, `Lifecycle: Active` appeared, returning from the Home Screen restored `Lifecycle: Active`, and no visible runtime error was reported.

These observations do not demonstrate background execution, network connection survival, pairing, Keep Screen Awake behavior, or any production control capability.

## Signing and privacy

Development signing remains local. The repository contains no Team ID, provisioning profile, certificate, device identifier, credential, or private path. Xcode-generated local signing changes must not be committed.
