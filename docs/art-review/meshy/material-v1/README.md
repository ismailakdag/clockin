# Happy Robot material v1 — 2026-09-19

Source: Meshy_AI_Happy_Robot_0918202115_texture.glb, original selected texture.

The GLB contains 632,548 triangles and 337,268 exported vertices. All original binary payload bytes are retained: geometry, indices, UVs, normals and three 2048px JPEG texture maps. No texture generation or painting was performed.

Changes: conservative orange selection sampled from the base-color atlas adds a standard glTF COLOR_0 vertex multiplier. Full-strength tint is linear RGB [1, 0.5, 0.35], smoothly reduced near low-saturation boundaries. White and cyan regions are excluded by the selection. Material roughness factor 0.8, normal scale 0.22, metallic factor 0, KHR_materials_specular factor 0.55. These reduce surface noise and strengthen orange while retaining the first texture design.

This is a review variant, not a mobile-ready asset. It has no rig or animations. No app or TestFlight integration was performed. The original remains untouched. Fine color borders should be checked again after any future mesh simplification because this version uses vertex color.

Validation: front, side and back inspected in Three.js 0.180.0 with synchronized cameras and identical studio lights. Both models loaded successfully. Binary-prefix equality and accessor identity verified; see validation.json for hashes.

Preview: run `python3 -m http.server 8768 --bind 127.0.0.1` in this directory and open http://127.0.0.1:8768. Dependencies are vendored locally. The preview uses ACES tone mapping; final appearance depends on the destination renderer and lighting. KHR_materials_specular support and COLOR_0 must be retained when converting to USDZ.

Reproduction: refine.py uses Python with numpy and Pillow only to sample the existing atlas; it does not edit images. Update the source path if necessary.
