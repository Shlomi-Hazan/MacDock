import AppKit
import Foundation
import AppDiscoveryCore

let home = FileManager.default.homeDirectoryForCurrentUser
let roots = [
    URL(fileURLWithPath: "/Applications", isDirectory: true),
    URL(fileURLWithPath: "/System/Applications", isDirectory: true),
    URL(fileURLWithPath: "/System/Library/CoreServices", isDirectory: true),
    home.appendingPathComponent("Applications", isDirectory: true)
]

let applications = ApplicationDiscoverer().discover(in: roots)
let candidateCount = applications.filter { $0.availability == .launchableCandidate }.count
let incompleteCount = applications.filter { $0.availability == .incompleteMetadata }.count
let inaccessibleCount = applications.filter { $0.availability == .inaccessible }.count
let runningCount = applications.filter(\.isRunning).count
let iconCount = applications.filter(\.hasIcon).count
let bundleIDCount = applications.filter { $0.bundleIdentifier != nil }.count

print("MacDock macOS application discovery experiment")
print("Roots scanned: \(roots.count) allowlisted locations")
print("Applications found: \(applications.count)")
print("Launchable candidates: \(candidateCount)")
print("Incomplete metadata: \(incompleteCount)")
print("Inaccessible: \(inaccessibleCount)")
print("Currently running: \(runningCount)")
print("With icon metadata: \(iconCount)")
print("With bundle identifier: \(bundleIDCount)")
print("Output intentionally omits filesystem paths and personal directory names.")
