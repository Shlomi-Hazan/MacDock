# macOS Application Discovery Experiment

This isolated Stage 0 experiment evaluates a bounded, native macOS application-discovery strategy for MacDock. It is not production MacDock code and does not launch, activate, terminate, or modify applications.

## Requirements

- macOS on Apple Silicon or Intel.
- Swift 6 / Xcode 26 or a compatible Swift toolchain supporting Swift tools version 6.0.

No third-party dependencies are required.

## Build, test, and run

From this directory:

```sh
swift test
swift build
swift run MacOSAppDiscovery
```

The executable scans only these explicit roots when they exist:

- `/Applications`
- `/System/Applications`
- `/System/Library/CoreServices`
- `~/Applications`

It prints aggregate counts only. It intentionally does not print application paths, user directory names, or full application inventories.

## What the experiment demonstrates

- Bounded discovery of `.app` bundles using Foundation file enumeration and AppKit bundle/icon metadata.
- Bundle metadata extraction without launching applications.
- A deterministic installation identity composed from the bundle identifier, when available, and a SHA-256 digest of the canonical installation URL. This is an internal experiment key, not an approved privacy-preserving network identifier.
- Running-state enrichment from `NSWorkspace.runningApplications`.
- Graceful classification of incomplete metadata instead of crashing.

The experiment does not prove that every discovered candidate is launchable. It does not test application launch or activation; those belong to Issue #7.

## Privacy and sandbox notes

The internal canonical URL is used only during local discovery and is not included in the public metadata model. The experiment's unsalted path digest is deterministic but predictable paths can be tested by dictionary attack; it must not be called inherently private or exposed as a production wire identifier. A future authenticated protocol should expose only an approved identifier, display name, icon representation, availability, and running state, and only after pairing authorization.

Production identity options remain design work:

- A random opaque application ID stored in a local registry provides strong non-linkability, but requires durable local persistence, migration when an app moves, and recovery when the registry is lost.
- A locally keyed HMAC of a canonical installation identity avoids exposing the raw path and remains deterministic on one Mac, but requires protected key lifecycle, rotation/migration handling, and careful treatment of reinstall or device replacement.

Neither option is implemented by this experiment.

This package was run as an unsandboxed command-line experiment. App Sandbox behavior, security-scoped bookmarks, Mac App Store distribution, and the exact entitlement set for a production companion remain unverified and are not claimed here.
