#!/bin/sh
set -e
cd "$(dirname "$0")/.."
swift build -c release --package-path Apps/TapasApp --product Tapas
OUTPUT_DIR=${1:-dist}
APP="$OUTPUT_DIR/Tapas.app"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp Apps/TapasApp/.build/release/Tapas "$APP/Contents/MacOS/Tapas"
# SwiftPM locates this in the main app resource directory.
ditto Apps/TapasApp/.build/release/Tapas_TapasCore.bundle "$APP/Contents/Resources/Tapas_TapasCore.bundle"
SPARKLE=Apps/TapasApp/.build/artifacts/sparkle/Sparkle
mkdir -p "$APP/Contents/Frameworks"
ditto "$SPARKLE/Sparkle.xcframework/macos-arm64_x86_64/Sparkle.framework" "$APP/Contents/Frameworks/Sparkle.framework"
cp Apps/TapasApp/Sources/TapasApp/Info.plist "$APP/Contents/Info.plist"
mkdir -p "$APP/Contents/Resources/Notices"
cp "$SPARKLE/LICENSE" "$APP/Contents/Resources/Notices/Sparkle-LICENSE.txt"
cp NOTICE.md PRIVACY.md "$APP/Contents/Resources/Notices/"
cp Apps/TapasApp/.build/checkouts/desert-ant-core/LICENSE.md "$APP/Contents/Resources/Notices/Desert-Ant-LICENSE.md"
cp Apps/TapasApp/.build/checkouts/desert-ant-core/THIRD_PARTY_NOTICES.md "$APP/Contents/Resources/Notices/Desert-Ant-THIRD-PARTY-NOTICES.md"
cp Apps/TapasApp/.build/checkouts/swift-numerics/LICENSE.txt "$APP/Contents/Resources/Notices/Swift-Numerics-LICENSE.txt"
ICONSET=$(mktemp -d /tmp/tapas-icon.XXXXXX)/Tapas.iconset
trap 'rm -rf "$(dirname "$ICONSET")"' EXIT HUP INT TERM
"$APP/Contents/MacOS/Tapas" --export-icon "$ICONSET"
iconutil -c icns "$ICONSET" -o "$APP/Contents/Resources/Tapas.icns"
rm -rf "$(dirname "$ICONSET")"
# Local builds stay ad-hoc unless a Developer ID identity is explicitly supplied.
if [ -n "${TAPAS_SIGNING_IDENTITY:-}" ]; then
    Scripts/sign-app.sh "$APP"
else
    codesign --force --sign - "$APP"
fi
echo "built $APP"
