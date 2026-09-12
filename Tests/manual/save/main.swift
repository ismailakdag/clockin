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
        .appending(path: "clockin-save-test-\(UUID().uuidString)", directoryHint: .isDirectory)
    try! FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    defer {
        try? FileManager.default.setAttributes([.posixPermissions: 0o700], ofItemAtPath: dir.path)
        try? FileManager.default.removeItem(at: dir)
    }

    let start = Date(timeIntervalSince1970: 1_780_000_000)
    let end = start.addingTimeInterval(3_600)
    let id = UUID()
    var stored = ClockinData()
    stored.sessions = [WorkSession(id: id, start: start, end: end, duration: 3_600,
                                   note: "", hourlyRate: 30, source: "Clockin")]
    let fileURL = dir.appending(path: "clockin.json")
    try! JSONEncoder().encode(stored).write(to: fileURL)

    let store = ClockStore(fileURL: fileURL)
    expect(store.sessions.count == 1, "the stored entry should load")

    // Klasoru yazmaya kapatiyoruz: atomik yazma ayni klasore gecici dosya
    // actigi icin basarisiz oluyor.
    try! FileManager.default.setAttributes([.posixPermissions: 0o500], ofItemAtPath: dir.path)

    // Once duzenleme: kayit hala yerinde oldugu icin `save()`'e kadar gidiyor.
    expect(store.updateSession(id: id, start: start, end: end.addingTimeInterval(600), note: "later"),
           "the edit still applies in memory")
    expect(store.statusMessage?.contains("Could not save") == true,
           "a write that failed must not be reported as an update")

    store.statusMessage = nil
    store.deleteSession(id: id)
    expect(store.statusMessage?.contains("Could not save") == true,
           "a write that failed must not be reported as a deletion either")

    try! FileManager.default.setAttributes([.posixPermissions: 0o700], ofItemAtPath: dir.path)
    expect(ClockStore(fileURL: fileURL).sessions.count == 1,
           "the entry the disk still holds should come back on reload")
}

print("save reporting checks passed")
