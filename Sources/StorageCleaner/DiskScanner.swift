import Foundation

enum DiskScanner {

    static func scan(_ location: Location) -> LocationResult {
        switch location.kind {
        case .folders: return folders(location)
        case .snapshots: return snapshots()
        case .projects: return projects()
        }
    }

    // MARK: Disk

    static func disk() -> DiskInfo {
        let url = URL(fileURLWithPath: NSHomeDirectory())
        let keys: Set<URLResourceKey> = [.volumeTotalCapacityKey, .volumeAvailableCapacityKey, .volumeAvailableCapacityForImportantUsageKey]
        guard let values = try? url.resourceValues(forKeys: keys) else { return DiskInfo() }
        var info = DiskInfo()
        info.total = Int64(values.volumeTotalCapacity ?? 0)
        info.free = Int64(values.volumeAvailableCapacity ?? 0)
        let important = values.volumeAvailableCapacityForImportantUsage ?? 0
        info.purgeable = max(0, important - info.free)
        return info
    }

    // MARK: Folders

    static func duTotal(_ path: String) -> Int64 {
        let out = Shell.run("/usr/bin/du", ["-sk", path]).output
        guard let first = out.split(whereSeparator: { $0 == "\t" || $0 == " " }).first else { return 0 }
        return (Int64(first) ?? 0) * 1024
    }

    private static let backupDate: DateFormatter = {
        let f = DateFormatter()
        f.dateStyle = .medium
        f.timeStyle = .none
        return f
    }()

    static func folders(_ location: Location) -> LocationResult {
        var result = LocationResult()
        let fm = FileManager.default
        let roots = location.expandedPaths

        for root in roots {
            guard fm.fileExists(atPath: root) else { continue }
            result.exists = true

            if !location.showChildren {
                result.total += duTotal(root)
                continue
            }

            // -a lists files as well as folders, -d 1 stops one level below the root.
            let out = Shell.run("/usr/bin/du", ["-a", "-k", "-d", "1", root]).output
            for line in out.split(separator: "\n") {
                guard let tab = line.firstIndex(of: "\t") else { continue }
                let kb = Int64(line[..<tab].trimmingCharacters(in: .whitespaces)) ?? 0
                let path = String(line[line.index(after: tab)...])
                if path == root || path == root + "/" { continue }

                let fileName = (path as NSString).lastPathComponent
                if fileName == ".DS_Store" || fileName == ".localized" { continue }
                if location.hideChildPrefixes.contains(where: { fileName.hasPrefix($0) }) { continue }
                if location.hideChildSuffixes.contains(where: { fileName.hasSuffix($0) }) { continue }

                let bytes = kb * 1024
                result.total += bytes
                guard bytes >= 1_000_000 else { continue }

                var name = fileName
                var detail: String? = roots.count > 1 ? tilde(root) : nil
                for suffix in [".app", ".avd"] where name.hasSuffix(suffix) {
                    name = String(name.dropLast(suffix.count))
                }
                if root.hasSuffix("MobileSync/Backup"),
                   let info = NSDictionary(contentsOfFile: path + "/Info.plist") {
                    if let device = info["Device Name"] as? String { name = device }
                    if let date = info["Last Backup Date"] as? Date {
                        detail = "Last backup " + backupDate.string(from: date)
                    }
                }

                result.items.append(Item(path: path, name: name, detail: detail, bytes: bytes, selectable: location.isPickable))
            }
        }

        result.items.sort { $0.bytes > $1.bytes }
        if result.items.count > 300 { result.items = Array(result.items.prefix(300)) }
        return result
    }

    // MARK: Time Machine

    static func snapshots() -> LocationResult {
        let out = Shell.run("/usr/bin/tmutil", ["listlocalsnapshots", "/"]).output
        let names = out.split(separator: "\n").map(String.init).filter { $0.contains("com.apple.TimeMachine") }
        var result = LocationResult()
        result.exists = true
        if names.isEmpty {
            result.note = "None found"
        } else {
            var note = "\(names.count) snapshot\(names.count == 1 ? "" : "s")"
            let purgeable = disk().purgeable
            if purgeable > 0 { note += ", up to \(purgeable.bytesText) purgeable" }
            result.note = note
        }
        result.items = names.map {
            Item(path: "snapshot:" + $0,
                 name: $0.replacingOccurrences(of: "com.apple.TimeMachine.", with: "Snapshot "),
                 bytes: 0, selectable: false)
        }
        return result
    }

    // MARK: Projects

    static func projects() -> LocationResult {
        let home = NSHomeDirectory()
        let args = [
            home, "-maxdepth", "8",
            "(", "-path", home + "/Library", "-o", "-path", home + "/.Trash",
            "-o", "-name", ".*", "-o", "-name", "*.app", "-o", "-name", "*.photoslibrary", ")", "-prune",
            "-o", "-type", "d", "(", "-name", "node_modules", "-o", "-name", "build", ")", "-prune", "-print"
        ]
        let out = Shell.run("/usr/bin/find", args).output
        let fm = FileManager.default
        var result = LocationResult()
        result.exists = true

        for line in out.split(separator: "\n") {
            let path = String(line)
            let parent = (path as NSString).deletingLastPathComponent
            let folder = (path as NSString).lastPathComponent
            let markers = folder == "node_modules"
                ? ["package.json"]
                : ["build.gradle", "build.gradle.kts", "settings.gradle", "settings.gradle.kts", "package.json"]
            guard markers.contains(where: { fm.fileExists(atPath: parent + "/" + $0) }) else { continue }

            let bytes = duTotal(path)
            guard bytes >= 100_000_000 else { continue }
            let project = (parent as NSString).lastPathComponent
            result.items.append(Item(path: path, name: project + "/" + folder, detail: tilde(parent), bytes: bytes, selectable: true))
            result.total += bytes
        }
        result.items.sort { $0.bytes > $1.bytes }
        return result
    }

    // MARK: Large files

    static func largeFiles(threshold: Int64) -> [Item] {
        let home = NSHomeDirectory()
        let keys: [URLResourceKey] = [.isRegularFileKey, .totalFileAllocatedSizeKey, .fileAllocatedSizeKey]
        guard let enumerator = FileManager.default.enumerator(
            at: URL(fileURLWithPath: home),
            includingPropertiesForKeys: keys,
            options: [],
            errorHandler: { _, _ in true }
        ) else { return [] }

        let skipped = [home + "/Library/Mobile Documents", home + "/Library/CloudStorage", home + "/.Trash"]
        var found: [Item] = []

        for case let url as URL in enumerator {
            let path = url.path
            if skipped.contains(where: { path.hasPrefix($0) }) || path.hasSuffix(".photoslibrary") {
                enumerator.skipDescendants()
                continue
            }
            guard let values = try? url.resourceValues(forKeys: Set(keys)), values.isRegularFile == true else { continue }
            let size = Int64(values.totalFileAllocatedSize ?? values.fileAllocatedSize ?? 0)
            guard size >= threshold else { continue }

            let insideLibrary = path.hasPrefix(home + "/Library/")
            let parent = tilde((path as NSString).deletingLastPathComponent)
            found.append(Item(
                path: path,
                name: url.lastPathComponent,
                detail: insideLibrary ? parent + ", managed by an app" : parent,
                bytes: size,
                selectable: !insideLibrary
            ))
        }
        return found.sorted { $0.bytes > $1.bytes }
    }
}
