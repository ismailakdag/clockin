// From the repository root: bash Tests/manual/screens/run [theme]
// Opens each main-window screen in a throwaway window with sample data and
// writes a 2x PNG per screen to Tests/manual/screens/out/<theme>-<screen>.png.
// Process-only defaults (NSArgumentDomain) keep the real preferences untouched.
import AppKit
import SwiftUI

@MainActor
final class AppDependencies {
    static let shared = AppDependencies()
    let store = ClockStore(fileURL: FileManager.default.temporaryDirectory
        .appendingPathComponent("screens-deps-\(UUID().uuidString).json"))
    let exchangeRates = ExchangeRateStore()
}

func spin(_ seconds: TimeInterval) { RunLoop.main.run(until: Date(timeIntervalSinceNow: seconds)) }

let themeName = CommandLine.arguments.dropFirst().first ?? "Carbon"
let theme = ClockinThemeChoice(rawValue: themeName) ?? .carbon
let now = Date()
let calendar = Calendar.current
UserDefaults.standard.setVolatileDomain([
    UIScale.key: 100, "Clockin.HistoryGroupByDay": true, "Clockin.HeatmapRange": "All", "Clockin.PinVisible": false, "Clockin.Theme": theme.rawValue, "Clockin.MascotEnabled": true, "Clockin.MascotDefault": "Auto",
    "Clockin.GoalDailyHours": 8.0, "Clockin.GoalMonthlyHours": 160.0, "Clockin.MinimalMode": false,
    "Clockin.USDTRYRates.v1": try! JSONEncoder().encode(["2026-09-15": 41.2]),
], forName: UserDefaults.argumentDomain)

// Three weeks of sessions and a running one.
var data = ClockinData()
let start = calendar.date(byAdding: .day, value: -60, to: calendar.startOfDay(for: now))!
data.rateRules = [RateRule(effectiveFrom: start, hourlyRate: 25)]
data.currencyCode = "USD"
var sessions: [WorkSession] = []
for day in 0..<60 where day % 7 != 5 {
    let dayStart = calendar.date(byAdding: .day, value: day, to: start)!.addingTimeInterval(9 * 3600)
    let hours = 2.5 + Double((day * 37) % 11) / 2
    sessions.append(WorkSession(id: UUID(), start: dayStart, end: dayStart.addingTimeInterval(hours * 3600),
                                duration: hours * 3600, note: day % 3 == 0 ? "Client work" : "", hourlyRate: 25, source: "manual"))
}
data.sessions = sessions
data.running = RunningSession(start: now.addingTimeInterval(-4062), accumulated: 4062, resumedAt: now, note: "")
let file = FileManager.default.temporaryDirectory.appendingPathComponent("screens-\(UUID().uuidString).json")
try! JSONEncoder().encode(data).write(to: file)
let store = ClockStore(fileURL: file)
let rates = ExchangeRateStore()

let app = NSApplication.shared
app.setActivationPolicy(.accessory)
app.finishLaunching()

let output = URL(fileURLWithPath: ProcessInfo.processInfo.environment["CLOCKIN_SCREEN_OUTPUT"] ?? "Tests/manual/screens/out", isDirectory: true)
try? FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)

