import AppKit
import Combine
import Sparkle

/// Sparkle owns scheduling, signature verification, installation and relaunch.
/// Keep one controller alive for the lifetime of this menu bar application.
@MainActor
final class UpdateChecker: ObservableObject {
    static let shared = UpdateChecker()

    /// True once Sparkle has started. Checks stay available while an update
    /// session runs: Sparkle then brings the open update to the front. Using
    /// `canCheckForUpdates` here swallowed the click when a background check
    /// had already found an update.
    @Published private(set) var isReady = false
    /// A version a background check found and did not put in front of the
    /// user. The menu bar and Settings show it until the user opens it.
    @Published private(set) var pendingVersion: String?
    @Published private(set) var automaticallyChecksForUpdates = false
    @Published private(set) var lastChecked: Date?
    @Published private(set) var startupError: String?

    private let controller: SPUStandardUpdaterController
    private let reminders = GentleUpdateReminders()
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
            startingUpdater: false, updaterDelegate: nil, userDriverDelegate: reminders
        )
        reminders.onChange = { [weak self] version in self?.pendingVersion = version }
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
            isReady = true
            startupError = nil
        } catch {
            startupError = error.localizedDescription
        }
    }

    func setAutomaticallyChecksForUpdates(_ enabled: Bool) {
        controller.updater.automaticallyChecksForUpdates = enabled
    }

    /// Starts a check, or brings an update that is already open or waiting
    /// to the front.
    func checkForUpdates() {
        guard started else { return }
        // Let the menu or panel close before Sparkle presents its window.
        DispatchQueue.main.async { [self] in
            NSApp.activate(ignoringOtherApps: true)
            controller.checkForUpdates(nil)
        }
    }
}

/// Clockin is a menu-bar app, so it is rarely the active app when a scheduled
/// check finds an update. Sparkle would then order its alert behind other
/// windows, where it goes unnoticed. Right after launch Sparkle can show it in
/// front; otherwise the update is offered from the menu bar and Settings until
/// the user opens it.
@MainActor
private final class GentleUpdateReminders: NSObject, @preconcurrency SPUStandardUserDriverDelegate {
    var onChange: ((String?) -> Void)?

    var supportsGentleScheduledUpdateReminders: Bool { true }

    func standardUserDriverShouldHandleShowingScheduledUpdate(_ update: SUAppcastItem, andInImmediateFocus immediateFocus: Bool) -> Bool {
        immediateFocus
    }

    func standardUserDriverWillHandleShowingUpdate(_ handleShowingUpdate: Bool, forUpdate update: SUAppcastItem, state: SPUUserUpdateState) {
        guard !handleShowingUpdate, !state.userInitiated else { return }
        onChange?(update.displayVersionString)
    }

    func standardUserDriverDidReceiveUserAttention(forUpdate update: SUAppcastItem) {
        onChange?(nil)
    }

    func standardUserDriverWillFinishUpdateSession() {
        onChange?(nil)
    }
}
