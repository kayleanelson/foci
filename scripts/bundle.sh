#!/usr/bin/env bash
# Builds build/Foci.app: the menu bar app, with the CLI inside it so a Shortcuts automation
# has a stable path to call.
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
xcrun actool icon/AppIcon.icon icon/Glyphs.xcassets --compile "$app/Contents/Resources" --app-icon AppIcon \
  --platform macosx --minimum-deployment-target 14.0 \
  --output-partial-info-plist build/icon-partial.plist >/dev/null
codesign --force --sign - "$app"
echo "built $app"
