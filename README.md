# Clockin

A native time tracker for Mac and iPhone that shows what your work is earning while you do it.

- Clock in, pause, clock out, or start with time you already worked
- Live earnings with an hourly rate schedule and USD/TRY conversion
- Earnings history, heatmap, goals, level and badges
- Timecard import from CSV or pasted text, without duplicating entries
- Focus companion, focus chime and focus radio
- Eight themes

The two apps share the same data model, but each keeps its own data on its device. They do not sync.

## Download for Mac

Get the signed, Apple-notarized installer from the [Clockin website](https://getclockin.netlify.app) or [GitHub Releases](https://github.com/ismailakdag/clockin/releases). Supports macOS 14 or later on Apple Silicon and Intel.

Open the DMG, drag Clockin into Applications, and open it there. If you open it straight from the DMG or from Downloads, Clockin offers to move itself to Applications. Future versions are installed through **Check for Updates…** inside Clockin. No Git, Xcode or Terminal is needed. Existing work history stays in place.

Each packaged Mac version's matching source is tagged `macos-v<version>`, for example [macos-v1.1.4](https://github.com/ismailakdag/clockin/tree/macos-v1.1.4). The instructions below are for building from source.

## Mac

Lives in the menu bar. The icon opens a panel with the timer and clock-in controls, over full-screen apps too, and there is a main window and an always-visible pinned timer. Keyboard shortcuts: ⌥⌘I clock in or resume, ⌥⌘P pause or resume, ⌥⌘O clock out, ⌥⌘E open the window.

Requires macOS 14. The packaged app supports both Apple Silicon and Intel.

Installations built from source need to install the packaged app once (see [Download for Mac](#download-for-mac)); work history stays in place. Releases are published with one command, `scripts/publish-mac.sh <version>`; setup, packaging and verification are documented in [Mac releases](docs/macos-releases.md).

For development, with Xcode installed:

```bash
./script/build_and_run.sh --verify
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
swiftc -swift-version 6 Sources/Clockin/Models.swift Sources/Clockin/ClockStore.swift Sources/Clockin/CSVImporter.swift Sources/Clockin/PastedTextImporter.swift Sources/Clockin/ImportComparison.swift Tests/manual/sessions/main.swift -o /tmp/clockin-sessions-tests && /tmp/clockin-sessions-tests
swiftc -swift-version 6 Sources/Clockin/ApplicationMover.swift Tests/manual/mover/main.swift -o /tmp/clockin-mover-tests && /tmp/clockin-mover-tests
swiftc -swift-version 6 Sources/Clockin/Models.swift Sources/Clockin/MenuBarStatus.swift Tests/manual/menubar/main.swift -o /tmp/clockin-menubar-tests && /tmp/clockin-menubar-tests
swiftc -swift-version 6 Sources/Clockin/MenuBarIcon.swift Tests/manual/menubaricon/main.swift -o /tmp/clockin-menubaricon-tests && /tmp/clockin-menubaricon-tests
swiftc -swift-version 6 Sources/Clockin/Models.swift Sources/Clockin/MenuBarStatus.swift Sources/Clockin/MenuBarIcon.swift Sources/Clockin/MenuBarController.swift Tests/manual/menubarpanelhost/main.swift -o /tmp/clockin-menubarpanelhost-tests && /tmp/clockin-menubarpanelhost-tests
bash Tests/manual/menubarpanel/render
swiftc -swift-version 6 Sources/Clockin/MascotMotion.swift Tests/manual/mascotmotion/main.swift -o /tmp/clockin-mascotmotion-tests && /tmp/clockin-mascotmotion-tests
swiftc -swift-version 6 Tests/manual/mascotassets/main.swift -o /tmp/clockin-mascotassets-tests && /tmp/clockin-mascotassets-tests
bash Tests/manual/mascotview/run
```

Exchange rates come from the free [Frankfurter API](https://frankfurter.dev/).

## License

Clockin is available under the [MIT License](LICENSE). Development continues on GitHub; packaged Mac releases and their matching source are published with `macos-v*` tags.
