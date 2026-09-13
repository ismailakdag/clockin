import Foundation

/// Guncelleme betiginin ciktisindan ilerleme cikarir.
///
/// Betik adim basina bir `::clockin-step <ad>` satiri yazar. Adim icindeki
/// ilerleme zamana gore tahmin edilir: her adimin onceki guncellemede ne
/// kadar surdugu saklanir ve cubuk o sureye gore akar. `swift build`'in
/// `[21/23]` sayaclari ise kullanilamiyor; modulun tamami tek bir adimda
/// derleniyor, sayac bir saniyede sona geliyor ve asil bekleme son adimda
/// geciyor. AppKit'e bagli degil; boylece elle testlerle denenebiliyor.
struct UpdateProgress: Equatable {
    enum Step: String, CaseIterable {
        case fetch
        case buildAppleSilicon = "build-arm64"
        case buildIntel = "build-x86_64"
        case package
        case install

        var title: String {
            switch self {
            case .fetch: "Fetching the latest version"
            case .buildAppleSilicon: "Building for Apple Silicon"
            case .buildIntel: "Building for Intel"
            case .package: "Packaging"
            case .install: "Installing"
            }
        }

        /// Henuz olculmemis bir adim icin tahmin, saniye. Apple Silicon bir
        /// Mac'te temiz derleme mimari basina 15-16 saniye surdu.
        var defaultDuration: TimeInterval {
            switch self {
            case .fetch: 2
            case .buildAppleSilicon, .buildIntel: 16
            case .package: 2
            case .install: 3
            }
        }
    }

    private(set) var step: Step?
    private(set) var stepStartedAt: Date?
    /// Betigin `::clockin-error` ile bildirdigi, kullaniciya gosterilecek neden.
    private(set) var errorMessage: String?
    /// Bu calismada tamamlanan adimlarin olculen sureleri.
    private(set) var measured: [Step: TimeInterval] = [:]
    /// Onceki calismalardan beklenen sureler.
    let expected: [Step: TimeInterval]

    init(expected: [Step: TimeInterval] = [:]) {
        self.expected = expected
    }

    var stepNumber: Int? {
        step.flatMap { Step.allCases.firstIndex(of: $0) }.map { $0 + 1 }
    }

    func expectedDuration(of step: Step) -> TimeInterval {
        max(0.5, expected[step] ?? step.defaultDuration)
    }

    func fraction(at now: Date) -> Double {
        guard let step, let started = stepStartedAt,
              let index = Step.allCases.firstIndex(of: step) else { return 0 }
        let durations = Step.allCases.map { expectedDuration(of: $0) }
        let total = durations.reduce(0, +)
        let finished = durations[..<index].reduce(0, +)
        let elapsed = max(0, now.timeIntervalSince(started))
        let current = durations[index] * Self.share(elapsed: elapsed, expected: durations[index])
        return min(1, (finished + current) / total)
    }

    /// Adimin ne kadarinin bittigi. Beklenen sure dolana kadar dogrusal
    /// ilerleyip yuzde doksana gelir, sonra yavaslayarak yuze yaklasir ama
    /// varmaz: adim uzarsa cubuk ne donar ne de dolup beklemeye baslar.
    static func share(elapsed: TimeInterval, expected: TimeInterval) -> Double {
        let ratio = elapsed / expected
        guard ratio > 0 else { return 0 }
        if ratio <= 1 { return 0.9 * ratio }
        return 0.9 + 0.1 * (1 - 1 / ratio)
    }

    private static let stepPrefix = "::clockin-step "
    private static let errorPrefix = "::clockin-error "

    mutating func consume(_ line: String, at now: Date) {
        let text = line.trimmingCharacters(in: .whitespaces)
        if text.hasPrefix(Self.stepPrefix) {
            guard let next = Step(rawValue: String(text.dropFirst(Self.stepPrefix.count))) else { return }
            if let step, let stepStartedAt {
                measured[step] = now.timeIntervalSince(stepStartedAt)
            }
            step = next
            stepStartedAt = now
        } else if text.hasPrefix(Self.errorPrefix) {
            errorMessage = String(text.dropFirst(Self.errorPrefix.count))
        }
    }
}
