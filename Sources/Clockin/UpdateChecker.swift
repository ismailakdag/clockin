import AppKit
import Combine
import Sparkle

/// Sparkle owns scheduling, signature verification, installation and relaunch.
/// Keep one controller alive for the lifetime of this menu bar application.
@MainActor
final class UpdateChecker: ObservableObject {
    static let shared = UpdateChecker()

    @Published private(set) var canCheckForUpdates = false
    @Published private(set) var automaticallyChecksForUpdates = false
    @Published private(set) var lastChecked: Date?
    @Published private(set) var startupError: String?

    private let controller: SPUStandardUpdaterController
    private var started = false

    var version: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "—"
    }

    private init() {
        // Preserve an existing user's opt-out exactly once. From here on,
        // Sparkle is the sole owner of this preference and the update schedule.
        let defaults = UserDefaults.standard
        if defaults.object(forKey: "SUEnableAutomaticChecks") == nil,
           let previous = defaults.object(forKey: "Clockin.AutoCheckUpdates") as? Bool {
            defaults.set(previous, forKey: "SUEnableAutomaticChecks")
        }
        defaults.removeObject(forKey: "Clockin.AutoCheckUpdates")
        controller = SPUStandardUpdaterController(
            startingUpdater: false, updaterDelegate: nil, userDriverDelegate: nil
        )
        controller.updater.publisher(for: \.canCheckForUpdates)
            .assign(to: &$canCheckForUpdates)
        controller.updater.publisher(for: \.automaticallyChecksForUpdates)
            .assign(to: &$automaticallyChecksForUpdates)
        controller.updater.publisher(for: \.lastUpdateCheckDate)
            .assign(to: &$lastChecked)
    }

    func start() {
        guard !started else { return }
        do {
            try controller.updater.start()
            started = true
            startupError = nil
        } catch {
            startupError = error.localizedDescription
        }
    }

    func setAutomaticallyChecksForUpdates(_ enabled: Bool) {
        controller.updater.automaticallyChecksForUpdates = enabled
    }

    func checkForUpdates() {
        guard canCheckForUpdates else { return }
        // Let MenuBarExtra dismiss before Sparkle presents its window.
        DispatchQueue.main.async { [self] in
            NSApp.activate(ignoringOtherApps: true)
            controller.checkForUpdates(nil)
        }
    }
}
