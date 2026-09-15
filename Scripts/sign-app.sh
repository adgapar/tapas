#!/bin/sh
# Sign the packaged app and its embedded updater for direct macOS distribution.
set -eu
SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
APP=${1:?Usage: TAPAS_SIGNING_IDENTITY='Developer ID Application: …' Scripts/sign-app.sh path/to/Tapas.app}
IDENTITY=${TAPAS_SIGNING_IDENTITY:?Set TAPAS_SIGNING_IDENTITY to a Developer ID Application identity in Keychain}
if [ "$IDENTITY" = - ]; then
    echo "Developer ID signing requires a certificate, not an ad-hoc identity." >&2
    exit 1
fi
if [ ! -f "$APP/Contents/MacOS/Tapas" ]; then
    echo "No packaged Tapas executable found: $APP" >&2
    exit 1
fi
# Sign nested updater code from the inside out, preserving helper entitlements.
FRAMEWORK="$APP/Contents/Frameworks/Sparkle.framework"
if [ -d "$FRAMEWORK" ]; then
    for COMPONENT in \
        "$FRAMEWORK/Versions/B/Autoupdate" \
        "$FRAMEWORK/Versions/B/XPCServices/Downloader.xpc" \
        "$FRAMEWORK/Versions/B/XPCServices/Installer.xpc" \
        "$FRAMEWORK/Versions/B/Updater.app"; do
        codesign --force --sign "$IDENTITY" --options runtime --timestamp \
            --preserve-metadata=entitlements "$COMPONENT"
    done
    codesign --force --sign "$IDENTITY" --options runtime --timestamp "$FRAMEWORK"
fi
codesign --force --sign "$IDENTITY" --options runtime --timestamp \
    --entitlements "$SCRIPT_DIR/../Apps/TapasApp/Tapas.entitlements" "$APP"
codesign --verify --deep --strict \
    --test-requirement '=anchor apple generic and certificate leaf[field.1.2.840.113635.100.6.1.13] exists' "$APP"
echo "Developer ID signed: $APP"
echo "Notarization is a separate step: Scripts/notarize-app.sh"
