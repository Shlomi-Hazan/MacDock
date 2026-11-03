import AppKit
import AppActivationCore
import Foundation

func printUsage() {
    print("Usage: MacOSAppActivation [--target PATH] [--status|--launch|--activate|--missing]")
    print("Default target: /System/Applications/Calculator.app")
}

let arguments = CommandLine.arguments
if arguments.contains("--help") {
    printUsage()
    exit(0)
}

var target = URL(fileURLWithPath: "/System/Applications/Calculator.app", isDirectory: true)
if let index = arguments.firstIndex(of: "--target"), arguments.indices.contains(index + 1) {
    target = URL(fileURLWithPath: arguments[index + 1], isDirectory: true)
}

let operation: String
if arguments.contains("--launch") { operation = "launch" }
else if arguments.contains("--activate") { operation = "activate" }
else if arguments.contains("--missing") { operation = "missing" }
else { operation = "status" }

let controller = ApplicationController()
if operation == "status" {
    let observation = controller.observe(bundleURL: target)
    print("Operation: status")
    print("Target exists: \(FileManager.default.fileExists(atPath: target.path))")
    print("Process running: \(observation.isRunning)")
    print("Process active: \(observation.isActive)")
    print("Process hidden: \(observation.isHidden)")
    print("Target frontmost observed: \(observation.isFrontmost)")
    exit(0)
}

let report: OperationReport
switch operation {
case "launch": report = controller.launch(bundleURL: target)
case "activate": report = controller.activate(bundleURL: target)
case "missing": report = controller.missing(bundleURL: target)
default:
    printUsage()
    exit(2)
}

print("Operation: \(report.operation.rawValue)")
print("Request outcome: \(report.requestOutcome.rawValue)")
print("Process running after operation: \(report.processObservation.isRunning)")
print("Process active after operation: \(report.processObservation.isActive)")
print("Target frontmost observed: \(report.processObservation.isFrontmost)")
print("Foreground outcome: \(report.foregroundOutcome.rawValue)")
if let errorDescription = report.errorDescription {
    print("Error: \(errorDescription)")
}
