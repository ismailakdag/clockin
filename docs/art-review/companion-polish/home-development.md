# Companion home refinement

Implemented on `ios/companion-art-polish` and uploaded as 0.2 (3); see `build-0.2-3.md` for distribution status. No commit or push.

## Implementation sequence

1. Room art: shallow side walls, a deeper floor, joinery and contact shadows. Furniture was fitted to distinct zones. The new companion bed brings the home catalog to 17 furnishings and the complete catalog to 51 items.
2. Decoration: every room and furnishing opens a reversible preview, including unaffordable items. Preview lighting, activity, lamp and layout stay local until choosing. Purchase checks run again before charging. Both Desk left and Desk right mirror the room and furniture together.
3. Companion behavior: an active session with a desk places the companion at the desk. An idle or paused companion can sit on the bean bag. A tired companion, or a paused session lasting at least four hours, can rest in the bed. An active session never selects sleep. Missing furniture falls back to the standing area. While sleeping, the head rests above the bedding and the outfit remains saved for waking.
4. Atmosphere: daytime, evening and night window tint and light; a saved lamp switch; gentle plant sway and coffee steam. Core Animation drives ambient movement without a per-frame SwiftUI timer. Offscreen, inactive, Reduce Motion, low-power and thermal restrictions use the shared animation policy. The clock updates once per minute only while the room is visible and active.

## Verification

- All 29 iPhone and 13 Mac README check groups passed.
- The expanded wardrobe group passed 1,421 checks. These cover old-save migration, layout and lamp persistence, locked preview isolation, insufficient funds, repeat purchase prevention, activity selection, all hourly light boundaries, mirrored furniture and companion bounds, and non-overlapping furniture zones in every room. The rug is intentionally allowed beneath furniture.
- The source-art contract passed: 25 accessories, 63 animation frames, three fixed poses, six colorways, three rooms and 17 furnishings.
- The generic iOS Simulator app and widget build passed. Fresh wardrobe checks and builds were repeated after final visual adjustments.
- Static production-compositor proofs cover four activities across three rooms in both layouts, 24 compositions. `home-development.png` presents four examples. These are offline compositions, not app screenshots, and do not prove the dynamic lighting or live animation behavior.

## Remaining live review

Device Hub window access repeatedly timed out. Real navigation, cancel/buy taps, scrolling visibility, background/resume, Reduce Motion transitions and ambient animation performance remain unverified in the running app. This limitation is not treated as a passing UI test.
