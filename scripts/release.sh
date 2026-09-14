#!/bin/zsh
set -euo pipefail
cd "${0:A:h:h}"

# Production is the default. --local-test explicitly skips Apple notarization.
MODE="${1:-production}"
[[ "$MODE" == production || "$MODE" == --local-test ]] || {
    print -u2 'Usage: scripts/release.sh [production|--local-test]'; exit 2
}
: "${APP_VERSION:?Set APP_VERSION (for example 1.1.0)}"
: "${BUILD_NUMBER:?Set BUILD_NUMBER to a monotonically increasing integer}"
: "${DOWNLOAD_URL_PREFIX:?Set DOWNLOAD_URL_PREFIX to the HTTPS release asset directory ending in /}"
[[ "$APP_VERSION" =~ '^[0-9]+\.[0-9]+\.[0-9]+$' && "$BUILD_NUMBER" =~ '^[1-9][0-9]*$' ]] || {
    print -u2 'Version must be x.y.z and build number a positive integer.'; exit 2
}
[[ "$DOWNLOAD_URL_PREFIX" == https://*/ ]] || {
    print -u2 'DOWNLOAD_URL_PREFIX must use HTTPS and end in /.'; exit 2
}
if [[ "$MODE" == production ]]; then
    : "${SIGNING_IDENTITY:?Set SIGNING_IDENTITY to a Developer ID Application identity}"
    : "${NOTARY_KEYCHAIN_PROFILE:?Set NOTARY_KEYCHAIN_PROFILE to an existing notarytool profile}"
    [[ "$SIGNING_IDENTITY" == 'Developer ID Application: '* ]] || {
        print -u2 'Production releases require a Developer ID Application identity.'; exit 2
    }
else
    export SIGNING_IDENTITY=-
    print 'LOCAL TEST ONLY: this build is not Developer ID signed or notarized.'
fi

FINAL_OUTPUT="$PWD/dist/releases/$APP_VERSION-$BUILD_NUMBER"
[[ ! -e "$FINAL_OUTPUT" ]] || { print -u2 "Release already exists: $FINAL_OUTPUT"; exit 1; }
export APP_VERSION BUILD_NUMBER
export ARCHITECTURES=universal
./build-app.sh

notarize() {
    local archive="$1" result="$2"
    xcrun notarytool submit "$archive" --keychain-profile "$NOTARY_KEYCHAIN_PROFILE" --wait --output-format json > "$result"
    [[ "$(plutil -extract status raw "$result")" == Accepted ]] || {
        print -u2 "Apple rejected notarization. See $result"; exit 1
    }
}

if [[ "$MODE" == production ]]; then
    # Staple the app itself before packaging, so a copied installation can be
    # assessed offline as well as the enclosing disk image.
    APP_ZIP="$PWD/dist/notary-$APP_VERSION-$BUILD_NUMBER.zip"
    ditto -c -k --sequesterRsrc --keepParent "$PWD/dist/Clockin.app" "$APP_ZIP"
    notarize "$APP_ZIP" "$PWD/dist/notary-app-$APP_VERSION-$BUILD_NUMBER.json"
    xcrun stapler staple "$PWD/dist/Clockin.app"
    xcrun stapler validate "$PWD/dist/Clockin.app"
    spctl --assess --type execute --verbose=2 "$PWD/dist/Clockin.app"
fi
./scripts/package-dmg.sh
DMG="$PWD/dist/Clockin-$APP_VERSION-$BUILD_NUMBER.dmg"
if [[ "$MODE" == production ]]; then
    codesign --sign "$SIGNING_IDENTITY" --timestamp "$DMG"
    # notarytool returns successfully for a finished but rejected submission too;
    # require Accepted before stapling or publishing any update metadata.
    notarize "$DMG" "$PWD/dist/notary-dmg-$APP_VERSION-$BUILD_NUMBER.json"
    xcrun stapler staple "$DMG"
    xcrun stapler validate "$DMG"
    spctl --assess --type open --context context:primary-signature --verbose=2 "$DMG"
fi

mkdir -p "$PWD/dist/releases"
OUTPUT="$(mktemp -d "$PWD/dist/releases/.preparing.XXXXXX")"
trap 'rm -rf "$OUTPUT"' EXIT
cp "$DMG" "$OUTPUT/"
if [[ -n "${RELEASE_NOTES_FILE:-}" ]]; then
    cp "$RELEASE_NOTES_FILE" "$OUTPUT/Clockin-$APP_VERSION-$BUILD_NUMBER.md"
fi
SPARKLE="$PWD/.build/artifacts/sparkle/Sparkle/bin"
sign_args=(--account "${SPARKLE_KEY_ACCOUNT:-com.ismailakdag.clockin}")
if [[ -n "${SPARKLE_PRIVATE_KEY_FILE:-}" ]]; then
    sign_args=(--ed-key-file "$SPARKLE_PRIVATE_KEY_FILE")
fi
"$SPARKLE/generate_appcast" "${sign_args[@]}" --maximum-deltas 0 \
    --download-url-prefix "$DOWNLOAD_URL_PREFIX" --embed-release-notes \
    -o "$OUTPUT/appcast.xml" "$OUTPUT"
swift scripts/verify-release.swift "$OUTPUT/appcast.xml" "$PWD/dist/Clockin.app/Contents/Info.plist"
(cd "$OUTPUT" && shasum -a 256 *.dmg appcast.xml > SHA256SUMS)
if [[ "$MODE" == --local-test ]]; then
    print 'Not for public distribution: Apple signing/notarization was skipped.' > "$OUTPUT/LOCAL-TEST-ONLY.txt"
fi
mv "$OUTPUT" "$FINAL_OUTPUT"
print "Release prepared and verified: $FINAL_OUTPUT"
print 'Publish the DMG, appcast.xml and SHA256SUMS together only after testing.'
