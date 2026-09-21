# iPhone 0.2 (4)

Built from the local `ios/companion-art-polish` worktree after 0.2 (3), including compact product cards, try-first clothing/color previews, purchase confirmation and the orbit level celebration. No commit or push was made.

- All 13 Mac and 29 iPhone README check groups passed. The Mac rolling-text test required normal window-server access after the sandbox prevented animation; its rerun passed 20 checks. Existing Mac concurrency warnings remain outside this iPhone change.
- The wardrobe group passed 1,514 checks.
- Generic iOS Simulator build and signed Release archive passed without warnings.
- App and widget both report 0.2 (4). All wardrobe, home and frame resources decode with expected dimensions; JSON files match the source. Xcode optimizes PNG encoding during archive, so file-byte identity is not expected.
- Both debug symbol bundles and all eight notification sounds are present. Strict nested code-signature verification passed.
- Project version and signing settings were not edited; build arguments supplied the version and build number.
- Direct device build was stopped by the phone lock state. TestFlight distribution was requested instead.

Archive: `/tmp/clockin-testflight-0.2-4/Clockin.xcarchive`

Upload succeeded on September 18, 2026, and processing completed. Export used automatic signing, symbol upload and `manageAppVersionAndBuildNumber=false`. English and Turkish What to Test notes were saved separately. The build was added to Clockin Internal and Clockin Public Beta, with automatic tester notification enabled. Submit for Review completed. Both group build lists subsequently showed **0.2 (4): Testing**, with 90 days remaining.

[App Store Connect build](https://appstoreconnect.apple.com/teams/2f645726-a8ca-4796-ba28-78a0d0f12f8c/apps/6811702631/testflight/ios/9c8f4903-de70-48de-b5f0-8d923cd87180)

Live touch interaction, iPhone Dynamic Type and physical-device animation performance remain unverified. The composition proofs are not live-device screenshots.
