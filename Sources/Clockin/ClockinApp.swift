import AppKit
import SwiftUI

@MainActor
final class AppDependencies {
    static let shared = AppDependencies()
    let store = ClockStore()
    let exchangeRates = ExchangeRateStore()
}

@MainActor
final class ClockinAppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        DispatchQueue.main.async {
            let dependencies = AppDependencies.shared
            FocusChimeController.shared.start(store: dependencies.store)
            KeyboardShortcutController.shared.start(store: dependencies.store)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                if UserDefaults.standard.bool(forKey: "Clockin.MinimalMode") {
                    // A minimal-mode relaunch must not resurrect the floating pin.
                    dependencies.store.setPinned(false)
                } else {
                    MainWindowController.shared.show(store: dependencies.store, exchangeRates: dependencies.exchangeRates)
                    // SwiftUI can finish installing MenuBarExtra after the
                    // first presentation call. Re-present once the scene is
                    // settled so a launch can never end up windowless.
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.9) {
                        if !UserDefaults.standard.bool(forKey: "Clockin.MinimalMode") {
                            MainWindowController.shared.show(store: dependencies.store, exchangeRates: dependencies.exchangeRates)
                        }
                    }
                }
                Task { await dependencies.exchangeRates.refresh(sessionDates: dependencies.store.sessions.map(\.start)) }
            }
        }
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        let dependencies = AppDependencies.shared
        MainWindowController.shared.show(store: dependencies.store, exchangeRates: dependencies.exchangeRates)
        return true
    }
}

@main
@MainActor
struct ClockinApp: App {
    @NSApplicationDelegateAdaptor(ClockinAppDelegate.self) private var appDelegate
    @StateObject private var store: ClockStore
    @StateObject private var exchangeRates: ExchangeRateStore
    @StateObject private var radio: RadioController
    @AppStorage("Clockin.MinimalMode") private var minimalMode = false

    init() {
        let dependencies = AppDependencies.shared
        _store = StateObject(wrappedValue: dependencies.store)
        _exchangeRates = StateObject(wrappedValue: dependencies.exchangeRates)
        _radio = StateObject(wrappedValue: RadioController.shared)
    }

    var body: some Scene {
        MenuBarExtra {
            Button("Open Clockin") {
                MainWindowController.shared.show(store: store, exchangeRates: exchangeRates)
            }
            Divider()
            if minimalMode {
                Text("MINIMAL MENU BAR MODE")
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                Divider()
            }
            if store.running == nil {
                Button("Clock in") { store.clockIn() }
            } else if store.running?.isPaused == true {
                Button("Resume") { store.resume() }
            } else {
                Button("Pause") { store.pause() }
            }
            if store.running != nil {
                Button("Clock out") { _ = store.clockOut() }
                Button("Cancel session", role: .destructive) { store.cancelRunning() }
            }
            if radio.isPlaying {
                Divider()
                Button("Stop focus radio") { radio.stop() }
            }
            Divider()
            if !minimalMode {
                Button(store.pinVisible ? "Hide pinned timer" : "Show pinned timer") {
                    store.setPinned(!store.pinVisible)
                }
            }
            Button(minimalMode ? "Exit minimal mode" : "Use minimal menu bar mode") {
                minimalMode.toggle()
                if minimalMode {
                    UserDefaults.standard.set(store.pinVisible, forKey: "Clockin.PinVisibleBeforeMinimal")
                    NSApp.setActivationPolicy(.accessory)
                    store.setPinned(false)
                    MainWindowController.shared.hide()
                } else {
                    let shouldRestorePin = UserDefaults.standard.object(forKey: "Clockin.PinVisibleBeforeMinimal") as? Bool ?? true
                    UserDefaults.standard.removeObject(forKey: "Clockin.PinVisibleBeforeMinimal")
                    MainWindowController.shared.show(store: store, exchangeRates: exchangeRates)
                    store.setPinned(shouldRestorePin)
                }
            }
            Button("Quit Clockin") { NSApp.terminate(nil) }
        } label: {
            MenuBarStatusLabel(store: store, exchangeRates: exchangeRates)
        }
        .menuBarExtraStyle(.menu)
    }
}

private struct MenuBarStatusLabel: View {
    @ObservedObject var store: ClockStore
    @ObservedObject var exchangeRates: ExchangeRateStore
    @AppStorage("Clockin.MinimalMode") private var minimalMode = false
    @AppStorage("Clockin.MinimalShowHours") private var showHours = true
    @AppStorage("Clockin.MinimalShowEarnings") private var showEarnings = true
    @AppStorage("Clockin.MinimalShowTRY") private var showTRY = true
    @AppStorage("Clockin.MinimalShowGoal") private var showGoal = false
    @AppStorage("Clockin.GoalDailyHours") private var dailyGoalHours = 0.0
    @AppStorage("Clockin.GoalMonthlyHours") private var monthlyGoalHours = 0.0
    @State private var now = Date()
    private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: store.running?.isPaused == true ? "pause.circle.fill" : (store.running == nil ? "timer" : "timer.circle.fill"))
            if minimalMode {
                Text(status(at: now))
                    .font(.system(size: 10, weight: .semibold, design: .monospaced))
                    .lineLimit(1)
            } else {
                Text("Clockin")
                    .font(.system(size: 10, weight: .semibold, design: .rounded))
            }
        }
        .onReceive(timer) { now = $0 }
    }

    private func status(at date: Date) -> String {
        let elapsed = store.running != nil ? store.elapsed(at: date) : store.todayDuration(at: date)
        let earnings = store.running != nil ? store.currentEarnings(at: date) : store.todayEarnings(at: date)
        var parts: [String] = []
        if showHours {
            parts.append(store.running != nil ? DurationText.clock(elapsed) : "T " + DurationText.compact(elapsed))
        }
        if showEarnings {
            parts.append(compactMoney(earnings, code: store.currencyCode))
        }
        if showTRY, store.currencyCode == "USD", let rate = exchangeRates.latestRate {
            parts.append(compactMoney(earnings * rate, code: "TRY"))
        }
        if showGoal {
            if dailyGoalHours > 0 {
                parts.append("D \(goalPercent(elapsed: store.todayDuration(at: date), goal: dailyGoalHours))%")
            }
            if monthlyGoalHours > 0 {
                parts.append("M \(goalPercent(elapsed: store.monthDuration(at: date), goal: monthlyGoalHours))%")
            }
        }
        if parts.isEmpty {
            return store.running == nil ? "Ready" : (store.running?.isPaused == true ? "Paused" : "Clocked in")
        }
        return parts.joined(separator: "  ·  ")
    }

    private func goalPercent(elapsed: TimeInterval, goal: Double) -> Int {
        guard goal > 0 else { return 0 }
        return min(999, max(0, Int((elapsed / 3600 / goal * 100).rounded())))
    }

    private func compactMoney(_ value: Double, code: String) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = code
        if code == "TRY" { formatter.currencySymbol = "₺" }
        formatter.minimumFractionDigits = 0
        formatter.maximumFractionDigits = 0
        return formatter.string(from: NSNumber(value: value)) ?? "\(code) \(Int(value.rounded()))"
    }
}
