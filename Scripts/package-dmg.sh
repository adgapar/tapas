#!/bin/sh
# Package a new build or an already signed app without changing that app's seal.
set -eu
cd "$(dirname "$0")/.."

DMGBUILD=${TAPAS_DMGBUILD:-.build/dmg-tools/bin/dmgbuild}
if [ ! -x "$DMGBUILD" ]; then
    echo "Install DMG build tooling: python3 -m venv .build/dmg-tools && .build/dmg-tools/bin/pip install dmgbuild==1.6.5" >&2
    exit 1
fi
PACKAGED_APP=${TAPAS_PACKAGED_APP:-}
if [ -n "$PACKAGED_APP" ]; then
    PLIST="$PACKAGED_APP/Contents/Info.plist"
else
    PLIST=Apps/TapasApp/Sources/TapasApp/Info.plist
fi
VERSION=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$PLIST")
ARCH=$(uname -m)
if [ "$ARCH" != arm64 ]; then
    echo "Tapas is supported on Apple silicon Macs only." >&2
    exit 1
fi
RELEASE=${TAPAS_RELEASE_LABEL:-"$VERSION"}
case "$RELEASE" in *[!A-Za-z0-9._-]*|'') echo "Invalid release label." >&2; exit 1 ;; esac
if [ -n "${TAPAS_NOTARY_PROFILE:-}" ] && [ -z "${TAPAS_SIGNING_IDENTITY:-}" ]; then
    echo "Set TAPAS_SIGNING_IDENTITY as well as TAPAS_NOTARY_PROFILE to sign the disk image." >&2
    exit 1
fi
DESTINATION="$(pwd)/dist/releases"
mkdir -p "$DESTINATION"
DMG="$DESTINATION/Tapas-$RELEASE-$ARCH.dmg"
if [ -e "$DMG" ]; then
    echo "Release artifact already exists: $DMG. Choose a new TAPAS_RELEASE_LABEL." >&2
    exit 1
fi
STAGING=$(mktemp -d /tmp/tapas-dmg.XXXXXX)
trap 'rm -rf "$STAGING"' EXIT HUP INT TERM
mkdir -p "$STAGING/image"
if [ -n "$PACKAGED_APP" ]; then
    ditto "$PACKAGED_APP" "$STAGING/image/Tapas.app"
else
    Scripts/package-app.sh "$STAGING/image"
fi
APP="$STAGING/image/Tapas.app"
codesign --verify --deep --strict "$APP"
NOTARIZED=false
if xcrun stapler validate "$APP" >/dev/null 2>&1; then
    NOTARIZED=true
elif [ -n "${TAPAS_NOTARY_PROFILE:-}" ]; then
    Scripts/notarize-app.sh "$APP"
    NOTARIZED=true
fi
if [ "$NOTARIZED" = true ]; then
    spctl --assess --type execute --verbose=2 "$APP"
fi
# Only the app is copied. Notarization reports stay in the staging directory.
# Privacy and license notices are already inside Contents/Resources/Notices.
swift Scripts/dmg-background.swift "$STAGING/background.tiff"
"$DMGBUILD" -s Scripts/dmg-settings.py \
    -D "app=$APP" -D "background=$STAGING/background.tiff" \
    "Tapas" "$STAGING/Tapas.dmg"
if [ -n "${TAPAS_SIGNING_IDENTITY:-}" ]; then
    codesign --force --sign "$TAPAS_SIGNING_IDENTITY" --timestamp "$STAGING/Tapas.dmg"
    codesign --verify --strict "$STAGING/Tapas.dmg"
fi
if [ -n "${TAPAS_NOTARY_PROFILE:-}" ]; then
    RESPONSE="$DMG.notarization.json"
    if ! xcrun notarytool submit "$STAGING/Tapas.dmg" --keychain-profile "$TAPAS_NOTARY_PROFILE" --wait --output-format json > "$RESPONSE"; then
        cat "$RESPONSE" >&2
        exit 1
    fi
    if [ "$(plutil -extract status raw -o - "$RESPONSE")" != Accepted ]; then
        cat "$RESPONSE" >&2
        echo "Disk image notarization was not accepted." >&2
        exit 1
    fi
    xcrun stapler staple "$STAGING/Tapas.dmg"
    xcrun stapler validate "$STAGING/Tapas.dmg"
    spctl --assess --type open --context context:primary-signature --verbose=2 "$STAGING/Tapas.dmg"
fi
hdiutil verify "$STAGING/Tapas.dmg"
mv "$STAGING/Tapas.dmg" "$DMG"
(cd "$DESTINATION" && shasum -a 256 "$(basename "$DMG")" > "$(basename "$DMG").sha256")
echo "Installer built: $DMG"
if [ -n "${TAPAS_NOTARY_PROFILE:-}" ]; then
    echo "App and disk image are Developer ID signed, notarized and stapled."
else
    echo "App notarized: $NOTARIZED. Disk image has not been submitted for notarization."
fi
