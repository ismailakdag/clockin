// Exact command from repository root: bash Tests/manual/menubarpanel/render
// Compiles real app sources without ClockinApp / its entry point. Never starts the app.
// ImageRenderer uses a solid theme background and a static ellipsis for the native Menu.
// The mascot, button styles, and progress bar are real production content.
// NSArgumentDomain supplies process-only defaults, so no real Clockin preferences change.
import AppKit
import SwiftUI

@MainActor
final class AppDependencies {
    static let shared = AppDependencies()
    let store = ClockStore(fileURL: FileManager.default.temporaryDirectory
        .appendingPathComponent("unused-panel-\(UUID().uuidString).json"))
    let exchangeRates = ExchangeRateStore()
}

var passed = 0
@MainActor func check(_ condition: Bool, _ message: String) {
    precondition(condition, message)
    passed += 1
}

let temporary = FileManager.default.temporaryDirectory.appendingPathComponent("panel-fixtures-\(UUID().uuidString)")
try FileManager.default.createDirectory(at: temporary, withIntermediateDirectories: true)
defer { try? FileManager.default.removeItem(at: temporary) }
// Rendering uses current wall time, so keep the running offset relative to it.
let current = Date()
let todayStart = Calendar.current.startOfDay(for: current)
let sessionEnd = min(current, todayStart.addingTimeInterval(3 * 3600))
let sessionStart = todayStart
let defaults = UserDefaults.standard
let cachedRates = try JSONEncoder().encode(["2026-09-15": 41.2])
defaults.setVolatileDomain([
    UIScale.key: 100,
    "Clockin.Theme": "Carbon", "Clockin.MascotEnabled": true,
    "Clockin.MascotDefault": "Auto", "Clockin.GoalDailyHours": 8.0,
    "Clockin.MinimalMode": false, "Clockin.USDTRYRates.v1": cachedRates
], forName: UserDefaults.argumentDomain)
let rates = ExchangeRateStore()
let radio = RadioController()
let actions = MenuBarPanelActions(openApp: {}, close: {}, checkForUpdates: {}, quit: {})
var images: [CGImage] = []
var sizes: [CGSize] = []
let names = ["Idle", "Running", "Paused", "Daylight"]
for index in 0..<4 {
    let theme = index == 3 ? ClockinThemeChoice.daylight : .carbon
    let suite = UserDefaults(suiteName: "panel-preview-\(UUID().uuidString)")!
    suite.setVolatileDomain([
        UIScale.key: 100,
        "Clockin.Theme": theme.rawValue, "Clockin.MascotEnabled": true,
        "Clockin.MascotDefault": "Auto", "Clockin.GoalDailyHours": 8.0,
        "Clockin.MinimalMode": false
    ], forName: UserDefaults.argumentDomain)
    var data = ClockinData()
    data.rateRules = [RateRule(effectiveFrom: todayStart, hourlyRate: 25)]
    data.sessions = [WorkSession(id: UUID(), start: sessionStart, end: sessionEnd,
        duration: min(8100, sessionEnd.timeIntervalSince(sessionStart)), note: "Preview", hourlyRate: 25, source: "manual")]
    if index > 0 {
        data.running = RunningSession(start: current.addingTimeInterval(-4062), accumulated: 4062,
            resumedAt: index == 2 ? nil : current, note: "Preview")
    }
    let file = temporary.appendingPathComponent("\(index).json")
    try JSONEncoder().encode(data).write(to: file)
    let store = ClockStore(fileURL: file)
    let content = MenuBarPanelView(actions: actions, previewSolidBackground: true)
        .defaultAppStorage(suite)
        .environmentObject(store).environmentObject(rates)
        .environmentObject(radio).environmentObject(UpdateChecker.shared)
        .environment(\.colorScheme, theme.palette.colorScheme)
        .environment(\.locale, Locale(identifier: "en_US"))
    let renderer = ImageRenderer(content: content)
    renderer.scale = 2
    guard let image = renderer.cgImage else { fatalError("No image for \(names[index])") }
    let size = CGSize(width: CGFloat(image.width) / 2, height: CGFloat(image.height) / 2)
    check(size.width == 320, "\(names[index]) width must be 320 pt")
    check((160...520).contains(size.height), "\(names[index]) height out of range: \(size.height)")
    images.append(image)
    sizes.append(size)
    print("\(names[index]): \(Int(size.width)) × \(Int(size.height)) pt")
}
check(images[0].dataProvider?.data != images[1].dataProvider?.data, "Idle and running must differ")
// Clocking in or out must not resize the panel under the pointer.
check(Set(sizes.map(\.height)).count == 1, "Every state must be the same height: \(sizes.map(\.height))")
let tileHeight = ceil(sizes.map(\.height).max()!) + 44
let width = 688
let height = Int(tileHeight * 2 + 16)
let bitmap = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: width * 2, pixelsHigh: height * 2,
    bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
    colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
bitmap.size = NSSize(width: width, height: height)
NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: bitmap)
NSColor(calibratedWhite: 0.18, alpha: 1).setFill()
NSRect(x: 0, y: 0, width: width, height: height).fill()
for index in images.indices {
    let x = CGFloat(16 + (index % 2) * 336)
    let top = CGFloat(height) - 16 - CGFloat(index / 2) * tileHeight
    (names[index] as NSString).draw(at: NSPoint(x: x, y: top - 18), withAttributes: [
        .font: NSFont.systemFont(ofSize: 12, weight: .medium), .foregroundColor: NSColor.white
    ])
    NSImage(cgImage: images[index], size: sizes[index]).draw(in:
        NSRect(x: x, y: top - 28 - sizes[index].height, width: 320, height: sizes[index].height))
}
NSGraphicsContext.restoreGraphicsState()
let output = URL(fileURLWithPath: "Tests/manual/menubarpanel/preview.png")
try bitmap.representation(using: .png, properties: [:])!.write(to: output)
print("\(passed) menu bar panel checks passed")
