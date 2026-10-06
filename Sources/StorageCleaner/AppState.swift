import Foundation
import SwiftUI
import AppKit

/// App state. The app measures and builds a cleanup plan. Files are only ever moved to the Trash,
/// and only after you confirm in a dialog and macOS confirms you with Touch ID or your password.
@MainActor
final class AppState: ObservableObject {
    @Published var results: [String: LocationResult] = [:]
    @Published var scanning = false
    @Published var progress = 0
    @Published var selection: Set<String> = []
    @Published var disk = DiskInfo()
    @Published var largeFiles: [Item] = []
    @Published var largeScanning = false
    @Published var largeScanned = false
    @Published var hasFullDiskAccess = Permissions.hasFullDiskAccess()
    @Published var alert: AppAlert? = nil
    @Published var working = false

    /// Every listed item by path, used for totals and the plan.
    private var index: [String: Item] = [:]

    // MARK: Totals

    var selectedBytes: Int64 {
        selection.reduce(0) { $0 + (index[$1]?.bytes ?? 0) }
    }

    func size(of location: Location) -> Int64 {
        results[location.id]?.total ?? 0
    }

    func total(for category: StorageCategory) -> Int64 {
        Catalog.locations(in: category).reduce(0) { $0 + size(of: $1) }
    }

    // MARK: Plan selection

    func selectableItems(_ location: Location) -> [Item] {
        results[location.id]?.items.filter(\.selectable) ?? []
    }

    func allSelected(_ location: Location) -> Bool {
        let items = selectableItems(location)
        return !items.isEmpty && items.allSatisfy { selection.contains($0.path) }
    }

    func setAll(_ location: Location, _ on: Bool) {
        for item in selectableItems(location) {
            if on { selection.insert(item.path) } else { selection.remove(item.path) }
        }
    }

    func toggle(_ item: Item, _ on: Bool) {
        if on { selection.insert(item.path) } else { selection.remove(item.path) }
    }

    func addSafeToPlan() {
        for location in Catalog.all where location.risk == .safe && location.isPickable {
            setAll(location, true)
        }
    }

    // MARK: Scanning

    func scanAll() {
        guard !scanning else { return }
        scanning = true
        progress = 0
        hasFullDiskAccess = Permissions.hasFullDiskAccess()
        refreshDisk()
        let locations = Catalog.all
        Task.detached(priority: .userInitiated) { [weak self] in
            for location in locations {
                let result = DiskScanner.scan(location)
                await self?.apply(location.id, result)
            }
            await self?.finishScan()
        }
    }

    private func apply(_ id: String, _ result: LocationResult) {
        results[id] = result
        for item in result.items { index[item.path] = item }
        progress += 1
    }

    private func finishScan() {
        scanning = false
        let known = Set(results.values.flatMap { $0.items.map(\.path) }).union(largeFiles.map(\.path))
        selection = selection.intersection(known)
        refreshDisk()
    }

    func refreshDisk() {
        disk = DiskScanner.disk()
    }

    func findLargeFiles(_ threshold: Int64) {
        guard !largeScanning else { return }
        largeScanning = true
        Task.detached(priority: .utility) { [weak self] in
            let items = DiskScanner.largeFiles(threshold: threshold)
            await self?.finishLarge(items)
        }
    }

    private func finishLarge(_ items: [Item]) {
        largeFiles = items
        for item in items { index[item.path] = item }
        largeScanning = false
        largeScanned = true
    }

    // MARK: Plan output (creates a new file, never touches existing ones)

    func planText() -> String {
        let date = DateFormatter.localizedString(from: Date(), dateStyle: .medium, timeStyle: .short)
        var lines: [String] = [
            "# Storage cleanup plan",
            "",
            "Created \(date). Free now: \(disk.free.bytesText) of \(disk.total.bytesText).",
            "Planned: \(selection.count) items, \(selectedBytes.bytesText). Free after cleanup: \((disk.free + selectedBytes).bytesText).",
            "",
            "Nothing has been deleted. This is a list to review and act on yourself.",
            ""
        ]
        var listed = Set<String>()
        for location in Catalog.all {
            let picked = (results[location.id]?.items ?? []).filter { selection.contains($0.path) }
            guard !picked.isEmpty else { continue }
            let subtotal = picked.reduce(Int64(0)) { $0 + $1.bytes }
            lines.append("## \(location.title) (\(subtotal.bytesText), \(location.risk.title))")
            lines.append("")
            lines.append(location.how)
            lines.append("")
            for item in picked {
                lines.append("- [ ] \(item.name), \(item.bytes.bytesText): `\(tilde(item.path))`")
                listed.insert(item.path)
            }
            lines.append("")
        }
        let large = largeFiles.filter { selection.contains($0.path) && !listed.contains($0.path) }
        if !large.isEmpty {
            lines.append("## Large files")
            lines.append("")
            for item in large { lines.append("- [ ] \(item.name), \(item.bytes.bytesText): `\(tilde(item.path))`") }
            lines.append("")
        }
        return lines.joined(separator: "\n")
    }

