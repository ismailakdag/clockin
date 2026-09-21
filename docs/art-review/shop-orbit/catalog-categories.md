# Unified companion catalog

Uploaded in TestFlight 0.2 (5). See `build-0.2-5.md` for checks and distribution status.

The Outfit, Home and Shop tabs are replaced by one catalog. A category menu filters the catalog; All categories displays grouped sections. Each product appears exactly once, regardless of ownership or unlock method.

Categories: Headwear, Eyewear, Neck accessories, Back accessories, Handheld items, Colors, Rooms, Furniture, Plants, Lighting and Decorations. Furniture placement slots stay internal and do not become shopping categories. The header preview switches to outfit or room according to the selected category.

Room layout and lamp settings remain available in an expandable Room settings section. Removing equipped items and restoring the classic color now happen in the item's preview, next to the existing choose action. Rooms retain the existing choose-another-room behavior.

Verification: 1,518 wardrobe checks passed, including complete category coverage, no duplicates, no empty categories and correct outfit/home preview classification. Generic iOS Simulator build passed without warnings. `git diff --check` passed. Live phone navigation and visual acceptance have not been verified for this change.
