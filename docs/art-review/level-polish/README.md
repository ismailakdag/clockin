## Latest: smooth effects, explicit dismissal and pinned controls

Current preview: `feedback.html`; updated badge entry point: `prestige75.html`.

- Level effects now schedule at 60 Hz instead of 24/30. Perimeter particles use direct geometry rather than repeated path trimming; comet glow uses a radial gradient instead of a per-frame blur pass.
- Dashboard badge visual scale is 0.86 with a 44-point touch target. Aurora and Sovereign orbit styles are exchanged, with 14.5-point core radius; core effects stay within the inset plate.
- Level-up cards have no timeout and backdrop taps do not dismiss them. Continue, Share and accessibility escape remain explicit actions. Other banners last four seconds; brief reactions retain their old duration.
- Badges XP track is a clean capsule: no edge symbols, divisions or particle dots.
- Focus chime, radio and session reminder can be pinned to Today with separate persistent keys. Pinning never enables playback/chimes. Chime interval/toggle and radio station/playback/volume are directly accessible. Sound settings and reminder settings open focused sheets. Settings and Today both expose customization.
- Level badge gallery has all nine designs, current/unlocked/locked states and a single animated selected preview; catalog tiles are static and the preview pauses when scrolled away.

Verification: Debug and Release simulator builds passed without warnings; six suites passed (591 checks: 103 celebration, 197 rolling, 109 radio, 96 chime sound, 44 reminder, 42 prestige). 9,009 sampled perimeter positions were finite, contained and continuous. The isolated geometry microbenchmark improved from 0.087 s to 0.001 s for 2,000 x 64 samples; this is not an app FPS multiplier. Warmed simulator Canvas cadence was 60.000 updates/sec over 360 samples, with a 16.667 ms maximum interval. Initial launch capture was 56.8 updates/sec including startup. Actual celebration center retained its card beyond seven seconds. Inspected badge gallery, pin cards, real dashboard and XP track screenshots. Native Simulator UI automation is unavailable through the enabled computer-use surface, so button taps and device GPU/battery behavior remain unverified. Published as TestFlight 0.2 (8) on 19 September 2026; verified Testing in Clockin Internal and Clockin Public Beta. See ../../ios-testflight-0.2-8.md for release evidence.

## Latest: revised level-up cards

Current card preview: `cards.html` / `cards-v3.mp4`. The card now uses the accepted compact LevelBadge, including real snapshot XP only when its level matches the queued celebration. Preserves the existing mascot drawing. No wings, Roman numerals or visible percentages are reintroduced.

Reworked hierarchy, lighting, sequential entrance and slower orbital comets. Exact 75-level rank milestones receive one contained burst; ordinary levels remain quieter. Shows the next rank and remaining levels. Actions stay outside scrollable content, with a constrained-layout fallback and larger accessibility text. Decorative scene respects narrow proposed widths. Motion remains gated by accessibility, activity and power policy.

Verified: final simulator build succeeded; 100 existing celebration-rule checks passed; git diff --check passed. Inspected recorded milestone/ordinary card frames, final level 500, and a 320 x 560 preview at accessibility3. Static captures had zero changed pixels below the status bar. Native button interaction and device performance were not tested. No TestFlight upload or release.

## Latest: stable short-level alignment

Reserve a three-digit number column using the actual numeral font metrics. LV and the first digit stay anchored for 1/75/150 instead of centering each string independently. Three-digit layout is unchanged; longer values can expand naturally. Fresh simulator build, diff check and 1/75/150 gallery visual check passed. Current recording: prestige-digit-layout-preview.mp4.

## Latest: centered level label

Centered the LV/number group above the 66-point XP track. No changes to the crystal, effects or progress calculation. Fresh simulator build, diff check and gallery visual inspection passed. Current recording: prestige-centered-preview.mp4.

## Latest: no visible percentage

Removed the compact badge's percentage text. The LV prefix is quieter, level digits are larger, and the number aligns with the actual XP track below. Accessibility still announces progress; XP calculation and fill width are unchanged. Fresh simulator build and gallery visual check passed. Current preview: prestige-no-percent-preview.mp4.

## Latest: contained Nebula and Solar effects

Reduced their core-orbit radii and clipped these two tiers' animated Canvas content to the inset plate shape. Star tips, radial rays and rim glints cannot extend beyond the outer frame. Fresh simulator build and gallery inspection passed. Current recording: prestige-contained-preview.mp4.

## Latest: integrated frames, no wings or laurel

Removed the internal prestige-name caption from the compact badge, all external wings/shoulders, and the laurel leaves below them. Cut metal bevels now live inside the plate silhouette; the crown remains. Removed obsolete horizontal wing padding. Updated current preview: prestige75.html / prestige-clean-frame-preview.mp4. Fresh simulator build, diff check and 1–500 gallery inspection passed. Older descriptions below are historical.

## Latest: Aurora wave removed

Removed the lower-edge sine ribbons entirely. Aurora now uses two slow lens arcs around the crystal, a quiet halo and broad swept metal shoulders. Higher prestige frames retain those shoulders with their crown/laurel additions. Simulator build and gallery visual check passed; fresh recording: prestige-aurora-preview.mp4. No XP or rank-threshold changes.

