import Foundation

@MainActor
final class AppDependencies {
    static let shared = AppDependencies()
    let exchangeRates = ExchangeRateStore()
}

@main
struct StoreValidation {
    @MainActor
    static func main() throws {
        let url = FileManager.default.temporaryDirectory
            .appending(path: "clockin-store-validation-\(UUID().uuidString).json")
        defer { try? FileManager.default.removeItem(at: url) }
        let store = ClockStore(fileURL: url)
        let base = Date(timeIntervalSince1970: 1_000_000)

        store.clockIn(elapsed: 3_900, note: "Manual continuation", at: base)
        precondition(store.elapsed(at: base) == 3_900)
        precondition(store.running?.start == base.addingTimeInterval(-3_900))
        store.pause(at: base.addingTimeInterval(60))
        precondition(store.elapsed(at: base.addingTimeInterval(90)) == 3_960)
        store.resume(at: base.addingTimeInterval(90))
        _ = store.clockOut(at: base.addingTimeInterval(150))
        precondition(store.sessions.count == 1)
        precondition(store.sessions[0].duration == 4_020)
        store.deleteSession(id: store.sessions[0].id)
        precondition(store.sessions.isEmpty)

        store.clockIn(elapsed: 600, at: base)
        precondition(store.allDuration(at: base) == 600)
        precondition(abs(store.allEarnings(at: base) - (600 / 3600 * store.hourlyRate)) < 0.0001)
        store.cancelRunning()
        precondition(store.running == nil)
        precondition(store.sessions.isEmpty)
        precondition(store.allDuration(at: base) == 0)
        precondition(store.allEarnings(at: base) == 0)

        print("Store workflow passed: manual start, pause, resume, clock out, delete, and cancel.")
    }
}
