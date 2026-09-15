#!/bin/sh
# Build a separate preview bundle; never replace the running development app.
set -eu
cd "$(dirname "$0")/.."

VERSION=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' Apps/TapasApp/Sources/TapasApp/Info.plist)
ARCH=$(uname -m)
if [ "$ARCH" != arm64 ]; then
    echo "This preview is supported on Apple silicon Macs only." >&2
    exit 1
fi
RELEASE="$VERSION-preview.1"
DESTINATION="$(pwd)/dist/releases"
mkdir -p "$DESTINATION"
DMG="$DESTINATION/Tapas-$RELEASE-$ARCH.dmg"
if [ -e "$DMG" ]; then
    echo "Release artifact already exists: $DMG. Move it aside before rebuilding." >&2
    exit 1
fi
STAGING=$(mktemp -d /tmp/tapas-dmg.XXXXXX)
trap 'rm -rf "$STAGING"' EXIT HUP INT TERM

Scripts/package-app.sh "$STAGING/image"
ln -s /Applications "$STAGING/image/Applications"
cp docs/releases/INSTALL.txt "$STAGING/image/Start here.txt"
cp NOTICE.md PRIVACY.md "$STAGING/image/"
codesign --verify --deep --strict "$STAGING/image/Tapas.app"
hdiutil create -volname "Tapas $VERSION Preview" -srcfolder "$STAGING/image" -fs HFS+ -format UDZO "$STAGING/preview.dmg"
hdiutil verify "$STAGING/preview.dmg"
mv "$STAGING/preview.dmg" "$DMG"
(cd "$DESTINATION" && shasum -a 256 "$(basename "$DMG")" > "$(basename "$DMG").sha256")
echo "Preview built: $DMG"
echo "Ad-hoc signed; not Developer ID signed or notarized."
