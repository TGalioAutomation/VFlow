#!/usr/bin/env bash
set -euo pipefail

# ==============================================================================
# VFlow Release Packaging Script
# Packages production distributable artifacts:
#   - build/VFlow.app (Codesigned native macOS application bundle)
#   - build/release/VFlow-v1.0.0-macOS-arm64.dmg (Compressed DMG with /Applications link)
#   - build/release/VFlow-v1.0.0-macOS-arm64.zip (Resource-fork preserved ZIP via ditto)
#   - build/release/SHA256SUMS.txt (SHA-256 checksums verifiable via shasum)
# ==============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WORKSPACE_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
BUILD_DIR="$WORKSPACE_ROOT/build"
APP_BUNDLE="$BUILD_DIR/VFlow.app"
RELEASE_DIR="$BUILD_DIR/release"
VERSION="v1.0.0"
ARCH="macOS-arm64"
DMG_NAME="VFlow-${VERSION}-${ARCH}.dmg"
ZIP_NAME="VFlow-${VERSION}-${ARCH}.zip"
DMG_PATH="$RELEASE_DIR/$DMG_NAME"
ZIP_PATH="$RELEASE_DIR/$ZIP_NAME"
CHECKSUM_FILE="$RELEASE_DIR/SHA256SUMS.txt"

echo "=========================================================="
echo " Packaging VFlow Release Distributables ($VERSION - $ARCH)"
echo " Workspace: $WORKSPACE_ROOT"
echo "=========================================================="

# 1. Build and Assemble VFlow.app Bundle
echo "[1/5] Building application bundle via scripts/build_app.sh..."
if [ -f "$SCRIPT_DIR/build_app.sh" ]; then
    bash "$SCRIPT_DIR/build_app.sh"
else
    echo "Error: build_app.sh not found at $SCRIPT_DIR/build_app.sh"
    exit 1
fi

if [ ! -d "$APP_BUNDLE" ]; then
    echo "Error: Application bundle was not created at $APP_BUNDLE"
    exit 1
fi

# 2. Verify and Enforce Code Signing
echo "[2/5] Enforcing code signature on VFlow.app..."
if command -v codesign >/dev/null 2>&1; then
    codesign --force --deep --sign - "$APP_BUNDLE"
    echo "Verifying bundle code signature..."
    codesign --verify --deep --strict --verbose=2 "$APP_BUNDLE"
else
    echo "Warning: codesign command not available, skipping signature enforcement."
fi

# Ensure release output directory exists
mkdir -p "$RELEASE_DIR"
rm -f "$DMG_PATH" "$ZIP_PATH" "$CHECKSUM_FILE"

# 3. Package DMG with /Applications Drag-and-Drop Staging
echo "[3/5] Packaging DMG: $DMG_NAME..."
STAGING_DIR="$(mktemp -d "${TMPDIR:-/tmp}/vflow_dmg_staging.XXXXXX")"
cleanup_staging() {
    if [ -d "$STAGING_DIR" ]; then
        rm -rf "$STAGING_DIR"
    fi
}
trap cleanup_staging EXIT INT TERM

# Copy application bundle to staging area using ditto to preserve permissions & metadata
ditto "$APP_BUNDLE" "$STAGING_DIR/VFlow.app"
# Create symlink to /Applications for standard drag-and-drop installer
ln -s /Applications "$STAGING_DIR/Applications"

# Create UDZO zlib-compressed DMG
hdiutil create \
    -volname "VFlow" \
    -srcfolder "$STAGING_DIR" \
    -ov \
    -format UDZO \
    "$DMG_PATH"

cleanup_staging
trap - EXIT INT TERM

if [ ! -f "$DMG_PATH" ]; then
    echo "Error: DMG file was not created at $DMG_PATH"
    exit 1
fi
echo "✅ DMG generated successfully: $DMG_PATH"

# 4. Package ZIP using ditto (preserving macOS resource forks, attributes & symlinks)
echo "[4/5] Packaging ZIP: $ZIP_NAME..."
ditto -c -k --sequesterRsrc --keepParent "$APP_BUNDLE" "$ZIP_PATH"

if [ ! -f "$ZIP_PATH" ]; then
    echo "Error: ZIP file was not created at $ZIP_PATH"
    exit 1
fi
echo "✅ ZIP generated successfully: $ZIP_PATH"

# 5. Compute SHA-256 Checksums
echo "[5/5] Computing SHA-256 Checksums in $RELEASE_DIR..."
(
    cd "$RELEASE_DIR"
    shasum -a 256 "$DMG_NAME" "$ZIP_NAME" > "SHA256SUMS.txt"
)

if [ ! -f "$CHECKSUM_FILE" ]; then
    echo "Error: Checksum file not created at $CHECKSUM_FILE"
    exit 1
fi

echo "Verifying checksum file integrity..."
(
    cd "$RELEASE_DIR"
    shasum -a 256 -c "SHA256SUMS.txt"
)

echo "=========================================================="
echo " 🎉 Release Packaging Complete!"
echo " Output directory: $RELEASE_DIR"
echo "----------------------------------------------------------"
ls -lh "$RELEASE_DIR"
echo "----------------------------------------------------------"
cat "$CHECKSUM_FILE"
echo "=========================================================="
