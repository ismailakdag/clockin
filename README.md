# Clockin

A native time tracker for Mac and iPhone that shows what your work is earning while you do it.

- Clock in, pause, clock out, or start with time you already worked
- Live earnings with an hourly rate schedule and USD/TRY conversion
- Earnings history, heatmap, goals, level and badges
- Timecard import from CSV or pasted text, without duplicating entries
- Focus companion, focus chime and focus radio
- Eight themes

The two apps share the same data model, but each keeps its own data on its device. They do not sync.

## Mac

Lives in the menu bar, with a main window and an always-visible pinned timer. Keyboard shortcuts: ⌥⌘I clock in or resume, ⌥⌘P pause or resume, ⌥⌘O clock out, ⌥⌘E open the window.

Requires macOS 14.

```bash
chmod +x build-app.sh
./build-app.sh
open dist/Clockin.app
```

Data is stored at `~/Library/Application Support/Clockin/clockin.json`.

## iPhone

Adds home and lock screen widgets, a Live Activity with pause and clock out, and Shortcuts actions.

Requires Xcode and iOS 17. Build steps and the iPhone checks are in [`iOS/README.md`](iOS/README.md).

## Checks

Dependency-free checks for the Mac app, run from the repository root:

```bash
swiftc Sources/Clockin/Models.swift Sources/Clockin/CSVImporter.swift Sources/Clockin/PastedTextImporter.swift Tests/manual/main.swift -o /tmp/clockin-tests && /tmp/clockin-tests
swiftc Sources/Clockin/Models.swift Sources/Clockin/ClockStore.swift Sources/Clockin/CSVImporter.swift Sources/Clockin/PastedTextImporter.swift Sources/Clockin/ImportComparison.swift Tests/manual/store/main.swift -o /tmp/clockin-store-tests && /tmp/clockin-store-tests
swiftc Sources/Clockin/Models.swift Sources/Clockin/ClockStore.swift Sources/Clockin/CSVImporter.swift Sources/Clockin/PastedTextImporter.swift Sources/Clockin/ImportComparison.swift Tests/manual/save/main.swift -o /tmp/clockin-save-tests && /tmp/clockin-save-tests
swiftc Sources/Clockin/Models.swift Sources/Clockin/ClockStore.swift Sources/Clockin/CSVImporter.swift Sources/Clockin/PastedTextImporter.swift Sources/Clockin/ImportComparison.swift Tests/manual/reimport/main.swift -o /tmp/clockin-reimport-tests && /tmp/clockin-reimport-tests
swiftc -swift-version 6 Sources/Clockin/UpdateProgress.swift Tests/manual/update/main.swift -o /tmp/clockin-update-tests && /tmp/clockin-update-tests
```

Exchange rates come from the free [Frankfurter API](https://frankfurter.dev/).
