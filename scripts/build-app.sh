#!/bin/bash
# Builds Boo.app and a DMG anyone can download and drag to Applications.
#
# No signing identity is assumed. Without an Apple Developer account the
# result is unsigned, so Gatekeeper will ask the user to right-click > Open
# the first time. That is stated plainly in the README rather than hidden.
set -euo pipefail
cd "$(dirname "$0")/.."

APP="Boo.app"
DIST="dist"
VERSION="${1:-1.0.0}"

rm -rf "$DIST" "$APP"
mkdir -p "$DIST"

echo "==> Building release binary"
# SwiftPM quietly ignores repeated --arch on some toolchains, so the two
# slices are built separately and lipo'd. Verified with `lipo -archs`
# below rather than assumed.
swift build -c release --triple arm64-apple-macosx14.0
ARM=$(swift build -c release --triple arm64-apple-macosx14.0 --show-bin-path)/Boo

UNIVERSAL=""
if swift build -c release --triple x86_64-apple-macosx14.0 2>/dev/null; then
  X86=$(swift build -c release --triple x86_64-apple-macosx14.0 --show-bin-path)/Boo
  if [ -f "$X86" ]; then UNIVERSAL="yes"; fi
fi

echo "==> Assembling $APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
if [ -n "$UNIVERSAL" ]; then
  lipo -create "$ARM" "$X86" -output "$APP/Contents/MacOS/Boo"
else
  echo "   (Intel slice unavailable - shipping Apple Silicon only)"
  cp "$ARM" "$APP/Contents/MacOS/Boo"
fi
echo "   architectures: $(lipo -archs "$APP/Contents/MacOS/Boo")"

echo "==> Rendering icon"
ICONSET=$(mktemp -d)/Boo.iconset
mkdir -p "$ICONSET"
swift scripts/make-icon.swift "$ICONSET" >/dev/null
iconutil -c icns "$ICONSET" -o "$APP/Contents/Resources/Boo.icns"

cat > "$APP/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleName</key><string>Boo</string>
    <key>CFBundleDisplayName</key><string>Boo</string>
    <key>CFBundleIdentifier</key><string>so.boo.menubar</string>
    <key>CFBundleVersion</key><string>$VERSION</string>
    <key>CFBundleShortVersionString</key><string>$VERSION</string>
    <key>CFBundleExecutable</key><string>Boo</string>
    <key>CFBundleIconFile</key><string>Boo</string>
    <key>CFBundlePackageType</key><string>APPL</string>
    <key>LSMinimumSystemVersion</key><string>14.0</string>
    <!-- Menu bar only: no Dock icon, no app switcher entry. -->
    <key>LSUIElement</key><true/>
    <key>NSHighResolutionCapable</key><true/>
</dict>
</plist>
PLIST

# Ad-hoc signature. Not notarised, but it stops macOS treating the bundle
# as damaged, which an entirely unsigned binary sometimes triggers.
codesign --force --deep --sign - "$APP" 2>/dev/null || echo "   (ad-hoc signing skipped)"

echo "==> Building DMG"
STAGE=$(mktemp -d)
cp -R "$APP" "$STAGE/"
ln -s /Applications "$STAGE/Applications"
hdiutil create -volname "Boo" -srcfolder "$STAGE" -ov -format UDZO \
    "$DIST/Boo-$VERSION.dmg" >/dev/null
rm -rf "$STAGE"

SIZE=$(du -h "$DIST/Boo-$VERSION.dmg" | cut -f1)
echo "==> Done: $DIST/Boo-$VERSION.dmg ($SIZE)"
