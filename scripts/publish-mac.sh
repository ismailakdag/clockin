#!/bin/zsh
# Clockin for Mac: one command from source to users.
#
#   scripts/publish-mac.sh 1.1.1              build, notarize and publish
#   scripts/publish-mac.sh 1.1.1 --dry-run    everything local, nothing published
#
# Steps: checks -> version bump commit + push -> universal build, Developer ID
# signing, Apple notarization, DMG, signed feed (scripts/release.sh) -> tamper
# test -> GitHub release -> website -> update feed. Each public step is
# downloaded again anonymously and compared before the next one starts.
#
# Needs docs/release-notes-<version>.md and the one-time setup in
# docs/macos-releases.md. It asks once before changing anything.
set -euo pipefail
cd "${0:A:h:h}"

VERSION="${1:-}"
MODE=publish
ASSUME_YES=0
for arg in "${@:2}"; do
  case "$arg" in
    --dry-run) MODE=dry-run ;;
    --yes) ASSUME_YES=1 ;;
    *) print -u2 "Unknown option: $arg"; exit 2 ;;
  esac
done
[[ "$VERSION" =~ '^[0-9]+\.[0-9]+\.[0-9]+$' ]] || {
  print -u2 'Usage: scripts/publish-mac.sh <version, e.g. 1.1.1> [--dry-run] [--yes]'; exit 2
}

NOTES="docs/release-notes-$VERSION.md"
NOTARY_KEYCHAIN_PROFILE="${NOTARY_KEYCHAIN_PROFILE:-ClockinNotary}"
TAG="macos-v$VERSION"
DOWNLOAD_URL_PREFIX="https://github.com/ismailakdag/clockin/releases/download/$TAG/"
PY=(/usr/bin/python3 scripts/publish-mac-release.py)

stop() { print -u2 "\nSTOPPED: $1"; exit 1; }
section() { print "\n==> $1"; }

section "Checking the source"
[[ -f "$NOTES" ]] || stop "Write the release notes first: $NOTES"
git diff --quiet HEAD -- || stop "There are uncommitted changes to tracked files. Commit or stash them first."
BRANCH="$(git branch --show-current)"
[[ -n "$BRANCH" ]] || stop "Check out a branch first."
git fetch -q origin
UPSTREAM="$(git rev-parse --abbrev-ref '@{upstream}' 2>/dev/null)" || stop "Branch $BRANCH has no upstream on GitHub."
[[ "$(git rev-list --count "$UPSTREAM..HEAD")" == 0 && "$(git rev-list --count "HEAD..$UPSTREAM")" == 0 ]] \
  || stop "Branch $BRANCH is not in step with $UPSTREAM. Push or pull first."
[[ "$BRANCH" == main ]] || print "Note: releasing from '$BRANCH', not main."

if [[ "$MODE" == publish ]]; then
  SIGNING_IDENTITY="$(security find-identity -v -p codesigning | sed -n 's/.*"\(Developer ID Application: .*\)"/\1/p' | head -1)"
  [[ -n "$SIGNING_IDENTITY" ]] || stop "No Developer ID Application certificate in the Keychain."
  xcrun notarytool history --keychain-profile "$NOTARY_KEYCHAIN_PROFILE" >/dev/null 2>&1 \
    || stop "Notarization profile '$NOTARY_KEYCHAIN_PROFILE' is missing or invalid. See the one-time setup in docs/macos-releases.md."
  PREFLIGHT="$("${PY[@]}" preflight "$VERSION" with-credentials | tee /dev/stderr)"
else
  PREFLIGHT="$("${PY[@]}" preflight "$VERSION" no-credentials | tee /dev/stderr)"
fi
BUILD="${${(M)${(f)PREFLIGHT}:#BUILD=*}#BUILD=}"
SOURCE_BUILD="$(plutil -extract CFBundleVersion raw Resources/Info.plist)"
(( SOURCE_BUILD >= BUILD )) && BUILD=$(( SOURCE_BUILD + 1 ))
[[ ! -e "dist/releases/$VERSION-$BUILD" && ! -e "dist/Clockin-$VERSION-$BUILD.dmg" ]] \
  || stop "dist already has files for $VERSION ($BUILD). Move them away first."

print "\n────────────────────────────────────────"
if [[ "$MODE" == publish ]]; then
  print "Publish Clockin for Mac $VERSION (build $BUILD) from $BRANCH"
  print "  signed by: $SIGNING_IDENTITY"
  print "  1. commit the version bump and push $BRANCH"
  print "  2. build, notarize with Apple and package (takes several minutes)"
  print "  3. GitHub release $TAG, website, then the update feed for existing users"
else
  print "Dry run for $VERSION (build $BUILD): ad-hoc build, no commit, nothing published."
fi
print "────────────────────────────────────────"
if [[ "$MODE" == publish && "$ASSUME_YES" != 1 ]]; then
  read -r "answer?Continue? [y/N] "
  [[ "$answer" == [yY]* ]] || stop "Cancelled."
fi

if [[ "$MODE" == publish ]]; then
  section "Committing the version bump"
  plutil -replace CFBundleShortVersionString -string "$VERSION" Resources/Info.plist
  plutil -replace CFBundleVersion -string "$BUILD" Resources/Info.plist
  git add Resources/Info.plist "$NOTES"
  git commit -q -m "Release Clockin for Mac $VERSION ($BUILD)"
  git push -q origin "$BRANCH"
  COMMIT="$(git rev-parse HEAD)"
  print "Pushed $(git rev-parse --short HEAD) to $BRANCH"
fi

section "Building the release"
export APP_VERSION="$VERSION" BUILD_NUMBER="$BUILD" DOWNLOAD_URL_PREFIX RELEASE_NOTES_FILE="$NOTES"
if [[ "$MODE" == publish ]]; then
  export SIGNING_IDENTITY NOTARY_KEYCHAIN_PROFILE
  ./scripts/release.sh production
else
  ./scripts/release.sh --local-test
fi
RELEASE_DIR="$PWD/dist/releases/$VERSION-$BUILD"

section "Checking that tampered files are rejected"
./scripts/test-release-verification.sh "$RELEASE_DIR"

if [[ "$MODE" == dry-run ]]; then
  # Free the version/build names so a real release can use them.
  DRY="dist/dry-runs/$VERSION-$BUILD-$(date +%Y%m%d-%H%M%S)"
  mkdir -p "$DRY"
  mv "$RELEASE_DIR" "$DRY/release"
  mv "dist/Clockin-$VERSION-$BUILD.dmg" "$DRY/"
  rm -f "dist/notary-"*"$VERSION-$BUILD"*(N)
  print "\nDRY RUN OK. Nothing was committed or published. Output: $DRY"
  exit 0
fi

"${PY[@]}" publish "$VERSION" "$BUILD" "$RELEASE_DIR" "$NOTES" "$COMMIT" "$PWD/dist/Clockin.app/Contents/Info.plist"
git fetch -q --tags origin

print "\n────────────────────────────────────────"
print "Clockin for Mac $VERSION ($BUILD) is live."
print "  GitHub:  https://github.com/ismailakdag/clockin/releases/tag/$TAG"
print "  Website: https://getclockin.netlify.app"
print "  Installed copies will offer the update on their next check."
print "────────────────────────────────────────"
