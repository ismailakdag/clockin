import Foundation

@MainActor
final class AppDependencies {
    static let shared = AppDependencies()
    let exchangeRates = ExchangeRateStore()
}

@main
struct ChimeValidation {
    @MainActor
    static func main() {
        let url = FileManager.default.temporaryDirectory
            .appending(path: "clockin-chime-validation-\(UUID().uuidString).json")
        defer { try? FileManager.default.removeItem(at: url) }
        let store = ClockStore(fileURL: url)
        let baseline = Date()
        store.clockIn(elapsed: 125, at: baseline)
        UserDefaults.standard.set(true, forKey: "Clockin.ChimeEnabled")
        UserDefaults.standard.set(7, forKey: "Clockin.ChimeIntervalMinutes")
        defer {
            UserDefaults.standard.removeObject(forKey: "Clockin.ChimeEnabled")
            UserDefaults.standard.removeObject(forKey: "Clockin.ChimeIntervalMinutes")
        }
        precondition(FocusChimeController.shared.remaining(store: store, at: baseline) == 295)
        store.pause(at: baseline)
        precondition(FocusChimeController.shared.remaining(store: store, at: baseline) == nil)
        print("Chime workflow passed: next-boundary countdown and paused silence.")
    }
}
