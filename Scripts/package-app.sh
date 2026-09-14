#!/bin/sh
set -e
cd "$(dirname "$0")/.."
swift build -c release --package-path Apps/TapasApp --product Tapas
APP=dist/Tapas.app
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp Apps/TapasApp/.build/release/Tapas "$APP/Contents/MacOS/Tapas"
cp Apps/TapasApp/Sources/TapasApp/Info.plist "$APP/Contents/Info.plist"
ICONSET=$(mktemp -d /tmp/tapas-icon.XXXXXX)/Tapas.iconset
"$APP/Contents/MacOS/Tapas" --export-icon "$ICONSET"
iconutil -c icns "$ICONSET" -o "$APP/Contents/Resources/Tapas.icns"
rm -rf "$(dirname "$ICONSET")"
# Stable identifier plus ad-hoc signing for a local development bundle.
codesign --force --deep --sign - "$APP"
echo "built $APP"
