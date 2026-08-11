# Clockin for macOS

A native SwiftUI menu-bar time tracker with pause/resume, hourly earnings, a floating always-visible timer, local persistence, and CSV timesheet import.

Double-clicking the app opens a regular Clockin window. Closing it keeps the menu-bar timer running; opening the app again brings the window back.

## Build and run

```bash
chmod +x build-app.sh
./build-app.sh
open dist/Clockin.app
```

Run the dependency-free validation suite with:

```bash
swiftc Sources/Clockin/Models.swift Sources/Clockin/CSVImporter.swift Sources/Clockin/PastedTextImporter.swift Tests/manual/main.swift -o /tmp/clockin-tests
/tmp/clockin-tests
```

The optional live API check is:

```bash
swiftc -parse-as-library Sources/Clockin/ExchangeRates.swift Tests/manual/exchange.swift -o /tmp/clockin-exchange-test
/tmp/clockin-exchange-test
```

Clockin lives in the macOS menu bar. Data is stored locally at:

```text
~/Library/Application Support/Clockin/clockin.json
```

CSV imports recognize the `Start Time`, `End Time`, `Duration`, `Notes`, and `Time Sheet Source` columns used by the supplied export.

Approved entries that are unavailable as CSV can be copied from the timecard page and pasted with **Paste approved timecards**. Both one-row and full-page copies are supported. Imports deduplicate by start time, end time, and duration across both formats.

Use **Start with elapsed time** to continue a timer from manually entered hours and minutes. An active timer can be cancelled without adding earnings, and completed/imported sessions can be deleted from **Earnings History**. Imported external entries within 90 seconds of a Clockin entry are marked as matched instead of duplicated.

The pinned widget has **Compact** and **Money** modes in Pay & Data and can also be resized from its edges. Money mode shows live USD earnings, the current TRY equivalent, and precise per-second USD/TRY momentum. The main timer adds the same earning velocity plus progress toward the next 10-unit earnings milestone.

Five live-switching themes are available: **Carbon**, **Neon Orange**, **Electric Blue**, **Synthwave**, and **Data Dense**. The USD/TRY card distinguishes an API-verified check from a cached value or an unavailable service. Paste preview separately reads the page's Approved summary and warns when the visible copied rows cover only part of that total.

Themes also change typography: rounded Carbon, terminal-style Neon Orange, clean Electric Blue, serif-display Synthwave, and monospace Data Dense. The optional **10-minute focus beep** is off by default, pauses with the timer, and can be previewed from Pay & Data.

Focus chimes can use Glass, Ping, Pop, Tink, Funk, Submarine, or Sosumi, with an independent 10–100% volume slider. The default is Glass at 75%.

Hourly earnings use an effective-date rate schedule. The initial rule applies the current rate from July 1, 2026 onward; earlier sessions retain their stored rate until an earlier override rule is added. Editing a rule immediately recalculates totals, daily charts, session earnings, USD values, and TRY conversions. Daily chart bars reserve top headroom and expose date, worked duration, USD, historical TRY, and exchange rate on hover.

The main dashboard stays focused on tracking; rate, theme, pin, import, and sound controls live on a separate gear-button Settings screen. Focus chime intervals are configurable from 1 to 120 minutes. Earnings history initially renders 30 sessions and safely expands with Show all / Show recent. All-time duration and earnings include the live session continuously; cancelling removes that contribution, while clocking out transfers it to completed history without changing the total.

USD/TRY data comes from the free, keyless [Frankfurter API](https://frankfurter.dev/) and is cached locally. Historical charts use the published rate for each day (or the previous available business-day rate).
