import Foundation
import LocalAuthentication

/// The only code in the app that can change files. It moves items to the Trash and never deletes
/// permanently. It runs only after the user confirms in a dialog and macOS verifies them with
/// Touch ID or the Mac password. The app never empties the Trash.
enum Deleter {
    struct Outcome {
        var moved: [String] = []
        var errors: [String] = []
    }

    /// Shows the macOS Touch ID or password prompt. Returns true only if macOS confirms the user.
    static func authenticate(reason: String) async -> Bool {
        let context = LAContext()
        var error: NSError?
        guard context.canEvaluatePolicy(.deviceOwnerAuthentication, error: &error) else { return false }
        do {
            return try await context.evaluatePolicy(.deviceOwnerAuthentication, localizedReason: reason)
        } catch {
            return false
        }
    }

    /// Places that are never touched, even if they were somehow selected.
    static func isProtected(_ path: String) -> Bool {
        let home = NSHomeDirectory()
        let standardized = (path as NSString).standardizingPath
        let topLevel = ["", "/Desktop", "/Documents", "/Downloads", "/Movies", "/Music", "/Pictures", "/Library", "/Applications", "/.Trash"].map { home + $0 }
        if topLevel.contains(standardized) || standardized == "/Applications" { return true }
        let blocked = [
            home + "/Library/Mobile Documents",
            home + "/Library/CloudStorage",
            home + "/Library/Containers",
            home + "/Library/Group Containers",
            home + "/Library/Messages",
            home + "/Library/Keychains",
            home + "/Library/Mail",
            home + "/Library/Safari",
            home + "/Pictures/Photos Library.photoslibrary",
            "/System", "/Library", "/usr", "/bin", "/sbin", "/private"
        ]
        if blocked.contains(where: { standardized == $0 || standardized.hasPrefix($0 + "/") }) { return true }
        return !(standardized.hasPrefix(home + "/") || standardized.hasPrefix("/Applications/"))
    }

    /// Moves items to the Trash. Nothing is deleted permanently.
    static func moveToTrash(_ paths: [String]) -> Outcome {
        let fm = FileManager.default
        var outcome = Outcome()
        for path in paths where !path.hasPrefix("snapshot:") {
            let name = (path as NSString).lastPathComponent
            guard !isProtected(path) else {
                outcome.errors.append("\(name): protected location, left in place")
                continue
            }
            guard fm.fileExists(atPath: path) else {
                outcome.errors.append("\(name): no longer there")
                continue
            }
            var targets = [path]
            // An Android emulator is a folder plus a matching .ini file next to it.
            if path.hasSuffix(".avd") { targets.append(String(path.dropLast(4)) + ".ini") }
            for target in targets where fm.fileExists(atPath: target) {
                do {
                    try fm.trashItem(at: URL(fileURLWithPath: target), resultingItemURL: nil) // SAFETY-ALLOWED: Trash only, after Touch ID or password
                    if target == path { outcome.moved.append(path) }
                } catch {
                    outcome.errors.append("\((target as NSString).lastPathComponent): \(error.localizedDescription)")
                }
            }
        }
        return outcome
    }
}
