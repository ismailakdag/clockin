# Companion artwork for 0.2 (3)

Based on `ios/wardrobe` at `37acc79`. Work lives on `ios/companion-art-polish`.

The existing robot identity is preserved. All 25 wardrobe sprites, 16 furniture sprites and three rooms were revised in the editable pixel drawing source. The drawings use a shared two-pixel grid, stepped material highlights, cool shadows and dark outlines. Clothing contours, handles, stitching and broad forms take priority over tiny decoration.

- Hats fit inside all animation poses, including the elevated celebration head.
- The mug handle meets the hand with the cup outside the face silhouette.
- Wings rise from the shoulders, and backpack side pockets remain visible behind the robot.
- Lamp and record-player options include a matching worktable instead of floating at the desk anchor.
- Room anchors separate the desk, wall storage, artwork and foreground items. Every item fits inside each room.
- Outfit has a larger close-up; Home retains the furnished room. Item thumbnails are taller.
- Existing ownership and item identifiers are preserved. The catalog now exposes all 50 authored items, including 19 previously unavailable options: 11 accessories and eight home items. The added options use focus coins; existing prices and milestone unlocks stay unchanged.
- Stretch, dance and music poses now carry the selected outfit. Occupied hands during the overhead stretch intentionally have no handheld item.
- The outfit close-up respects the companion visibility setting. Accessory celebration banners retain the current outfit and show the unlocked accessory.
- Outfit textures are decoded off the main actor and shared by static and animated views.

## Review images

- `overview.png`: four outfits and three furnished rooms.
- `home-before.png` and `home-after.png`: furnished room comparison. The after preview uses the app's 180-point mascot canvas; the old preview used a smaller canvas.
- `outfit-fit.png`: hats on four poses, with both large and small examples.
- `display-sizes.png`: static outfit compositions at 48, 62, 64, 72, 80 and 120 pixels, including all three fixed poses. This is an art review sheet, not an app screenshot.
- `fixed-pose2.png`, `fixed-pose3.png` and `fixed-pose4.png`: the runtime compositor output for stretch, dance and music poses.

Recreate the full sheets from the repository root using the existing `iOS/Tools/make-wardrobe-preview.swift` entry point. Source artwork lives in `iOS/Tools/MascotArt.swift`.

## Verification

All 13 Mac and 29 iPhone README-listed groups passed on the expanded catalog. The wardrobe group passed 940 checks, including catalog-to-art equality, real image composition and occupied-hand behavior. The art contract validates all 25 garments across 63 animation frames plus three fixed poses, including rotated bounds, the two-pixel grid, tight crops and furniture bounds in all three rooms. Initial compiler cache sandbox errors were resolved with a temporary module cache. The Mac rolling-text test required desktop service access and then passed all 20 checks.

The generic iOS Simulator build passed. App and widget bundles both contain the fixed-pose anchor manifest, wardrobe and home resources. The app was installed and launched on the isolated Clockin Art Review simulator with neutral fixtures. No archive or upload was performed.

### Appearance coverage

| Surface | Source/layout review | Static image review | Live interaction |
| --- | --- | --- | --- |
| Today companion card | 62-point canvas, 14-point card padding | Reviewed at 62 px | Pending |
| Outfit close-up | 260-point hero, 6-point inset, visibility setting | Large outfit sheet reviewed | Pending |
| Companion home | 180-point mascot in a 360 by 240 room, centered scaling | Three rooms and all 16 furniture options reviewed | Pending |
| Desk mode | 72-point companion or furnished room background | Reviewed at 72 px and room scale | Pending |
| Session summary | 64-point companion, 24-point content padding | Reviewed at 64 px | Pending |
| Celebration banner and level card | 48 and 120-point canvases | Reviewed at both sizes | Pending |
| Medium home-screen widget | 80-point companion, static outfit composition | Reviewed at 80 px; extension builds | Pending |
| Stretch, dance and music modes | New normalized anchors, shared outfit texture cache | Runtime compositor outputs reviewed | Pending |

The small and lock-screen widgets do not contain a companion in the current design. Their layouts were not expanded.

Live interaction review remains incomplete: Device Hub started, but access to its window repeatedly timed out. Actual navigation, equip/buy interactions, animation clearance and on-device performance still require a live pass. These changes remain local on `ios/companion-art-polish`, uncommitted, and have not been uploaded as TestFlight 0.2 (3).

## Proportion refinement

A second visual pass reduced 23 accessories individually around their attachment points. Bow ties and trophies are approximately 38 percent smaller, mugs 32 percent smaller, and backpacks 24 percent smaller. Glasses are narrower than the visor; hat widths were reduced independently from the height clearance required by celebration poses. Headphones and wings retain their fitted spans. The native two-pixel art grid is preserved.

`proportions-comparison.png` shows the previous proportions above the revised ones on the same robot canvas. All 25 accessories were visually reviewed on hello, working, coffee and celebration poses at large and small sizes. Runtime compositions were also regenerated for the three fixed poses.

Fresh validation after this change: 940 wardrobe checks passed; the art contract passed for 63 animation frames plus three fixed poses; the generic iOS Simulator build succeeded. All 25 decoded sprite images and the attachment manifest in both the app and widget match the source. This pass changes source art only; the earlier live interaction limitation remains. No upload was performed.

## Home development

The home refinement adds furniture previews, mirrored layouts, a companion bed, activity placement and restrained ambient motion. Current implementation and verification details are in `home-development.md`; the current overview is `home-development.png`. This supersedes the earlier static home sizing notes. Live interaction review remains pending and no upload has been performed.
