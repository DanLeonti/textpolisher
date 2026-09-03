#!/usr/bin/env bash
#
# One-shot release pipeline for TextPolisher.
#
# Solves the stale-DMG cache trap by publishing each build under a VERSIONED,
# immutable filename (TextPolisher-<version>.dmg) and pointing both the website
# /download redirect and the in-app appcast at that versioned URL. A new release
# is always a new URL, so no edge/browser cache can ever serve an old build.
# The only stable-URL object is appcast.json (tiny, short-cached), which the
# app polls to discover the latest versioned DMG.
#
# Usage:
#   SIGN_IDENTITY="Developer ID Application: Your Name (TEAMID)" \
#   NOTARY_PROFILE="text_polisher" \
#   Scripts/release.sh
#
# Prereq: bump CFBundleShortVersionString in Packaging/Info.plist first.
# After it finishes: commit & push (site/_redirects, Packaging/appcast.json,
# Packaging/Info.plist) so Cloudflare Pages deploys the new /download redirect.
#
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

BUCKET="textpolisher"
VERSION="$(/usr/libexec/PlistBuddy -c "Print CFBundleShortVersionString" Packaging/Info.plist)"
DMG_VERSIONED="TextPolisher-${VERSION}.dmg"

: "${SIGN_IDENTITY:?Set SIGN_IDENTITY to your Developer ID Application identity}"
if [[ -z "${NOTARY_PROFILE:-}" && ( -z "${APPLE_ID:-}" || -z "${TEAM_ID:-}" || -z "${APP_PASSWORD:-}" ) ]]; then
    echo "Set NOTARY_PROFILE (or APPLE_ID + TEAM_ID + APP_PASSWORD) to notarize." >&2
    exit 1
fi

echo "==> Releasing TextPolisher $VERSION ($DMG_VERSIONED)"

# 1. Build + sign + notarize + staple (produces dist/TextPolisher.dmg)
Scripts/make_dmg.sh

# 2. Point appcast.json at the versioned, immutable DMG URL.
python3 - "$VERSION" "$DMG_VERSIONED" <<'PY'
import json, sys
version, dmg = sys.argv[1], sys.argv[2]
path = "Packaging/appcast.json"
data = json.load(open(path))
data["version"] = version
data["url"] = f"https://dl.textpolisher.app/{dmg}"
with open(path, "w") as f:
    json.dump(data, f, indent=2)
    f.write("\n")
print(f"    appcast url -> {data['url']}")
PY

# 3. Point the website /download redirect at the same versioned DMG while
#    preserving permanent redirects for the retired account and billing pages.
cat > site/_redirects <<EOF
/download  https://dl.textpolisher.app/$DMG_VERSIONED  302
/login  /  301
/register  /  301
/account  /  301
/reset-password  /  301
/refund  /  301
EOF
echo "    /download -> https://dl.textpolisher.app/$DMG_VERSIONED"

# 4. Upload to R2:
#    - versioned DMG: cache forever + immutable (URL is unique per release)
#    - stable DMG: short cache, for anyone using the legacy direct link
#    - appcast.json: short cache so the update check sees the new version fast
echo "==> Uploading to R2"
npx --yes wrangler@4 r2 object put "$BUCKET/$DMG_VERSIONED" --remote --file="dist/TextPolisher.dmg" \
    --content-type=application/x-apple-diskimage \
    --cache-control="public, max-age=31536000, immutable"
npx --yes wrangler@4 r2 object put "$BUCKET/TextPolisher.dmg" --remote --file="dist/TextPolisher.dmg" \
    --content-type=application/x-apple-diskimage \
    --cache-control="public, max-age=60"
npx --yes wrangler@4 r2 object put "$BUCKET/appcast.json" --remote --file="Packaging/appcast.json" \
    --content-type=application/json \
    --cache-control="public, max-age=60"

echo ""
echo "Released $VERSION."
echo "Primary download (cache-safe): https://dl.textpolisher.app/$DMG_VERSIONED"
echo ""
echo "Now commit & push so Pages deploys the /download redirect:"
echo "  git add site/_redirects Packaging/appcast.json Packaging/Info.plist"
echo "  git commit -m \"Release $VERSION\" && git push"
