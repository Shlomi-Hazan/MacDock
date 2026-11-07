# MacDock Product Requirements

## Product purpose and positioning

MacDock is a local-first, secure Mac Control Center: a native Mac companion and a foreground-operated iPhone application for controlling and observing one Mac from one iPhone on the same local network. The product combines a customizable application Dock with explicitly authorized, privacy-conscious Mac controls.

The iPhone is a user-operated control surface, not a general remote-administration client. The MVP requires no cloud account or cloud service and does not promise operation while the iOS application is backgrounded.

## Operating context and primary journey

The supported MVP relationship is one Mac and one iPhone. The user installs the Mac companion, opens MacDock on the iPhone, discovers a candidate Mac, completes a reviewed two-sided pairing flow, and reaches an authenticated session. Discovery, transport readiness, authentication, and authorization are distinct states.

After setup, the user can configure a Dock, launch or activate supported applications, inspect supported Mac status, and invoke explicitly enabled controls. Each sensitive operation is visible, bounded, and independently rejectable. The UI must report `Unavailable`, `Unsupported`, `Denied`, `Stale`, `Failed`, and `Unknown` instead of inventing success.

The iOS application remains foreground-operated in the MVP. Background execution, cloud access, arbitrary shell execution, and unrestricted remote administration are outside the product boundary.

## Approved MVP feature groups

### F1 — Core Dock

Minimum scope: discover supported Mac applications, display names and icons, add/remove/reorder Dock items, persist the configuration, and request launch or activation for supported logical application identifiers.

User-visible behavior: the user edits the Dock on the iPhone and receives `Submitted`, `Acknowledged`, `Process observed`, `Activation requested`, `Frontmost observed`, `Failed`, `Unsupported`, or `Unknown` outcomes as applicable.

Permissions and boundaries: operations require an authenticated session and capability authorization. The Mac resolves logical IDs against its current catalog. No arbitrary paths, shell commands, unrestricted process control, or raw directories cross the wire.

Acceptance criteria: Dock membership/order survives supported relaunch and reconnection; launch and activation failures preserve configuration; unsupported or unverifiable outcomes are truthful.

Unverified assumptions: catalog source, icon representation, supported application classes, activation observability, and distribution permissions require implementation evidence.

### F2 — System Audio

Minimum scope: adjust and display the supported Mac output volume and mute state.

Non-goals: microphone access, audio capture, and mandatory per-application volume control.

The UI must handle output-device changes, unsupported controls, denied access, and unknown state. Acceptance requires bounded, authorized operations and state refresh after device changes. Per-device and system-wide behavior is a feasibility dependency, not an assumption.

### F3 — Music and Media

Minimum scope: display supported Now Playing metadata and provide play/pause and next/previous controls only for explicitly validated player integrations.

Non-goals: universal control of every player, undocumented/private MediaRemote APIs, media capture, and background playback management.

Unsupported players and unavailable metadata must be visible. Acceptance requires a documented support matrix, truthful command outcomes, and no fallback that silently controls an unintended player.

### F4 — Network Information

Minimum scope: display validated download/upload statistics and optionally offer a user-initiated, bounded speed test only after feasibility validation.

The product must distinguish MacDock traffic from interface/system-wide telemetry. A speed test must disclose duration and data budget, require explicit consent, stop deterministically, and never run silently or in the background. Whole-system statistics and suitable public APIs remain conditional requirements.

Acceptance requires measurement provenance, stale/unavailable states, bounded resource use, and privacy review. No claim of whole-system throughput is valid until supported by evidence.

### F5 — Battery Monitoring

Minimum scope: show Mac battery/charging state where applicable, the iPhone application's own battery state using supported APIs, and supported peripheral battery telemetry only when legitimately available.

Desktop Macs without batteries and unavailable peripherals must display `Unavailable`, `Unsupported`, or `Stale`. The MVP does not promise universal AirPods, Bluetooth, USB, or accessory coverage.

Acceptance requires source and freshness semantics, no personal hardware identifiers in logs, and graceful handling of unavailable telemetry.

### F6 — Touchpad

Minimum scope: a foreground iPhone touch surface for supported Mac pointer movement and primary click.

Additional gestures are conditional on feasibility. Control is disabled by default, visibly enabled, explicitly authorized, and revocable. No hidden background pointer control, user-input monitoring, recording, or screen capture is allowed.

Acceptance requires validated macOS permission behavior, bounded event handling, cancellation on disconnect, and no replay after reconnect.

### F7 — Keyboard

Minimum scope: user-initiated constrained text insertion from the iPhone.

Non-goals: unrestricted key-event injection, keylogging, keyboard capture, password interception, Secure Input bypass, or guaranteed support for every application/layout.

The feature requires explicit permission, visible enabled state, short-lived/revocable authorization, and truthful rejection for protected or unsupported contexts. Acceptance is conditional on physical and distribution validation of Accessibility/Input Monitoring and Secure Input behavior.

### F8 — Clipboard Transfer

Minimum scope: explicit, one-shot text transfer in either direction using supported pasteboard APIs.

The baseline does not continuously poll or synchronize the clipboard. Transfers require meaningful user intent, operation-level authorization, content-type and size limits, expiration where appropriate, and visible direction/status. Rejection, privacy restriction, and unavailable states are first-class outcomes.

