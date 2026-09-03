#!/usr/bin/env bash
#
# Generates Packaging/AppIcon.icns from a 1024x1024 PNG so build_app.sh can
# embed it in the app bundle.
#
# Usage:
#   Scripts/make_icon.sh [path/to/icon-1024.png]
#
# The source PNG defaults to Packaging/icon_source.png. If you pass a path, it is
# copied to Packaging/icon_source.png so future runs need no argument.
#
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SRC="${1:-$ROOT/Packaging/icon_source.png}"

if [[ ! -f "$SRC" ]]; then
    echo "Source PNG not found: $SRC" >&2
    echo "Pass a 1024x1024 PNG: Scripts/make_icon.sh /path/to/icon.png" >&2
    exit 1
fi

mkdir -p "$ROOT/Packaging"
if [[ "$SRC" != "$ROOT/Packaging/icon_source.png" ]]; then
    cp "$SRC" "$ROOT/Packaging/icon_source.png"
    SRC="$ROOT/Packaging/icon_source.png"
fi

ICONSET="$(mktemp -d)/AppIcon.iconset"
mkdir -p "$ICONSET"

# (size, filename) pairs expected by iconutil.
gen() { sips -z "$1" "$1" "$SRC" --out "$ICONSET/$2" >/dev/null; }
gen 16   icon_16x16.png
gen 32   icon_16x16@2x.png
gen 32   icon_32x32.png
gen 64   icon_32x32@2x.png
gen 128  icon_128x128.png
gen 256  icon_128x128@2x.png
gen 256  icon_256x256.png
gen 512  icon_256x256@2x.png
gen 512  icon_512x512.png
gen 1024 icon_512x512@2x.png

iconutil -c icns "$ICONSET" -o "$ROOT/Packaging/AppIcon.icns"
rm -rf "$(dirname "$ICONSET")"

echo "Created: $ROOT/Packaging/AppIcon.icns"
echo "Now rebuild the app (Scripts/build_app.sh or Scripts/make_dmg.sh) to embed it."
