#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."

swift build -c release
binary="$(swift build -c release --show-bin-path)/DropConvert"

app="build/DropConvert.app"
rm -rf "$app"
mkdir -p "$app/Contents/MacOS"
cp "$binary" "$app/Contents/MacOS/DropConvert"

cat > "$app/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleExecutable</key><string>DropConvert</string>
  <key>CFBundleIdentifier</key><string>com.dropconvert.app</string>
  <key>CFBundleName</key><string>DropConvert</string>
  <key>CFBundlePackageType</key><string>APPL</string>
  <key>CFBundleShortVersionString</key><string>0.1.0</string>
  <key>CFBundleVersion</key><string>1</string>
  <key>LSMinimumSystemVersion</key><string>15.0</string>
  <key>LSUIElement</key><true/>
  <key>NSHighResolutionCapable</key><true/>
</dict>
</plist>
PLIST

plutil -lint "$app/Contents/Info.plist" >/dev/null
codesign --force --sign - "$app"
echo "Built $app"