@MainActor func capture(_ name: String, _ view: some View, size: CGSize = CGSize(width: 390, height: 650)) {
    if let filter = ProcessInfo.processInfo.environment["CLOCKIN_SCREEN_FILTER"],
       !filter.split(separator: ",").contains(Substring(name)) { return }
    let root = view
        .environmentObject(store).environmentObject(rates)
        .environmentObject(RadioController.shared).environmentObject(UpdateChecker.shared)
        .frame(width: size.width, height: size.height)
        .background(theme.palette.background)
        .preferredColorScheme(theme.palette.colorScheme)
        .environment(\.locale, Locale(identifier: "en_US"))
    let window = NSWindow(contentRect: NSRect(origin: CGPoint(x: 60, y: 60), size: size), styleMask: [.borderless], backing: .buffered, defer: false)
    window.appearance = NSAppearance(named: theme.palette.colorScheme == .dark ? .darkAqua : .aqua)
    let hosting = NSHostingView(rootView: root)
    window.contentView = hosting
    window.orderFrontRegardless()
    spin(1.5)
    let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: Int(size.width * 2), pixelsHigh: Int(size.height * 2), bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
    rep.size = size
    hosting.cacheDisplay(in: hosting.bounds, to: rep)
    let url = output.appendingPathComponent("\(theme.rawValue.replacingOccurrences(of: " ", with: ""))-\(name).png")
    try! rep.representation(using: .png, properties: [:])!.write(to: url)
    print("wrote \(url.path) \(rep.pixelsWide)x\(rep.pixelsHigh)")
    window.orderOut(nil)
}

capture("history", HistoryView())
capture("heatmap", HeatmapView())
capture("progress", ProgressDashboardView())
capture("settings", SettingsView())
capture("settings-tall", SettingsView(), size: CGSize(width: 390, height: 2400))
capture("timer", MainView(), size: CGSize(width: 390, height: 1400))

// The actual sheet roots, at their production sizes, in real AppKit windows.
capture("rates", RateScheduleView(), size: CGSize(width: 390, height: 560))
capture("manual-entry", ManualEntryView(), size: CGSize(width: 390, height: 420))
capture("edit-entry", ManualEntryView(editing: sessions.last), size: CGSize(width: 390, height: 420))
capture("manual-start", ManualStartView(), size: CGSize(width: 390, height: 420))
capture("session-summary", SessionSummaryView(session: sessions.last!), size: CGSize(width: 350, height: 340))
capture("share", ShareStatsView())
capture("paste-import", PasteImportView(), size: CGSize(width: 390, height: 480))
let imported = [WorkSession(id: UUID(), start: now.addingTimeInterval(-7200), end: now.addingTimeInterval(-3600), duration: 3600, note: "Client review", hourlyRate: 25, source: "CSV")]
capture("import-comparison", ImportComparisonView(sessions: imported + Array(sessions.suffix(2)), sourceTitle: "Timesheet CSV", onImported: {}), size: CGSize(width: 390, height: 560))
capture("guide", GuideView(), size: CGSize(width: 390, height: 670))
let panelActions = MenuBarPanelActions(openApp: {}, close: {}, checkForUpdates: {}, quit: {})
capture("menubar", MenuBarPanelView(actions: panelActions), size: CGSize(width: 320, height: 380))
// Volatile preferences and initializer fixtures cover secondary screen states.
func previewPreference(_ key: String, _ value: Any) {
    var values = UserDefaults.standard.volatileDomain(forName: UserDefaults.argumentDomain)
    values[key] = value
    UserDefaults.standard.setVolatileDomain(values, forName: UserDefaults.argumentDomain)
}
previewPreference("Clockin.HistoryGroupByDay", false)
capture("history-sessions", HistoryView(), size: CGSize(width: 390, height: 1100))
previewPreference("Clockin.HistoryGroupByDay", true)
for (index, section) in ["Badges", "Records", "Weekly", "Reports"].enumerated() {
    capture("progress-\(section.lowercased())", ProgressDashboardView(initialTab: index + 1))
}
previewPreference("Clockin.HeatmapRange", "Week")
capture("heatmap-week", HeatmapView())
previewPreference("Clockin.HeatmapRange", "Month")
capture("heatmap-month", HeatmapView())
previewPreference("Clockin.HeatmapRange", "All")
// Additional dashboard and panel states never affect the user's store.
store.pause()
capture("timer-paused", MainView())
capture("menubar-paused", MenuBarPanelView(actions: panelActions), size: CGSize(width: 320, height: 380))
store.cancelRunning()
capture("timer-idle", MainView())
capture("menubar-idle", MenuBarPanelView(actions: panelActions), size: CGSize(width: 320, height: 240))
try? FileManager.default.removeItem(at: file)
