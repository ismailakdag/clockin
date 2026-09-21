# Compact shop and orbit celebration

Changes after TestFlight 0.2 (3), now uploaded as 0.2 (4). See `build-0.2-4.md` for distribution status.

- Product thumbnails reduced from 82pt tall to a 44pt square. Adaptive cards use a 96pt minimum width, or 150pt with accessibility text sizes. The main companion preview is smaller.
- Every item opens a try-first sheet, including locked clothing and colors. Draft appearance is passed to the existing animated mascot renderer without changing ownership, equipment or coins. Previews also work when the companion is hidden elsewhere.
- The purchase action stays at the bottom of the sheet. A successful purchase keeps the preview open with a Purchased confirmation, the item name, a Done button and a VoiceOver announcement. Choosing already-owned items does not charge again. Home options are tucked into an expandable section.
- Level celebrations use a dark space scene, a vector astronaut with the companion face, an orbit trail and planet horizon. The finite arrival animation respects animation policy, Reduce Motion and companion visibility. There is no continuous particle or display timer. Continue and Share remain explicit actions.

## Verification

- All 29 iPhone README check groups passed. Default compiler caches were redirected to a writable temporary path where necessary.
- The wardrobe group passed 1,514 checks, including draft isolation and selected appearance for every clothing item and colorway, insufficient funds and repeat-purchase protection.
- Final generic iOS Simulator build passed without warnings or errors. Project version and signing settings were unchanged.
- `git diff --check` passed.
- The images in this folder are offline SwiftUI composition proofs of the production card components, rendered on macOS with the actual artwork. They are not screenshots from a running iPhone. They verify static composition only, not animation, iOS Dynamic Type or touch interaction.
- Device Hub control timed out. Live try/cancel/buy, VoiceOver announcement, large iOS text, short landscape layout and animation performance still need running-device acceptance.

## Device acceptance

Open Companion, compare the compact Outfit/Home/Shop grids, and tap a locked item. Cancel and verify appearance and balance are unchanged. Buy an affordable item, verify the Purchased confirmation and one deduction, close, reopen and choose the owned item without another deduction. Preview a colorway with other accessories equipped. Verify milestone-only and unaffordable items can be previewed but cannot be bought. Cross a level with synthetic sessions and check Continue, Share, Reduce Motion, background/resume, large text and companion-hidden mode.
