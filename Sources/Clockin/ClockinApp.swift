import AppKit
import Combine
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
        MenuBarController.shared.start(.clockin(AppDependencies.shared))
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
                    // SwiftUI can still be settling its scene after the first
                    // presentation call. Re-present once it is settled so a
                    // launch can never end up windowless.
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

    init() {
        // Preserve the interface-size preference written by pre-percent builds
        // before any view reads the new integer-backed AppStorage key.
        UIScale.migrateLegacyValueIfNeeded()
    }

    var body: some Scene {
        // The menu-bar item and its panel are AppKit (MenuBarController), so
        // they can open over full-screen apps. An App needs a scene, so this
        // is an unused Settings scene with its menu command removed, because
        // settings live in the main window. macOS can still open it on its own
        // (seen around a Sparkle alert); it then hides itself and shows the
        // main window instead of an empty "Clockin Settings" window.
        Settings { SettingsSceneRedirect() }
            .commands { CommandGroup(replacing: .appSettings) {} }
    }
}

/// Content of the unused Settings scene. Its window is never shown: whenever
/// macOS orders it in, it is ordered out again and the main window opens.
/// SwiftUI reuses the window, so visibility is observed, not just the first
/// appearance.
private struct SettingsSceneRedirect: NSViewRepresentable {
    final class RedirectView: NSView {
        private var visibility: NSKeyValueObservation?

        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            visibility = nil
            guard let window else { return }
            window.alphaValue = 0
            visibility = window.observe(\.isVisible, options: [.initial, .new]) { window, _ in
                DispatchQueue.main.async {
                    MainActor.assumeIsolated { RedirectView.redirect(window) }
                }
            }
        }

        private static func redirect(_ window: NSWindow) {
            guard window.isVisible else { return }
            window.orderOut(nil)
            let dependencies = AppDependencies.shared
            MainWindowController.shared.show(store: dependencies.store, exchangeRates: dependencies.exchangeRates)
        }
    }

    func makeNSView(context: Context) -> RedirectView { RedirectView(frame: .zero) }
    func updateNSView(_ nsView: RedirectView, context: Context) {}
}

extension MenuBarController.Host {
    @MainActor
    static func clockin(_ dependencies: AppDependencies) -> Self {
        let store = dependencies.store
        let exchangeRates = dependencies.exchangeRates
        @Sendable func flag(_ key: String, _ fallback: Bool) -> Bool {
            UserDefaults.standard.object(forKey: key) as? Bool ?? fallback
        }
        let openApp: @MainActor () -> Void = {
            MenuBarController.shared.close(animated: false)
            MainWindowController.shared.show(store: store, exchangeRates: exchangeRates)
        }
        return Self(
            status: {
                // Idle there is nothing to compute: only the icon shows.
                guard store.running != nil else { return MenuBarStatus(state: .idle, text: nil) }
                let now = Date()
                return MenuBarStatus.make(
                    isRunning: true,
                    isPaused: store.running?.isPaused == true,
                    sessionElapsed: store.elapsed(at: now),
                    sessionEarnings: store.currentEarnings(at: now),
                    currencyCode: store.currencyCode,
                    tryRate: exchangeRates.latestRate,
                    todayDuration: store.todayDuration(at: now),
                    monthDuration: store.monthDuration(at: now),
                    dailyGoalHours: UserDefaults.standard.double(forKey: "Clockin.GoalDailyHours"),
                    monthlyGoalHours: UserDefaults.standard.double(forKey: "Clockin.GoalMonthlyHours"),
                    fields: .init(
                        hours: flag("Clockin.MinimalShowHours", true),
                        seconds: flag("Clockin.MinimalShowSeconds", false),
                        earnings: flag("Clockin.MinimalShowEarnings", true),
                        tryEquivalent: flag("Clockin.MinimalShowTRY", true),
                        goal: flag("Clockin.MinimalShowGoal", false)
                    )
                )
            },
            minimalMode: { flag("Clockin.MinimalMode", false) },
            changes: Publishers.Merge3(
                store.objectWillChange.map { _ in () },
                exchangeRates.objectWillChange.map { _ in () },
                NotificationCenter.default.publisher(for: UserDefaults.didChangeNotification).map { _ in () }
            ).eraseToAnyPublisher(),
            content: { close in
                AnyView(
                    MenuBarPanelView(actions: MenuBarPanelActions(
                        openApp: openApp,
                        close: close,
                        checkForUpdates: {
                            MenuBarController.shared.close(animated: false)
                            UpdateChecker.shared.checkForUpdates()
                        },
                        quit: { NSApp.terminate(nil) }
                    ))
                    .environmentObject(store)
                    .environmentObject(exchangeRates)
                    .environmentObject(RadioController.shared)
                    .environmentObject(UpdateChecker.shared)
                )
            },
            menu: {
                let menu = NSMenu()
                menu.addItem(ClosureMenuItem("Open Clockin", action: openApp))
                menu.addItem(.separator())
                let pending = UpdateChecker.shared.pendingVersion
                let updates = ClosureMenuItem(pending.map { "Install Clockin \($0)…" } ?? "Check for Updates…") {
                    UpdateChecker.shared.checkForUpdates()
                }
                updates.isEnabled = UpdateChecker.shared.isReady
                menu.addItem(updates)
                menu.addItem(ClosureMenuItem("Quit Clockin") { NSApp.terminate(nil) })
                menu.autoenablesItems = false
                return menu
            }
        )
    }
}

/// An NSMenuItem that runs a closure.
@MainActor
final class ClosureMenuItem: NSMenuItem {
    private let handler: @MainActor () -> Void

    init(_ title: String, action handler: @escaping @MainActor () -> Void) {
        self.handler = handler
        super.init(title: title, action: #selector(run), keyEquivalent: "")
        target = self
    }

    @available(*, unavailable)
    required init(coder: NSCoder) { fatalError("init(coder:) is not supported") }

    @objc private func run() { handler() }
}
