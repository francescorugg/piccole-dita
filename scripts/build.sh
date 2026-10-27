#!/bin/bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"
APP="$ROOT/dist/Piccole Dita.app"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources" build/ModuleCache build/AppIcon.iconset
cp App/Info.plist "$APP/Contents/Info.plist"
xcrun swiftc App/main.swift -o "$APP/Contents/MacOS/PiccoleDita" \
  -framework AppKit -framework AVFoundation -O \
  -target arm64-apple-macosx14.0 -module-cache-path "$ROOT/build/ModuleCache"
xcrun swift -module-cache-path "$ROOT/build/ModuleCache" -target arm64-apple-macosx14.0 App/Icon.swift "$ROOT/build/icon.png"
for size in 16 32 128 256 512; do
  sips -z "$size" "$size" build/icon.png --out "build/AppIcon.iconset/icon_${size}x${size}.png" >/dev/null
  double=$((size * 2))
  sips -z "$double" "$double" build/icon.png --out "build/AppIcon.iconset/icon_${size}x${size}@2x.png" >/dev/null
done
iconutil -c icns build/AppIcon.iconset -o "$APP/Contents/Resources/AppIcon.icns"
codesign --force --deep --sign - "$APP"
codesign --verify --deep --strict "$APP"
plutil -lint "$APP/Contents/Info.plist"
ditto -c -k --sequesterRsrc --keepParent "$APP" dist/PiccoleDita-Mac-AppleSilicon.zip
printf '\nApp creata in: %s\n' "$APP"
