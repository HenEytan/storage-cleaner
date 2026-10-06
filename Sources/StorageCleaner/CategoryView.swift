import SwiftUI
import AppKit

struct CategoryView: View {
    let category: StorageCategory

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                Text(category.rawValue).font(.largeTitle.bold())
                Text(category.blurb).foregroundStyle(.secondary)
                RiskKey().padding(.bottom, 4)
                ForEach(Catalog.locations(in: category)) { LocationCard(location: $0) }
            }
            .padding(24)
            .frame(maxWidth: 900, alignment: .leading)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

struct RiskKey: View {
    var body: some View {
        HStack(spacing: 18) {
            HStack(spacing: 6) { RiskBadge(risk: .safe); Text("Comes back on its own") }
            HStack(spacing: 6) { RiskBadge(risk: .review); Text("Your decision") }
            HStack(spacing: 6) { RiskBadge(risk: .careful); Text("Remove from inside the app") }
        }
        .font(.callout)
        .foregroundStyle(.secondary)
    }
}

struct RiskBadge: View {
    let risk: Risk

    var body: some View {
        Text(risk.title)
            .font(.caption.weight(.semibold))
            .padding(.horizontal, 7)
            .padding(.vertical, 2)
            .background(Capsule().fill(risk.color.opacity(0.18)))
            .foregroundStyle(risk.color)
    }
}

struct SizeLabel: View {
    @EnvironmentObject var state: AppState
    let location: Location
    var compact = false

    var body: some View {
        if let result = state.results[location.id] {
            if let note = result.note {
                Text(note).font(.callout).foregroundStyle(.secondary)
            } else if !result.exists {
                Text("Not on this Mac").font(.callout).foregroundStyle(.tertiary)
            } else {
                Text(result.total.bytesText)
                    .font(compact ? Font.body.weight(.semibold) : Font.title3.weight(.semibold))
                    .monospacedDigit()
            }
        } else if state.scanning {
            ProgressView().controlSize(.small)
        } else {
            Text("Not measured").font(.callout).foregroundStyle(.tertiary)
        }
    }
}

struct LocationCard: View {
    @EnvironmentObject var state: AppState
    let location: Location
    @State private var expanded = false
    @State private var showAll = false

    var body: some View {
        let items = state.results[location.id]?.items ?? []
        let existing = location.expandedPaths.first { FileManager.default.fileExists(atPath: $0) }

        HStack(spacing: 0) {
            Rectangle().fill(location.risk.color).frame(width: 4)

            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .top, spacing: 12) {
                    if location.isPickable {
                        Toggle("", isOn: Binding(
                            get: { state.allSelected(location) },
                            set: { state.setAll(location, $0) }
                        ))
                        .toggleStyle(.checkbox)
                        .labelsHidden()
                        .disabled(state.selectableItems(location).isEmpty)
                        .help("Add everything listed here to the plan")
                        .padding(.top, 2)
                    }
                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 8) {
                            Text(location.title).font(.headline)
                            RiskBadge(risk: location.risk)
                        }
                        Text(location.effect)
                            .font(.callout)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    Spacer(minLength: 12)
                    SizeLabel(location: location)
                }

                HStack(spacing: 8) {
                    Button(expanded ? "Hide details" : "Details") {
                        withAnimation(.easeOut(duration: 0.15)) { expanded.toggle() }
                    }
                    if let manual = location.manual {
                        Button(manual.label) { state.copyCommand(manual.command) }
                            .help("Copies the command so you can run it yourself. The app never runs it.")
                    }
                    if let link = location.settingsURL, let url = URL(string: link) {
                        Button(location.settingsLabel) { NSWorkspace.shared.open(url) }
                    }
                    if let path = existing {
                        Button("Show in Finder") { Finder.reveal(path) }
                    }
                    Spacer()
                }
                .controlSize(.small)

