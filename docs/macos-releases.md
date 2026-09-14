# Clockin for Mac: installer and updates

Clockin ships as a universal DMG for macOS 14 or later. The user opens the DMG,
drags Clockin into Applications and opens the app. Subsequent versions arrive
through **Check for Updates…** in Settings or the menu bar. Sparkle downloads,
verifies, replaces the application and relaunches it. Git, Xcode and Terminal
are not needed on the user's Mac.

Existing installations built from source need to install this first packaged
version once. The old updater cannot bootstrap Sparkle automatically.
Sessions remain in `~/Library/Application Support/Clockin/clockin.json` and
preferences keep the existing `com.ismailakdag.clockin` bundle identifier.

## Current distribution status

Version **1.1.0 (4)** is publicly available for Apple Silicon and Intel. Its application bundle is Developer ID signed, notarized by Apple and stapled. The signed outer DMG contains the app, Applications shortcut and MIT license; the outer DMG is not separately notarized.

- [Download the installer](https://github.com/ismailakdag/clockin/releases/download/macos-v1.1.0/Clockin-1.1.0-4.dmg)
- [Signed update feed](https://github.com/ismailakdag/clockin/releases/download/macos-updates/appcast.xml)
- [Source matching the app build](https://github.com/ismailakdag/clockin/tree/macos-v1.1.0)
- [End-user website](https://clockin-for-mac.erdmncdr.chatgpt.site/)

The public DMG and feed were downloaded anonymously and verified using the public key shipped in the application. Both feed and archive tampering were rejected. The downloaded app passed Gatekeeper and stapler validation, was installed to Applications, opened successfully and reported “You’re up to date” against the live feed. Existing work-data JSON remained semantically identical after installation; only its JSON serialization changed.

Future releases must increment the build number, sign with the existing Developer ID identity and Sparkle key, pass notarization and verification, then publish their versioned DMG before updating the stable signed feed. Update the website’s pinned installer URL after the new download is verified. Never move the Mac feed to the repository’s generic latest-release URL.

The feed uses the dedicated `macos-updates` release instead of `releases/latest`,
so future iPhone or prerelease uploads do not break Mac update checks. Before
shipping, confirm the repository in `SUFeedURL` is the one you control. If using
a fork or another HTTPS host, change that URL before the first installation.
Do not publish this app's feed into an unrelated project's release.

## Signing keys

Sparkle 2.10.0 is pinned in Package.swift and Package.resolved. Its Ed25519 public
key is embedded in Resources/Info.plist. The matching private key was created in
the Mac login Keychain under account `com.ismailakdag.clockin`. Never regenerate
or replace that key for routine releases; installed versions trust the original
public key. Back up the key securely before moving or erasing this Mac.

The updater requires both signed feeds and signed archives and verifies archives
before extraction. Signature failures do not expire. Release verification reads
only the embedded public key and never requests the private key from Keychain.

## Build and package locally

```sh
./build-app.sh
./script/build_and_run.sh --verify
```

For a full local test release, choose an unused build number:

```sh
APP_VERSION=1.1.0 BUILD_NUMBER=3 \
DOWNLOAD_URL_PREFIX=https://github.com/ismailakdag/clockin/releases/download/macos-v1.1.0/ \
./scripts/release.sh --local-test
```

Output: `dist/releases/1.1.0-3/` containing the DMG, signed appcast, checksums and
`LOCAL-TEST-ONLY.txt`. This mode must not be published as a production release.
Build numbers must increase for every distributed build, including rebuilds of
the same marketing version. Existing release files are never overwritten.

## Notarize using the existing Xcode account

This path uses the account already signed into Xcode and does not need a separate
app-specific password. Start with a new version/build number:

```sh
APP_VERSION=1.1.0 BUILD_NUMBER=4 ARCHITECTURES=universal \
SIGNING_IDENTITY='Developer ID Application: Your Name (TEAMID)' ./build-app.sh

TEAM_ID=TEAMID \
SIGNING_IDENTITY='Developer ID Application: Your Name (TEAMID)' \
./scripts/notarize-xcode.sh
```

Open the resulting `dist/Clockin-1.1.0-4.xcarchive` in Xcode Organizer to see
Apple's status. Opening an external archive imports a copy into
`~/Library/Developer/Xcode/Archives/<date>/`. Use that Organizer copy for export,
since it is the copy whose notarization status Xcode refreshes. After approval,
use **Export Notarized App** in Organizer or its imported archive path:

```sh
xcodebuild -exportNotarizedApp \
  -archivePath "$HOME/Library/Developer/Xcode/Archives/2026-09-14/Clockin-1.1.0-4.xcarchive" \
  -exportPath dist/notarized-1.1.0-4

SIGNING_IDENTITY='Developer ID Application: Your Name (TEAMID)' \
DOWNLOAD_URL_PREFIX=https://github.com/ismailakdag/clockin/releases/download/macos-v1.1.0/ \
RELEASE_NOTES_FILE=docs/release-notes-1.1.0.md \
./scripts/package-notarized-app.sh dist/notarized-1.1.0-4/Clockin.app
```

This produces a signed DMG containing a notarized, stapled application. The
outer DMG is signed but not separately notarized. The app itself must pass
Gatekeeper and ticket validation before this script packages anything. To
notarize and staple the outer DMG too, use the notarytool path below.

## Prepare a production release with notarytool

One-time setup on the release Mac:

1. Install a **Developer ID Application** certificate and its private key in
   Keychain. Apple Development is not a substitute for distribution signing.
2. Store your Apple notarization credentials using the interactive command
   `xcrun notarytool store-credentials ClockinNotary` and follow its prompts.
   Do not paste credentials into a chat or commit them to the repository.
3. Confirm repository ownership/write access and the feed URL.

Then prepare the release (use the identity exactly as shown by
`security find-identity -v -p codesigning`):

```sh
APP_VERSION=1.1.0 BUILD_NUMBER=4 \
SIGNING_IDENTITY='Developer ID Application: Your Name (TEAMID)' \
NOTARY_KEYCHAIN_PROFILE=ClockinNotary \
DOWNLOAD_URL_PREFIX=https://github.com/ismailakdag/clockin/releases/download/macos-v1.1.0/ \
RELEASE_NOTES_FILE=docs/release-notes-1.1.0.md \
./scripts/release.sh
```

The script builds arm64 and x86_64, signs Sparkle's nested helpers inside-out,
notarizes and staples the app, creates a DMG, notarizes and staples the DMG,
generates signed update metadata, and verifies signatures with the app's public
key. It requires Apple's `Accepted` response and Gatekeeper assessments before
producing the final release directory. Apple steps require real credentials and
were not exercised by local ad-hoc tests.

For a secured CI environment, `SPARKLE_PRIVATE_KEY_FILE` can point to an ephemeral
secret file instead of Keychain. Do not commit that file. Otherwise signing uses
`SPARKLE_KEY_ACCOUNT` (default `com.ismailakdag.clockin`).

## Publish

Using the repository you control:

1. Create a draft versioned release, for example `macos-v1.1.0`, from the exact
   source used for the build. Upload the versioned DMG and SHA256SUMS.
2. Test the DMG from a clean Mac, including offline first launch after copying to
   Applications, and test an older packaged version updating to it.
3. Publish the versioned release. Confirm its DMG URL is downloadable without a
   GitHub account. Never replace an already published DMG with different bytes.
4. Create the stable `macos-updates` release once (do not mark it as the latest
   product release). Upload or replace its `appcast.xml` with the **unchanged,
   signed** generated file only after the DMG is accessible.
5. Download the live appcast and DMG into a temporary directory and run
   `swift scripts/verify-release.swift /path/to/appcast.xml dist/Clockin.app/Contents/Info.plist`.
   Check from the installed old app. It should offer the new version and install
   and relaunch without opening GitHub or a terminal.

Only replacing the signed feed makes an update visible to existing users. Do
not hand-edit signed XML, release notes or archives after signing. Do not raise
the minimum OS version without retaining a compatible feed entry for older Macs.

## Verification

```sh
./scripts/test-release-verification.sh dist/releases/1.1.0-3
codesign --verify --deep --strict dist/Clockin.app
lipo -archs dist/Clockin.app/Contents/MacOS/Clockin
hdiutil verify dist/Clockin-1.1.0-3.dmg
```

On 2026-09-14 a copied Clockin app with a separate test bundle identifier updated
from 1.0.0 (1) to 1.1.0 (2) against a signed loopback feed: discovery, download,
verification, extraction, Install and Relaunch, Settings showing 1.1.0, and a
subsequent 'You're up to date' dialog were observed in the actual UI. The
session data file's SHA-256 stayed unchanged. This proves the local package
update flow, not public HTTPS delivery, notarization or Intel runtime behavior.

The test feed allowed HTTP only for localhost in the copied test bundle; no
transport exceptions are present in the shipping application plist.

A second UI test upgraded that installation to a Developer ID signed test build
(1.1.1, build 4), including download, Install and Relaunch, successful startup,
and verification of team LU36PKDPT3 and hardened runtime in the installed copy.
The session data checksum remained unchanged in this test too.

References: [Sparkle setup](https://sparkle-project.org/documentation/),
[Apple Mac distribution](https://developer.apple.com/macos/distribution/).
