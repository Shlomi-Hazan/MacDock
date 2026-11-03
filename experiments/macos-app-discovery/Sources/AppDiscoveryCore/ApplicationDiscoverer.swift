import AppKit
import Foundation

public struct ApplicationDiscoverer {
    public init() {}

    /// Scans only explicit, user-visible application roots. It does not traverse arbitrary volumes.
    public func discover(in roots: [URL], runningApplications: [NSRunningApplication] = NSWorkspace.shared.runningApplications) -> [DiscoveredApplication] {
        let runningPaths = Set(runningApplications.compactMap { $0.bundleURL?.standardizedFileURL.resolvingSymlinksInPath().path })
        var results: [DiscoveredApplication] = []
        var seen = Set<String>()
        let keys: [URLResourceKey] = [.isDirectoryKey, .isSymbolicLinkKey, .isReadableKey]

        for root in roots {
            guard let enumerator = FileManager.default.enumerator(at: root, includingPropertiesForKeys: keys, options: [.skipsHiddenFiles]) else { continue }
            for case let url as URL in enumerator {
                guard url.pathExtension.caseInsensitiveCompare("app") == .orderedSame else { continue }
                enumerator.skipDescendants()
                let canonicalURL = url.standardizedFileURL.resolvingSymlinksInPath()
                let values = try? canonicalURL.resourceValues(forKeys: Set(keys))
                guard values?.isDirectory == true else { continue }
                let readable = values?.isReadable ?? false
                let bundle = Bundle(url: canonicalURL)
                let bundleIdentifier = bundle?.bundleIdentifier
                let identity = ApplicationIdentity(bundleIdentifier: bundleIdentifier, canonicalURL: canonicalURL)
                guard seen.insert(identity.publicKey).inserted else { continue }

                let displayName = (bundle?.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String)
                    ?? (bundle?.object(forInfoDictionaryKey: "CFBundleName") as? String)
                    ?? bundle?.localizedInfoDictionary?["CFBundleDisplayName"] as? String
                let executable = bundle?.executableURL
                let complete = readable && bundle != nil && executable != nil
                let hasIcon = NSWorkspace.shared.icon(forFile: canonicalURL.path).isValid
                let path = canonicalURL.path
                results.append(DiscoveredApplication(
                    identity: identity,
                    displayName: displayName,
                    bundleIdentifier: bundleIdentifier,
                    availability: complete ? .launchableCandidate : (readable ? .incompleteMetadata : .inaccessible),
                    isRunning: runningPaths.contains(path),
                    hasIcon: hasIcon
                ))
            }
        }
        return results.sorted { $0.identity.publicKey < $1.identity.publicKey }
    }
}
