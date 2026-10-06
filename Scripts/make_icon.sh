#!/bin/bash
# Builds Resources/AppIcon.icns from Scripts/make_icon.swift using macOS tools.
set -euo pipefail
cd "$(dirname "$0")/.."
WORK="build/icon"
mkdir -p "$WORK/AppIcon.iconset"
swift Scripts/make_icon.swift "$WORK/icon_1024.png"
for s in 16 32 128 256 512; do
  sips -z $s $s "$WORK/icon_1024.png" --out "$WORK/AppIcon.iconset/icon_${s}x${s}.png" >/dev/null
  d=$((s*2))
  sips -z $d $d "$WORK/icon_1024.png" --out "$WORK/AppIcon.iconset/icon_${s}x${s}@2x.png" >/dev/null
done
iconutil -c icns "$WORK/AppIcon.iconset" -o Resources/AppIcon.icns
echo "Icon ready"
