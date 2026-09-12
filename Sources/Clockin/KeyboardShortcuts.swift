import AppKit
import Foundation

@MainActor
final class KeyboardShortcutController {
    static let shared = KeyboardShortcutController()

    private var globalMonitor: Any?
    private var localMonitor: Any?
    private var store: ClockStore?

    func start(store: ClockStore) {
        self.store = store
        guard globalMonitor == nil, localMonitor == nil else { return }

        globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self, Self.matches(event) else { return }
            Task { @MainActor in self.perform(event) }
        }
        localMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self, Self.matches(event) else { return event }
            Task { @MainActor in self.perform(event) }
            return nil
        }
    }

    /// Yalnizca bu dort tusu tuketiriz.
    ///
    /// Once "Option-Command ve herhangi bir karakter" yeterli sayiliyordu. Yerel
    /// izleyici ise eslesen olayi `nil` dondurup yutuyor, `perform` da taninmayan
    /// tusta hicbir sey yapmiyordu: Option-Command ile baslayan butun diger
    /// kisayollar sessizce kayboluyordu.
    private static let shortcutKeys: Set<String> = ["i", "p", "o", "e"]

    private static func matches(_ event: NSEvent) -> Bool {
        let modifiers = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        guard modifiers == [.command, .option],
              let key = event.charactersIgnoringModifiers?.lowercased() else { return false }
        return shortcutKeys.contains(key)
    }

    private func perform(_ event: NSEvent) {
        guard let store, let key = event.charactersIgnoringModifiers?.lowercased() else { return }
        switch key {
        case "i":
            if store.running == nil { store.clockIn() }
            else if store.running?.isPaused == true { store.resume() }
        case "p":
            if store.running?.isPaused == true { store.resume() } else { store.pause() }
        case "o":
            _ = store.clockOut()
        case "e":
            MainWindowController.shared.show(store: store, exchangeRates: AppDependencies.shared.exchangeRates)
        default:
            break
        }
    }
}
