# Screen review

Run from the repository root:

```bash
bash Tests/manual/screens/run Carbon
bash Tests/manual/screens/run Daylight
```

Each run captures 35 states in real AppKit windows at 100% UI scale by default. Main screens are 390 pt wide; the menu bar panel is 320 pt. The output includes the original settings captures, all requested sheets, Progress sections, History session rows, Heatmap ranges, and running/paused/idle timer and panel states.

The harness uses a unique temporary directory for sessions and backups, a complete in-memory exchange-rate fixture, and process-only preferences. Both explicit defaults access in the source snapshots and SwiftUI AppStorage use ScreenDefaults, whose setters only update a volatile domain. It snapshots the source files before compiling, so simultaneous editing does not invalidate the compilation. `ProgressDashboardView(initialTab:)` selects a preview section; production still starts at Overview.

Optional environment variables:

- `CLOCKIN_SCREEN_SCALE=150`: render at 100, 115, 130 or 150% (including main/panel host windows and click coordinates; pinned hosts retain their production preset dimensions).
- `CLOCKIN_SCREEN_OUTPUT=/tmp/clockin-screens`: alternate output directory.
- `CLOCKIN_SCREEN_FILTER=progress-badges,heatmap-month`: recapture selected states.
