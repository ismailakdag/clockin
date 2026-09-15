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
        UIScale.migrateLegacyValueIfNeeded()
        // Sparkle'dan once sorulur: DMG'den calisan kopya guncellenemez.
        if MoveToApplications.offerIfNeeded() {
            NSApp.terminate(nil)
            return
        }
        UpdateChecker.shared.start()
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
    @StateObject private var updates = UpdateChecker.shared
    @AppStorage("Clockin.MinimalMode") private var minimalMode = false

    init() {
        // Preserve the interface-size preference written by pre-percent builds
        // before any view reads the new integer-backed AppStorage key.
        UIScale.migrateLegacyValueIfNeeded()
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
            Divider()
            Button("Check for Updates…") { updates.checkForUpdates() }
                .disabled(!updates.canCheckForUpdates)
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
    @AppStorage("Clockin.MinimalShowSeconds") private var showSeconds = false
    @AppStorage("Clockin.GoalDailyHours") private var dailyGoalHours = 0.0
    @AppStorage("Clockin.GoalMonthlyHours") private var monthlyGoalHours = 0.0
    @State private var now = Date()
    private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    var body: some View {
        let status = currentStatus(at: now)
        HStack(spacing: 5) {
            // A bold drawn stopwatch: hollow and switched off when idle, solid
            // while a session runs, with pause bars when paused.
            Image(nsImage: MenuBarIcon.image(iconState(status.state)))
                .renderingMode(.template)
            if minimalMode {
                if let text = status.text {
                    Text(text)
                        .font(.system(size: 12, weight: .semibold))
                        .monospacedDigit()
                        .lineLimit(1)
                }
            } else {
                Text("Clockin")
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
            }
        }
        // Idle, nothing in the label changes, so the clock is ignored.
        .onReceive(timer) { date in if store.running != nil { now = date } }
    }

    private func currentStatus(at date: Date) -> MenuBarStatus {
        MenuBarStatus.make(
            isRunning: store.running != nil,
            isPaused: store.running?.isPaused == true,
            sessionElapsed: store.elapsed(at: date),
            sessionEarnings: store.currentEarnings(at: date),
            currencyCode: store.currencyCode,
            tryRate: exchangeRates.latestRate,
            todayDuration: store.todayDuration(at: date),
            monthDuration: store.monthDuration(at: date),
            dailyGoalHours: dailyGoalHours,
            monthlyGoalHours: monthlyGoalHours,
            fields: .init(hours: showHours, seconds: showSeconds, earnings: showEarnings, tryEquivalent: showTRY, goal: showGoal)
        )
    }

    private func iconState(_ state: MenuBarStatus.State) -> MenuBarIcon.State {
        switch state {
        case .idle: .idle
        case .running: .running
        case .paused: .paused
        }
    }
}
