#!/usr/bin/env bash
#
# Builds a distributable disk image (TextPolisher.dmg) with a styled installer
# window: app icon on the left, Applications on the right, and a big arrow
# between them so non-technical users know to drag-and-drop to install.
#
# Usage:
#   Scripts/make_dmg.sh                       # ad-hoc, shows Gatekeeper warning
#
#   # Frictionless (no Gatekeeper warning): sign + notarize + staple in one go.
#   SIGN_IDENTITY="Developer ID Application: Your Name (TEAMID)" \
#   APPLE_ID="you@example.com" TEAM_ID="TEAMID" APP_PASSWORD="abcd-efgh-ijkl-mnop" \
#   Scripts/make_dmg.sh
#
#   # ...or, after saving credentials once with:
#   #   xcrun notarytool store-credentials text_polisher \
#   #     --apple-id you@example.com --team-id TEAMID --password <app-specific-password>
#   SIGN_IDENTITY="Developer ID Application: Your Name (TEAMID)" \
#   NOTARY_PROFILE="text_polisher" Scripts/make_dmg.sh
#
# APP_PASSWORD is an app-specific password from https://appleid.apple.com
# (Sign-In and Security > App-Specific Passwords) - NOT your Apple ID password.
#
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_NAME="TextPolisher"
VOLNAME="${VOLNAME:-TextPolisher}"
APP_DIR="$ROOT/dist/$APP_NAME.app"
# Override DMG_PATH to build a differently-named artifact (e.g. a free variant)
# without clobbering the shipping dist/TextPolisher.dmg.
DMG_PATH="${DMG_PATH:-$ROOT/dist/$APP_NAME.dmg}"

BACKGROUND_TIFF="$ROOT/Packaging/dmg-background.tiff"
DMG_VENV="$ROOT/dist/dmgvenv"
DMGBUILD="$DMG_VENV/bin/dmgbuild"

echo "==> Building the app"
"$ROOT/Scripts/build_app.sh"

# Regenerate the installer-window background if it is missing.
if [[ ! -f "$BACKGROUND_TIFF" ]]; then
    echo "==> Rendering DMG background"
    swift "$ROOT/Scripts/make_dmg_background.swift"
fi

# dmgbuild lays out the installer window (background, icon positions, hidden
# chrome) by writing the .DS_Store directly - no Finder automation required, so
# this works headless / in CI. Provisioned once into a local venv.
if [[ ! -x "$DMGBUILD" ]]; then
    echo "==> Provisioning dmgbuild"
    python3 -m venv "$DMG_VENV"
    "$DMG_VENV/bin/pip" install --quiet --upgrade pip dmgbuild
fi

echo "==> Building styled disk image"
rm -f "$DMG_PATH"
"$DMGBUILD" \
    -s "$ROOT/Scripts/dmg_settings.py" \
    -D app="$APP_DIR" \
    -D background="$BACKGROUND_TIFF" \
    "$VOLNAME" "$DMG_PATH"

# Notarize + staple so Gatekeeper opens the app with no warning. Requires the
# app to be Developer ID signed (set SIGN_IDENTITY above) and hardened runtime,
# which Scripts/build_app.sh applies when SIGN_IDENTITY is set.
NOTARIZED=0
if [[ -n "${NOTARY_PROFILE:-}" ]]; then
    echo "==> Notarizing (keychain profile: $NOTARY_PROFILE)"
    xcrun notarytool submit "$DMG_PATH" --keychain-profile "$NOTARY_PROFILE" --wait
    echo "==> Stapling"
    xcrun stapler staple "$DMG_PATH"
    NOTARIZED=1
elif [[ -n "${APPLE_ID:-}" && -n "${TEAM_ID:-}" && -n "${APP_PASSWORD:-}" ]]; then
    echo "==> Notarizing (apple-id: $APPLE_ID)"
    xcrun notarytool submit "$DMG_PATH" \
        --apple-id "$APPLE_ID" --team-id "$TEAM_ID" --password "$APP_PASSWORD" --wait
    echo "==> Stapling"
    xcrun stapler staple "$DMG_PATH"
    NOTARIZED=1
fi

echo ""
echo "Created: $DMG_PATH"
echo ""
if [[ "$NOTARIZED" == "1" ]]; then
    echo "Signed, notarized and stapled - installs with NO Gatekeeper warning."
    echo ""
    echo "Share this .dmg file. To install, the recipient:"
    echo "  1. Opens the .dmg and drags TextPolisher onto Applications."
    echo "  2. Opens it from Applications and clicks Open."
    echo "  3. Grants Accessibility access when prompted."
else
    echo "Share this .dmg file. To install, the recipient:"
    echo "  1. Opens the .dmg and drags TextPolisher onto Applications."
    echo "  2. Opens it from Applications (first time: System Settings >"
    echo "     Privacy & Security > 'Open Anyway' if Gatekeeper warns)."
    echo "  3. Grants Accessibility access when prompted."
    echo ""
    echo "Note: this build is not notarized, so it triggers a Gatekeeper warning."
    echo "Set NOTARY_PROFILE (or APPLE_ID + TEAM_ID + APP_PASSWORD) to notarize"
    echo "automatically and remove that warning."
fi
