import AppKit
import Foundation

// ClockStore'u uygulamanin geri kalani olmadan derleyebilmek icin: gercek
// sabitlenmis pencere SwiftUI ve AppKit penceresi getiriyor, testte gerekmez.
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
}

MainActor.assumeIsolated {
    let dir = FileManager.default.temporaryDirectory
        .appending(path: "clockin-store-test-\(UUID().uuidString)", directoryHint: .isDirectory)
    try! FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: dir) }

    // Not duzenlemek calisilan sureyi degistirmemeli: 3 saatlik aralikta
    // 1 saat mola verilmis bir kayit 2 saat olarak kalmali.
    let start = Date(timeIntervalSince1970: 1_780_000_000)
    let end = start.addingTimeInterval(3 * 3600)
    let id = UUID()
    var data = ClockinData()
    data.sessions = [WorkSession(id: id, start: start, end: end, duration: 2 * 3600,
                                 note: "", hourlyRate: 30, source: "Clockin")]
    let editURL = dir.appending(path: "edit.json")
    try! JSONEncoder().encode(data).write(to: editURL)

    let store = ClockStore(fileURL: editURL)
    expect(store.updateSession(id: id, start: start, end: end, note: "note only"), "note-only edit should save")
    expect(store.sessions[0].duration == 7_200, "note-only edit should keep the worked duration")
    expect(ClockStore(fileURL: editURL).sessions[0].duration == 7_200, "kept duration should persist")
    expect(store.updateSession(id: id, start: start, end: end.addingTimeInterval(3600), note: "later"),
           "moving the end time should save")
    expect(store.sessions[0].duration == 3 * 3600, "moving the end time should keep the one hour break")
    expect(!store.updateSession(id: id, start: start, end: start.addingTimeInterval(1800), note: ""),
           "times shorter than the break should be rejected")

    // Okunamayan dosyanin uzerine yazilmamali; kopyasi kenarda kalmali.
    let corruptURL = dir.appending(path: "corrupt.json")
    let garbage = Data("{ not json".utf8)
    try! garbage.write(to: corruptURL)
    let recovered = ClockStore(fileURL: corruptURL)
    let copies = (try? FileManager.default.contentsOfDirectory(atPath: dir.path))?
        .filter { $0.hasPrefix("clockin-unreadable-") } ?? []
    expect(copies.count == 1, "an unreadable file should be copied aside")
    expect((try? Data(contentsOf: dir.appending(path: copies[0]))) == garbage, "the copy should hold the original bytes")
    expect(recovered.statusMessage?.contains("could not be read") == true, "the user should be told the data could not be read")

    // Dosya hic yoksa ilk kurulumdur: uyari yok.
    let fresh = ClockStore(fileURL: dir.appending(path: "missing/clockin.json"))
    expect(fresh.statusMessage == nil, "a missing file is a fresh start, not an error")
}

print("store checks passed")
