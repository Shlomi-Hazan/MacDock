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

## Signing and privacy

Development signing remains local. The repository contains no Team ID, provisioning profile, certificate, device identifier, credential, or private path. Xcode-generated local signing changes must not be committed.
