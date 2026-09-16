#!/bin/zsh
set -euo pipefail
cd "${0:A:h}"

# Local builds stay ad-hoc signed. release.sh requires Developer ID + notarization.
CONFIGURATION="${CONFIGURATION:-release}"
ARCHITECTURES="${ARCHITECTURES:-native}"
SIGNING_IDENTITY="${SIGNING_IDENTITY:--}"
APP_DIR="$PWD/dist/Clockin.app"
CONTENTS="$APP_DIR/Contents"
SPARKLE_ROOT="$PWD/.build/artifacts/sparkle/Sparkle"

build_args=(-c "$CONFIGURATION" --disable-automatic-resolution)
if [[ "$ARCHITECTURES" == universal ]]; then
    build_args+=(--arch arm64 --arch x86_64)
elif [[ "$ARCHITECTURES" != native ]]; then
    print -u2 'ARCHITECTURES must be native or universal.'
    exit 2
fi
# Resolve explicitly so Package.resolved remains the source of truth.
swift package resolve
swift build "${build_args[@]}"
BIN_DIR="$(swift build "${build_args[@]}" --show-bin-path)"

# A clean bundle prevents obsolete resources or old updater helpers shipping.
rm -rf "$APP_DIR"
mkdir -p "$CONTENTS/MacOS" "$CONTENTS/Resources" "$CONTENTS/Frameworks"
cp "$BIN_DIR/Clockin" "$CONTENTS/MacOS/Clockin"
cp Resources/Info.plist "$CONTENTS/Info.plist"
cp Resources/Clockin.icns "$CONTENTS/Resources/Clockin.icns"
ditto "$BIN_DIR/Clockin_Clockin.bundle" "$CONTENTS/Resources/Clockin_Clockin.bundle"
ditto "$SPARKLE_ROOT/Sparkle.xcframework/macos-arm64_x86_64/Sparkle.framework" "$CONTENTS/Frameworks/Sparkle.framework"
cp "$SPARKLE_ROOT/LICENSE" "$CONTENTS/Resources/Sparkle-LICENSE.txt"

# Optional release overrides never modify the source plist.
[[ -z "${APP_VERSION:-}" ]] || plutil -replace CFBundleShortVersionString -string "$APP_VERSION" "$CONTENTS/Info.plist"
[[ -z "${BUILD_NUMBER:-}" ]] || plutil -replace CFBundleVersion -string "$BUILD_NUMBER" "$CONTENTS/Info.plist"
[[ -z "${UPDATE_FEED_URL:-}" ]] || plutil -replace SUFeedURL -string "$UPDATE_FEED_URL" "$CONTENTS/Info.plist"
plutil -lint "$CONTENTS/Info.plist"

# Sign nested code from the inside out. Preserve XPC sandbox entitlements.
# Do not use --deep for signing; Sparkle helpers must receive their own signatures.
sign_args=(--force --sign "$SIGNING_IDENTITY")
if [[ "$SIGNING_IDENTITY" != - ]]; then
    sign_args+=(--options runtime --timestamp)
fi
FRAMEWORK="$CONTENTS/Frameworks/Sparkle.framework"
for helper in "$FRAMEWORK/Versions/B/XPCServices/"*.xpc(N); do
    codesign "${sign_args[@]}" --preserve-metadata=entitlements "$helper"
done
codesign "${sign_args[@]}" "$FRAMEWORK/Versions/B/Autoupdate"
codesign "${sign_args[@]}" "$FRAMEWORK/Versions/B/Updater.app"
codesign "${sign_args[@]}" "$FRAMEWORK"
codesign "${sign_args[@]}" "$APP_DIR"
codesign --verify --deep --strict --verbose=2 "$APP_DIR"
print "Built: $APP_DIR"
