#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WORKSPACE_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
BUILD_DIR="$WORKSPACE_ROOT/build"
APP_BUNDLE="$BUILD_DIR/VFlow.app"
CONTENTS_DIR="$APP_BUNDLE/Contents"
MACOS_DIR="$CONTENTS_DIR/MacOS"
RESOURCES_DIR="$CONTENTS_DIR/Resources"

echo "=========================================================="
echo " Building VFlow macOS Native Application (Release)"
echo " Workspace: $WORKSPACE_ROOT"
echo "=========================================================="

# 1. Compile Release Binary
echo "[1/5] Compiling Swift Release Binary..."
export DEVELOPER_DIR="${DEVELOPER_DIR:-/Applications/Xcode.app/Contents/Developer}"
swift build -c release --package-path "$WORKSPACE_ROOT"

RELEASE_BIN="$WORKSPACE_ROOT/.build/release/VFlow"
if [ ! -f "$RELEASE_BIN" ]; then
    echo "Error: Release binary not found at $RELEASE_BIN"
    exit 1
fi

# 2. Prepare App Bundle Structure
echo "[2/5] Creating App Bundle Structure..."
rm -rf "$APP_BUNDLE"
mkdir -p "$MACOS_DIR"
mkdir -p "$RESOURCES_DIR"

# Copy binary
cp "$RELEASE_BIN" "$MACOS_DIR/VFlow"
chmod +x "$MACOS_DIR/VFlow"

# 3. Copy 3D Assets
echo "[3/5] Bundling 3D Assets..."
for asset in app_icon_nobg.png voice_orb_nobg.png neural_core_nobg.png; do
    if [ -f "$WORKSPACE_ROOT/assets/$asset" ]; then
        cp "$WORKSPACE_ROOT/assets/$asset" "$RESOURCES_DIR/"
    fi
done

# 4. Generate AppIcon.icns from app_icon_nobg.png
echo "[4/5] Generating AppIcon.icns..."
ICON_SRC="$WORKSPACE_ROOT/assets/app_icon_nobg.png"
if [ -f "$ICON_SRC" ] && command -v sips >/dev/null 2>&1 && command -v iconutil >/dev/null 2>&1; then
    ICONSET_DIR="$BUILD_DIR/AppIcon.iconset"
    rm -rf "$ICONSET_DIR"
    mkdir -p "$ICONSET_DIR"

    sips -z 16 16     "$ICON_SRC" --out "$ICONSET_DIR/icon_16x16.png" >/dev/null 2>&1
    sips -z 32 32     "$ICON_SRC" --out "$ICONSET_DIR/icon_16x16@2x.png" >/dev/null 2>&1
    sips -z 32 32     "$ICON_SRC" --out "$ICONSET_DIR/icon_32x32.png" >/dev/null 2>&1
    sips -z 64 64     "$ICON_SRC" --out "$ICONSET_DIR/icon_32x32@2x.png" >/dev/null 2>&1
    sips -z 128 128   "$ICON_SRC" --out "$ICONSET_DIR/icon_128x128.png" >/dev/null 2>&1
    sips -z 256 256   "$ICON_SRC" --out "$ICONSET_DIR/icon_128x128@2x.png" >/dev/null 2>&1
    sips -z 256 256   "$ICON_SRC" --out "$ICONSET_DIR/icon_256x256.png" >/dev/null 2>&1
    sips -z 512 512   "$ICON_SRC" --out "$ICONSET_DIR/icon_256x256@2x.png" >/dev/null 2>&1
    sips -z 512 512   "$ICON_SRC" --out "$ICONSET_DIR/icon_512x512.png" >/dev/null 2>&1
    sips -z 1024 1024 "$ICON_SRC" --out "$ICONSET_DIR/icon_512x512@2x.png" >/dev/null 2>&1

    iconutil -c icns "$ICONSET_DIR" -o "$RESOURCES_DIR/AppIcon.icns"
    rm -rf "$ICONSET_DIR"
    echo "Generated $RESOURCES_DIR/AppIcon.icns"
fi

# 5. Write Info.plist
echo "[5/5] Writing Info.plist..."
cat << 'EOF' > "$CONTENTS_DIR/Info.plist"
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleIdentifier</key>
    <string>com.apexdev.vflow</string>
    <key>CFBundleName</key>
    <string>VFlow</string>
    <key>CFBundleDisplayName</key>
    <string>VFlow</string>
    <key>CFBundleExecutable</key>
    <string>VFlow</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>1.0.1</string>
    <key>CFBundleVersion</key>
    <string>2</string>
    <key>CFBundleIconFile</key>
    <string>AppIcon</string>
    <key>LSMinimumSystemVersion</key>
    <string>14.0</string>
    <key>LSUIElement</key>
    <true/>
    <key>NSPrincipalClass</key>
    <string>NSApplication</string>
    <key>NSMicrophoneUsageDescription</key>
    <string>VFlow cần quyền Microphone để sử dụng tính năng gõ tiếng Việt bằng giọng nói (Voice Dictation).</string>
    <key>NSSpeechRecognitionUsageDescription</key>
    <string>VFlow sử dụng nhận dạng giọng nói để chuyển lời nói thành văn bản tức thì.</string>
    <key>NSHighResolutionCapable</key>
    <true/>
</dict>
</plist>
EOF

# Optional ad-hoc codesign
if command -v codesign >/dev/null 2>&1; then
    codesign --force --deep --sign - "$APP_BUNDLE" >/dev/null 2>&1 || true
fi

echo "=========================================================="
echo " ✅ VFlow.app build successfully packaged at:"
echo "    $APP_BUNDLE"
echo "=========================================================="
