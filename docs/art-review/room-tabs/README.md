# Room sizing and category tabs

Local changes after TestFlight 0.2 (5), not uploaded.

The catalog header used a fixed 196-point height while the room canvas is 360 by 240. Its fit scale left 38-point side bars in a 370-point-wide card. Room cards now use the artwork aspect ratio in both the catalog and item preview. Outfits retain their compact fixed-height preview. The canvas and furniture anchors are unchanged.

Categories are visible horizontal tabs with icons, a selected outline, 44-point minimum tap height and accessibility selection traits. Selecting a category brings its tab into view. Existing categories, item filtering and purchases are unchanged.

## Verification

- Release generic iOS Simulator app and widget build passed without warnings.
- Existing wardrobe integration suite passed 2,076 checks.
- Before/after composition renders were inspected at 320, 393 and 844-point widths; a 440-point render is also included. They use the production frame modifier and category tabs with the actual room artwork. These are desktop SwiftUI renders, not live iPhone screenshots, and omit furniture and the companion to isolate framing.
- iPhone touch navigation and Dynamic Type remain unverified. No new TestFlight upload.
