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
    /// Inclusive end date for a manually bounded period. Nil means open-ended.
    var effectiveUntil: Date?
    var hourlyRate: Double

    init(id: UUID = UUID(), effectiveFrom: Date, effectiveUntil: Date? = nil, hourlyRate: Double) {
        self.id = id
        self.effectiveFrom = effectiveFrom
        self.effectiveUntil = effectiveUntil
        self.hourlyRate = hourlyRate
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        effectiveFrom = try container.decode(Date.self, forKey: .effectiveFrom)
        effectiveUntil = try container.decodeIfPresent(Date.self, forKey: .effectiveUntil)
        hourlyRate = try container.decode(Double.self, forKey: .hourlyRate)
    }

    func applies(to date: Date, calendar: Calendar = .autoupdatingCurrent) -> Bool {
        guard date >= effectiveFrom else { return false }
        guard let effectiveUntil else { return true }
        let endExclusive = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: effectiveUntil)) ?? effectiveUntil
        return date < endExclusive
    }
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

/// Elle girilen ya da duzenlenen kaydin saatleri. Duzenleyici onizlemesi ile
/// magaza ayni hesabi kullanir; ikisi ayri hesaplayinca ekranda gorulen sure
/// kaydedilenden farkli cikiyordu.
enum EntryTimes {
    /// Bitis baslangictan onceyse ertesi gundur. Takvim gunu eklenir, 24 saat
    /// degil: saat geri alinan gecede 22:00-06:00 dokuz saattir.
    static func end(start: Date, end: Date, calendar: Calendar) -> Date {
        guard end < start else { return end }
        return calendar.date(byAdding: .day, value: 1, to: end) ?? end.addingTimeInterval(86_400)
    }

    /// Kaydedilecek calisilan sure. Yeni kayit araligin tamamidir. Saatleri
    /// degismeyen kayit suresini korur; saatleri degisen kayit, duraklatma ya
    /// da dis kaynak yuzunden aralikla sure arasindaki farki korur. Sonuc
    /// sifir ya da negatifse bu saatler kaydin molasindan kisadir.
    static func workedDuration(start: Date, end: Date, replacing old: WorkSession?) -> TimeInterval {
        guard let old else { return end.timeIntervalSince(start) }
        guard start != old.start || end != old.end else { return old.duration }
        let gap = old.end.timeIntervalSince(old.start) - old.duration
        return end.timeIntervalSince(start) - gap
    }
}

enum DurationText {
    /// `includeSeconds: false` menu cubugundaki dar alan icin; buyuk sayac ve
    /// sabitlenmis widget saniyeyi gostermeye devam eder.
    static func clock(_ interval: TimeInterval, includeSeconds: Bool = true) -> String {
        let seconds = max(0, Int(interval))
        guard includeSeconds else {
            return String(format: "%02d:%02d", seconds / 3600, (seconds % 3600) / 60)
        }
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
    /// Ekranda saniyede onlarca kez cagriliyor. `NumberFormatter` her
    /// cagrida yeniden kuruluyordu; `FormatStyle` deger tipi oldugu icin
    /// ayni ciktiyi kurulum maliyeti olmadan uretir.
    func money(code: String, maxFractionDigits: Int = 2) -> String {
        let maximum = max(0, maxFractionDigits)
        let minimum = min(2, maximum)
        return formatted(.currency(code: code).precision(.fractionLength(minimum...maximum)))
    }
}
