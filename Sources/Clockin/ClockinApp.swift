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
                if !UserDefaults.standard.bool(forKey: "Clockin.MinimalMode") {
                    MainWindowController.shared.show(store: dependencies.store, exchangeRates: dependencies.exchangeRates)
                }
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
    @AppStorage("Clockin.MinimalMode") private var minimalMode = false

    init() {
        let dependencies = AppDependencies.shared
        _store = StateObject(wrappedValue: dependencies.store)
        _exchangeRates = StateObject(wrappedValue: dependencies.exchangeRates)
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
            Divider()
            if !minimalMode {
                Button(store.pinVisible ? "Hide pinned timer" : "Show pinned timer") {
                    store.setPinned(!store.pinVisible)
                }
            }
            Button(minimalMode ? "Exit minimal mode" : "Use minimal menu bar mode") {
                minimalMode.toggle()
                if minimalMode {
                    NSApp.setActivationPolicy(.accessory)
                    store.setPinned(false)
                    MainWindowController.shared.hide()
                } else {
                    MainWindowController.shared.show(store: store, exchangeRates: exchangeRates)
                }
            }
            Button("Quit Clockin") { NSApp.terminate(nil) }
        } label: {
            MenuBarStatusLabel(store: store)
        }
        .menuBarExtraStyle(.menu)
    }
}

private struct MenuBarStatusLabel: View {
    @ObservedObject var store: ClockStore
    @AppStorage("Clockin.MinimalMode") private var minimalMode = false
    @State private var now = Date()
    private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: store.running?.isPaused == true ? "pause.circle.fill" : (store.running == nil ? "timer" : "timer.circle.fill"))
            if minimalMode {
                Text(status(at: now))
                    .font(.system(size: 10, weight: .semibold, design: .monospaced))
                    .lineLimit(1)
            }
        }
        .onReceive(timer) { now = $0 }
    }

    private func status(at date: Date) -> String {
        if store.running != nil {
            return DurationText.clock(store.elapsed(at: date)) + "  " + store.currentEarnings(at: date).money(code: store.currencyCode)
        }
        return "Today " + store.todayEarnings(at: date).money(code: store.currencyCode)
    }
}
