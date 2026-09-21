# Companion 3D prototype

A procedural RealityKit scene for look development, available on iOS 18 and later under **Companion > Try the 3D companion**. It includes a wooden room, rounded robot, desk, laptop, cup, lamp, plant, shelf, and circular window.

Controls switch between Classic, Beanie and Wings; Hello, Focus and Celebrate; warm lamp on/off; and a bounded camera orbit. The scene uses its own local state and does not read or write wardrobe ownership, coins, work sessions or purchases. Existing 2D companion surfaces remain unchanged.

The preview uses a virtual camera with `ARView.cameraMode = .nonAR`, automatic AR session configuration disabled, and no device camera request. See [Apple's virtual camera documentation](https://developer.apple.com/documentation/realitykit/perspectivecamera).

## Verification

- Debug and Release generic iOS Simulator builds pass without warnings.
- The scene runs in the dedicated art-review simulator.
- 161 opt-in runtime smoke checks pass across repeated outfit/pose switches, attachment parents, finite bounds, ground clearance, camera limits/reset, lamp state and a stable entity count (162).
- [Wings and celebration](wings-celebration.png) and [beanie and focus from another angle](beanie-focus.png) are actual simulator screenshots, not generated concept art.
- Smooth curves use one mesh each rather than a cylinder per curve segment. The scene owner persists across SwiftUI updates. The render view is removed while inactive or dismissed, and its animations and anchors are cleaned up. Pose transitions are finite and honor Reduce Motion.
- Device Hub UI automation timed out. States were selected with debug launch arguments; gesture delivery, modal dismissal, and control taps were not manually exercised. Physical-device frame rate, energy use, memory and thermal performance remain unmeasured.
- No TestFlight upload, commit, push or PR was performed.

## Repeat locally

Choose an already booted disposable simulator from `xcrun simctl list devices booted`, then run:

```sh
iOS/Tools/preview-companion-3d.sh SIMULATOR_UDID --3d-wings --3d-celebrate
```

Other debug arguments: `--3d-beanie`, `--3d-focus`, `--3d-side`. The debug-only `--3d-checks` flag writes `Documents/companion-3d-checks.txt` inside that simulator app's container. The direct debug launch presents the preview as the root screen; its Done button has no presenting sheet in this mode. The normal Companion entry presents a dismissible full-screen sheet. Release builds do not include these launch routes or diagnostics.

## Scope

This is a functional prototype made from simple meshes, not finished sculpted character art. It does not reproduce the generated concept's textures, cloth, detailed furniture or lighting fidelity. Only the isolated preview uses 3D. A full migration, animated work cycles, production asset authoring, localization, widget snapshots and physical-device optimization are future work.
