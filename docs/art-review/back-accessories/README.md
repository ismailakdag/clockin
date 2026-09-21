# Back accessory visibility

The raised-arm silhouette hid most of the original wings. Compact back items also disappeared behind side-facing sitting and working poses.

Wings now spread below the raised forearms. Backpack, jetpack and cape fitting includes authored offsets for working, coffee and fixed side poses. All back items retain their rear layer so they do not cover the robot's face or torso. Animation and still/widget composition share this placement through `WardrobeArt.overlays`.

The generator and preview renderer preserve the same fitting metadata. The two proof boards use the production compositor, real frame PNGs and wardrobe assets. They are offline renders, not device screenshots or live animation recordings.

Columns: wings, cape, backpack, jetpack. Rows: angry raised arms, celebration, working, coffee.

- [Before](before.png)
- [After](after.png)

## Verification

- Regression check failed on the original angry wings: only 11.6% of the accessory was visible.
- After the change, 67.7% remains visible in that pose, with both wings exposed.
- 2,076 wardrobe checks pass. Visibility coverage includes all 59 motion frames and three fixed poses, rear-layer preservation, and minimum exposure on both wings.
- Art contract passes for all 25 garments, including full canvas bounds with pose offsets, 2x2 pixel cells and tight crops. Also verifies 63 frame anchors, six colorways, three rooms and 17 home items.
- iOS Simulator Debug build succeeds for app and widget, without warnings.
- Live device animation has not been verified. Uploaded in TestFlight 0.2 (5); see `../shop-orbit/build-0.2-5.md` for distribution status.
