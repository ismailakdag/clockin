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
            MainWindowController.shared.show(store: dependencies.store, exchangeRates: dependencies.exchangeRates)
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
            Button(store.pinVisible ? "Hide pinned timer" : "Show pinned timer") {
                store.setPinned(!store.pinVisible)
            }
            Button("Quit Clockin") { NSApp.terminate(nil) }
        } label: {
            Image(systemName: store.running?.isPaused == true ? "pause.circle.fill" : (store.running == nil ? "timer" : "timer.circle.fill"))
        }
        .menuBarExtraStyle(.menu)
    }
}
