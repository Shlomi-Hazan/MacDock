# Stage 0 Research: Apple Platform API Feasibility

- Status: Research baseline
- Date: 2026-11-03
- Issue: [#2](https://github.com/Shlomi-Hazan/MacDock/issues/2)
- Scope: Native API capability and permission analysis before production implementation

## Executive summary

MacDock's core interaction is technically plausible with native Apple frameworks, but documentation feasibility is not runtime proof. The strongest initial direction is:

- `Network.framework` with Bonjour service discovery through `NWBrowser`.
- `NWListener` on the Mac companion and `NWConnection` for an explicit application protocol.
- TLS configured through Network.framework, with peer authentication and trust decisions defined separately.
- `NSWorkspace` for application launch and `NSRunningApplication` for running-state inspection and activation attempts.
- Keychain-backed device trust, with CryptoKit for application-level cryptographic operations where required.
- SwiftUI/UIKit scene lifecycle with a foreground-only iPhone Dock for the MVP.

The following remain unproven until the related experiments run on the target Mac and iPhone: exact local-network permission behavior, Bonjour service visibility, TLS identity and trust UX, application catalog completeness and icon handling, application activation reliability, and the battery/thermal trade-off of optional Keep Screen Awake.

## Evidence classification

- **Documented:** directly supported by the linked Apple documentation.
- **Inference:** a constrained engineering conclusion derived from documented behavior; it is not a runtime result.
- **Experiment required:** must be tested on physical devices or a signed app because documentation does not establish the product behavior.
- **Not selected:** considered but deliberately not adopted as a design decision in this Issue.

## Supported platforms and version considerations

| Concern | Documented finding | MacDock implication | Classification |
| --- | --- | --- | --- |
| Local Network privacy | Apple documents Local Network privacy for iOS/iPadOS starting with iOS/iPadOS 14 and macOS starting with macOS 15. | The eventual minimum OS versions must be selected before entitlement and compatibility work. Until then, do not claim a minimum deployment target. | Documented; decision open |
| Network framework | Network.framework exposes `NWBrowser`, `NWListener`, `NWConnection`, TCP, TLS, UDP, and related protocol types. | It is a native candidate on both iOS and macOS for the local control channel. | Documented |
| AppKit control | `NSWorkspace` exposes application launch APIs; `NSRunningApplication` exposes running-app inspection and activation attempts. | The Mac companion can investigate these APIs without committing to Apple Events or Accessibility automation. | Documented |
| iOS lifecycle | UIKit scenes transition between foreground-active, inactive, background, and suspended states; SwiftUI exposes scene phase. | A foreground-only interactive Dock is compatible with the platform model. Background continuity must not be promised by the MVP. | Documented |
| Secure Enclave | Apple documents hardware and algorithm restrictions, including P-256 key use and device-local key behavior. | Secure Enclave may strengthen a device identity, but it is not automatically required for the first pairing design. | Documented; design decision open |

Sources: [TN3179: Understanding local network privacy](https://developer.apple.com/documentation/technotes/tn3179-understanding-local-network-privacy), [Network framework](https://developer.apple.com/documentation/network), [Managing your app's life cycle](https://developer.apple.com/documentation/uikit/managing-your-app-s-life-cycle), [Protecting keys with the Secure Enclave](https://developer.apple.com/documentation/security/protecting-keys-with-the-secure-enclave).

## API capability matrix

| Area | API or capability | iOS | macOS | Permissions / configuration | MacDock assessment |
| --- | --- | --- | --- | --- | --- |
| Discovery | `NWBrowser` with a Bonjour service descriptor | Supported candidate | Supported candidate | `NSLocalNetworkUsageDescription`; `NSBonjourServices` for declared Bonjour types | **Recommended candidate.** Issue #3 must verify service visibility, duplicate results, denial, and reconnect behavior. |
| Advertising | `NWListener` configured for a Bonjour service | Supported candidate | Supported candidate | Local Network privacy; declared Bonjour type; macOS signing identity considerations | **Recommended candidate** for the Mac companion. The exact service name and metadata are not selected here. |
| Transport | `NWConnection` over TCP or another Network.framework protocol | Supported candidate | Supported candidate | iOS local-network permission for local destinations; macOS App Sandbox network entitlements when sandboxed | **Recommended candidate.** Issue #4 must test lifecycle, path changes, framing, cancellation, and reconnect. |
| TLS | `NWProtocolTLS` / `NWParameters.tls` | Supported candidate | Supported candidate | Certificate/key handling and peer trust policy | **Supported capability, not a complete trust design.** TLS encryption does not by itself establish that the peer is the intended Mac or iPhone. |
| App catalog | `NSWorkspace` plus file and bundle metadata APIs | Not applicable | Supported candidate | App Sandbox file access may constrain paths; exact catalog source requires testing | **Recommended investigation.** Issue #6 must define scope, stable identity, display name, and icon representation. |
| Launch | `NSWorkspace.openApplication(at:configuration:completionHandler:)` | Not applicable | Supported candidate | App location and sandbox/signing behavior require validation | **Recommended candidate.** The completion result must not be treated as proof of user-visible readiness without experiment. |
| Running state | `NSWorkspace` and `NSRunningApplication` | Not applicable | Supported candidate | Application class and process lifecycle constraints | **Recommended candidate.** Instances can become stale after termination; Issue #7 must test state races. |
| Activation | `NSRunningApplication.activate(options:)` | Not applicable | Supported candidate | Activation policy and target app behavior | **Conditional only.** Apple documents a Boolean result, but activation and focus semantics require physical validation; do not promise universal focus. |
| Key storage | Keychain Services | Supported | Supported | Keychain accessibility/access groups and platform signing configuration | **Recommended for long-lived trust material.** Select restrictive accessibility and device-sync behavior deliberately. |
| Cryptography | CryptoKit | Supported candidate | Supported candidate | No special entitlement for ordinary framework use; key storage and trust remain separate | **Recommended where application cryptography is needed.** Do not invent a protocol before Issue #5. |
| Hardware-backed keys | CryptoKit `SecureEnclave` / Security framework Secure Enclave | Supported on compatible hardware | Supported on compatible hardware | Hardware, key type, access-control, and unlock constraints | **Optional hardening candidate.** Requires device experiments and a recovery story. |
| iOS lifecycle | SwiftUI `scenePhase`, UIKit scene/application lifecycle | Supported | Not applicable | No special entitlement for lifecycle observation | **Use to make foreground-only behavior explicit** and stop/restore transient work safely. |
| Keep Screen Awake | `UIApplication.isIdleTimerDisabled` | Supported candidate | Not applicable | User-facing setting and lifecycle restoration | **Optional product behavior.** The default is `false`; battery, thermal, and restoration behavior require Issue #8 testing. |

Primary references: [NWBrowser](https://developer.apple.com/documentation/network/nwbrowser), [NWListener](https://developer.apple.com/documentation/network/nwlistener), [NWConnection](https://developer.apple.com/documentation/network/nwconnection), [NWParameters](https://developer.apple.com/documentation/network/nwparameters), [NSWorkspace](https://developer.apple.com/documentation/appkit/nsworkspace), [NSWorkspace application launch](https://developer.apple.com/documentation/appkit/nsworkspace/openapplication%28at%3Aconfiguration%3Acompletionhandler%3A%29), [NSRunningApplication activation](https://developer.apple.com/documentation/appkit/nsrunningapplication/activate%28options%3A%29), [Keychain Services](https://developer.apple.com/documentation/security/keychain-services), [CryptoKit](https://developer.apple.com/documentation/cryptokit), [UIApplication idle timer](https://developer.apple.com/documentation/uikit/uiapplication/isidletimerdisabled).

## Local networking: permissions and limitations

### Local Network privacy

Apple documents that local-network operations, including Bonjour browsing, registering, and resolving services, are governed by Local Network privacy. Apps should include `NSLocalNetworkUsageDescription` with a user-facing explanation. Apps using specific Bonjour service types should declare them through `NSBonjourServices`.

The documented denial behavior is important for MacDock:

- An `NWBrowser` may enter a waiting state with a DNS policy-denied error.
- An `NWConnection` may enter `waiting` with `NWPath.UnsatisfiedReason.localNetworkDenied`.
- There is no general API that simply returns the current Local Network permission state.
- When permission changes, Network.framework can retry a waiting connection; this must be reflected in MacDock's state machine rather than hidden behind an indefinite spinner.

These findings are documented in [TN3179](https://developer.apple.com/documentation/technotes/tn3179-understanding-local-network-privacy), [NSLocalNetworkUsageDescription](https://developer.apple.com/documentation/bundleresources/information-property-list/nslocalnetworkusagedescription), and [NWConnection.State.waiting](https://developer.apple.com/documentation/network/nwconnection/state-swift.enum/waiting%28_%3A%29).

### Entitlements and declarations

| Target | Declaration or entitlement | Current assessment |
| --- | --- | --- |
| iOS app | `NSLocalNetworkUsageDescription` | Required when the app uses the local network; wording must explain pairing/control purpose. |
| iOS app | `NSBonjourServices` | Required for the specific Bonjour service types the app browses or registers. |
| iOS app | `com.apple.developer.networking.multicast` | Required for multicast/broadcast operations and some uncommon Bonjour use cases; do not request it before Issue #3 establishes that it is necessary. |
| macOS app | `com.apple.security.app-sandbox` | Required for Mac App Store distribution; its file and network restrictions must be designed around, not disabled casually. |
| macOS sandboxed app | `com.apple.security.network.client` | Allows outgoing network connections. |
| macOS sandboxed app | `com.apple.security.network.server` | Allows listening for incoming network connections. |
| macOS app | `com.apple.security.automation.apple-events` | Relevant only if the final design sends Apple events to other apps and the target distribution/signing model requires the entitlement. It is not a prerequisite for `NSWorkspace` launch itself. |

Sources: [Security entitlements](https://developer.apple.com/documentation/bundleresources/security-entitlements), [network client entitlement](https://developer.apple.com/documentation/bundleresources/entitlements/com.apple.security.network.client), [App Sandbox](https://developer.apple.com/documentation/security/app-sandbox), [Apple Events entitlement](https://developer.apple.com/documentation/bundleresources/entitlements/com.apple.security.automation.apple-events), [NSBonjourServices](https://developer.apple.com/documentation/bundleresources/information-property-list/nsbonjourservices).

## User-facing permission explanations

These are product copy candidates, not final localized strings:

- **iPhone Local Network:** “MacDock uses your local network to find and connect to your Mac. It does not send your Dock controls through a cloud service.”
- **Mac Local Network:** “MacDock uses your local network to accept connections from your paired iPhone and control the Mac locally.”
- **Mac automation, only if required:** “MacDock needs permission to send approved commands to the selected application in order to request activation. It does not grant access to unrelated applications or data.”
- **Keep Screen Awake:** “Keep Screen Awake keeps the Dock visible while you use it and may increase battery and device temperature. You can turn it off at any time.”

The exact permission prompts and whether a prompt appears depend on the final API path, target type, signing, OS version, and operation. Copy must not claim capabilities the implementation has not demonstrated.

## macOS application control

### Discovery and catalog

`NSWorkspace` is the native AppKit workspace interface and documents launching apps and interacting with file/application locations. The product still needs to define which applications are eligible, how aliases and multiple copies are represented, and how icons are obtained. App Sandbox may constrain access to arbitrary file locations; this is an inference requiring an experiment with installed applications in realistic locations.

### Launch

Apple documents `NSWorkspace.openApplication(at:configuration:completionHandler:)` as asynchronous and reports an `NSRunningApplication` on success or an error on failure. This provides a useful boundary for a launch request, but it does not define MacDock's complete success semantics. Issue #7 must distinguish command receipt, OS acceptance, process existence, and user-visible readiness.

### Activation and focus

Apple documents `NSRunningApplication.activate(options:)` as an attempt that returns `true` if activation succeeded and `false` if the app has quit or cannot be activated. Apple also documents cooperative activation and notes that an activation request does not guarantee activation in all contexts. Therefore, universal foreground focus is **not confirmed**. MacDock must report unsupported, denied, failed, or unknown outcomes honestly.

Apple Events and Accessibility automation are separate mechanisms with additional privacy and entitlement implications. They must not be introduced as a workaround without a specific experiment and security review.

References: [NSWorkspace](https://developer.apple.com/documentation/appkit/nsworkspace), [openApplication](https://developer.apple.com/documentation/appkit/nsworkspace/openapplication%28at%3Aconfiguration%3Acompletionhandler%3A), [NSRunningApplication.activate](https://developer.apple.com/documentation/appkit/nsrunningapplication/activate%28options%3A%29), [NSApplication cooperative activation](https://developer.apple.com/documentation/appkit/nsapplication/activate%28%29).

## Security capabilities and limits

### Keychain

Apple documents Keychain Services as encrypted storage for small secrets, keys, certificates, and identities. Keychain accessibility and synchronizability are independent design choices. MacDock should store long-lived peer trust material in the Keychain rather than in a plist or ordinary preferences, but the exact item class, accessibility, access group, and device-only policy belong to Issue #5.

References: [Keychain Services](https://developer.apple.com/documentation/security/keychain-services), [Keychain item attributes](https://developer.apple.com/documentation/security/item-attribute-keys-and-values), [restricting Keychain accessibility](https://developer.apple.com/documentation/security/restricting-keychain-item-accessibility).

### CryptoKit and Secure Enclave

CryptoKit provides documented primitives for hashing, authentication, symmetric encryption, signatures, and key agreement, and can work with Secure Enclave-backed keys. Secure Enclave is more restrictive: Apple documents hardware requirements, P-256 limitations, device-local private keys, and inability to import preexisting private keys into the enclave.

**Recommendation:** use Keychain as the baseline storage boundary and evaluate CryptoKit for the validated pairing protocol. Treat Secure Enclave as optional hardening, not a requirement that could block the one-Mac/one-iPhone MVP. A device identity must still have a recovery and re-pairing story.

References: [CryptoKit](https://developer.apple.com/documentation/cryptokit), [SecureEnclave.P256](https://developer.apple.com/documentation/cryptokit/secureenclave/p256), [Protecting keys with the Secure Enclave](https://developer.apple.com/documentation/security/protecting-keys-with-the-secure-enclave).

### TLS and peer authentication

Network.framework exposes TLS parameters and Apple documents a local-network TLS identity flow using certificates, a CA, and trust evaluation. This confirms that encrypted local transport is available; it does not choose MacDock's certificate, public-key, or trust-on-first-use model. A QR code can transport setup data, but it is not sufficient authentication without a user-confirmed and cryptographically verified trust step.

Reference: [Creating an Identity for Local Network TLS](https://developer.apple.com/documentation/network/creating-an-identity-for-local-network-tls).

## iOS lifecycle and Keep Screen Awake

UIKit documents that scenes move between foreground-active, inactive, background, and suspended states; SwiftUI exposes this through `scenePhase`. Background apps should do little work and may be suspended or terminated. The documented background modes do not justify an always-on interactive Dock for this product.

`UIApplication.isIdleTimerDisabled` can disable the idle timer, but Apple's documentation says the default is `false` and recommends resetting it to `false` when no longer necessary because of power conservation. The optional Keep Screen Awake feature therefore requires a user-controlled setting, lifecycle-safe restoration, battery/thermal testing, and an explicit decision in Issue #8.

References: [Managing your app's life cycle](https://developer.apple.com/documentation/uikit/managing-your-app-s-life-cycle), [Preparing your UI to run in the background](https://developer.apple.com/documentation/uikit/preparing-your-ui-to-run-in-the-background), [SwiftUI ScenePhase.background](https://developer.apple.com/documentation/swiftui/scenephase/background), [UIApplication idleTimerDisabled](https://developer.apple.com/documentation/uikit/uiapplication/isidletimerdisabled).

## Recommended direction and alternatives

### Recommended candidates

1. Bonjour service advertisement on the Mac and `NWBrowser` discovery on iPhone.
2. `NWListener`/`NWConnection` for a small explicit application protocol.
3. Network.framework TLS plus a separately defined peer-authentication/trust protocol.
4. `NSWorkspace` and `NSRunningApplication` as the first macOS launch/activation experiment surface.
5. Keychain for trust material and CryptoKit where the protocol needs explicit cryptographic operations.
6. SwiftUI/UIKit lifecycle state as the source for foreground-only behavior.

These are API recommendations, not a final architecture or production protocol decision.

### Alternatives and trade-offs

| Alternative | Benefit | Trade-off / current decision |
| --- | --- | --- |
| Multipeer Connectivity | Higher-level peer discovery/session model | Adds a different abstraction and Bonjour/security behavior to validate; not selected before Issue #3/#4 evidence. |
| `URLSession` | Mature HTTP/URL transport and connectivity waiting | Less direct fit for a small bidirectional local control protocol; not rejected for all designs, but not the leading candidate. |
| Raw BSD sockets | Low-level control | More lifecycle, framing, and security work than Network.framework; not preferred. |
| Apple Events/UI scripting for control | Could reach some app-specific behaviors | Adds automation/accessibility permissions and app-specific reliability/security risks; not a baseline requirement. |
| Secure Enclave for all identities | Hardware-backed private-key operations | Hardware, algorithm, unlock, backup, and recovery constraints; optional until tested. |

## Experiment questions by related Issue

This document intentionally does not perform these experiments or implement their systems.

- **Issue #3 — Bonjour discovery:** Which service type and metadata are visible on the target iPhone and Mac? How do denial, duplicate services, sleep/wake, Wi-Fi changes, and multiple interfaces appear?
- **Issue #4 — local transport and TLS:** Which listener/connection configuration survives real network changes? What framing, timeout, cancellation, TLS identity, and peer-verification behavior are observable?
- **Issue #5 — pairing threat model:** Which user-confirmed flow authenticates both peers, prevents relay/confusion, stores trust safely, expires setup data, and supports reset/re-pair?
- **Issue #6 — application discovery:** Which installed applications are visible under the intended sandbox/signing model? Can stable identity, display name, icon extraction, and launch eligibility be obtained for ordinary and edge-case apps?
- **Issue #7 — launch and activation:** What do launch completion, process existence, activation Boolean, active state, hidden state, and failure modes mean in practice? What happens if requests are made during disconnect/reconnect, and can delayed execution be prevented?
- **Issue #8 — iOS background limits and Keep Screen Awake:** What lifecycle events occur on the target device, what work survives backgrounding, and what are the battery/thermal effects and restoration requirements of `isIdleTimerDisabled`?
- **Issue #9 — architecture and ADRs:** Which findings justify stable module boundaries, message/state models, and ADRs without prematurely freezing implementation details?

## Risks and potential blockers

1. **Local Network permission denial:** Discovery and local connections can wait or fail without a general permission query. UX must explain and recover from this explicitly.
2. **macOS sandbox and signing:** App catalog access, network listening, and automation behavior depend on target distribution/signing choices and entitlements.
3. **Activation is conditional:** A launch or activation request may not imply a confirmed foreground state. Product success semantics must remain layered.
4. **Trust is separate from encryption:** TLS, Bonjour, QR setup, and a shared local network do not independently prove peer identity.
5. **iOS suspension:** Background execution cannot be treated as a continuously available control channel for the MVP.
6. **Secure Enclave recovery:** Device-bound keys can complicate device replacement, reset, and re-pairing.
7. **Version ambiguity:** The project has not selected minimum macOS/iOS deployment targets, so availability and entitlement conclusions must be rechecked when targets are chosen.

## Conclusion

The platform APIs support a credible path for a foreground iPhone Dock and a Mac menu-bar companion, subject to experiments. The research does not prove end-to-end discovery, pairing, launch, activation, or background behavior. Issues #3–#8 remain the owners of those runtime questions. No production architecture, protocol, entitlement set, or minimum OS version is finalized by this document.
