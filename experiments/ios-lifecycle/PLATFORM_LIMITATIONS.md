# iOS Lifecycle Platform Limitations

MacDock's interactive Dock is a foreground experience. SwiftUI `scenePhase` and UIKit scene lifecycle callbacks can describe transitions among foreground active, inactive, and background, but they do not provide an always-running interactive channel after suspension or termination.

The experiment intentionally adds no background modes, background networking entitlement, private API, or keep-alive mechanism. A connection may be interrupted, suspended, or terminated when the app leaves the foreground; this experiment does not claim otherwise.

`UIApplication.isIdleTimerDisabled` is an app-controlled idle-timer preference, not a promise that the device cannot be manually locked. It must remain explicit, reversible, and lifecycle-scoped. Longer screen-on time can increase battery consumption, display wear, and device temperature. Physical battery, thermal, lock/unlock, and lifecycle observations remain required on the target iPhone.

References:

- [Apple: Managing your app's life cycle](https://developer.apple.com/documentation/uikit/managing-your-app-s-life-cycle)
- [Apple: Preparing your UI to run in the background](https://developer.apple.com/documentation/uikit/preparing-your-ui-to-run-in-the-background)
- [Apple: SwiftUI ScenePhase](https://developer.apple.com/documentation/swiftui/scenephase)
- [Apple: UIApplication.isIdleTimerDisabled](https://developer.apple.com/documentation/uikit/uiapplication/isidletimerdisabled)
