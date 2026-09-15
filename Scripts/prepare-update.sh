#!/bin/sh
# Prepare release assets locally. This does not publish anything.
set -eu
cd "$(dirname "$0")/.."
DMG=${1:?Usage: Scripts/prepare-update.sh path/to/release.dmg vVERSION}
TAG=${2:?Supply the immutable GitHub release tag}
case "$TAG" in *[!A-Za-z0-9._-]*|'') echo "Invalid release tag" >&2; exit 1 ;; esac
codesign --verify --strict "$DMG"
xcrun stapler validate "$DMG"
DEST="dist/updates/$TAG"
mkdir -p "$DEST"
cp "$DMG" "$DEST/"
cp "$DMG.sha256" "$DEST/"
Apps/TapasApp/.build/artifacts/sparkle/Sparkle/bin/generate_appcast \
    --account work.tapas.Tapas --maximum-deltas 0 \
    --download-url-prefix "https://github.com/adgapar/tapas/releases/download/$TAG/" \
    "$DEST"
echo "Prepared $DEST. Publish the versioned DMG first, then appcast.xml to the updates release."
