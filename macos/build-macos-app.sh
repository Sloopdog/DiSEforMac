#!/bin/zsh
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")" && pwd)"
BUILD_DIR="$ROOT_DIR/.build/release"
APP_DIR="$ROOT_DIR/build/DiSE Programmer.app"
BIN_NAME="DiSEMac"
APP_VERSION="${APP_VERSION:-1.0}"
BUILD_STAMP="$(date '+%Y%m%d.%H%M%S')"
ICON_SCRIPT="$ROOT_DIR/make-app-icon.swift"
CUSTOM_ICON_PNG="$ROOT_DIR/AppIcon.png"
BUILD_ICON_PNG="$ROOT_DIR/build/AppIcon.png"
GENERATED_ICON_PNG="$ROOT_DIR/build/AppIcon.generated.png"
ICON_PNG=""
ICONSET_DIR="$ROOT_DIR/build/AppIcon.iconset"
ICON_ICNS="$APP_DIR/Contents/Resources/AppIcon.icns"

swift build -c release --package-path "$ROOT_DIR"

rm -rf "$APP_DIR"
mkdir -p "$APP_DIR/Contents/MacOS" "$APP_DIR/Contents/Resources"

if [[ -f "$CUSTOM_ICON_PNG" ]]; then
  ICON_PNG="$CUSTOM_ICON_PNG"
elif [[ -f "$BUILD_ICON_PNG" ]]; then
  ICON_PNG="$BUILD_ICON_PNG"
elif [[ -f "$ICON_SCRIPT" ]]; then
  ICON_PNG="$GENERATED_ICON_PNG"
  swift "$ICON_SCRIPT" "$ICON_PNG"
fi

if [[ -n "$ICON_PNG" && -f "$ICON_PNG" ]]; then
  rm -rf "$ICONSET_DIR"
  mkdir -p "$ICONSET_DIR"

  sips -z 16 16     "$ICON_PNG" --out "$ICONSET_DIR/icon_16x16.png" >/dev/null
  sips -z 32 32     "$ICON_PNG" --out "$ICONSET_DIR/icon_16x16@2x.png" >/dev/null
  sips -z 32 32     "$ICON_PNG" --out "$ICONSET_DIR/icon_32x32.png" >/dev/null
  sips -z 64 64     "$ICON_PNG" --out "$ICONSET_DIR/icon_32x32@2x.png" >/dev/null
  sips -z 128 128   "$ICON_PNG" --out "$ICONSET_DIR/icon_128x128.png" >/dev/null
  sips -z 256 256   "$ICON_PNG" --out "$ICONSET_DIR/icon_128x128@2x.png" >/dev/null
  sips -z 256 256   "$ICON_PNG" --out "$ICONSET_DIR/icon_256x256.png" >/dev/null
  sips -z 512 512   "$ICON_PNG" --out "$ICONSET_DIR/icon_256x256@2x.png" >/dev/null
  sips -z 512 512   "$ICON_PNG" --out "$ICONSET_DIR/icon_512x512.png" >/dev/null
  cp "$ICON_PNG" "$ICONSET_DIR/icon_512x512@2x.png"
  iconutil -c icns "$ICONSET_DIR" -o "$ICON_ICNS"
fi

cat > "$APP_DIR/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleDevelopmentRegion</key>
    <string>en</string>
    <key>CFBundleExecutable</key>
    <string>DiSEMac</string>
    <key>CFBundleIdentifier</key>
    <string>com.shaise.dise.macos</string>
    <key>CFBundleInfoDictionaryVersion</key>
    <string>6.0</string>
    <key>CFBundleIconFile</key>
    <string>AppIcon</string>
    <key>CFBundleName</key>
    <string>DiSE Programmer</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>$APP_VERSION</string>
    <key>CFBundleVersion</key>
    <string>$BUILD_STAMP</string>
    <key>LSMinimumSystemVersion</key>
    <string>13.0</string>
    <key>NSPrincipalClass</key>
    <string>NSApplication</string>
</dict>
</plist>
PLIST

cp "$BUILD_DIR/$BIN_NAME" "$APP_DIR/Contents/MacOS/$BIN_NAME"
codesign --force --deep --sign - "$APP_DIR" >/dev/null 2>&1 || true

echo "Built: $APP_DIR"