                if expanded {
                    Text(location.how)
                        .font(.callout)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(10)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(RoundedRectangle(cornerRadius: 6).fill(Color.primary.opacity(0.05)))

                    if let manual = location.manual {
                        Text(manual.command)
                            .font(.system(.callout, design: .monospaced))
                            .textSelection(.enabled)
                            .padding(10)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(RoundedRectangle(cornerRadius: 6).fill(Color.primary.opacity(0.08)))
                    }

                    if !items.isEmpty {
                        VStack(spacing: 0) {
                            ForEach(showAll ? items : Array(items.prefix(8))) { item in
                                ItemRow(item: item)
                                Divider()
                            }
                        }
                        if items.count > 8 {
                            Button(showAll ? "Show fewer" : "Show all \(items.count)") { showAll.toggle() }
                                .buttonStyle(.link)
                        }
                    } else if location.showChildren && state.results[location.id]?.exists == true {
                        Text("Nothing larger than 1 MB here.").font(.callout).foregroundStyle(.secondary)
                    }
                }
            }
            .padding(16)
        }
        .background(Color(nsColor: .controlBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.primary.opacity(0.08)))
    }
}

struct ItemRow: View {
    @EnvironmentObject var state: AppState
    let item: Item

    private var isSnapshot: Bool { item.path.hasPrefix("snapshot:") }

    var body: some View {
        HStack(spacing: 10) {
            if item.selectable {
                Toggle("", isOn: Binding(
                    get: { state.selection.contains(item.path) },
                    set: { state.toggle(item, $0) }
                ))
                .toggleStyle(.checkbox)
                .labelsHidden()
            } else if isSnapshot {
                Image(systemName: "clock.arrow.circlepath").foregroundStyle(.secondary).frame(width: 16)
            } else {
                Image(systemName: "lock").foregroundStyle(.tertiary).frame(width: 16)
                    .help("Managed by its app, so it cannot be added to the plan")
            }
            VStack(alignment: .leading, spacing: 1) {
                Text(item.name).lineLimit(1).truncationMode(.middle)
                if let detail = item.detail {
                    Text(detail).font(.caption).foregroundStyle(.secondary).lineLimit(1).truncationMode(.middle)
                }
            }
            Spacer()
            if item.bytes > 0 {
                Text(item.bytes.bytesText).monospacedDigit().foregroundStyle(.secondary)
            }
            if !isSnapshot {
                Button { Finder.reveal(item.path) } label: { Image(systemName: "magnifyingglass") }
                    .buttonStyle(.borderless)
                    .help("Show in Finder")
            }
        }
        .padding(.vertical, 6)
    }
}

struct LargeFilesView: View {
    @EnvironmentObject var state: AppState
    @State private var threshold: Int64 = 1_000_000_000

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                Text("Large files").font(.largeTitle.bold())
                Text("Finds single files above a size anywhere in your home folder. Files inside app data folders are shown but locked, because the app that owns them should remove them. iCloud Drive is skipped.")
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                HStack(spacing: 12) {
                    Picker("Larger than", selection: $threshold) {
                        Text("500 MB").tag(Int64(500_000_000))
                        Text("1 GB").tag(Int64(1_000_000_000))
                        Text("5 GB").tag(Int64(5_000_000_000))
                    }
                    .frame(width: 210)
                    Button(state.largeScanned ? "Search again" : "Search") { state.findLargeFiles(threshold) }
                        .buttonStyle(.borderedProminent)
                        .disabled(state.largeScanning)
                    if state.largeScanning {
                        ProgressView().controlSize(.small)
                        Text("This can take a few minutes.").foregroundStyle(.secondary)
                    }
                }

                if state.largeScanned && !state.largeScanning {
                    if state.largeFiles.isEmpty {
                        Text("No files above this size were found.").foregroundStyle(.secondary)
                    } else {
                        let total = state.largeFiles.reduce(Int64(0)) { $0 + $1.bytes }
                        Text("\(state.largeFiles.count) files, \(total.bytesText) in total").font(.headline)
                    }
                }

                VStack(spacing: 0) {
                    ForEach(state.largeFiles) { item in
                        ItemRow(item: item)
                        Divider()
                    }
                }
            }
            .padding(24)
            .frame(maxWidth: 900, alignment: .leading)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}
