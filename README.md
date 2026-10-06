# Storage Cleaner

A native Mac app (SwiftUI, macOS 13 or later) that shows where your disk space went, builds a cleanup plan,
and can move the planned items to the Trash after macOS confirms it is you.

Safety rules built into the code:

* Measuring only runs `du`, `tmutil listlocalsnapshots` and `find`, through an allowlist in `Shell.swift`.
* Files are only ever moved to the Trash, never deleted permanently. The app never empties the Trash.
* Moving requires a confirmation dialog and then Touch ID or your Mac password (`Deleter.swift`).
* Protected places are refused even if selected: iCloud Drive, cloud storage, app containers, Messages, Mail,
  Keychains, the Photos library, system folders, and top level folders like Documents.
* App data and other "Use the app" items cannot be selected at all.
* Snapshot, Docker, package cache and simulator commands are never run. The app copies them for you.
* The build stops if any other delete, move or shell code appears in `Sources`.

Builds run on GitHub Actions and are published under Releases.
