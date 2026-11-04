# MacDock

MacDock is an independent, native Apple-platform application that turns an iPhone into a customizable Dock and control surface for a Mac over a local network.

## Project status

MacDock has completed Stage 0 with a maintainer-approved Conditional Go and is beginning Stage 1: architecture and foundation. The current production foundation contains only inert native application shells; networking, pairing, application inventory, Dock synchronization, launch, and activation are not implemented.

The shared foundation package is located at `MacDockShared/`. It contains only Foundation-compatible models and pure logic shared by the native targets. Run its tests with:

```sh
swift test --package-path MacDockShared
```

The initial MVP targets one Mac and one iPhone. The interactive Dock is expected to operate while the iOS application is in the foreground. The first MVP focuses on securely pairing the devices, displaying a customizable set of Mac applications, and launching or activating those applications from the iPhone.

Touchpad, keyboard, media controls, clipboard synchronization, and other advanced capabilities are intentionally out of scope for the initial MVP.

## Local development

The initial native foundation is organized as an Xcode workspace containing two independent application projects:

- `MacDockMac/MacDockMac.xcodeproj` — macOS menu bar companion shell.
- `MacDockiOS/MacDockiOS.xcodeproj` — foreground-only iOS SwiftUI shell with truthful `Active`, `Inactive`, and `Background` scene status.

Open `MacDock.xcworkspace` in Xcode. For signing-safe command-line validation, use the project targets directly and disable signing for generic iOS builds when a local development team is not configured:

```sh
xcodebuild -workspace MacDock.xcworkspace -list
xcodebuild -project MacDockMac/MacDockMac.xcodeproj -target MacDockMac -configuration Debug build
xcodebuild -project MacDockiOS/MacDockiOS.xcodeproj -target MacDockiOS -configuration Debug -sdk iphonesimulator CODE_SIGNING_ALLOWED=NO build
```

Development signing remains local. Do not commit Team IDs, provisioning profiles, certificates, or device identifiers.

For graphical validation, select the `MacDockMac` scheme and `My Mac` in Xcode to confirm the menu bar shell appears, then use `Quit MacDock`. Select `MacDockiOS` with an available simulator or locally signed development device to confirm the placeholder screen and its scene lifecycle status. These checks do not enable any production networking, background execution, or control behavior.

## Continuous integration

Pull requests and pushes to `main` run the following validation:

- `Repository Integrity` checks the change range, required foundation files, and sensitive file names.
- `Foundation Validation / swift-package-tests` runs the complete `MacDockShared` test suite on a hosted macOS runner.
- `Foundation Validation / native-build-*` builds macOS Debug/Release and iOS Simulator/generic-device Debug/Release targets with signing disabled.
- `Foundation Validation / secret-scan` runs the pinned Gitleaks Action without PR comments or uploaded artifacts.

CI compilation does not prove physical-device installation or runtime behavior. Use the local commands above and the manual validation plans under `docs/testing/` for those checks. The hosted workflow reports its Xcode and Swift toolchain versions so runner updates remain visible.
Action dependencies are pinned to reviewed immutable commit SHAs; upgrades require release/tag verification and a review of permissions and behavior.

## Development principles

- Native Swift and SwiftUI development.
- Local-first communication using Apple platform APIs.
- Security and privacy by design.
- Public, issue-driven development through pull requests.
- Experiments are kept separate from production components.
- Decisions are documented and verified against implementation reality.

## Documentation

- [Product requirements](PRD.md)
- [Roadmap](ROADMAP.md)
- [Contributing](CONTRIBUTING.md)
- [Security](SECURITY.md)
- [AI and development-agent guidance](AGENTS.md)
- [Development workflow](docs/DEVELOPMENT_WORKFLOW.md)
- [Research notes](docs/research/)
- [Architecture decisions](docs/decisions/)

## License

MacDock is licensed under the MIT License. See [LICENSE](LICENSE).
