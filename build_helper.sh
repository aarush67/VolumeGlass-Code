#!/bin/bash
# Build VolumeGlassUpdater helper and copy to app bundle

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$SCRIPT_DIR"
HELPER_SRC="$PROJECT_DIR/VolumeGlassUpdater/main.swift"
BUILD_TEMP="$PROJECT_DIR/build"

echo "Building VolumeGlassUpdater helper..."
mkdir -p "$BUILD_TEMP"

# Use Xcode's deployment target when available, fall back to 14.0
DEPLOY_TARGET="${MACOSX_DEPLOYMENT_TARGET:-14.0}"

swiftc -o "$BUILD_TEMP/VolumeGlassUpdater" \
    "$HELPER_SRC" \
    -framework AppKit \
    -framework SwiftUI \
    -O \
    -target arm64-apple-macos${DEPLOY_TARGET}

echo "✅ VolumeGlassUpdater built successfully"

# Sign with Hardened Runtime
SIGN_IDENTITY="${EXPANDED_CODE_SIGN_IDENTITY:--}"
codesign --force --options runtime --sign "$SIGN_IDENTITY" "$BUILD_TEMP/VolumeGlassUpdater"
echo "✅ Signed VolumeGlassUpdater with Hardened Runtime"

# CODESIGNING_FOLDER_PATH is set by Xcode to the actual built .app path
# for any configuration (Debug or Release). Fall back to BUILT_PRODUCTS_DIR.
if [ -n "$CODESIGNING_FOLDER_PATH" ]; then
    HELPERS_DIR="$CODESIGNING_FOLDER_PATH/Contents/Helpers"
elif [ -n "$BUILT_PRODUCTS_DIR" ]; then
    HELPERS_DIR="$BUILT_PRODUCTS_DIR/VolumeGlass.app/Contents/Helpers"
else
    HELPERS_DIR="$BUILD_TEMP/Release/VolumeGlass.app/Contents/Helpers"
fi

mkdir -p "$HELPERS_DIR"
cp "$BUILD_TEMP/VolumeGlassUpdater" "$HELPERS_DIR/"
codesign --force --options runtime --sign "$SIGN_IDENTITY" "$HELPERS_DIR/VolumeGlassUpdater"
echo "✅ Copied and re-signed in $HELPERS_DIR"
