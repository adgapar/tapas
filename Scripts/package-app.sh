#!/bin/sh
set -e
cd "$(dirname "$0")/.."
swift build -c release --package-path Apps/TapasApp --product Tapas
APP=dist/Tapas.app
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp Apps/TapasApp/.build/release/Tapas "$APP/Contents/MacOS/Tapas"
cp Apps/TapasApp/Sources/TapasApp/Info.plist "$APP/Contents/Info.plist"
echo "built $APP"
