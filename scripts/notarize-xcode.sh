#!/bin/zsh
set -euo pipefail
cd "${0:A:h:h}"
: "${TEAM_ID:?Set TEAM_ID to your paid Apple Developer team}"
: "${SIGNING_IDENTITY:?Set SIGNING_IDENTITY to a Developer ID Application identity}"
APP="$PWD/dist/Clockin.app"
VERSION="$(plutil -extract CFBundleShortVersionString raw "$APP/Contents/Info.plist")"
BUILD="$(plutil -extract CFBundleVersion raw "$APP/Contents/Info.plist")"
ARCHIVE="$PWD/dist/Clockin-$VERSION-$BUILD.xcarchive"
[[ ! -e "$ARCHIVE" ]] || { print -u2 "Archive exists: $ARCHIVE"; exit 1; }
codesign --verify --deep --strict "$APP"
mkdir -p "$ARCHIVE/Products/Applications"
ditto "$APP" "$ARCHIVE/Products/Applications/Clockin.app"
export ARCHIVE TEAM_ID SIGNING_IDENTITY
/usr/bin/python3 <<'PY'
import datetime, os, pathlib, plistlib
archive = pathlib.Path(os.environ['ARCHIVE'])
with (archive / 'Products/Applications/Clockin.app/Contents/Info.plist').open('rb') as f:
    app = plistlib.load(f)
metadata = {
    'ArchiveVersion': 2,
    'CreationDate': datetime.datetime.now(datetime.timezone.utc).replace(tzinfo=None),
    'Name': 'Clockin',
    'SchemeName': 'Clockin',
    'ApplicationProperties': {
        'ApplicationPath': 'Applications/Clockin.app',
        'Architectures': ['arm64', 'x86_64'],
        'CFBundleIdentifier': app['CFBundleIdentifier'],
        'CFBundleShortVersionString': app['CFBundleShortVersionString'],
        'CFBundleVersion': app['CFBundleVersion'],
        'SigningIdentity': os.environ['SIGNING_IDENTITY'],
        'Team': os.environ['TEAM_ID'],
    },
}
with (archive / 'Info.plist').open('wb') as f:
    plistlib.dump(metadata, f)
options = {
    'method': 'developer-id', 'destination': 'upload',
    'signingStyle': 'manual', 'signingCertificate': os.environ['SIGNING_IDENTITY'],
    'teamID': os.environ['TEAM_ID'],
}
with (archive.parent / 'DeveloperIDExport.plist').open('wb') as f:
    plistlib.dump(options, f)
PY
# Uses the account already signed into Xcode. No app-specific password is needed.
xcodebuild -exportArchive -archivePath "$ARCHIVE" \
    -exportOptionsPlist "$PWD/dist/DeveloperIDExport.plist" \
    -exportPath "$PWD/dist/xcode-upload-$VERSION-$BUILD" -allowProvisioningUpdates
print "Submitted archive: $ARCHIVE"
print 'After Apple approves, export with:'
print "xcodebuild -exportNotarizedApp -archivePath '$ARCHIVE' -exportPath '$PWD/dist/notarized-$VERSION-$BUILD'"
