# MacDock Product Requirements

## Purpose

MacDock provides an iPhone-based Dock for launching and activating applications on a paired Mac over the local network.

## Primary user and operating context

The primary user operates one Mac and one iPhone on the same local network. The Mac runs the MacDock companion application, and the iPhone runs the MacDock app in the foreground. The initial MVP does not require a cloud account or a cloud service.

The Dock is a focused control surface, not a replacement for the macOS Dock or a general remote-control suite.

## Primary user journey

1. The user installs and opens the MacDock companion on the Mac.
2. The user opens MacDock on the iPhone and starts setup.
3. The iPhone discovers an available Mac on the local network.
4. The user confirms pairing on both devices through a user-confirmed flow. QR code setup is preferred for convenience, but the QR payload is not authentication by itself.
5. After pairing, the iPhone displays the Mac's available applications and an initial Dock.
6. The user selects applications, adds or removes Dock items, and reorders them.
7. The user taps an item to request launch or activation on the Mac.
8. The iPhone displays connection, progress, success, or recoverable error state.

If the iOS app leaves the foreground, the interactive Dock is not required to remain available in the MVP. The app must clearly communicate this limitation during onboarding and when the connection is interrupted.

## Product use cases

### Pair one iPhone with one Mac

The user can identify the intended Mac, approve pairing on the participating devices, and reach a connected state without relying on local-network reachability as authentication.

### Configure the Dock

The user can view available Mac applications, add an application to the Dock, remove an existing item, and reorder items. The resulting order and membership persist for the paired user and Mac within the MVP.

### Launch an application

The user can tap a Dock item and receive a visible result. If the application is not running, MacDock requests launch. If launch is unavailable or fails, the user receives an actionable error without losing the Dock configuration.

### Activate an application

When the application is already running and the platform permits activation, MacDock requests activation or focus. If activation cannot be performed or verified, the user receives an explicit state rather than a false success.

### Recover from connection interruption

The user can distinguish disconnected, reconnecting, connected, and failed states. MacDock may retry ordinary interruptions and must provide a clear way to retry or re-pair when recovery is not possible.

## Functional requirements

### FR-1: Device discovery and pairing

The iPhone can discover one intended Mac on the local network and the user can approve a secure pairing flow on both devices. Discovery is not authentication. The product must not present a device as trusted solely because it answered discovery.

### FR-2: Connection lifecycle

The iPhone displays at least `disconnected`, `discovering`, `pairing`, `connected`, `reconnecting`, and `error` states as applicable. State changes must not silently discard the user's Dock configuration.

### FR-3: Application catalog

The Mac provides a user-facing list of applications that MacDock is permitted and able to launch. The iPhone can display a stable identity and user-readable name for each listed application. The exact catalog source and permission model remain Stage 0 validation topics.

### FR-4: Dock customization

The user can add, remove, and reorder applications. The UI provides confirmation through the resulting Dock state, and persisted configuration survives ordinary app relaunch and reconnection within the supported one-Mac/one-iPhone relationship.

### FR-5: Launch

Tapping an application requests launch on the Mac. The UI communicates progress and a verified success or failure state. A failed request must not corrupt the Dock configuration.

### FR-6: Activation

When technically supported and permitted, tapping an already-running application requests activation or focus. The product must distinguish verified activation from an unsupported, denied, or unknown result.

### FR-7: Foreground operation

The interactive iPhone Dock is supported while the iOS app is in the foreground. The product does not promise an always-on background Dock in the MVP.

### FR-8: Recovery

After an ordinary local-network interruption, the app presents reconnecting/reconnected state when recovery succeeds, and an actionable error when it does not. Pairing data is retained unless the user explicitly removes trust or recovery requires re-pairing.

## Nonfunctional requirements

- **Security:** pairing must include explicit peer authentication and encrypted communication appropriate to the final validated design. QR data, Bonjour, and local-network access alone are insufficient authentication.
- **Privacy:** the MVP is local-first, sends no application-control data to a cloud service, and avoids exposing unnecessary application names, identifiers, or payloads in logs.
- **Reliability:** ordinary connection interruptions must result in an explicit state and a bounded recovery path rather than an indefinite spinner.
- **Responsiveness:** common Dock interactions should provide immediate local feedback while the Mac operation is pending; exact latency targets require measurement during later validation.
- **Accessibility:** core Dock actions and connection/error states must be usable with supported iOS accessibility features before release.
- **Maintainability:** requirements and later technical decisions must remain traceable to Issues, ADRs, tests, and verified implementation behavior.

