import SwiftUI

enum Page: Hashable {
    case overview
    case category(StorageCategory)
    case largeFiles
}

struct ContentView: View {
    @EnvironmentObject var state: AppState
    @State private var page: Page? = .overview

    var body: some View {
        NavigationSplitView {
            List(selection: $page) {
                Label("Overview", systemImage: "internaldrive").tag(Page.overview)
                Section("Clean up") {
                    ForEach(StorageCategory.allCases) { category in
                        HStack {
                            Label(category.rawValue, systemImage: category.symbol)
                            Spacer()
                            let total = state.total(for: category)
                            if total > 0 {
                                Text(total.bytesText).font(.caption).foregroundStyle(.secondary).monospacedDigit()
                            }
                        }
                        .tag(Page.category(category))
                    }
                    Label("Large files", systemImage: "doc.text.magnifyingglass").tag(Page.largeFiles)
                }
            }
            .navigationSplitViewColumnWidth(min: 230, ideal: 250)
        } detail: {
            VStack(spacing: 0) {
                if !state.hasFullDiskAccess { AccessBanner() }
                Group {
                    switch page ?? .overview {
                    case .overview: OverviewView(goTo: { page = $0 })
                    case .category(let category): CategoryView(category: category)
                    case .largeFiles: LargeFilesView()
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                SelectionBar()
            }
        }
        .toolbar {
            ToolbarItemGroup {
                Label("Review only, nothing is deleted", systemImage: "lock.shield")
                    .labelStyle(.titleAndIcon)
                    .foregroundStyle(.green)
                    .help("This app only measures and builds a plan. It never deletes, moves or changes files.")
                Button { state.scanAll() } label: {
                    Label("Scan again", systemImage: "arrow.clockwise")
                }
                .disabled(state.scanning)
                .help("Measure everything again")
            }
        }
        .alert(state.alert?.title ?? "", isPresented: Binding(
            get: { state.alert != nil },
            set: { if !$0 { state.alert = nil } }
        ), presenting: state.alert) { _ in
            Button("OK", role: .cancel) {}
        } message: { alert in
            Text(alert.message)
        }
        .task {
            if state.results.isEmpty { state.scanAll() }
        }
    }
}

struct AccessBanner: View {
    @EnvironmentObject var state: AppState

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: "lock.shield").font(.title2).foregroundStyle(.orange)
            VStack(alignment: .leading, spacing: 2) {
                Text("Full Disk Access is off").font(.headline)
                Text("Without it, several Library folders measure as empty. Turn it on for Storage Cleaner in Settings, then quit and reopen the app.")
                    .font(.callout).foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer()
            Button("Open Settings") { Permissions.openFullDiskAccessSettings() }
            Button("Check again") {
                state.hasFullDiskAccess = Permissions.hasFullDiskAccess()
                if state.hasFullDiskAccess { state.scanAll() }
            }
        }
        .padding(14)
        .background(Color.orange.opacity(0.12))
    }
}

struct SelectionBar: View {
    @EnvironmentObject var state: AppState

    var body: some View {
        if !state.selection.isEmpty {
            HStack(spacing: 12) {
                Image(systemName: "list.bullet.clipboard").foregroundStyle(.orange)
                Text("Plan: \(state.selection.count) items, \(state.selectedBytes.bytesText)")
                    .font(.headline).monospacedDigit()
                Spacer()
                Button("Clear plan") { state.selection.removeAll() }
                Button("Copy plan") { state.copyPlan() }
                Button("Save plan to Desktop") { state.savePlan() }
                    .buttonStyle(.borderedProminent)
                    .tint(.orange)
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 12)
            .background(.bar)
        }
    }
}
