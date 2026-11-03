# Experiment Report: macOS Application Launch and Activation

- Issue: [#7](https://github.com/Shlomi-Hazan/MacDock/issues/7)
- Status: Stage 0 feasibility experiment
- Scope: native launch, activation, and read-only observation; no production control protocol

## Research question

Can a native macOS companion use `NSWorkspace.openApplication(at:configuration:completionHandler:)` and `NSRunningApplication.activate(options:)` while reporting launch acceptance, process existence, activation result, and foreground observation as separate outcomes?

## State model

| Stage | Meaning | Evidence source |
| --- | --- | --- |
| Request submitted | The experiment called the native API | Local command execution |
| Request accepted/rejected | AppKit completion or activation Boolean | API result |
| Process running | A matching `NSRunningApplication` was observed | Bounded read-only polling |
| Activation issued | `activate(options:)` was called for an existing process | Local command execution |
| Activation accepted/rejected | Boolean returned by `NSRunningApplication.activate` | API result |
| Frontmost observed | `NSWorkspace.frontmostApplication` matched the target process | Independent observation |
| Unknown/unverified | Required evidence did not arrive before the timeout | Explicit experiment outcome |

No row is inferred solely from another row. In particular, launch acceptance does not prove process readiness or foreground focus.

## Implementation

The experiment uses:

- `NSWorkspace.openApplication(at:configuration:completionHandler:)` for launch-only requests.
- `NSWorkspace.runningApplications` for read-only process lookup.
- `NSRunningApplication.activate(options:)` for activation of an already-running target.
- `NSWorkspace.frontmostApplication` for independent frontmost comparison.
- Bounded polling: 10 seconds for process appearance after launch and 3 seconds for frontmost observation after activation.
- A missing-application scenario with a fixed nonexistent path; no installed application is deleted or modified.

The executable refuses to launch an already-running target and refuses to activate a target without a matching running process. It does not retry indefinitely and does not automatically replay an operation after a timeout.

## Controlled runtime evidence

Environment: Apple Silicon development Mac, Swift 6.2.4, Xcode 26.3. Commands were run locally by the tool environment. Calculator was selected as a low-risk system application.

### A. Not-running launch

Before the request, `--status` reported:

```text
Target exists: true
Process running: false
Process active: false
Target frontmost observed: false
```

The launch command returned:

```text
Operation: launch
Request outcome: requestAccepted
Process running after operation: false
Process active after operation: false
Target frontmost observed: false
Foreground outcome: foregroundUnverified
```

This is concrete evidence that AppKit accepted the launch request, while the bounded observation immediately following the callback did not yet see the process or frontmost state. A separate status invocation after the command reported:

```text
Target exists: true
Process running: true
Process active: true
Target frontmost observed: true
```

The result demonstrates asynchronous startup and why launch completion must not be treated as confirmed foreground readiness.

### B. Already-running activation

With Calculator observed running, the activation command returned:

```text
Operation: activate
Request outcome: activationAccepted
Process running after operation: true
Process active after operation: true
Target frontmost observed: true
Foreground outcome: frontmostObserved
```

This confirms the behavior for this target and environment only. It does not establish universal foreground behavior for every application class or policy state.

### C. Missing application

The experiment used `/System/Applications/MacDock-Missing.app`, which did not exist. The result was:

```text
Operation: missing
Request outcome: requestRejected
Process running after operation: false
Target frontmost observed: false
Error: The application “MacDock-Missing.app” could not be launched because it was not found.
```

No installed application was removed or changed.

### D. Restricted/non-activatable application

No safe representative restricted or non-activatable application was selected. This scenario is not claimed as runtime-tested. Documentation and API behavior indicate that application policy, activation policy, sandboxing, and process lifecycle can affect results; a future test must use a deliberately controlled fixture or an explicitly approved harmless target.

### E. Race and disappearance behavior

The experiment does not terminate applications and therefore did not force a process-disappearance race. The code uses a bounded lookup and reports a missing process as activation rejection; it does not retry indefinitely. A production implementation still needs an integration test for disappearance between lookup and activation.

## Accessibility, Apple Events, and sandbox findings

The tested operations used only `NSWorkspace` and `NSRunningApplication`. No Accessibility or Automation prompt was observed, and the experiment did not call AppleScript, UI scripting, or Apple Events. This demonstrates only the behavior of this unsandboxed local run; it does not prove that every future operation, sandbox profile, signing model, or distribution channel will need no additional authorization.

No broad entitlements were added. App Sandbox and Mac App Store behavior remain unverified and must be evaluated with the selected distribution model. Apple Events or Accessibility should not be introduced as a workaround for uncertain activation without a separate capability and security review.

## Production security boundary

The future MacDock companion must accept launch/activation requests only after secure pairing and an authenticated session. It should:

- authorize only applications present in the local discovery model;
- reject arbitrary executable paths and shell commands;
- use replay-resistant request IDs and bounded execution;
- distinguish accepted, running, activated, frontmost-observed, failed, and unknown states;
- avoid automatic replay of a potentially non-idempotent request after a lost acknowledgment;
- preserve Dock configuration when launch or activation fails.

This experiment does not implement pairing, authorization, or the production request protocol.

## Validation

- `swift test`: passed, 2 tests.
- `swift build`: passed without compiler warnings after callback-state cleanup.
- Controlled Calculator status/launch/activation runs: completed as documented above.
- Missing application rejection: completed as documented above.
- `git diff --check`: required before submission.
- Privacy and secrets review: no credentials, paths from output, signing identities, or device identifiers are committed.

## Conclusions and limitations

`NSWorkspace` provides a viable asynchronous launch boundary, and `NSRunningApplication.activate(options:)` can produce a successful activation plus observed frontmost state for Calculator in this environment. Neither API provides a universal guarantee that every request will result in a visible foreground application. Production success semantics must remain layered and truthful.

Remaining questions include sandbox/distribution behavior, restricted application classes, process disappearance races, and the final authenticated authorization protocol. These are not production implementation decisions in Issue #7.
