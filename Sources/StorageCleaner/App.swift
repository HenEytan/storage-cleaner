import SwiftUI
import AppKit

@main
struct StorageCleanerApp: App {
    @StateObject private var state = AppState()

    init() {
        // Lets the app show a window and Dock icon when started with `swift run` as well.
        NSApplication.shared.setActivationPolicy(.regular)
    }

    var body: some Scene {
        WindowGroup("Storage Cleaner") {
            ContentView()
                .environmentObject(state)
                .frame(minWidth: 940, minHeight: 640)
                .onAppear { NSApp.activate(ignoringOtherApps: true) }
        }
        .commands {
            CommandGroup(replacing: .newItem) {}
        }
    }
}
