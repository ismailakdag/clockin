# iPhone TestFlight build 0.2 (3)

Built from the current local `ios/companion-art-polish` worktree, including the wardrobe proportions and companion home changes. Uploaded on September 18, 2026. No commit or push was made.

- All 29 iPhone and 13 Mac README check groups passed again.
- The wardrobe group passed 1,421 checks; the separate art contract passed.
- Added the missing Combine import to HistoryView during the final warning review.
- The signed Release archive completed with `ARCHIVE SUCCEEDED`, without compiler warnings.
- Clockin.app and ClockinWidgets.appex both report version 0.2, build 3.
- Both bundles contain all 25 wardrobe sprites, 17 furnishings, three rooms, colorways and fixed-pose anchors. The app contains all eight notification sounds. Both debug symbol bundles are present.
- Strict code-signature verification passed for the app and widget with normal system trust access. The sandbox-only attempt could not access the required trust chain.
- Version and signing settings in the project file were not changed; archive arguments supplied build 3.

Archive: `/tmp/clockin-companion-0.2-3-20260918/Clockin.xcarchive`

Upload completed with `Upload succeeded` and `EXPORT SUCCEEDED`. App Store Connect completed processing 0.2 (3). Export used automatic signing, symbol upload and `manageAppVersionAndBuildNumber=false`.

English (U.S.) and Turkish What to Test notes were saved in their respective localization fields. The build was added to Clockin Internal and Clockin Public Beta, with automatic tester notification enabled. The requested Submit for Review step completed, and both group build lists subsequently showed 0.2 (3) as **Testing**, with 90 days remaining. No pending review was shown in the final Public Beta group state.

[App Store Connect build](https://appstoreconnect.apple.com/teams/2f645726-a8ca-4796-ba28-78a0d0f12f8c/apps/6811702631/testflight/ios/56b65b44-452d-47ab-8397-829bfd57aa7a)

Live interaction and physical-device performance remain unverified because Device Hub window access still times out. Successful build and upload do not constitute a completed live UI acceptance test.
