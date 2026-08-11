import Foundation

@MainActor
final class AppDependencies {
    static let shared = AppDependencies()
    let exchangeRates = ExchangeRateStore()
}

@main
struct RateScheduleValidation {
    @MainActor
    static func main() {
        let url = FileManager.default.temporaryDirectory
            .appending(path: "clockin-rate-validation-\(UUID().uuidString).json")
        defer { try? FileManager.default.removeItem(at: url) }
        let store = ClockStore(fileURL: url)
        let calendar = Calendar.current
        let august = calendar.date(from: DateComponents(year: 2026, month: 8, day: 2, hour: 10))!
        store.clockIn(at: august)
        _ = store.clockOut(at: august.addingTimeInterval(3600))
        let augustSession = store.sessions.first!
        precondition(store.earnings(for: augustSession) == 25)

        store.updateRate(40)
        precondition(store.earnings(for: augustSession) == 40)

        let january = calendar.date(from: DateComponents(year: 2026, month: 1, day: 2, hour: 10))!
        store.clockIn(at: january)
        _ = store.clockOut(at: january.addingTimeInterval(3600))
        let januarySession = store.sessions.first { calendar.component(.month, from: $0.start) == 1 }!
        precondition(store.earnings(for: januarySession) == 40)

        let januaryRule = calendar.date(from: DateComponents(year: 2026, month: 1, day: 1))!
        store.addRateRule(effectiveFrom: januaryRule, hourlyRate: 18)
        precondition(store.earnings(for: januarySession) == 18)
        precondition(store.earnings(for: augustSession) == 40)
        precondition(store.totalEarnings == 58)
        print("Rate schedule passed: July+ changed dynamically; earlier period changed independently.")
    }
}
