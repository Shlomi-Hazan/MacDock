# Production Bonjour Candidate Discovery

- Issue: [#39](https://github.com/Shlomi-Hazan/MacDock/issues/39)
- Status: Implementation proposal and validation plan
- Service type: `_macdock._tcp`
- Scope: untrusted candidate discovery only

## Boundary

MacDockiOS browses for nearby services using `NWBrowser`. A visible service is an attacker-controlled candidate and is never treated as an identity, authenticated peer, paired device, trusted session, or authorization grant. This feature does not connect to candidates, exchange keys, establish TLS, or expose application-control commands.

The macOS shell advertises the documented service with a minimal `NWListener`. Incoming connections are cancelled immediately. The listener is present only so the iOS browser can observe a real service; it is not a transport endpoint or RPC surface.

## Implementation

- `MacDockShared/BonjourDiscovery.swift` contains the Foundation-only candidate model and deterministic reducer.
- `MacDockiOS/BonjourDiscoveryCoordinator.swift` owns the `NWBrowser` lifecycle and maps platform callbacks into the reducer.
- `MacDockiOS/Info.plist` declares the local-network explanation and `_macdock._tcp` Bonjour service.
- `MacDockMac/MacDockMacApp.swift` starts and stops the minimal advertisement with the application lifecycle.

Candidate identifiers use bounded service name, type, and domain fields. Interface details and raw addresses are not exposed. Candidate metadata is capped and displayed with an explicit `Untrusted candidate` label.

## Deterministic behavior

The shared reducer covers browser start, ready, waiting, failure, cancellation, candidate appearance/disappearance, duplicate suppression, bounded candidate count, and retry. The iOS coordinator uses a generation counter so callbacks from a cancelled or superseded browser cannot update the current state.

Waiting and failure are intentionally presented as availability states. The UI does not claim that a particular error proves Local Network denial, because Network.framework state alone may not uniquely identify the cause.

## Validation

Automated reducer tests cover candidate appearance and disappearance, duplicate advertisements, stale callbacks after cancellation, retry after failure, bounded metadata, and the invariant that discovery remains untrusted.

The required physical-device validation is not claimed here. It must be performed by the maintainer on a Mac and iPhone on the same local Wi-Fi.

## Maintainer physical test procedure

1. Build and run `MacDockMac` on the physical Mac. Confirm the menu-bar shell starts and the MacDock advertiser remains running.
2. Build and run `MacDockiOS` on the physical iPhone. On first use, allow Local Network access when iOS presents the prompt.
3. Confirm the iOS screen shows `Discovery: Ready`, a Mac candidate, and `Untrusted candidate`. No pairing or connection control should be shown.
4. Stop MacDockMac from Xcode or quit it from the menu. Confirm the candidate disappears or the list becomes empty.
5. Relaunch MacDockMac. Confirm the candidate reappears without any trust or pairing state.
6. If needed, deny Local Network access in Settings > Privacy & Security > Local Network, relaunch MacDockiOS, and confirm the UI reports an unavailable/waiting state without claiming a specific cause.
7. Restore Local Network access, relaunch the iOS app, and confirm discovery can be retried.

The test does not validate transport connectivity, TLS, pairing, authentication, authorization, background behavior, or application control. Do not record a physical result until the maintainer performs the steps.

## Security and privacy review

- No peer keys, credentials, QR tokens, or trust records are exchanged.
- No raw address, interface identifier, personal path, or device identifier is logged or shown.
- No background mode or idle-timer behavior is added.
- No incoming payload is parsed and no command is accepted.
- No production transport or pairing capability is introduced.

The implementation remains subject to the Issue #38 requirements baseline and the unresolved construction gates in ADR 0003.
