# Experiment Report: macOS Application Discovery

- Issue: [#6](https://github.com/Shlomi-Hazan/MacDock/issues/6)
- Status: Stage 0 feasibility experiment
- Scope: discovery and metadata only; no launch or activation

## Research question

Can MacDock build a useful, privacy-preserving inventory of applications available on the Mac without treating running applications as the complete installed inventory, relying on display names as identity, or recursively traversing arbitrary user storage?

## Approach

The experiment uses a bounded allowlist of application roots and inspects `.app` bundles with Foundation and AppKit. It reads bundle identifiers, display-name metadata, executable presence, readability, icon availability, and running state. It does not launch or activate an application.

`NSWorkspace.runningApplications` is used only to enrich discovery results with current running state. It is not used as the installed-app inventory.

## Normalized model proposal

The smallest future protocol-facing model should contain:

| Field | Purpose | Exposure |
| --- | --- | --- |
| Approved application identity | Stable logical reference for Dock selection | Only after authenticated authorization and an approved identifier design |
| Bundle identifier, optional | Useful logical identifier when present | Safe when not treated as unique alone |
| Display name, optional | User-facing label | Safe after sanitization |
| Icon representation, optional | Dock rendering data or versioned icon reference | Transfer normalized data, never a permanent path |
| Availability | Available, incomplete, or unavailable | Safe |
| Running state | Best-effort current state | Safe after authentication |
| Freshness/source metadata | Allows the client to reason about stale discovery | Safe if it contains no path or personal data |

Internal canonical URLs, file-resource identifiers, bundle objects, filesystem errors, and the experiment's unsalted SHA-256 path digest must remain macOS-local. Absolute paths and personal directory names must not cross the future protocol boundary. Authentication alone does not make a predictable path digest a privacy-preserving identifier.

## Identity strategy

Display name is never an identity. The proposed internal identity is composite:

1. Use the bundle identifier when present as the logical application identifier.
2. Add an installation discriminator derived from the canonical, symlink-resolved bundle URL so two installations with the same bundle identifier remain distinct. In this experiment that discriminator is a plain SHA-256 digest used only locally for deterministic comparison.
3. If the bundle identifier is missing, use the same local experimental digest mechanism, but do not expose it as a network identity.

This preserves deterministic identity for the same installation and distinguishes duplicates, but it is not inherently privacy-preserving: a predictable path digest is susceptible to dictionary attacks. A move, reinstall, or replacement can change the installation discriminator; the future Dock layer must therefore retain its selected record and mark it unavailable rather than silently deleting it. A later production design must choose either random locally persisted IDs or a locally keyed HMAC, with explicit key lifecycle and migration handling, and must not silently merge distinct installations.

### Production wire-identifier alternatives

| Strategy | Stability | Privacy and recovery trade-off |
| --- | --- | --- |
| Random opaque ID in a local registry | Stable while the registry and mapping survive | Stronger non-linkability; requires protected persistence, migration, and registry recovery behavior |
| Locally keyed HMAC of canonical identity | Deterministic on one Mac while the key remains stable | Avoids plain path disclosure; requires Keychain-backed key lifecycle, rotation/migration handling, and careful reinstall semantics |

Neither strategy is implemented or selected by this Stage 0 experiment. The experimental SHA-256 key is strictly internal and is not an approved production wire identifier. Authenticated access controls metadata exposure but does not change the digest's dictionary-attack properties.

## Discovery versus Dock state

Discovery answers which application candidates currently exist and what metadata is available. Dock state answers which opaque identities the user selected and in what order. They are separate stores and lifecycles.

If discovery is temporarily unavailable, the Dock configuration must remain intact. A selected application that disappears becomes unavailable and may be repaired or removed through an explicit user action. Discovery refresh must not reorder or delete user choices.

## Runtime evidence

### Tool-executed on the development Mac

Environment: Apple Silicon macOS, Swift 6.2.4, Xcode 26.3. The exact OS marketing version is not included in this report because the experiment does not depend on exposing machine identity.

Command:

```sh
swift test
swift build
swift run MacOSAppDiscovery
```

Observed aggregate output:

| Observation | Result |
| --- | ---: |
| Allowlisted roots scanned | 4 |
| Application bundles found | 258 |
| Launchable candidates by experiment heuristic | 258 |
| Incomplete metadata | 0 |
| Inaccessible bundles | 0 |
| Currently running | 37 |
| Bundles with icon metadata | 258 |
| Bundles with bundle identifier | 257 |

The `launchable candidate` classification means the bundle was readable, had bundle metadata, and exposed an executable URL. It is not proof that launching would succeed under every user, sandbox, entitlement, or application policy.

### Automated fixture evidence

Unit tests verify deterministic identity, duplicate bundle identifiers at different installation URLs, opaque identity when a bundle identifier is absent, and graceful classification of an incomplete `.app` fixture.

The test suite does not fabricate an inaccessible real application or alter installed applications.

### Not tested

- Sandboxed execution or Mac App Store distribution.
- Launch or activation behavior.
- A real inaccessible application under the target user's permissions.
- A real duplicate bundle identifier installed on the development Mac.
- Stale Launch Services registration or translocation behavior.
- Icon encoding and transfer over the MacDock protocol.

## API and platform findings

- `NSWorkspace.runningApplications` is suitable for running-state enrichment, not a complete installed inventory.
- `Bundle` and AppKit metadata provide useful identifiers, names, executable information, and icons without launching an application.
- A bounded scan of explicit application roots is more predictable for this experiment than arbitrary volume traversal. It is still a policy choice and must be revisited for production distribution.
- Launchability is conditional. A readable bundle with an executable is only a candidate; actual launch behavior requires the separate Issue #7 experiment.
- App Sandbox behavior was not verified. A production Mac App Store companion may require a different discovery strategy, security-scoped access, or distribution decision; this is tracked for the distribution/architecture work rather than inferred from this unsandboxed run.

## Rejected or deferred alternatives

- **Running applications as the inventory:** rejected because it omits installed apps that are not running.
- **Display name as identity:** rejected because names are mutable and non-unique.
- **Arbitrary recursive filesystem traversal:** rejected for privacy, performance, and permission reasons.
- **Permanent filesystem paths in the protocol:** rejected because they disclose local structure and break when apps move.
- **Application launch during discovery:** deferred to Issue #7 to keep discovery side-effect free.

## Limitations and next steps

The experiment supports a bounded discovery prototype and a deterministic internal composite identity comparison. It does not establish a privacy-preserving production identity, App Sandbox compatibility, complete Launch Services inventory semantics, or successful launching. Issue #7 must validate launch and activation separately. Distribution research must resolve sandbox and Mac App Store constraints before production discovery APIs are finalized.
