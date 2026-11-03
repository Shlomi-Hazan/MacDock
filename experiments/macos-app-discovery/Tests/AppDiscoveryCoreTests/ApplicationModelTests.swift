import Foundation
import Testing
@testable import AppDiscoveryCore

@Test func identityIsDeterministicForTheSameInstallation() {
    let url = URL(fileURLWithPath: "/Applications/Example.app")
    #expect(ApplicationIdentity(bundleIdentifier: "com.example.app", canonicalURL: url) == ApplicationIdentity(bundleIdentifier: "com.example.app", canonicalURL: url))
}

@Test func duplicateBundleIdentifiersRemainDistinctByInstallation() {
    let first = ApplicationIdentity(bundleIdentifier: "com.example.app", canonicalURL: URL(fileURLWithPath: "/Applications/Example.app"))
    let second = ApplicationIdentity(bundleIdentifier: "com.example.app", canonicalURL: URL(fileURLWithPath: "/Volumes/Other/Example.app"))
    #expect(first != second)
    #expect(first.bundleIdentifier == second.bundleIdentifier)
}

@Test func missingBundleIdentifierUsesOpaqueLocationDigest() {
    let identity = ApplicationIdentity(bundleIdentifier: nil, canonicalURL: URL(fileURLWithPath: "/Applications/Legacy.app"))
    #expect(identity.bundleIdentifier == nil)
    #expect(identity.publicKey.hasPrefix("app:unknown-bundle:"))
    #expect(!identity.publicKey.contains("/Applications"))
}

@Test func incompleteBundleIsReportedWithoutCrashing() throws {
    let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
    let fixture = root.appendingPathComponent("Incomplete.app", isDirectory: true)
    try FileManager.default.createDirectory(at: fixture, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: root) }

    let applications = ApplicationDiscoverer().discover(in: [root], runningApplications: [])
    #expect(applications.count == 1)
    #expect(applications[0].availability == .incompleteMetadata)
}
