// From the repository root: bash Tests/manual/screens/run [theme]
// Opens each main-window screen in a throwaway window with sample data and
// writes a 2x PNG per screen to Tests/manual/screens/out/<theme>-<screen>.png.
// Process-only defaults keep the real preferences untouched.
import AppKit
import SwiftUI

// The snapshot compiler redirects explicit UserDefaults.standard references here;
// defaultAppStorage below also covers SwiftUI property wrappers. All writes stay
// in a volatile domain. The lock protects read-modify-write across callers.
final class ScreenDefaults: UserDefaults, @unchecked Sendable {
    static let suite = "Clockin.ScreenReview.\(UUID().uuidString)"
    static let shared = ScreenDefaults(suiteName: suite)!
    private let writeLock = NSRecursiveLock()

    override func set(_ value: Any?, forKey key: String) {
        writeLock.lock()
        defer { writeLock.unlock() }
        var values = volatileDomain(forName: UserDefaults.argumentDomain)
        values[key] = value
        setVolatileDomain(values, forName: UserDefaults.argumentDomain)
    }
    override func set(_ value: Bool, forKey key: String) { set(value as Any, forKey: key) }
    override func set(_ value: Int, forKey key: String) { set(value as Any, forKey: key) }
    override func set(_ value: Float, forKey key: String) { set(value as Any, forKey: key) }
    override func set(_ value: Double, forKey key: String) { set(value as Any, forKey: key) }
    override func set(_ value: URL?, forKey key: String) { set(value?.absoluteString as Any?, forKey: key) }
    override func removeObject(forKey key: String) { set(nil as Any?, forKey: key) }
}

let fixtureDirectory = FileManager.default.temporaryDirectory.appendingPathComponent("clockin-screens-data-\(UUID().uuidString)", isDirectory: true)
try! FileManager.default.createDirectory(at: fixtureDirectory, withIntermediateDirectories: true)
defer { try? FileManager.default.removeItem(at: fixtureDirectory) }

@MainActor
final class AppDependencies {
    static let shared = AppDependencies()
    let store = ClockStore(fileURL: fixtureDirectory.appendingPathComponent("dependencies/clockin.json"))
    let exchangeRates = ExchangeRateStore()
}

func spin(_ seconds: TimeInterval) { RunLoop.main.run(until: Date(timeIntervalSinceNow: seconds)) }

