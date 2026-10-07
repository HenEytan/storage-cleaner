import SwiftUI

struct OverviewView: View {
    @EnvironmentObject var state: AppState
    var goTo: (Page) -> Void

    private func sorted(_ risk: Risk) -> [Location] {
        Catalog.all
            .filter { $0.risk == risk && $0.category != .map && state.results[$0.id]?.exists != false }
            .sorted { state.size(of: $0) > state.size(of: $1) }
    }

    private func whereSpaceIs() -> [Item] {
        var items = state.results["home"]?.items ?? []
        if let library = state.results["library"], library.total > 0 {
            items.append(Item(path: NSHomeDirectory() + "/Library", name: "Library (app data and caches)", bytes: library.total, selectable: false))
        }
        if let apps = state.results["apps"], apps.total > 0 {
            items.append(Item(path: "/Applications", name: "Applications", bytes: apps.total, selectable: false))
        }
        return items.sorted { $0.bytes > $1.bytes }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                DiskBarView()

                let mapItems = whereSpaceIs()
                if !mapItems.isEmpty {
                    SectionBox(title: "Where your space is", subtitle: "Largest first. Library holds app data and caches, which macOS shows as System Data.") {
                        let top = max(mapItems.first?.bytes ?? 1, 1)
                        ForEach(Array(mapItems.prefix(12))) { item in
                            MapRow(name: item.name, bytes: item.bytes, fraction: Double(item.bytes) / Double(top), path: item.path)
                        }
                    }
                }

                if state.scanning {
                    HStack(spacing: 10) {
                        ProgressView(value: Double(state.progress), total: Double(Catalog.all.count))
                            .frame(width: 180)
                        Text("Measuring \(min(state.progress + 1, Catalog.all.count)) of \(Catalog.all.count) places")
                            .foregroundStyle(.secondary)
                    }
                }

                SectionBox(title: "Safe to clean", subtitle: "These rebuild or download again on their own.") {
                    ForEach(sorted(.safe)) { SummaryRow(location: $0, goTo: goTo) }
                    HStack(spacing: 12) {
                        Button("Add safe items to plan") { state.addSafeToPlan() }
                            .buttonStyle(.borderedProminent)
                            .disabled(state.scanning)
                        Text("Then use the bar at the bottom to save the plan or move it to the Trash.")
                            .font(.callout).foregroundStyle(.secondary)
                    }
                    .padding(.top, 6)
                }

                SectionBox(title: "Worth a look", subtitle: "Open each one and tick what you no longer need to add it to the plan.") {
                    ForEach(sorted(.review)) { SummaryRow(location: $0, goTo: goTo) }
                }

                SectionBox(title: "Clean from inside the app", subtitle: "Shown so you know where the space is. The app that owns this data should remove it.") {
                    ForEach(sorted(.careful)) { SummaryRow(location: $0, goTo: goTo) }
                }
            }
            .padding(24)
            .frame(maxWidth: 900, alignment: .leading)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

struct DiskBarView: View {
    @EnvironmentObject var state: AppState

    var body: some View {
        let disk = state.disk
        let total = max(Double(disk.total), 1)
        let selected = Double(state.selectedBytes)
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(disk.free.bytesText)
                    .font(.system(size: 34, weight: .bold, design: .rounded))
                    .monospacedDigit()
                Text("free of \(disk.total.bytesText)").foregroundStyle(.secondary)
                Spacer()
                if state.selectedBytes > 0 {
                    Text("\(state.selectedBytes.bytesText) selected")
                        .fontWeight(.semibold)
                        .foregroundStyle(.orange)
                }
            }
            GeometryReader { geo in
                let width = geo.size.width
                let usedWidth = width * Double(disk.used) / total
                let selectedWidth = min(usedWidth, width * selected / total)
                ZStack(alignment: .leading) {
                    Rectangle().fill(Color.primary.opacity(0.08))
                    Rectangle().fill(Color.secondary.opacity(0.55)).frame(width: usedWidth)
                    Rectangle().fill(Color.orange).frame(width: selectedWidth).offset(x: usedWidth - selectedWidth)
                }
                .clipShape(RoundedRectangle(cornerRadius: 6))
            }
            .frame(height: 22)
            Text(summary).font(.callout).foregroundStyle(.secondary)
        }
        .padding(18)
        .background(RoundedRectangle(cornerRadius: 12).fill(Color(nsColor: .controlBackgroundColor)))
    }

    private var summary: String {
        let after = state.disk.free + state.selectedBytes
        var text = state.selectedBytes > 0
            ? "After you clean everything in the plan you would have \(after.bytesText) free."
            : "Aim to keep at least 50 GB free so updates and swap work smoothly."
        if state.disk.purgeable > 1_000_000_000 {
            text += " macOS also marks \(state.disk.purgeable.bytesText) as purgeable, mostly snapshots and caches it can remove on its own."
        }
        return text
    }
}

struct SectionBox<Content: View>: View {
    let title: String
    let subtitle: String
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title).font(.title2.bold())
            Text(subtitle).foregroundStyle(.secondary)
            VStack(alignment: .leading, spacing: 0) { content }
                .padding(.top, 4)
        }
    }
}

struct SummaryRow: View {
    @EnvironmentObject var state: AppState
    let location: Location
    var goTo: (Page) -> Void

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 10) {
                Circle().fill(location.risk.color).frame(width: 8, height: 8)
                Text(location.title)
                Spacer()
                SizeLabel(location: location, compact: true)
                Button("Open") { goTo(.category(location.category)) }
                    .controlSize(.small)
            }
            .padding(.vertical, 8)
            Divider()
        }
    }
}

struct MapRow: View {
    let name: String
    let bytes: Int64
    let fraction: Double
    let path: String

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 5) {
                    Text(name).lineLimit(1).truncationMode(.middle)
                    GeometryReader { geo in
                        Capsule()
                            .fill(Color.accentColor.opacity(0.7))
                            .frame(width: max(3, geo.size.width * fraction))
                    }
                    .frame(height: 5)
                }
                Text(bytes.bytesText).monospacedDigit().fontWeight(.semibold).frame(width: 90, alignment: .trailing)
                Button { Finder.reveal(path) } label: { Image(systemName: "magnifyingglass") }
                    .buttonStyle(.borderless)
                    .help("Show in Finder")
            }
            .padding(.vertical, 7)
            Divider()
        }
    }
}
