#!/bin/sh
# Use a Keychain profile; never put account passwords in scripts or arguments.
set -eu
APP=${1:?Usage: TAPAS_NOTARY_PROFILE=tapas Scripts/notarize-app.sh path/to/Tapas.app}
PROFILE=${TAPAS_NOTARY_PROFILE:?Set TAPAS_NOTARY_PROFILE to a notarytool Keychain profile}
APP=$(CDPATH= cd -- "$(dirname -- "$APP")" && pwd)/$(basename -- "$APP")
codesign --verify --deep --strict \
    --test-requirement '=anchor apple generic and certificate leaf[field.1.2.840.113635.100.6.1.13] exists' "$APP"
STAGING=$(mktemp -d /tmp/tapas-notary.XXXXXX)
trap 'rm -rf "$STAGING"' EXIT HUP INT TERM
ARCHIVE="$STAGING/Tapas.zip"
RESPONSE="$APP.notarization.json"
ditto -c -k --keepParent "$APP" "$ARCHIVE"
if ! xcrun notarytool submit "$ARCHIVE" --keychain-profile "$PROFILE" --wait --output-format json > "$RESPONSE"; then
    cat "$RESPONSE" >&2
    echo "Notarization did not complete. Submission details: $RESPONSE" >&2
    exit 1
fi
STATUS=$(plutil -extract status raw -o - "$RESPONSE")
if [ "$STATUS" != Accepted ]; then
    cat "$RESPONSE" >&2
    echo "Apple did not accept this submission. Use notarytool log with its submission ID." >&2
    exit 1
fi
xcrun stapler staple "$APP"
xcrun stapler validate "$APP"
spctl --assess --type execute --verbose=2 "$APP"
echo "Notarized and stapled: $APP"
