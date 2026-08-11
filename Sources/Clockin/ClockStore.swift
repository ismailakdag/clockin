import AppKit
import Foundation

@MainActor
final class ClockStore: ObservableObject {
    @Published private(set) var data: ClockinData
    @Published var statusMessage: String?

    private let fileURL: URL
    private let calendar = Calendar.autoupdatingCurrent
    private let backupDirectory: URL

    init(fileURL: URL? = nil) {
        self.fileURL = fileURL ?? Self.defaultFileURL
        self.backupDirectory = self.fileURL.deletingLastPathComponent().appending(path: "Backups", directoryHint: .isDirectory)
        if let content = try? Data(contentsOf: self.fileURL),
           let decoded = try? JSONDecoder().decode(ClockinData.self, from: content) {
            data = decoded
        } else {
            data = ClockinData()
        }
        let needsRateMigration = data.rateRules == nil
        if needsRateMigration {
            let july2026 = Calendar.current.date(from: DateComponents(year: 2026, month: 7, day: 1)) ?? .distantPast
            data.rateRules = [RateRule(effectiveFrom: july2026, hourlyRate: data.hourlyRate)]
        }
        if needsRateMigration { save() }
        else { createAutomaticBackupIfNeeded() }
    }

    static var defaultFileURL: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        return base.appending(path: "Clockin", directoryHint: .isDirectory).appending(path: "clockin.json")
    }

    var latestBackupDate: Date? {
        let files = (try? FileManager.default.contentsOfDirectory(
            at: backupDirectory,
            includingPropertiesForKeys: [.contentModificationDateKey],
            options: [.skipsHiddenFiles]
        )) ?? []
        return files.compactMap { try? $0.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate }.max()
    }

    var backupCount: Int {
        ((try? FileManager.default.contentsOfDirectory(at: backupDirectory, includingPropertiesForKeys: nil, options: [.skipsHiddenFiles])) ?? []).count
    }

    var running: RunningSession? { data.running }
    var sessions: [WorkSession] { data.sessions.sorted { $0.start > $1.start } }
    var hourlyRate: Double { data.hourlyRate }
    var currencyCode: String { data.currencyCode }
    var pinVisible: Bool { data.pinVisible }
    var rateRules: [RateRule] { (data.rateRules ?? []).sorted { $0.effectiveFrom < $1.effectiveFrom } }
    var currentRateEffectiveFrom: Date? { rateRules.last(where: { $0.effectiveFrom <= Date() })?.effectiveFrom }

    func elapsed(at date: Date = .now) -> TimeInterval { data.running?.elapsed(at: date) ?? 0 }
    func currentEarnings(at date: Date = .now) -> Double { elapsed(at: date) / 3600 * effectiveRate(at: date, fallback: hourlyRate) }

    func effectiveRate(at date: Date, fallback: Double) -> Double {
        rateRules.last(where: { $0.effectiveFrom <= date })?.hourlyRate ?? fallback
    }

    func earnings(for session: WorkSession) -> Double {
        session.duration / 3600 * effectiveRate(at: session.start, fallback: session.hourlyRate)
    }

    func clockIn(elapsed: TimeInterval = 0, note: String = "", at date: Date = .now) {
        guard data.running == nil else { return }
        let safeElapsed = max(0, elapsed)
        data.running = RunningSession(
            start: date.addingTimeInterval(-safeElapsed),
            accumulated: safeElapsed,
            resumedAt: date,
            note: note
        )
        save()
    }

    func cancelRunning() {
        guard data.running != nil else { return }
        data.running = nil
        save()
        statusMessage = "Active session cancelled. No earnings were added."
    }

    func pause(at date: Date = .now) {
        guard var running = data.running, let resumedAt = running.resumedAt else { return }
        running.accumulated += max(0, date.timeIntervalSince(resumedAt))
        running.resumedAt = nil
        data.running = running
        save()
    }

    func resume(at date: Date = .now) {
        guard var running = data.running, running.resumedAt == nil else { return }
        running.resumedAt = date
        data.running = running
        save()
    }

    @discardableResult
    func clockOut(at date: Date = .now) -> WorkSession? {
        guard let running = data.running else { return nil }
        let session = WorkSession(
            id: UUID(), start: running.start, end: date, duration: running.elapsed(at: date),
            note: running.note, hourlyRate: hourlyRate, source: "Clockin"
        )
        data.sessions.append(session)
        data.running = nil
        save()
        return session
    }

    func updateRate(_ value: Double) {
        guard value >= 0, value.isFinite else { return }
        data.hourlyRate = value
        if let index = data.rateRules?.indices
            .filter({ data.rateRules![$0].effectiveFrom <= Date() })
            .max(by: { data.rateRules![$0].effectiveFrom < data.rateRules![$1].effectiveFrom }) {
            data.rateRules?[index].hourlyRate = value
        }
        save()
    }

    func addRateRule(effectiveFrom: Date, hourlyRate: Double) {
        guard hourlyRate >= 0, hourlyRate.isFinite else { return }
        let day = calendar.startOfDay(for: effectiveFrom)
        if let index = data.rateRules?.firstIndex(where: { calendar.isDate($0.effectiveFrom, inSameDayAs: day) }) {
            data.rateRules?[index].hourlyRate = hourlyRate
        } else {
            data.rateRules = (data.rateRules ?? []) + [RateRule(effectiveFrom: day, hourlyRate: hourlyRate)]
        }
        syncCurrentRate()
        save()
    }

    func updateRateRule(id: UUID, effectiveFrom: Date, hourlyRate: Double) {
        guard hourlyRate >= 0, hourlyRate.isFinite,
              let index = data.rateRules?.firstIndex(where: { $0.id == id }) else { return }
        data.rateRules?[index].effectiveFrom = calendar.startOfDay(for: effectiveFrom)
        data.rateRules?[index].hourlyRate = hourlyRate
        syncCurrentRate()
        save()
    }

    func deleteRateRule(id: UUID) {
        guard (data.rateRules?.count ?? 0) > 1 else { return }
        data.rateRules?.removeAll { $0.id == id }
        syncCurrentRate()
        save()
    }

    private func syncCurrentRate() {
        if let current = (data.rateRules ?? []).filter({ $0.effectiveFrom <= Date() }).max(by: { $0.effectiveFrom < $1.effectiveFrom }) {
            data.hourlyRate = current.hourlyRate
        }
    }

    func updateCurrency(_ value: String) {
        data.currencyCode = value
        save()
    }

    func setPinned(_ value: Bool) {
        data.pinVisible = value
        save()
        PinnedWindowController.shared.update(isVisible: value, store: self)
    }

    func importCSV(from url: URL) {
        do {
            let granted = url.startAccessingSecurityScopedResource()
            defer { if granted { url.stopAccessingSecurityScopedResource() } }
            let imported = try CSVImporter.parse(data: Data(contentsOf: url), hourlyRate: hourlyRate)
            importSessions(imported)
        } catch {
            statusMessage = error.localizedDescription
        }
    }

    func importPastedText(_ text: String) {
        do {
            let imported = try PastedTextImporter.parse(text, hourlyRate: hourlyRate)
            importSessions(imported)
        } catch {
            statusMessage = error.localizedDescription
        }
    }

    func exportBackup(to url: URL) {
        do {
            let encoded = try JSONEncoder().encode(data)
            try encoded.write(to: url, options: .atomic)
            statusMessage = "Backup exported."
        } catch {
            statusMessage = "Could not export backup: \(error.localizedDescription)"
        }
    }

    func importBackup(from url: URL) {
        do {
            let content = try Data(contentsOf: url)
            let decoded = try JSONDecoder().decode(ClockinData.self, from: content)
            guard decoded.sessions.allSatisfy({ $0.duration >= 0 && $0.end >= $0.start }) else {
                throw CocoaError(.validationMissingMandatoryProperty)
            }
            data = decoded
            save()
            statusMessage = "Backup restored."
        } catch {
            statusMessage = "Could not restore backup: \(error.localizedDescription)"
        }
    }

    func restoreLatestBackup() {
        let files = ((try? FileManager.default.contentsOfDirectory(
            at: backupDirectory,
            includingPropertiesForKeys: [.contentModificationDateKey],
            options: [.skipsHiddenFiles]
        )) ?? []).sorted {
            let left = (try? $0.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast
            let right = (try? $1.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast
            return left > right
        }
        guard let latest = files.first else {
            statusMessage = "No automatic backup exists yet."
            return
        }
        importBackup(from: latest)
    }

    func previewPastedText(_ text: String) -> [WorkSession] {
        (try? PastedTextImporter.parse(text, hourlyRate: hourlyRate)) ?? []
    }

    func deleteSession(id: UUID) {
        guard let index = data.sessions.firstIndex(where: { $0.id == id }) else { return }
        data.sessions.remove(at: index)
        save()
        statusMessage = "Session deleted."
    }

    private func importSessions(_ imported: [WorkSession]) {
        var fresh: [WorkSession] = []
        var matched = 0
        for session in imported {
            let key = Self.deduplicationKey(session)
            if let duplicateIndex = data.sessions.firstIndex(where: { Self.deduplicationKey($0) == key }) {
                if session.source != "Clockin", data.sessions[duplicateIndex].source == "Clockin",
                   data.sessions[duplicateIndex].matchedExternalSource == nil {
                    data.sessions[duplicateIndex].matchedExternalSource = session.source
                    matched += 1
                }
                continue
            }
            if fresh.contains(where: { Self.deduplicationKey($0) == key }) {
                continue
            }
            if session.source != "Clockin", let index = findClockinMatch(for: session) {
                data.sessions[index].matchedExternalSource = session.source
                matched += 1
            } else {
                fresh.append(session)
            }
        }
        data.sessions.append(contentsOf: fresh)
        save()
        if fresh.isEmpty, matched == 0 {
            statusMessage = "All entries were already imported."
        } else {
            let importedText = "Imported \(fresh.count)"
            let matchedText = matched > 0 ? ", matched \(matched) with Clockin" : ""
            statusMessage = importedText + matchedText + "."
        }
    }

    private func findClockinMatch(for external: WorkSession) -> Int? {
        data.sessions.firstIndex { local in
            guard local.source == "Clockin", local.matchedExternalSource == nil else { return false }
            let sameDay = calendar.isDate(local.start, inSameDayAs: external.start)
            let startClose = abs(local.start.timeIntervalSince(external.start)) <= 90
            let endClose = abs(local.end.timeIntervalSince(external.end)) <= 90
            let durationClose = abs(local.duration - external.duration) <= 120
            return sameDay && startClose && endClose && durationClose
        }
    }

    func todayDuration(at date: Date = .now) -> TimeInterval {
        duration(on: date)
    }

    func todayEarnings(at date: Date = .now) -> Double {
        earnings(on: date)
    }

    func duration(on date: Date) -> TimeInterval {
        let day = calendar.startOfDay(for: date)
        let completed = data.sessions.filter { calendar.isDate($0.start, inSameDayAs: day) }.reduce(0) { $0 + $1.duration }
        let active = data.running.map { calendar.isDate($0.start, inSameDayAs: day) ? $0.elapsed(at: .now) : 0 } ?? 0
        return completed + active
    }

    func earnings(on date: Date) -> Double {
        let day = calendar.startOfDay(for: date)
        let completed = data.sessions.filter { calendar.isDate($0.start, inSameDayAs: day) }.reduce(0) { $0 + earnings(for: $1) }
        let active = data.running.map { calendar.isDate($0.start, inSameDayAs: day) ? currentEarnings(at: .now) : 0 } ?? 0
        return completed + active
    }

    func monthEarnings(at date: Date = .now) -> Double {
        let completed = data.sessions.filter { calendar.isDate($0.start, equalTo: date, toGranularity: .month) }
            .reduce(0) { $0 + earnings(for: $1) }
        let active = data.running.map { calendar.isDate($0.start, equalTo: date, toGranularity: .month) ? currentEarnings(at: date) : 0 } ?? 0
        return completed + active
    }

    func monthDuration(at date: Date = .now) -> TimeInterval {
        let completed = data.sessions.filter { calendar.isDate($0.start, equalTo: date, toGranularity: .month) }
            .reduce(0) { $0 + $1.duration }
        let active = data.running.map { calendar.isDate($0.start, equalTo: date, toGranularity: .month) ? $0.elapsed(at: date) : 0 } ?? 0
        return completed + active
    }

    var totalDuration: TimeInterval { data.sessions.reduce(0) { $0 + $1.duration } }
    var totalEarnings: Double { data.sessions.reduce(0) { $0 + earnings(for: $1) } }
    func allDuration(at date: Date = .now) -> TimeInterval { totalDuration + elapsed(at: date) }
    func allEarnings(at date: Date = .now) -> Double { totalEarnings + currentEarnings(at: date) }

    private static func deduplicationKey(_ session: WorkSession) -> String {
        "\(Int(session.start.timeIntervalSince1970))|\(Int(session.end.timeIntervalSince1970))|\(Int(session.duration))"
    }

    private func save() {
        do {
            try FileManager.default.createDirectory(at: fileURL.deletingLastPathComponent(), withIntermediateDirectories: true)
            createAutomaticBackupIfNeeded()
            let encoded = try JSONEncoder().encode(data)
            try encoded.write(to: fileURL, options: .atomic)
        } catch {
            statusMessage = "Could not save: \(error.localizedDescription)"
        }
    }

    private func createAutomaticBackupIfNeeded() {
        guard FileManager.default.fileExists(atPath: fileURL.path) else { return }
        do {
            try FileManager.default.createDirectory(at: backupDirectory, withIntermediateDirectories: true)
            let stamp = Int(Date().timeIntervalSince1970 * 1000)
            let destination = backupDirectory.appending(path: "clockin-\(stamp)-\(UUID().uuidString).json")
            try FileManager.default.copyItem(at: fileURL, to: destination)
            let backups = try FileManager.default.contentsOfDirectory(at: backupDirectory, includingPropertiesForKeys: [.contentModificationDateKey], options: [.skipsHiddenFiles])
                .sorted {
                    let left = (try? $0.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast
                    let right = (try? $1.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast
                    return left > right
                }
            for old in backups.dropFirst(30) { try? FileManager.default.removeItem(at: old) }
        } catch {
            // A failed backup must never block the primary save.
        }
    }
}
