#!/bin/bash
# Baut "HA Leiste.app" (Apple Silicon + Intel) und ein ZIP zum Verteilen.
set -euo pipefail
cd "$(dirname "$0")/.."
VERSION="${1:-$(cat VERSION)}"
APP="build/HA Leiste.app"

swift build -c release --arch arm64 --arch x86_64
BIN="$(swift build -c release --arch arm64 --arch x86_64 --show-bin-path)"

rm -rf build && mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN/HALeiste" "$APP/Contents/MacOS/HALeiste"
sed "s/@VERSION@/$VERSION/g" ressourcen/Info.plist > "$APP/Contents/Info.plist"
swift scripts/symbol.swift build/AppIcon.iconset
iconutil -c icns build/AppIcon.iconset -o "$APP/Contents/Resources/AppIcon.icns"
# Ohne Apple-Entwicklerkonto: lokale Signatur (beim ersten Start "Trotzdem öffnen")
codesign --force --deep --sign - "$APP"
(cd build && ditto -c -k --sequesterRsrc --keepParent "HA Leiste.app" "HA-Leiste-$VERSION.zip")
echo "Fertig: build/HA-Leiste-$VERSION.zip"
