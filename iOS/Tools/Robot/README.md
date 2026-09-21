# Clockin native 3D greeting

The Today companion card uses `ClockinRobotView` while idle, in Auto mode, with
Settings > Appearance > 3D greeting enabled (default off; experiment retained for possible later use). Existing 2D reactions
continue for working, paused, angry and celebration states and custom poses.

The 31,105-triangle source is the reviewed `animated-mobile-v3.glb` from the
companion art workspace, SHA256
`bb9b9fdfd3b8c8fd1cb16e94b9bfce0d9d6d9fa9be89780ecf00af0560b30aa6`.
The app bundles `ClockinRobot.scn` (about 8.6 MB), including the original texture
layout, orange vertex tint, skin and corrected wave. GLB and conversion libraries
are not runtime dependencies. Only the reviewed wave clip is included.

## Conversion

`convert.m` uses the official GLTFKit2 0.5.15 macOS framework, downloaded from
https://github.com/warrenm/GLTFKit2/releases/tag/0.5.15 . The release XCFramework
zip SHA256 is `9d0c338282acce4986494aa02a5f1495278f56c60d43f31453fefea6875b4928`.

Compile with clang, Foundation, SceneKit and the framework's macOS `-F` path;
set the same path as linker rpath. Run the resulting executable with the input
GLB and output SCN paths. The importer shifts the source wave's nonzero first
time to zero (duration about 4.167 seconds). Channels are attached to their
individual bones: root-relative animation paths did not play after archiving.
The first track values are stored as the static pose for Reduce Motion.

Validate the exported scene from the repository root:

```sh
swift -module-cache-path /tmp/clockin-swift-cache iOS/Tools/Robot/validate.swift iOS/Clockin/Resources/Robot/ClockinRobot.scn
```

## Playback and verification

Native SceneKit, transparent background, 30 FPS, no network. Animation/rendering
pause while the page is inactive, app is backgrounded, Reduce Motion is enabled,
or Low Power Mode is enabled. The renderer is torn down when removed. Failed
scene loading falls back to the existing 2D companion. A tap restarts the wave.

Verified on 2026-09-19:
- iPhone Simulator Debug build succeeds.
- Signed generic iOS Debug build succeeds with the existing development team.
- Native scene validation: 28 animated bones, one skin, 31,105 triangles,
  material and vertex colors present.
- Simulator Today screen shows the robot, and different captured poses confirm
  wave playback with separated feet.
- Physical device installation was blocked because the paired phone was locked.
  User chose to keep this change in the simulator; no device installation completed.
- No TestFlight upload. Device performance and Reduce Motion/Low Power UI behavior
  still need on-device verification; do not infer them from a simulator build.
