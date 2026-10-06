import Foundation
import AppKit

/// Runs measuring tools only. Every call is checked against a read only allowlist,
/// so this app cannot start any program that deletes, moves or changes files.
enum Shell {
    struct Result {
        let status: Int32
        let output: String
    }

    private static let forbiddenFindArgs: Set<String> = ["-delete", "-exec", "-execdir", "-ok", "-okdir", "-fprint", "-fls"] // SAFETY-ALLOWED (blocklist)

    /// The only programs the app may start, each with a check on its arguments.
    private static func isAllowed(_ launchPath: String, _ args: [String]) -> Bool {
        switch launchPath {
        case "/usr/bin/du":
            return true
        case "/usr/bin/tmutil":
            return args.first == "listlocalsnapshots"
        case "/usr/bin/find":
            return args.allSatisfy { !forbiddenFindArgs.contains($0) }
        default:
            return false
        }
    }

    @discardableResult
    static func run(_ launchPath: String, _ args: [String]) -> Result {
        guard isAllowed(launchPath, args) else {
            return Result(status: -1, output: "Blocked: Storage Cleaner only runs read only measuring tools.")
        }
        let process = Process()
        process.executableURL = URL(fileURLWithPath: launchPath)
        process.arguments = args
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = FileHandle.nullDevice
        do { try process.run() } catch {
            return Result(status: -1, output: error.localizedDescription)
        }
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        return Result(status: process.terminationStatus, output: String(decoding: data, as: UTF8.self))
    }
}

enum Finder {
    static func reveal(_ path: String) {
        NSWorkspace.shared.activateFileViewerSelecting([URL(fileURLWithPath: path)])
    }
}

enum Clipboard {
    static func copy(_ text: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
    }
}

enum Permissions {
    /// Safari's folder is protected by macOS, so reading it only works with Full Disk Access.
    static func hasFullDiskAccess() -> Bool {
        let path = NSHomeDirectory() + "/Library/Safari"
        return (try? FileManager.default.contentsOfDirectory(atPath: path)) != nil
    }

    static func openFullDiskAccessSettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_AllFiles") {
            NSWorkspace.shared.open(url)
        }
    }
}
