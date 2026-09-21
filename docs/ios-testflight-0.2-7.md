# iOS TestFlight 0.2 (7)

Source: companion-art working tree based on `37acc79633924e90034e3107f5cd22878994eca6`, frozen at `/private/tmp/clockin-testflight-level75/source/iOS`. This includes uncommitted level/prestige design changes. Per-file SHA-256 manifest: `/private/tmp/clockin-testflight-level75/source-manifest.json`.

## Included changes

- Revised level-up cards, lighting, staged entrance and slower orbital comet effects.
- Shared compact level badge with 75-level structural prestige tiers and one-shot rank unlock burst.
- Next-rank target; stable one/two/three-digit alignment; no visible percentage, Roman numeral crest, external wings or hanging ornaments.
- Larger-text and constrained-screen fallback with persistent action buttons.
- Keeps existing 2D companion. The release snapshot excludes the Prototype directory, the 3D companion button/sheet and its launch route. Experimental originals remain in the art worktree.

## Verification

- Signed Release archive succeeded; app and widget both 0.2 (7).
- 30/30 iOS check groups passed, including levelprestige. Initial environment-only module-cache permission failures were rerun with a writable cache; final results are in `check-results-final.json`.
- Strict recursive signature validation passed with access to the macOS trust store.
- Eight CAF sounds; no GLB/USDZ assets in the app bundle.
- Card simulator visuals, milestone/normal animations, accessibility size and static-motion fallback were checked during design work. No new physical-device power profiling.
- Build 0.2 (6) was verified live as the previous TestFlight build before selecting build 7. Version overrides were supplied at archive time; project version settings were unchanged.

## What to Test

English:
Level-up celebrations have a new layout, balanced lighting and orbiting comet effects. Level badges gain a distinct look every 75 levels, with a short burst when a new rank unlocks. Cards show the next rank target and adapt better to larger text and smaller screens. Please check level-up celebrations, badge alignment, Reduce Motion and battery use during longer sessions. The existing 2D companion is preserved.

Turkish:
Level atlama kartları yenilendi: dengeli ışık, dönen kuyruklu yıldızlar ve her 75 levelde yeni rozet görünümü. Yeni kademeye geçişte kısa bir kutlama efekti var; kartta sonraki kademe hedefi gösteriliyor. Büyük yazı ve dar ekran düzeni iyileştirildi. Level atlama kutlamalarını, rozet hizalarını, Hareketi Azalt ayarını ve uzun kullanımda pil tüketimini kontrol edin. Mevcut 2D maskot korunuyor.

## Distribution

Upload/export succeeded on 19 September 2026 at 12:59 Europe/Istanbul. Processing completed. English and Turkish test notes were saved; beta review submission completed with automatic tester notifications enabled.

Live verification: **Clockin Internal** and **Clockin Public Beta** both show **0.2 (7) — Testing**, with 90 days remaining. Existing builds were not withdrawn or expired.

Build: https://appstoreconnect.apple.com/teams/2f645726-a8ca-4796-ba28-78a0d0f12f8c/apps/6811702631/testflight/ios/2f3cb783-b60e-4c1b-ab47-7d9c86e25b61
Public beta: https://testflight.apple.com/join/tr6kSDMN
Archive and logs: `/private/tmp/clockin-testflight-level75/`.