let themeName = CommandLine.arguments.dropFirst().first ?? "Carbon"
let theme = ClockinThemeChoice(rawValue: themeName) ?? .carbon
let now = Date()
let calendar = Calendar.current
ScreenDefaults.shared.setVolatileDomain([
    UIScale.key: Int(ProcessInfo.processInfo.environment["CLOCKIN_SCREEN_SCALE"] ?? "100") ?? 100, "Clockin.HistoryGroupByDay": true, "Clockin.HeatmapRange": "All", "Clockin.PinVisible": false, "Clockin.Theme": theme.rawValue, "Clockin.MascotEnabled": true, "Clockin.MascotDefault": "Auto",
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
let file = fixtureDirectory.appendingPathComponent("clockin.json")
try! JSONEncoder().encode(data).write(to: file)
let store = ClockStore(fileURL: file)
// Cover every requested UTC day, including today, so MainView.task returns
// without contacting a rate service or writing URLSession's disk cache.
let rateFormatter = DateFormatter()
rateFormatter.locale = Locale(identifier: "en_US_POSIX")
rateFormatter.timeZone = TimeZone(secondsFromGMT: 0)
rateFormatter.dateFormat = "yyyy-MM-dd"
let rateDays = sessions.map(\.start) + [now]
let fixtureRates = Dictionary(rateDays.map { (rateFormatter.string(from: $0), 41.2) }, uniquingKeysWith: { first, _ in first })
ScreenDefaults.shared.set(try! JSONEncoder().encode(fixtureRates), forKey: "Clockin.USDTRYRates.v1")
ScreenDefaults.shared.set(now, forKey: "Clockin.USDTRYRatesUpdated.v1")
let rates = ExchangeRateStore()

let app = NSApplication.shared
app.setActivationPolicy(.accessory)
app.finishLaunching()

let output = URL(fileURLWithPath: ProcessInfo.processInfo.environment["CLOCKIN_SCREEN_OUTPUT"] ?? "Tests/manual/screens/out", isDirectory: true)
try? FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)

@MainActor func capture(_ name: String, _ view: some View, size: CGSize = CGSize(width: 390, height: 650), clickAt: CGPoint? = nil, scaleWindow: Bool = true) {
    if let filter = ProcessInfo.processInfo.environment["CLOCKIN_SCREEN_FILTER"],
       !filter.split(separator: ",").contains(Substring(name)) { return }
    let size = scaleWindow ? CGSize(width: S(size.width), height: S(size.height)) : size
    let root = view
        .defaultAppStorage(ScreenDefaults.shared)
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
    if let point = clickAt {
        let location = CGPoint(x: S(point.x), y: size.height - S(point.y))
        for type in [NSEvent.EventType.leftMouseDown, .leftMouseUp] {
            let event = NSEvent.mouseEvent(with: type, location: location, modifierFlags: [], timestamp: ProcessInfo.processInfo.systemUptime,
                windowNumber: window.windowNumber, context: nil, eventNumber: 0, clickCount: 1, pressure: 1)!
            window.sendEvent(event)
        }
        spin(0.5)
        guard let popover = app.windows.first(where: { $0 !== window && $0.isVisible && $0.className.contains("Popover") }),
              let content = popover.contentView,
              let popoverRep = content.bitmapImageRepForCachingDisplay(in: content.bounds) else {
            fatalError("\(name): date field did not open a popover")
        }
        content.cacheDisplay(in: content.bounds, to: popoverRep)
        let popoverURL = output.appendingPathComponent("\(theme.rawValue)-\(name)-popover.png")
        try! popoverRep.representation(using: .png, properties: [:])!.write(to: popoverURL)
        print("verified \(name): native picker popover opened")
        popover.orderOut(nil)
    }
    let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: Int(size.width * 2), pixelsHigh: Int(size.height * 2), bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
    rep.size = size
    hosting.cacheDisplay(in: hosting.bounds, to: rep)
    let url = output.appendingPathComponent("\(theme.rawValue.replacingOccurrences(of: " ", with: ""))-\(name).png")
    try! rep.representation(using: .png, properties: [:])!.write(to: url)
    print("wrote \(url.path) \(rep.pixelsWide)x\(rep.pixelsHigh)")
    if ProcessInfo.processInfo.environment["CLOCKIN_LAYER_CAPTURE"] != nil, let layer = hosting.layer {
        // Second opinion from the layer tree, to tell capture artifacts from real ones.
        let ctx = CGContext(data: nil, width: Int(size.width * 2), height: Int(size.height * 2), bitsPerComponent: 8, bytesPerRow: 0,
                            space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
        ctx.scaleBy(x: 2, y: 2)
        if hosting.isFlipped { ctx.translateBy(x: 0, y: size.height); ctx.scaleBy(x: 1, y: -1) }
        layer.render(in: ctx)
        let layerURL = url.deletingPathExtension().appendingPathExtension("layer.png")
        try! NSBitmapImageRep(cgImage: ctx.makeImage()!).representation(using: .png, properties: [:])!.write(to: layerURL)
    }
    window.orderOut(nil)
    window.contentView = nil
}

capture("history", HistoryView())
capture("heatmap", HeatmapView())
capture("progress", ProgressDashboardView())
capture("settings", SettingsView())
capture("settings-tall", SettingsView(), size: CGSize(width: 390, height: 2400))
capture("timer", MainView(), size: CGSize(width: 390, height: 1400))

// The actual sheet roots, at their production sizes, in real AppKit windows.
capture("rates", RateScheduleView(), size: CGSize(width: 390, height: 560))
let originalRule = store.rateRules[0]
store.updateRateRule(id: originalRule.id, effectiveFrom: originalRule.effectiveFrom, effectiveUntil: now, hourlyRate: originalRule.hourlyRate)
capture("rates-bounded", RateScheduleView(), size: CGSize(width: 390, height: 560))
store.updateRateRule(id: originalRule.id, effectiveFrom: originalRule.effectiveFrom, effectiveUntil: originalRule.effectiveUntil, hourlyRate: originalRule.hourlyRate)
capture("manual-entry", ManualEntryView(), size: CGSize(width: 390, height: 420))
capture("edit-entry", ManualEntryView(editing: sessions.last), size: CGSize(width: 390, height: 420))
capture("date-field", ManualEntryView(), size: CGSize(width: 390, height: 420), clickAt: CGPoint(x: 150, y: 154))
capture("time-field", ManualEntryView(), size: CGSize(width: 390, height: 420), clickAt: CGPoint(x: 120, y: 222))
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
    var values = ScreenDefaults.shared.volatileDomain(forName: UserDefaults.argumentDomain)
    values[key] = value
    ScreenDefaults.shared.setVolatileDomain(values, forName: UserDefaults.argumentDomain)
}
for (mode, width, height) in [("Compact", 246.0, 72.0), ("Money", 320.0, 112.0), ("Goal", 300.0, 116.0), ("All", 370.0, 230.0), ("Total", 340.0, 156.0)] {
    previewPreference("Clockin.PinnedMode", mode)
    capture("timer-pinned-\(mode.lowercased())", PinnedTimerView(), size: CGSize(width: width, height: height), scaleWindow: false)
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
precondition(ScreenDefaults.shared.persistentDomain(forName: ScreenDefaults.suite)?.isEmpty != false,
             "Screen preferences must never be persisted")
print("verified: preferences stayed process-only; session data and backups are isolated")
