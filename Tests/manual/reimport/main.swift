import AppKit
import Foundation

// ClockStore'u uygulamanin geri kalani olmadan derlemek icin.
@MainActor
final class PinnedWindowController {
    static let shared = PinnedWindowController()
    func update(isVisible: Bool, store: ClockStore) {}
}

func expect(_ condition: @autoclosure () -> Bool, _ message: String) {
    guard condition() else {
        FileHandle.standardError.write(Data("FAILED: \(message)\n".utf8))
        exit(1)
    }
    print("ok: \(message)")
}

// Ayni dokumun duzeltilmis halini yeniden ice aktarmak kayit cogaltmamali.
//
// iPhone arsivinde 9 Agustos 29 saat gorunuyordu: ayni vardiya iki kayit,
// baslangiclari ayni, bitisleri 5 dakika farkli. Isaretsiz eski bir kayit
// hicbir satirla eslesmedigi icin duzeltilmis satir yeni is sayiliyordu.
MainActor.assumeIsolated {
    let dir = FileManager.default.temporaryDirectory
        .appending(path: "clockin-reimport-test-\(UUID().uuidString)", directoryHint: .isDirectory)
    try! FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: dir) }

    // 9 Agustos 2026 11:12 UTC
    let base = Date(timeIntervalSince1970: 1_786_273_920)
    func at(_ minutes: Double) -> Date { base.addingTimeInterval(minutes * 60) }
    func row(_ from: Double, _ to: Double, source: String, linked: String? = nil) -> WorkSession {
        var s = WorkSession(id: UUID(), start: at(from), end: at(to), duration: (to - from) * 60,
                            note: "", hourlyRate: 25, source: source)
        s.matchedExternalSource = linked
        return s
    }
    @MainActor func store(_ name: String, _ sessions: [WorkSession]) -> ClockStore {
        var data = ClockinData()
        data.sessions = sessions
        let url = dir.appending(path: "\(name).json")
        try! JSONEncoder().encode(data).write(to: url)
        return ClockStore(fileURL: url)
    }
    func csv(_ name: String, _ rows: [(Double, Double)], source: String = "starfleet") -> URL {
        let iso = ISO8601DateFormatter()
        var text = "Start Time,End Time,Duration,Notes,Time Sheet Source\n"
        for (from, to) in rows {
            text += "\(iso.string(from: at(from))),\(iso.string(from: at(to))),\(Int((to - from) * 60_000)),,\(source)\n"
        }
        let url = dir.appending(path: "\(name).csv")
        try! text.write(to: url, atomically: true, encoding: .utf8)
        return url
    }
    @MainActor func hours(_ s: ClockStore) -> Double { s.sessions.reduce(0) { $0 + $1.duration } / 3600 }

    // 1. Asil hata: eski surumun isaretsiz biraktigi kaydin uzerine duzeltilmis CSV.
    do {
        let s = store("legacy", [row(0, 508, source: "starfleet")])          // 11:12 -> 19:40
        let url = csv("corrected", [(0, 513)])                                 // 11:12 -> 19:45
        let preview = try! CSVImporter.parse(data: Data(contentsOf: url), hourlyRate: 25)
        expect(s.compareImportedSessions(preview).items.first?.kind == .matched,
               "a corrected CSV row is previewed as an update, not as new work")
        s.importCSV(from: url)
        expect(s.sessions.count == 1, "re-importing a corrected CSV row does not append a second copy")
        expect(abs(hours(s) - 8.55) < 0.01, "the day keeps one shift's worth of hours")
        expect(s.sessions.first?.matchedExternalSource == "starfleet",
               "the healed record is linked for the next import")
    }

    // 2. Gercek sira: bos arsiv, CSV, sonra duzeltilmis CSV, sonra bir duzeltme daha.
    do {
        let s = store("sequence", [])
        s.importCSV(from: csv("first", [(0, 508)]))
        expect(s.sessions.count == 1, "the first CSV adds the row")
        s.importCSV(from: csv("second", [(0, 513)]))
        s.importCSV(from: csv("third", [(0, 518)]))
        expect(s.sessions.count == 1, "later corrections update the row instead of stacking copies")
    }

    // 3. Sayac kaydi eskisi gibi dokumle duzeltilir.
    do {
        let s = store("timer", [row(0, 508, source: "Clockin")])
        s.importCSV(from: csv("official", [(0, 513)]))
        expect(s.sessions.count == 1, "a timer entry is still corrected by the official row")
    }

    // 4-7. Fazla eslestirme olmamali.
    do {
        let s = store("shifts", [row(-132, -12, source: "starfleet")])        // 09:00 -> 11:00
        s.importCSV(from: csv("afternoon", [(168, 408)]))                     // 14:00 -> 18:00
        expect(s.sessions.count == 2, "two separate shifts on one day stay separate")
    }
    do {
        let s = store("brief", [row(-132, 108, source: "starfleet")])         // 09:00 -> 13:00
        s.importCSV(from: csv("brief", [(78, 318)]))                          // 12:30 -> 16:30
        expect(s.sessions.count == 2, "a brief overlap is not treated as the same work")
    }
    do {
        let s = store("employer", [row(0, 508, source: "starfleet")])
        s.importCSV(from: csv("acme", [(0, 513)], source: "acme"))
        expect(s.sessions.count == 2, "another employer's timecard does not absorb this record")
    }
    do {
        let s = store("nextday", [row(0, 508, source: "starfleet")])
        s.importCSV(from: csv("nextday", [(1440, 1953)]))
        expect(s.sessions.count == 2, "the same hours on the next day are a different session")
    }

    // 8. Birebir ayni satir yine atlanir.
    do {
        let s = store("identical", [row(0, 508, source: "starfleet")])
        s.importCSV(from: csv("identical", [(0, 508)]))
        expect(s.sessions.count == 1, "an identical row is still skipped")
    }

    // 9. Ayni dosyada ayni isin iki yazimi tek kayit olur; onizleme de ayni seyi soyler.
    do {
        let s = store("samefile", [])
        let url = csv("twice", [(0, 508), (0, 513)])
        let preview = s.compareImportedSessions(try! CSVImporter.parse(data: Data(contentsOf: url), hourlyRate: 25))
        expect(preview.items.map(\.kind) == [.new, .duplicate], "the preview marks the second writing as a duplicate")
        s.importCSV(from: url)
        expect(s.sessions.count == 1, "two near-identical rows in one file import as one session")
    }

    print("all re-import checks passed")
}
