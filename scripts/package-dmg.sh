#!/bin/zsh
set -euo pipefail
cd "${0:A:h:h}"
APP="$PWD/dist/Clockin.app"
[[ -d "$APP" ]] || { print -u2 'Build Clockin.app first with ./build-app.sh'; exit 1; }
VERSION="$(plutil -extract CFBundleShortVersionString raw "$APP/Contents/Info.plist")"
BUILD="$(plutil -extract CFBundleVersion raw "$APP/Contents/Info.plist")"
[[ "$VERSION" =~ '^[0-9]+\.[0-9]+\.[0-9]+$' && "$BUILD" =~ '^[1-9][0-9]*$' ]] || {
    print -u2 'Version must be x.y.z and build number a positive integer.'; exit 2
}
OUTPUT="$PWD/dist/Clockin-$VERSION-$BUILD.dmg"
[[ ! -e "$OUTPUT" ]] || { print -u2 "Already exists: $OUTPUT (increment the build number)."; exit 1; }
STAGING="$(mktemp -d "$PWD/dist/dmg-stage.XXXXXX")"
trap 'rm -rf "$STAGING"' EXIT
codesign --verify --deep --strict "$APP"
ditto "$APP" "$STAGING/Clockin.app"
cp LICENSE "$STAGING/LICENSE.txt"
ln -s /Applications "$STAGING/Applications"
hdiutil create -volname Clockin -srcfolder "$STAGING" -format UDZO -fs HFS+ "$OUTPUT"
hdiutil verify "$OUTPUT"
print "Installer: $OUTPUT"
