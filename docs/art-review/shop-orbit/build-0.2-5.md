# iPhone TestFlight 0.2 (5)

Prepared from the local `ios/companion-art-polish` working files at base commit `37acc79`, in an isolated release worktree. No commit, push or PR. The original worktree is preserved.

## Changes since 0.2 (4)

- Replaces overlapping Outfit, Home and Shop tabs with one categorized catalog. Each product appears once. Categories choose the matching outfit or room preview.
- Keeps room settings in a disclosure and moves removing an equipped item into its preview.
- Improves wings, cape, backpack and jetpack placement across raised-arm, working, coffee and fixed poses while keeping them behind the companion.
- Preserves the compact cards, purchase previews and confirmations, home improvements and space-themed level celebration already distributed in earlier builds.

## Excluded

The procedural 3D preview, its launch routes and entry button, diagnostics and Meshy work are excluded. The app and widget binaries contain no Companion3D symbols or preview label.

## Verification

- All 13 Mac and 29 iPhone README swiftc groups pass. The wardrobe group passes 2,076 checks. Existing Mac concurrency warnings remain.
- Art contract passes: 63 frames, 25 garments, six colorways, three rooms and 17 furniture items.
- Generic iOS Simulator Release build and signed device archive pass with no compiler warnings. The app installs and launches in the isolated art-review simulator.
- App and widget report 0.2 (5); all 108 frame, wardrobe and home PNGs decode with matching source dimensions in both bundles, JSON manifests match source, all eight notification sounds and both debug symbol bundles are present. Strict recursive signing verification passes.
- Source project version and signing settings remain unchanged.
- Device Hub UI access timed out. Live catalog selection, touch interaction and physical-device performance remain unverified.

Archive: `/tmp/clockin-testflight-0.2-5/Clockin.xcarchive`

Upload completed on September 18, 2026 at 23:45 Europe/Istanbul with Upload succeeded and EXPORT SUCCEEDED. Processing completed. English and Turkish What to Test notes were saved separately. The build was added to Clockin Internal and Clockin Public Beta with automatic tester notification enabled. Submit for Review completed. Both group build lists independently show 0.2 (5) as Testing, expiring in 90 days. No pending review appears in the final observed state.

[App Store Connect build](https://appstoreconnect.apple.com/teams/2f645726-a8ca-4796-ba28-78a0d0f12f8c/apps/6811702631/testflight/ios/53e297d9-f19b-402e-bc0e-684d1b4e31df)

## What to Test

English:
Companion items now live in one catalog organized by category, without duplicates across Outfit, Home and Shop. Try filtering clothing, colors, rooms and furnishings, previewing an item, buying it, equipping it and removing it. Room layout and lamp controls remain under Room settings. Wings, capes, backpacks and jetpacks should stay more visible during angry, celebrating, working and coffee poses. This build keeps the existing pixel-art companion.

Turkish:
Maskot ürünleri artık Outfit, Home ve Shop arasında tekrarlanmadan, kategorilere ayrılmış tek bir katalogda. Kıyafet, renk, oda ve ev eşyalarını filtrelemeyi; ürün önizlemeyi, satın almayı, takmayı ve çıkarmayı deneyin. Oda düzeni ve lamba kontrolleri Room settings altında. Kanat, pelerin, sırt çantası ve jetpack sinirli, kutlama, çalışma ve kahve pozlarında daha belirgin görünmeli. Bu sürüm mevcut pixel art maskotu kullanır.
