# Room editor implementation plan

1. Persist per-room, per-item offsets in the existing wardrobe JSON. Missing or
   malformed arrangement data keeps the old layout. Backups already carry this JSON.
   Store coordinates in the canonical 360×240 room, so screen size and room direction
   do not change the saved arrangement.
2. Share placement bounds between live rooms, editing and render checks. Wall items
   stay within the wall and clear the window; furniture feet stay on the floor.
   Rugs can sit underneath furniture. A four-point grid snaps only when moving.
3. Add an explicit Edit room destination in Companion. Work on a local draft;
   dragging and reset never write defaults. Save merges only arrangement changes
   for that room, leaving coins, ownership and other rooms intact.
4. Select or drag equipped items. Show selection, placement feedback and small
   directional controls for precise/accessibility adjustments. Cancel discards the
   draft, reset restores the starting preset, and per-item reset fixes one object.
5. Keep bean-bag/bed pose anchors and lamp/steam effects attached to moved furniture.
6. Verify geometry, mirror transforms, collision feedback, legacy/backups and
   transactional saves; exercise actual pointer gestures in the available native
   review harness, then archive and distribute through the existing TestFlight flow.

First version preserves the current one-equipped-item-per-slot collection model.
The editor moves equipped decorations; item selection/purchases remain in Companion.

Implementation and verification completed for all six steps. Release evidence:
[iOS room editor build 23](ios-room-editor-build-23.md).
