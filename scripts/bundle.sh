#!/usr/bin/env bash
# Builds build/Foci.app: the menu bar app, with the CLI and example config inside it so a
# Shortcuts automation has a stable path to call.
set -euo pipefail
cd "$(dirname "$0")/.."

swift build -c release --product FociMenu
swift build -c release --product foci
bin=$(swift build -c release --show-bin-path)

app=build/Foci.app
rm -rf "$app"
mkdir -p "$app/Contents/MacOS" "$app/Contents/Resources"
cp scripts/Info.plist "$app/Contents/Info.plist"
cp "$bin/FociMenu" "$app/Contents/MacOS/Foci"
cp "$bin/foci" "$app/Contents/Resources/foci"
cp config.example.json "$app/Contents/Resources/"
codesign --force --sign - "$app"
echo "built $app"
