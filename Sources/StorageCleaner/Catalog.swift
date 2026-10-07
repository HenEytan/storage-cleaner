import Foundation

enum Catalog {
    static let all: [Location] = [

        // MARK: Developer tools

        Location(
            id: "avd", title: "Android emulators", category: .developer, risk: .review,
            paths: ["~/.android/avd"],
            effect: "Each emulator image is often 5 to 15 GB. A deleted emulator can be recreated in Android Studio.",
            how: "Tick the emulators you no longer use to add them to your plan. Remove them later in Android Studio Device Manager, so the matching settings file goes too. Wipe Data also shrinks emulators you keep.",
            hideChildSuffixes: [".ini"]
        ),
        Location(
            id: "gradle", title: "Gradle caches and downloaded Gradle versions", category: .developer, risk: .safe,
            paths: ["~/.gradle/caches", "~/.gradle/wrapper/dists"],
            effect: "Downloaded dependencies and Gradle versions. The next build downloads what it needs again, so it is slower once.",
            how: "Quit Android Studio before cleaning."
        ),
        Location(
            id: "sdk", title: "Android SDK images, NDK and build tools", category: .developer, risk: .review,
            paths: ["~/Library/Android/sdk/system-images", "~/Library/Android/sdk/ndk", "~/Library/Android/sdk/build-tools"],
            effect: "Emulator system images and older NDK and build tool versions. A project that needs a removed version asks to download it again.",
            how: "Keep the versions your current projects and emulators use. Android Studio SDK Manager can remove these too."
        ),
        Location(
            id: "studio", title: "Android Studio and Google app caches", category: .developer, risk: .safe,
            paths: ["~/Library/Caches/Google", "~/Library/Logs/Google"],
            effect: "Caches and logs from Android Studio and other Google apps, including folders left by older versions.",
            how: "Quit Android Studio first. Folders named after older Android Studio versions are no longer used."
        ),
        Location(
            id: "xcode", title: "Xcode build data", category: .developer, risk: .safe,
            paths: ["~/Library/Developer/Xcode/DerivedData", "~/Library/Developer/Xcode/iOS DeviceSupport", "~/Library/Developer/CoreSimulator/Caches"],
            effect: "Xcode build output and device symbols. Rebuilt automatically when needed.",
            how: "Quit Xcode first."
        ),
        Location(
            id: "sims", title: "iOS simulators", category: .developer, risk: .review,
            paths: ["~/Library/Developer/CoreSimulator/Devices"],
            effect: "Simulator devices. Unavailable ones belong to Xcode versions that are no longer installed.",
            how: "When you are ready, run this command yourself in Terminal. It removes only unavailable simulators. Manage the rest in Xcode > Window > Devices and Simulators.",
            action: .manual(label: "Copy command", command: "xcrun simctl delete unavailable"),
            showChildren: false
        ),
        Location(
            id: "docker", title: "Docker data", category: .developer, risk: .review,
            paths: ["~/Library/Containers/com.docker.docker"],
            effect: "Images, containers and build cache. Cleaning removes unused images, stopped containers and build cache. Named volumes are kept.",
            how: "When you are ready, run this command yourself in Terminal with Docker Desktop running. It asks for confirmation before removing anything. You can also lower the disk limit in Docker Desktop Settings > Resources.",
            action: .manual(label: "Copy command", command: "docker system prune"),
            showChildren: false
        ),
        Location(
            id: "pkg", title: "Package manager caches", category: .developer, risk: .safe,
            paths: ["~/.npm/_cacache", "~/Library/Caches/Homebrew", "~/Library/Caches/pip", "~/Library/pnpm/store", "~/Library/Caches/Yarn"],
            effect: "Download caches of npm, Homebrew, pip, pnpm and Yarn. Packages download again on the next install.",
            how: "When you are ready, run the command for each tool you have installed: npm cache clean --force, brew cleanup, pnpm store prune, pip3 cache purge.",
            action: .manual(label: "Copy commands", command: "npm cache clean --force\nbrew cleanup\npnpm store prune\npip3 cache purge"),
            showChildren: false
        ),
        Location(
            id: "projects", title: "Project build folders and node_modules", category: .developer, risk: .safe,
            kind: .projects,
            effect: "node_modules and build folders inside your projects. Restored by npm install or the next build.",
            how: "Only folders over 100 MB are listed. Skip the projects you are working on right now."
        ),

        // MARK: System and caches

        Location(
            id: "snapshots", title: "Time Machine local snapshots", category: .system, risk: .safe,
            kind: .snapshots,
            effect: "Restore points stored on this disk, counted as System Data. Backups on your external Time Machine disk are not affected.",
            how: "When you are ready, run this command yourself in Terminal. It asks macOS to release local restore points only.",
            action: .manual(label: "Copy command", command: "tmutil thinlocalsnapshots / 999999999999 4")
        ),
        Location(
            id: "caches", title: "App caches", category: .system, risk: .safe,
            paths: ["~/Library/Caches"],
            effect: "Temporary files apps keep to load faster. Apps rebuild them when needed.",
            how: "Quit the apps first. Apple system caches are not listed, and developer caches are listed under Developer tools.",
            hideChildPrefixes: ["com.apple.", "Google", "Homebrew", "pip", "Yarn", "pnpm", "CloudKit"]
        ),
        Location(
            id: "logs", title: "Logs and crash reports", category: .system, risk: .safe,
            paths: ["~/Library/Logs"],
            effect: "Old app logs and diagnostic reports.",
            how: "Nothing you use day to day is stored here.",
            hideChildPrefixes: ["Google"]
        ),
        Location(
            id: "backups", title: "iPhone and iPad backups", category: .system, risk: .review,
            paths: ["~/Library/Application Support/MobileSync/Backup"],
            effect: "Local device backups. A deleted backup cannot be restored.",
            how: "Keep the latest backup of any device that does not also back up to iCloud. Backups of phones you no longer own are safe to remove."
        ),
        Location(
            id: "appsupport", title: "App data", category: .system, risk: .careful,
            paths: ["~/Library/Application Support"],
            effect: "Data apps keep, such as Claude, Chrome, Slack and Zoom. Some folders may belong to apps you already removed.",
            how: "Clear data from inside each app. Use the magnifier to open a folder in Finder if it belongs to an app you no longer have installed.",
            action: .guide,
            hideChildPrefixes: ["MobileSync"]
        ),
        Location(
            id: "containers", title: "App containers", category: .system, risk: .careful,
            paths: ["~/Library/Containers", "~/Library/Group Containers"],
            effect: "Sandboxed app data, such as WhatsApp and Telegram media and Office files.",
            how: "Clear media inside the app, for example WhatsApp > Settings > Storage and Data > Manage Storage.",
            action: .guide,
            hideChildPrefixes: ["com.docker.docker"]
        ),
        Location(
            id: "messages", title: "Messages attachments", category: .system, risk: .careful,
            paths: ["~/Library/Messages/Attachments"],
            effect: "Photos and files from your Messages conversations.",
            how: "In Storage Settings, open Messages to review and delete large attachments. You can also set Messages to keep conversations for 1 year.",
            action: .guide,
            settingsURL: "x-apple.systempreferences:com.apple.settings.Storage",
            settingsLabel: "Open Storage Settings",
            showChildren: false
        ),

        // MARK: Your files

        Location(
            id: "downloads", title: "Downloads", category: .files, risk: .review,
            paths: ["~/Downloads"],
            effect: "Installers, archives and files you downloaded. DMG, PKG and ZIP files you already used are usually not needed.",
            how: "Tick what you no longer need to add it to your plan."
        ),
        Location(
            id: "movies", title: "Movies and recordings", category: .files, risk: .review,
            paths: ["~/Movies"],
            effect: "Screen recordings, meeting recordings and videos.",
            how: "Check that recordings you want to keep are in the cloud before removing them here."
        ),
        Location(
            id: "desktop", title: "Desktop", category: .files, risk: .review,
            paths: ["~/Desktop"],
            effect: "Screenshots and files saved to the Desktop.",
            how: "Tick what you no longer need to add it to your plan."
        ),
        Location(
            id: "documents", title: "Documents", category: .files, risk: .review,
            paths: ["~/Documents"],
            effect: "Your documents, by top level folder.",
            how: "Ticking adds the whole folder to your plan. To pick single files, open it in Finder with the magnifier or use Large files."
        ),
        Location(
            id: "icloud", title: "iCloud Drive copies on this Mac", category: .files, risk: .careful,
            paths: ["~/Library/Mobile Documents"],
            effect: "Local copies of iCloud Drive files. Deleting them here deletes them from iCloud on every device.",
            how: "In Finder, right click a file or folder in iCloud Drive and choose Remove Download. It stays in iCloud and downloads again when you open it.",
            action: .guide,
            showChildren: false
        ),

        // MARK: Apps and media

        Location(
            id: "apps", title: "Applications", category: .apps, risk: .review,
            paths: ["/Applications"],
            effect: "Installed apps, largest first. A removed app can be installed again.",
            how: "Tick apps you no longer use to add them to your plan. After removing an app, check App data for its leftover folder."
        ),
        Location(
            id: "photos", title: "Photos library", category: .apps, risk: .careful,
            paths: ["~/Pictures/Photos Library.photoslibrary"],
            effect: "Your photo library. With iCloud Photos, Optimize Mac Storage keeps small copies here and originals in iCloud.",
            how: "In Photos, open Settings > iCloud and choose Optimize Mac Storage. Never delete the library in Finder.",
            action: .guide,
            settingsURL: "file:///System/Applications/Photos.app",
            settingsLabel: "Open Photos",
            showChildren: false
        ),

        // MARK: Where the space is (measured last, because it walks your whole home folder)

        Location(
            id: "home", title: "Home folder", category: .map, risk: .review,
            paths: ["~"],
            effect: "Every folder in your home folder, largest first. Library is measured separately.",
            how: "Use the magnifier to open a folder in Finder, then check the matching card in the other sections or use Large files.",
            action: .guide,
            hideChildPrefixes: ["Library"]
        ),
        Location(
            id: "library", title: "Library", category: .map, risk: .review,
            paths: ["~/Library"],
            effect: "App data, caches and containers. Most of what macOS calls System Data lives here.",
            how: "The biggest folders here usually match the App caches, App data, App containers, Docker and Developer cards.",
            action: .guide
        )
    ]

    static func locations(in category: StorageCategory) -> [Location] {
        all.filter { $0.category == category }
    }
}
