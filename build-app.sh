#!/bin/zsh
set -euo pipefail

cd "${0:A:h}"
swift build -c release

APP_DIR="$PWD/dist/Clockin.app"
CONTENTS="$APP_DIR/Contents"
mkdir -p "$CONTENTS/MacOS" "$CONTENTS/Resources"
cp ".build/release/Clockin" "$CONTENTS/MacOS/Clockin"
cp "Resources/Info.plist" "$CONTENTS/Info.plist"
if [[ -d ".build/release/Clockin_Clockin.bundle" ]]; then
  cp -R ".build/release/Clockin_Clockin.bundle" "$CONTENTS/Resources/"
fi
cp "Resources/Clockin.icns" "$CONTENTS/Resources/Clockin.icns"
codesign --force --deep --sign - "$APP_DIR"

print "Built: $APP_DIR"
print "Open with: open '$APP_DIR'"
