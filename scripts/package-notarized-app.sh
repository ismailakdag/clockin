#!/bin/zsh
set -euo pipefail
cd "${0:A:h:h}"
: "${1:?Pass the Clockin.app exported by Xcode after notarization}"
: "${SIGNING_IDENTITY:?Set your Developer ID Application identity}"
: "${DOWNLOAD_URL_PREFIX:?Set the HTTPS directory where the DMG will be published}"
[[ "$SIGNING_IDENTITY" == 'Developer ID Application: '* && "$DOWNLOAD_URL_PREFIX" == https://*/ ]] || {
    print -u2 'A Developer ID identity and HTTPS download prefix ending in / are required.'; exit 2
}
EXPORTED_APP="${1:A}"
PLIST="$EXPORTED_APP/Contents/Info.plist"
[[ "$(plutil -extract CFBundleIdentifier raw "$PLIST")" == com.ismailakdag.clockin ]] || {
    print -u2 'Expected the production Clockin bundle identifier.'; exit 1
}
xcrun stapler validate "$EXPORTED_APP"
codesign --verify --deep --strict "$EXPORTED_APP"
spctl --assess --type execute --verbose=2 "$EXPORTED_APP"
VERSION="$(plutil -extract CFBundleShortVersionString raw "$PLIST")"
BUILD="$(plutil -extract CFBundleVersion raw "$PLIST")"
FINAL_OUTPUT="$PWD/dist/releases/$VERSION-$BUILD"
[[ ! -e "$FINAL_OUTPUT" ]] || { print -u2 "Release exists: $FINAL_OUTPUT"; exit 1; }
[[ "$EXPORTED_APP" != "$PWD/dist/Clockin.app" ]] || {
    print -u2 'Pass the exported app from its own export directory.'; exit 2
}
rm -rf "$PWD/dist/Clockin.app"
ditto "$EXPORTED_APP" "$PWD/dist/Clockin.app"
./scripts/package-dmg.sh
DMG="$PWD/dist/Clockin-$VERSION-$BUILD.dmg"
codesign --sign "$SIGNING_IDENTITY" --timestamp "$DMG"
codesign --verify --strict "$DMG"
mkdir -p "$PWD/dist/releases"
OUTPUT="$(mktemp -d "$PWD/dist/releases/.preparing.XXXXXX")"
trap 'rm -rf "$OUTPUT"' EXIT
cp "$DMG" "$OUTPUT/"
if [[ -n "${RELEASE_NOTES_FILE:-}" ]]; then
    cp "$RELEASE_NOTES_FILE" "$OUTPUT/Clockin-$VERSION-$BUILD.md"
fi
sign_args=(--account "${SPARKLE_KEY_ACCOUNT:-com.ismailakdag.clockin}")
if [[ -n "${SPARKLE_PRIVATE_KEY_FILE:-}" ]]; then
    sign_args=(--ed-key-file "$SPARKLE_PRIVATE_KEY_FILE")
fi
.build/artifacts/sparkle/Sparkle/bin/generate_appcast "${sign_args[@]}" \
    --maximum-deltas 0 --download-url-prefix "$DOWNLOAD_URL_PREFIX" \
    --embed-release-notes -o "$OUTPUT/appcast.xml" "$OUTPUT"
swift scripts/verify-release.swift "$OUTPUT/appcast.xml" "$PLIST"
(cd "$OUTPUT" && shasum -a 256 *.dmg appcast.xml > SHA256SUMS)
print 'Developer ID signed DMG containing an Apple-notarized, stapled app. The outer DMG has not separately been notarized.' > "$OUTPUT/NOTARIZATION.txt"
mv "$OUTPUT" "$FINAL_OUTPUT"
print "Prepared: $FINAL_OUTPUT"