Acceptance requires privacy review, no silent repeated transfer, deterministic cancellation, and no retention beyond the documented operation boundary.

## Functional requirements

- **FR-1 Discovery and pairing:** discover one candidate Mac and complete a reviewed two-sided pairing flow; discovery and QR data are not authentication by themselves.
- **FR-2 Authenticated session:** expose no control capability before peer authentication, session freshness, and authorization gates pass.
- **FR-3 Capability authorization:** negotiate only supported capabilities; deny by default and keep sensitive grants separate from session authentication.
- **FR-4 Connection lifecycle:** distinguish discovery, transport, authentication, authorization, disconnected, reconnecting, failed, and cancelled states.
- **FR-5 Core Dock:** satisfy F1 with logical application IDs and truthful outcomes.
- **FR-6 Audio:** satisfy F2 only for validated output-device operations.
- **FR-7 Media:** satisfy F3 only for documented player integrations.
- **FR-8 Network:** satisfy F4 with explicit provenance and bounded speed-test behavior.
- **FR-9 Battery:** satisfy F5 with availability/freshness semantics.
- **FR-10 Pointer:** satisfy F6 with explicit high-risk authorization and cancellation.
- **FR-11 Keyboard:** satisfy F7 with constrained insertion and protected-context failure.
- **FR-12 Clipboard:** satisfy F8 with one-shot consent and bounded content handling.
- **FR-13 Foreground operation:** communicate that the interactive iPhone surface is supported in the foreground only.
- **FR-14 Recovery:** preserve local configuration, invalidate sensitive grants on session change, and never automatically replay non-idempotent operations.

## Nonfunctional requirements

- **Security:** authenticated transport and peer identity are separate from operation authorization; no unreviewed cryptographic construction is accepted by this document.
- **Privacy:** local-first operation, minimal telemetry, no exporter/private-key logging, explicit clipboard direction, and no hidden input monitoring.
- **Reliability:** bounded timeouts, deterministic cancellation, stale-callback rejection, idempotent reads where possible, and no replay of launch/input/clipboard operations after uncertain delivery.
- **Accessibility:** core Dock and status views must be accessible; privileged Mac permissions must be explained before activation.
- **Performance:** control surfaces should provide immediate local acknowledgement while preserving truthful remote outcomes; targets require later measurement.
- **Maintainability:** every feature maps to a feasibility result, Issue, security gate, tests, and documented platform limitation.

## State glossary and errors

`Discovered` means an untrusted candidate is visible. `Transport ready` means a connection exists. `Authenticated` means the reviewed peer proof succeeded. `Authorized` means the requested capability/operation is currently permitted. None of these states implies the next one.

User-visible errors include `No Mac found`, `Not paired`, `Pairing rejected or expired`, `Disconnected`, `Reconnecting`, `Permission required`, `Denied`, `Unsupported`, `Unavailable`, `Stale`, `Timed out`, `Operation failed`, `Unknown result`, and `Foreground required`. Recovery must be bounded and must not silently elevate trust or replay a sensitive operation.

## MVP acceptance criteria

The expanded MVP is complete only when:

1. One iPhone and one Mac complete reviewed peer authentication and explicit authorization without relying on discovery as trust.
2. Core Dock behavior, launch/activation outcome semantics, and persistence are validated.
3. Each F2–F8 capability has an explicit support matrix, permissions, denied/unsupported states, tests, and documented limitations.
4. High-risk input and clipboard operations require visible, revocable, operation-appropriate authorization.
5. Disconnect, reconnect, stale callbacks, lost acknowledgments, duplicate delivery, revocation, and changed-peer cases are tested without unsafe replay.
6. Privacy, accessibility, physical-device, distribution, and foreground-only limitations are documented.

## Requirements versus assumptions

Requirements define intended product behavior. They do not prove API feasibility. The following remain evidence questions: universal media control, whole-system network telemetry, speed-test implementation, peripheral battery coverage, Accessibility/Input Monitoring distribution, Secure Input behavior, and iOS/macOS clipboard privacy behavior. Current-SDK compilation is not minimum-OS runtime validation.

## Open product decisions

- Exact minimum OS versions, distribution model, and App Sandbox/entitlement posture.
- Supported media-player matrix and whether speed testing ships in the first public build.
- Acceptable partial battery coverage and stale-data thresholds.
- Whether constrained keyboard input is included in the first public release despite permission and protected-context limitations.
- Accessibility/Input Monitoring UX and distribution acceptability for pointer/keyboard.
- Clipboard content types, maximum size, expiration, and user-confirmation wording.
- Final pairing construction, transcript, identity algorithm, revocation, and recovery, subject to ADR 0003 review.

## Explicitly out of scope

- Public-internet remote control, cloud accounts, or cloud synchronization.
- Arbitrary shell execution, unrestricted administration, arbitrary paths, or privilege escalation.
- Multi-Mac or multi-iPhone pairing.
- Guaranteed always-on iOS background operation.
- Hidden pointer/keyboard control, keylogging, screen capture, or Secure Input bypass.
- Automatic continuous clipboard monitoring.
- Private Apple APIs or unverified universal media/player/peripheral support.
