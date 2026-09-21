# iPhone TestFlight 0.2 (6)

Prepared from local companion polish files at base commit `37acc79`, isolated in a detached release worktree. Original work preserved. No commit, push or PR.

## Changes since 0.2 (5)

- Category tabs and a room preview that fills the available width.
- Seated working legs facing the laptop, with separate room placement under the desk.
- Hand items hidden throughout typing and drinking, restored when idle and visible in try-on.
- Gentle wing-flap bursts, respecting the existing motion and visibility policy.
- Headwear hides the built-in antenna in animated poses, fixed poses and widget composites; removing headwear restores it.

Procedural 3D prototype, preview route and button are excluded.

## Validation

- iPhone: all 29 README swiftc groups pass, including 2,474 wardrobe checks.
- Mac: 12 of 13 groups pass. The menu-bar panel host check fails at `still not activated after a click on the item`. It also fails on unchanged 0.2 (5) source and in a temporary accessory-app bundle. This baseline Mac finding remains unresolved; it is not counted as a passing check.
- Art contract passes. Generic Simulator Release app/widget build and signed iPhone archive pass.
- Both bundles are 0.2 (6). All 108 mascot PNGs in each bundle decode with source dimensions; manifests match. Eight chime sounds are present. Deep signature checks pass. No Companion3D binary symbols.
- No version or signing project changes. Physical-device interaction and battery performance were not re-tested.

Archive: `/tmp/clockin-testflight-0.2-6/Clockin.xcarchive`.

## What to Test

Companion categories now use tabs, and the room fills its preview width. Working poses have correctly facing seated legs. Handheld items stay hidden while typing or drinking and return when idle; try-on previews still show them. Wings now flap gently in short bursts. Hats and headphones hide the built-in antenna, which returns when removed. Please check outfit changes, item previews, room placement, motion with Reduce Motion enabled, and phone warmth during a running session.

Maskot kategorileri artık sekmeler halinde; oda önizleme alanının genişliğini dolduruyor. Çalışma pozuna doğru yöne bakan oturan bacaklar eklendi. Bardak ve diğer el eşyaları yazarken veya kahve içerken gizleniyor, boşta geri geliyor; ürün denemesinde görünmeye devam ediyor. Kanatlar kısa aralıklarla hafifçe çırpıyor. Şapka ve kulaklık takınca robotun kendi anteni gizleniyor, çıkarınca geri geliyor. Kıyafet değiştirmeyi, ürün önizlemelerini, oda yerleşimini, Hareketi Azalt açıkken animasyonları ve sayaç çalışırken telefonun ısınmasını kontrol edin.

## Distribution

Upload succeeded and EXPORT SUCCEEDED at 00:33 Europe/Istanbul on September 19, 2026. Processing completed. English and Turkish What to Test notes saved. Submitted for beta review with automatic tester notifications enabled. Build 0.2 (6) is assigned to Clockin Internal and Clockin Public Beta; both group pages were verified as Testing on September 19, 2026.

[App Store Connect build](https://appstoreconnect.apple.com/teams/2f645726-a8ca-4796-ba28-78a0d0f12f8c/apps/6811702631/testflight/ios/69a69725-7f21-442f-b692-42122dbb9aa2)
