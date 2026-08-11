import Foundation

struct WorkSession: Codable, Identifiable, Hashable, Sendable {
    var id: UUID
    var start: Date
    var end: Date
    var duration: TimeInterval
    var note: String
    var hourlyRate: Double
    var source: String
    var matchedExternalSource: String? = nil

    var earnings: Double { duration / 3600 * hourlyRate }
}

struct RateRule: Codable, Identifiable, Hashable, Sendable {
    var id: UUID = UUID()
    var effectiveFrom: Date
    var hourlyRate: Double
}

struct RunningSession: Codable, Equatable, Sendable {
    var start: Date
    var accumulated: TimeInterval
    var resumedAt: Date?
    var note: String

    var isPaused: Bool { resumedAt == nil }

    func elapsed(at date: Date = .now) -> TimeInterval {
        accumulated + max(0, resumedAt.map { date.timeIntervalSince($0) } ?? 0)
    }
}

struct ClockinData: Codable, Sendable {
    var hourlyRate: Double = 25
    var currencyCode: String = "USD"
    var running: RunningSession?
    var sessions: [WorkSession] = []
    var pinVisible: Bool = false
    var rateRules: [RateRule]?
}

enum DurationText {
    static func clock(_ interval: TimeInterval) -> String {
        let seconds = max(0, Int(interval))
        return String(format: "%02d:%02d:%02d", seconds / 3600, (seconds % 3600) / 60, seconds % 60)
    }

    static func compact(_ interval: TimeInterval) -> String {
        let minutes = max(0, Int(interval / 60))
        if minutes < 60 { return "\(minutes)m" }
        let hours = minutes / 60
        let remainder = minutes % 60
        return remainder == 0 ? "\(hours)h" : "\(hours)h \(remainder)m"
    }
}

extension Double {
    func money(code: String, maxFractionDigits: Int = 2) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = code
        formatter.minimumFractionDigits = 2
        formatter.maximumFractionDigits = maxFractionDigits
        return formatter.string(from: NSNumber(value: self)) ?? String(format: "%.2f %@", self, code)
    }
}
