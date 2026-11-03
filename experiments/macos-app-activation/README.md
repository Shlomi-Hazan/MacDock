# macOS Launch and Activation Experiment

This isolated Stage 0 experiment evaluates native AppKit launch and activation behavior. It is local-only and is not a production MacDock control endpoint.

## Requirements

- macOS on Apple Silicon or Intel.
- Swift 6 / Xcode 26 or a compatible Swift toolchain supporting Swift tools version 6.0.

No third-party dependencies are required.

## Build and test

From this directory:

```sh
swift test
swift build
```

## Safe commands

The default target is `/System/Applications/Calculator.app`. Use an explicit target only when it is a harmless application and its current state has been checked first.

```sh
swift run MacOSAppActivation --status
swift run MacOSAppActivation --launch
swift run MacOSAppActivation --activate
swift run MacOSAppActivation --missing --target /System/Applications/MacDock-Missing.app
swift run MacOSAppActivation --status --target /System/Applications/Calculator.app
```

The experiment never uses a shell to launch an app, never sends Apple Events, never changes system permissions, and never terminates an application. `--launch` refuses to issue a launch request when the target is already running; `--activate` refuses to issue activation when no matching process is running.

## Outcome semantics

The output keeps these observations separate:

1. Request outcome: completion handler acceptance or rejection from AppKit.
2. Process observation: whether a matching `NSRunningApplication` is seen after bounded polling.
3. Foreground observation: whether `NSWorkspace.frontmostApplication` matches the target process.

An accepted launch is not reported as confirmed foreground readiness. Startup is asynchronous and may outlive the launch completion callback.

## Privacy and permissions

Output contains only operation states and sanitized error text. It does not print filesystem paths beyond the explicit command input. The experiment does not request Accessibility, Automation, Full Disk Access, or other broad permissions. This unsandboxed run does not prove that a future sandboxed or distributed companion will have identical behavior.
