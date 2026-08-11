import Foundation

@main
struct ExchangeValidation {
    @MainActor
    static func main() async {
        let store = ExchangeRateStore()
        let historicalDay = Calendar.current.date(from: DateComponents(year: 2026, month: 1, day: 23))!
        await store.refresh(sessionDates: [historicalDay])
        guard let latest = store.latestRate, latest > 0,
              let historical = store.rate(on: historicalDay), historical > 0 else {
            FileHandle.standardError.write(Data("FAILED: live current and historical USD/TRY rates\n".utf8))
            exit(1)
        }
        print(String(format: "Exchange API passed: latest %.3f, 2026-01-23 %.3f.", latest, historical))
    }
}
