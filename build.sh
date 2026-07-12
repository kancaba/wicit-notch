#!/bin/bash
# Builds Wicit and assembles a runnable .app bundle with an ad-hoc signature.
#
# Usage:
#   ./build.sh          # debug build + bundle
#   ./build.sh release  # optimized build + bundle
#   ./build.sh run      # build, bundle, then relaunch the app
set -euo pipefail

cd "$(dirname "$0")"

CONFIG="debug"
RUN=false
for arg in "$@"; do
    case "$arg" in
        release) CONFIG="release" ;;
        run)     RUN=true ;;
    esac
done

APP_NAME="Wicit"
BUNDLE="build/${APP_NAME}.app"

echo "▶ Building ($CONFIG)…"
swift build -c "$CONFIG"

BIN_PATH="$(swift build -c "$CONFIG" --show-bin-path)/${APP_NAME}"

echo "▶ Assembling ${BUNDLE}…"
rm -rf "$BUNDLE"
mkdir -p "${BUNDLE}/Contents/MacOS"
mkdir -p "${BUNDLE}/Contents/Resources"

cp "$BIN_PATH" "${BUNDLE}/Contents/MacOS/${APP_NAME}"
cp "Resources/Info.plist" "${BUNDLE}/Contents/Info.plist"

if [ -f "Resources/AppIcon.icns" ]; then
    cp "Resources/AppIcon.icns" "${BUNDLE}/Contents/Resources/AppIcon.icns"
fi

# Bundle the mediaremote-adapter (universal now-playing helper).
if [ -d "Vendor/MediaRemoteAdapter" ]; then
    cp -R "Vendor/MediaRemoteAdapter" "${BUNDLE}/Contents/Resources/MediaRemoteAdapter"
fi

echo "▶ Ad-hoc signing…"
codesign --force --deep --sign - "$BUNDLE"

echo "✔ Built ${BUNDLE}"

if [ "$RUN" = true ]; then
    echo "▶ Relaunching…"
    pkill -x "$APP_NAME" 2>/dev/null || true
    sleep 0.3
    open "$BUNDLE"
fi
