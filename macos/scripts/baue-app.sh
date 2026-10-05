#!/bin/bash
# Baut "Home Assistant ToolBox.app" mit Widgets (Apple Silicon + Intel) und ein ZIP zum Verteilen.
# Braucht Xcode und XcodeGen (brew install xcodegen).
set -euo pipefail
cd "$(dirname "$0")/.."
VERSION="${1:-$(cat VERSION)}"

rm -rf build && mkdir -p build
swift scripts/symbol.swift build/AppIcon.iconset
iconutil -c icns build/AppIcon.iconset -o ressourcen/AppIcon.icns

command -v xcodegen >/dev/null || brew install xcodegen
xcodegen generate --spec project.yml --quiet

xcodebuild -project HAToolBox.xcodeproj -scheme HAToolBox -configuration Release -derivedDataPath build/dd \
  MARKETING_VERSION="$VERSION" -skipPackagePluginValidation build 2>&1 | tee build/xcodebuild.log | grep -E "error:|warning: .*(deprecated|unused)|BUILD (SUCCEEDED|FAILED)" || true
grep -q "BUILD SUCCEEDED" build/xcodebuild.log || { grep -B2 -A6 "error:" build/xcodebuild.log | head -80; exit 1; }

cp -R "build/dd/Build/Products/Release/Home Assistant ToolBox.app" build/
codesign --verify --deep --strict "build/Home Assistant ToolBox.app" && echo "Signatur ok"
codesign -d --entitlements - "build/Home Assistant ToolBox.app/Contents/PlugIns/HAToolBoxWidgets.appex" 2>/dev/null | head -20 || true
(cd build && ditto -c -k --sequesterRsrc --keepParent "Home Assistant ToolBox.app" "HomeAssistantToolBox-macOS-$VERSION.zip")
echo "Fertig: build/HomeAssistantToolBox-macOS-$VERSION.zip"