## Product constraints

- The iPhone Dock is interactive while the iOS application is in the foreground.
- QR code discovery or setup is preferred, but a QR code is not authentication by itself.
- The first release supports one Mac and one iPhone.
- Communication is local-first; no cloud service is required for the MVP.
- A Mac companion application must be installed and available for pairing and control.
- Keep Screen Awake may be offered as an optional user-controlled iPhone setting if supported behavior, battery impact, thermal behavior, and idle-timer restoration are validated. It is not required for the baseline MVP.

## MVP acceptance criteria

The MVP product baseline is accepted when all of the following are true in a validated implementation:

1. A user can discover and securely pair one iPhone with one intended Mac through a user-confirmed flow.
2. The iPhone clearly communicates the connection lifecycle and does not treat discovery as trust.
3. The user can view the supported Mac application catalog and create a Dock by adding, removing, and reordering items.
4. Dock configuration remains intact across ordinary reconnection and supported app relaunch scenarios.
5. A user tap produces a visible launch result, or a truthful actionable failure state.
6. Already-running application activation is reported truthfully as successful, unsupported, denied, or unknown according to validated platform behavior.
7. The foreground-only limitation is communicated and no unsupported background guarantee is made.
8. Security, privacy, accessibility, and recovery validation results are documented before the MVP is declared complete.

## Product states and user-visible errors

| State or error | User-visible meaning | Expected recovery |
| --- | --- | --- |
| No Mac found | No eligible Mac is currently discoverable | Check local network and retry discovery |
| Mac found, not paired | A Mac is available but not trusted | Start and confirm pairing on both devices |
| Pairing rejected or expired | Pairing was not completed or its confirmation window ended | Retry pairing; do not silently trust the device |
| Disconnected | The trusted connection is unavailable | Retry or wait for reconnecting state |
| Reconnecting | MacDock is attempting bounded recovery | Wait, retry, or open recovery guidance |
| Application unavailable | The selected app is no longer available or permitted | Refresh the catalog and choose another item |
| Launch failed | The Mac did not confirm a successful launch | Retry and preserve Dock configuration |
| Activation unsupported or unknown | Running-app activation cannot be guaranteed | Inform the user without claiming success |
| Foreground required | The iOS app is not in the supported foreground state | Return to MacDock on the iPhone |

## Requirements versus assumptions to validate

The requirements above define intended user-visible behavior. The following are assumptions, not commitments, until validated by Stage 0 research:

- Bonjour and Network.framework provide the required local discovery and transport behavior under current Apple permissions and platform versions.
- The selected secure pairing design can provide mutual user confirmation, peer authentication, key storage, encrypted transport, expiration, and recovery without unacceptable UX friction.
- The Mac can produce a useful application catalog with stable identity, display name, icon representation, and launch eligibility.
- macOS APIs and permissions allow reliable launch and activation/focus behavior for the supported application classes.
- The iPhone can maintain the required foreground experience and optionally control the idle timer without harmful battery or thermal behavior.
- The chosen persistence boundary is sufficient for one Mac and one iPhone without prematurely designing multi-device synchronization.
- The proposed connection states and retry behavior can be made deterministic enough for testing.

Stage 0 research Issues own the evidence and limitations for these assumptions. No assumption should be treated as an API guarantee until documented and verified.

## Open product decisions

- Which macOS and iOS minimum versions are supported?
- Which application classes are included in the initial catalog, and how are duplicates or unavailable apps represented?
- What exact user-visible behavior is required when launch or activation returns an unknown result?
- Should the MVP include optional Keep Screen Awake, and what user setting, battery messaging, and restoration behavior are acceptable?
- What is the preferred recovery path after a trusted pairing becomes invalid or a Mac is reinstalled?
- Which accessibility and localization requirements are release blockers for the first public build?

## Out of scope for the MVP

- Touchpad input.
- Keyboard input.
- Media and volume controls.
- Clipboard synchronization.
- Multiple Mac support.
- Profiles, groups, and advanced visual customization.
- Always-on background Dock behavior on iOS.
- Cloud accounts, remote access over the internet, and multi-user synchronization.
