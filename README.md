# Storage Cleaner

A native Mac app (SwiftUI, macOS 13 or later) that shows where your disk space went and builds a cleanup plan.
It is review only: it never deletes, moves or changes your files.

* It only runs measuring tools (`du`, `tmutil listlocalsnapshots`, `find`) through an allowlist in `Shell.swift`.
* The build stops if any delete, move or shell code appears in `Sources`.
* The only file it writes is a new plan file on your Desktop.

Builds run on GitHub Actions and are published under Releases.
