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

    private static func matches(_ event: NSEvent) -> Bool {
        let modifiers = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        return modifiers == [.command, .option] && event.charactersIgnoringModifiers != nil
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
