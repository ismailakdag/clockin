# iOS TestFlight 0.2 (8)

Source: companion-art working tree, frozen at `/private/tmp/clockin-testflight-0.2-8/source/iOS`. This includes the approved level animation and dashboard feedback changes. Per-file SHA-256 manifest: `source-manifest.json` (323 files).

## Included changes

- Level badge and celebration rendering targets 60 updates/sec; direct orbit geometry replaces repeated path trimming, and comet glow rendering is cheaper.
- Dashboard level badge is 14% smaller while keeping a 44-point hit target.
- Aurora (375) and Sovereign (including 500) core orbit styles are swapped and drawn closer to the gem, inside the outer frame.
- Level-up cards remain open until an explicit action; background taps and the former automatic timeout no longer dismiss them.
- Badges XP progress is a clean capsule without flanking icons, dots or crossing stripes.
- Persistent pin controls for Focus Chime, Radio and Session Reminder on Today. Pinning does not enable the feature; radio controls remain accessible while stopped.
- Level badge gallery shows all nine rank designs, with current/unlocked/locked states and one animated selected preview.
- Existing 2D companion retained. Only this release snapshot excludes experimental Prototype files, the 3D companion button/sheet and its launch route. Original experiments remain in the art worktree.

## Verification

- Signed Release archive succeeded without warnings. App and widget both report 0.2 (8).
- All 30 iOS check groups passed against the release snapshot. Source manifest remained unchanged after archive.
- Strict recursive signature validation passed; eight CAF sounds and no GLB/USDZ assets in the app bundle.
- Prior revision verification: Debug and Release simulator builds; 591 checks across six affected suites; 9,009 valid orbit sample positions; visual inspection of dashboard, gallery, pinned cards, XP track and persistent celebration.
- Warmed simulator Canvas cadence measured 60.000 updates/sec across 360 samples. This is a simulator update measurement, not a physical-device GPU guarantee. The actual celebration center retained the card beyond seven seconds.
- Native button automation and physical-device battery/GPU profiling remain unverified.
- Latest live build was verified as 0.2 (7) before selecting build 8. Version overrides were supplied at archive time; source project settings were unchanged.

## What to Test

English:
Level animations have been optimized for smoother motion. The dashboard level badge is smaller, and Aurora/Sovereign orbit effects sit closer to the gem. Level-up cards now stay open until you continue. The Badges XP bar has a cleaner design. Browse all level badge styles in Badges > Level badges. Pin Focus Chime, Radio and Session Reminder controls to Today from their settings or Today > Customize Today. Please check animations, level-up dismissal, pinned controls, badge previews and Reduce Motion during normal use.

Turkish:
Level animasyonları daha akıcı hareket için optimize edildi. Dashboard level rozeti küçültüldü; Aurora ve Sovereign halka efektleri elmasa yaklaştırıldı. Level atlama kartları artık Devam düğmesine basana kadar açık kalıyor. Badges XP barı sadeleştirildi. Badges > Level badges bölümünden tüm level rozetlerini inceleyebilirsiniz. Focus Chime, Radio ve oturum hatırlatıcısını kendi ayarlarından veya Today > Customize Today üzerinden dashboarda sabitleyebilirsiniz. Animasyonları, kartın kapanmasını, sabitlenen kontrolleri, rozet önizlemelerini ve Hareketi Azalt ayarını kontrol edin.

## Distribution

Upload/export succeeded on 19 September 2026 at 13:56 Europe/Istanbul. App Store Connect records upload at 13:57. Processing completed; English and Turkish test notes were saved. Beta review submission completed with automatic tester notifications enabled.

Live verification: **Clockin Internal** and **Clockin Public Beta** both show **0.2 (8) — Testing**, with 90 days remaining. Existing builds were not withdrawn or expired.

Build: https://appstoreconnect.apple.com/teams/2f645726-a8ca-4796-ba28-78a0d0f12f8c/apps/6811702631/testflight/ios/07d2df5e-5d06-4d34-8084-e6a63fe79bb7
Public beta: https://testflight.apple.com/join/tr6kSDMN

Archive, upload log, test logs and source snapshot: `/private/tmp/clockin-testflight-0.2-8/`.