    func copyPlan() {
        Clipboard.copy(planText())
        alert = AppAlert(title: "Plan copied", message: "Paste it into Notes, a doc or a chat to review it.")
    }

    func savePlan() {
        let desktop = URL(fileURLWithPath: NSHomeDirectory()).appendingPathComponent("Desktop")
        let stamp = DateFormatter()
        stamp.dateFormat = "yyyy-MM-dd HH.mm.ss"
        var url = desktop.appendingPathComponent("Storage cleanup plan \(stamp.string(from: Date())).md")
        var counter = 2
        while FileManager.default.fileExists(atPath: url.path) {
            url = desktop.appendingPathComponent("Storage cleanup plan \(stamp.string(from: Date())) \(counter).md")
            counter += 1
        }
        guard let data = planText().data(using: .utf8),
              FileManager.default.createFile(atPath: url.path, contents: data) else {
            alert = AppAlert(title: "Could not save the plan", message: "Use Copy plan instead and paste it anywhere.")
            return
        }
        Finder.reveal(url.path)
        alert = AppAlert(title: "Plan saved", message: "Saved to your Desktop as \(url.lastPathComponent). Nothing was deleted.")
    }

    // MARK: Move to Trash (only after macOS confirms it is you)

    func moveSelectionToTrash() {
        let paths = Array(selection)
        guard !paths.isEmpty, !working else { return }
        let reason = "move \(paths.count) item\(paths.count == 1 ? "" : "s") (\(selectedBytes.bytesText)) to the Trash"
        Task {
            let approved = await Deleter.authenticate(reason: reason)
            guard approved else {
                alert = AppAlert(title: "Nothing was moved", message: "macOS did not confirm it is you, so no files were touched.")
                return
            }
            working = true
            let outcome = await Task.detached(priority: .userInitiated) { Deleter.moveToTrash(paths) }.value
            finishTrash(outcome)
        }
    }

    private func finishTrash(_ outcome: Deleter.Outcome) {
        working = false
        let moved = Set(outcome.moved)
        let bytes = outcome.moved.reduce(Int64(0)) { $0 + (index[$1]?.bytes ?? 0) }
        selection.subtract(moved)
        for id in Array(results.keys) {
            guard var result = results[id] else { continue }
            let removed = result.items.filter { moved.contains($0.path) }
            guard !removed.isEmpty else { continue }
            result.items.removeAll { moved.contains($0.path) }
            result.total = max(0, result.total - removed.reduce(Int64(0)) { $0 + $1.bytes })
            results[id] = result
        }
        largeFiles.removeAll { moved.contains($0.path) }
        refreshDisk()
        var message = moved.isEmpty
            ? "No files were moved."
            : "Moved \(moved.count) item\(moved.count == 1 ? "" : "s") (\(bytes.bytesText)) to the Trash. Nothing was deleted permanently, so you can restore anything from the Trash. The space is freed when you empty the Trash yourself."
        if !outcome.errors.isEmpty {
            message += "\n\nSkipped:\n" + outcome.errors.prefix(8).joined(separator: "\n")
            if outcome.errors.count > 8 { message += "\nand \(outcome.errors.count - 8) more." }
        }
        alert = AppAlert(title: moved.isEmpty ? "Nothing was moved" : "Moved to the Trash", message: message)
    }

    func copyCommand(_ command: String) {
        Clipboard.copy(command)
        alert = AppAlert(title: "Command copied", message: "Nothing has been run. Paste it into Terminal yourself when you are ready:\n\n\(command)")
    }
}