## Current refinement: no Roman numerals

Roman numeral crests and the duplicate rank label on the celebration card were removed. Original Canvas-drawn faceted crystals now occupy the emblem socket; high ranks add a platinum inner cut. The actual LV number is the single numeric label. Current preview: prestige75.html; recording: prestige-crystal-preview.mp4. Fresh simulator build, 42 boundary checks and visual inspection passed.

# Current: 75-level structural prestige

The 75-level design below supersedes the older 50-level experiments retained later in this file. Current preview: `prestige75.html`.

- 1–74 Spark: rounded core; 75–149 Orbit: cut metal; 150–224 Nebula: double rim.
- 225–299 Solar: armored shoulders; 300–374 Nova: forged wings; 375–449 Aurora: layered wings/ribbons.
- 450–524 Sovereign (including level 500): gold crown, laurel, platinum-cut crystal and ceremonial halo.
- 525–599 Celestial: rear arch; 600+ Eternal: apex crest/seal. Beyond 600 the apex structure remains; it never returns to starter art.

A single 2.4-second ring/particle burst accompanies exact rank milestone celebrations; the compact badge also bursts when its observed rank increases while active. Continuous effects remain controlled and gated by motion, power, visibility and scene policies. Original mascot art and XP rules remain unchanged.

Verified: fresh simulator build; 42 rank-boundary cases plus 500-level identity/XP invariants; 1–500 silhouette gallery; unlock burst verified from recorded frames; reduced-motion preview had zero changed pixels below the status bar across two captures. Canvas drawing bounds explicitly include outer metalwork, preventing cropped crowns/wings. No device profiling or release performed.

## Historical design notes (superseded)

# Level celebration and 50-level bar progression

Implemented in the companion-art worktree, preserving existing companion art and celebration rules.

## Visual direction

Dark navy depth (#060B16), illuminated metal edges, white/cool suit highlights and a rank-tinted key light. Rounded system typography for the level number; compact monospaced percentages. One orbital focus around the existing astronaut. Bright comet heads with tapered trails pass behind/in front of the character. Atmosphere and planet horizon establish depth without replacing the mascot drawing.

Cosmetic tiers: 1–49 Spark, 50–99 Orbit, 100–149 Nebula, 150–199 Solar, 200–249 Nova, 250–299 Aurora. Every subsequent 50 levels continues with a numbered generation and shifted hue. Ornaments and particle counts are capped to control visual density and cost. XP earning and level math are unchanged.

The dashboard badge and Badges XP bar share the tier style. The celebration's explicitly labeled next-style track measures levels toward the next 50-level unlock, not XP.

## Research and implementation sources

- Apple, Canvas: https://developer.apple.com/documentation/swiftui/canvas
- Apple, Drawing and graphics: https://developer.apple.com/documentation/swiftui/drawing-and-graphics
- Apple, TimelineView: https://developer.apple.com/documentation/swiftui/timelineview
- GDC 2019, Steph Chow, From Zero to Hero: Visualizing Player Progression within UI/UX: https://www.gdcvault.com/play/1026271/From-Zero-to-Hero-Visualizing

The GDC session overview informed visible rank progression; it was not treated as source code. Rendering uses original SwiftUI/Canvas code, not copied third-party assets or libraries. Existing design/SwiftUI skill guidance used for hierarchy, contrast, and restrained persistent motion.

## Verification

- iPhone 17 Pro Max simulator Debug build succeeded.
- 100 existing celebration-rule checks passed.
- New levelprestige manual checks cover 15 tier boundaries, negative input, continued variants and XP modulo behavior.
- Rank gallery visually checked, including 300+ continuation.
- Static fallback checked with two captures: zero changed pixels below the OS status bar.
- No real-device GPU/battery profiling, TestFlight upload or production release.

Animation work is gated by visibility, active tab, scene phase, Reduce Motion, Low Power and existing thermal policy. Comet rendering runs at most 30 fps, bar highlights 24 fps. Level effects are hidden from accessibility; native labels and buttons remain accessible. Card retains vertical scroll fallback for constrained layouts.

Debug preview: launch with --level-effects-preview; optional --preview-bars, --preview-level 250, --preview-still. Normal startup remains RootView. Preview does not alter the user's XP or unlock state.

Manual test:
`swiftc -module-cache-path /tmp/clockin-level-tests-cache iOS/Clockin/Celebrations/LevelPrestige.swift iOS/Tests/manual/levelprestige/main.swift -o /tmp/clockin-level-tests && /tmp/clockin-level-tests`

## Compact dashboard badge follow-up

The top-left badge now has dedicated effects on a single 24 fps timeline: traveling rim comet (all levels), emblem orbit (50), nebula stars (100), rotating solar rays (150), twin comets/stars (200), aurora ribbons (250). Text and actual XP fill remain readable; zero XP does not display a filled track. Existing visibility, reduced-motion, scene and power-policy gates remain.

Verified with a fresh successful simulator build, all-tier animation recording and the normal dashboard at level 1 / 0 XP. See badge.html, badge-effects.mp4 and dashboard-badge.png.
