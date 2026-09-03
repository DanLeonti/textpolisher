#!/usr/bin/env bash
#
# Builds text_polisher.app from the SwiftPM executable, signs it, and
# refreshes the macOS Services registry so "Polish Text" appears in the
# right-click > Services menu.
#
# Usage:
#   Scripts/build_app.sh                 # ad-hoc signed (local use)
#   SIGN_IDENTITY="Developer ID Application: Your Name (TEAMID)" Scripts/build_app.sh
#
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_NAME="TextPolisher"
CONFIG="${CONFIG:-release}"
APP_DIR="$ROOT/dist/$APP_NAME.app"
CONTENTS="$APP_DIR/Contents"

cd "$ROOT"

echo "==> Building ($CONFIG)"
swift build -c "$CONFIG"
BIN_PATH="$(swift build -c "$CONFIG" --show-bin-path)/$APP_NAME"

echo "==> Assembling app bundle"
rm -rf "$APP_DIR"
mkdir -p "$CONTENTS/MacOS" "$CONTENTS/Resources"
cp "$BIN_PATH" "$CONTENTS/MacOS/$APP_NAME"
cp "$ROOT/Packaging/Info.plist" "$CONTENTS/Info.plist"
if [[ -f "$ROOT/Packaging/AppIcon.icns" ]]; then
    cp "$ROOT/Packaging/AppIcon.icns" "$CONTENTS/Resources/AppIcon.icns"
else
    echo "    (no Packaging/AppIcon.icns yet - run Scripts/make_icon.sh to add an icon)"
fi

echo "==> Signing"
# A stable signing identity (Developer ID, or a self-signed code-signing cert)
# keeps the macOS Accessibility grant valid across rebuilds. Ad-hoc signing
# changes the binary hash every build, so you must re-grant Accessibility each
# time. Set SIGN_IDENTITY, or create a local cert named "text_polisher Local"
# (Keychain Access > Certificate Assistant > Create a Certificate >
# Type: Code Signing) and this script will use it automatically.
LOCAL_IDENTITY="text_polisher Local"
if [[ -n "${SIGN_IDENTITY:-}" ]]; then
    codesign --force --options runtime --timestamp --sign "$SIGN_IDENTITY" "$APP_DIR"
    echo "    Signed with: $SIGN_IDENTITY"
    echo "    To notarize: xcrun notarytool submit (zip the .app) then xcrun stapler staple \"$APP_DIR\""
elif security find-identity -v -p codesigning 2>/dev/null | grep -q "$LOCAL_IDENTITY"; then
    codesign --force --sign "$LOCAL_IDENTITY" "$APP_DIR"
    echo "    Signed with local identity: $LOCAL_IDENTITY (Accessibility grant persists across rebuilds)."
else
    codesign --force --sign - "$APP_DIR"
    echo "    Ad-hoc signed. NOTE: re-grant Accessibility after each rebuild,"
    echo "    or create a '$LOCAL_IDENTITY' code-signing cert so the grant persists."
fi

echo "==> Refreshing Services registry"
/System/Library/CoreServices/pbs -update >/dev/null 2>&1 || true
/System/Library/CoreServices/pbs -flush  >/dev/null 2>&1 || true

echo ""
echo "Built: $APP_DIR"
echo "Run:   open \"$APP_DIR\""
echo ""
echo "First launch:"
echo "  1. Grant Accessibility access when prompted (System Settings > Privacy & Security > Accessibility > TextPolisher)."
echo "  2. Enable the service in System Settings > Keyboard > Keyboard Shortcuts > Services > Text."
echo "  3. Select text in any app and use right-click > Services > Polish Text, or press Option+Cmd+P."
