import Foundation

@main
struct PasteboardValidation {
    static func main() throws {
        let data = FileHandle.standardInput.readDataToEndOfFile()
        let text = String(data: data, encoding: .utf8) ?? ""
        let sessions = try PastedTextImporter.parse(text, hourlyRate: 35)
        print("Paste parsed: \(sessions.count) sessions, \(DurationText.compact(sessions.reduce(0) { $0 + $1.duration })).")
    }
}
