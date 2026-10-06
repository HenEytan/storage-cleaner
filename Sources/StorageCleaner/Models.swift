import Foundation
import SwiftUI

enum Risk {
    case safe, review, careful

    var title: String {
        switch self {
        case .safe: return "Safe"
        case .review: return "Review"
        case .careful: return "Use the app"
        }
    }

    var color: Color {
        switch self {
        case .safe: return .green
        case .review: return .blue
        case .careful: return .orange
        }
    }
}

enum StorageCategory: String, CaseIterable, Identifiable, Hashable {
    case developer = "Developer tools"
    case system = "System and caches"
    case files = "Your files"
    case apps = "Apps and media"

    var id: String { rawValue }

    var symbol: String {
        switch self {
        case .developer: return "hammer"
        case .system: return "gearshape.2"
        case .files: return "folder"
        case .apps: return "square.grid.2x2"
        }
    }

    var blurb: String {
        switch self {
        case .developer: return "Emulators, SDKs, build caches and Docker. Usually the largest hidden part of System Data on a developer Mac."
        case .system: return "Time Machine snapshots, caches, logs, device backups and app data."
        case .files: return "Your own files. Everything here needs a decision from you."
        case .apps: return "Installed apps and your photo library."
        }
    }
}

enum Kind {
    case folders
    case snapshots
    case projects
}

/// What the app offers for a location. None of these delete anything.
enum CleanAction {
    /// Items can be ticked and added to the cleanup plan.
    case pick
    /// A command the user can copy and run themselves later. The app never runs it.
    case manual(label: String, command: String)
    /// Explanation only, with a link to the right app or setting.
    case guide
}

struct Location: Identifiable {
    let id: String
    let title: String
    let category: StorageCategory
    let risk: Risk
    var kind: Kind = .folders
    var paths: [String] = []
    let effect: String
    let how: String
    var action: CleanAction = .pick
    var settingsURL: String? = nil
    var settingsLabel: String = "Open Settings"
    var hideChildPrefixes: [String] = []
    var hideChildSuffixes: [String] = []
    var showChildren: Bool = true

    var expandedPaths: [String] {
        paths.map { NSString(string: $0).expandingTildeInPath }
    }

    var isPickable: Bool {
        if case .pick = action { return true }
        return false
    }

    var manual: (label: String, command: String)? {
        if case let .manual(label, command) = action { return (label, command) }
        return nil
    }
}

struct Item: Identifiable, Hashable {
    var id: String { path }
    let path: String
    let name: String
    var detail: String? = nil
    let bytes: Int64
    var selectable: Bool
}

struct LocationResult {
    var total: Int64 = 0
    var items: [Item] = []
    var exists = false
    var note: String? = nil
}

struct DiskInfo {
    var total: Int64 = 0
    var free: Int64 = 0
    var purgeable: Int64 = 0
    var used: Int64 { max(0, total - free) }
}

struct AppAlert: Identifiable {
    let id = UUID()
    let title: String
    let message: String
}

extension Int64 {
    var bytesText: String {
        ByteCountFormatter.string(fromByteCount: self, countStyle: .file)
    }
}

func tilde(_ path: String) -> String {
    let home = NSHomeDirectory()
    return path.hasPrefix(home) ? "~" + String(path.dropFirst(home.count)) : path
}
