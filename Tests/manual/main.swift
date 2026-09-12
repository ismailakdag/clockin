import Foundation

func expect(_ condition: @autoclosure () -> Bool, _ message: String) {
    guard condition() else {
        FileHandle.standardError.write(Data("FAILED: \(message)\n".utf8))
        exit(1)
    }
}

let csv = #""Date","Time Sheet Source","Start Time","End Time","Duration","Notes""# + "\n" +
    #""2026-08-03","starfleet","2026-08-03T18:48:00.000Z","2026-08-03T21:01:00.000Z","7980000","Project, with comma""#
let sessions = try CSVImporter.parse(data: Data(csv.utf8), hourlyRate: 30)
expect(sessions.count == 1, "one CSV row should import")
expect(sessions[0].duration == 7_980, "duration should convert milliseconds to seconds")
expect(sessions[0].note == "Project, with comma", "quoted commas should parse")
expect(sessions[0].source == "starfleet", "source should be retained")
expect(sessions[0].earnings == 66.5, "earnings should use imported duration and rate")

let running = RunningSession(
    start: Date(timeIntervalSince1970: 100),
    accumulated: 40,
    resumedAt: Date(timeIntervalSince1970: 200),
    note: ""
)
expect(running.elapsed(at: Date(timeIntervalSince1970: 230)) == 70, "pause/resume elapsed math")

let rows = CSVImporter.parseRows("a,b\n1,\"hello \"\"world\"\"\"")
expect(rows[1][1] == "hello \"world\"", "escaped CSV quotes")
let windowsRows = CSVImporter.parseRows("a,b\r\n1,2\r\n")
expect(windowsRows.count == 2, "CRLF exports should split into rows")

let pasted = """
Dec 31, 2025 - Aug 31, 2026
Saturday
January 17
Approved
Starfleet
15:20
15:22
2
M
Friday
January 23
Approved
Starfleet
23:26
23:48
22
M
"""
let parserNow = Calendar.current.date(from: DateComponents(year: 2025, month: 7, day: 1))!
let pastedSessions = try PastedTextImporter.parse(pasted, hourlyRate: 30, now: parserNow)
expect(pastedSessions.count == 2, "full-page pasted rows should parse")
expect(pastedSessions[0].duration == 120, "pasted start and end times should define duration")
expect(Calendar.current.component(.year, from: pastedSessions[0].start) == 2026, "date range should infer entry year")

let joinedPageRows = """
HomePlanner Clock Out 10 M
Jan 01, 2026 - Aug 31, 2026
FridayJanuary 23
Approved
Starfleet
09:00
09:25
25
M
SaturdayJanuary 24
Approved
Starfleet
00:07
00:13
6
M
"""
let joinedSessions = try PastedTextImporter.parse(joinedPageRows, hourlyRate: 35, now: parserNow)
expect(joinedSessions.count == 2, "joined weekday/date page rows should parse")
expect(joinedSessions.reduce(0) { $0 + $1.duration } == 1_860, "joined page durations should be accurate")
expect(PastedTextImporter.approvedSummaryDuration(in: "Total 218h 56m Approved 55h 46m Submitted") == 788_160,
       "page approved summary should parse separately from visible rows")

if CommandLine.arguments.count > 1 {
    let realData = try Data(contentsOf: URL(fileURLWithPath: CommandLine.arguments[1]))
    let realSessions = try CSVImporter.parse(data: realData, hourlyRate: 30)
    expect(!realSessions.isEmpty, "provided CSV should contain valid sessions")
    print("Provided CSV parsed: \(realSessions.count) sessions, \(DurationText.compact(realSessions.reduce(0) { $0 + $1.duration })).")
}

// money() bir donem `.fractionLength(2...maxFractionDigits)` kullandi.
// Heatmap kazanc etiketi bunu 0 ile cagiriyor, yani aralik `2...0` oluyordu:
// gecersiz bir ClosedRange ve calisma aninda cokme. Asagidaki matris o
// cagriyi da kapsiyor — cokerse bu betik zaten hic bitmez — ve ciktinin
// esdeger yapilandirilmis bir NumberFormatter ile ayni kalmasini bekler.
func referenceMoney(_ value: Double, code: String, maxFractionDigits: Int) -> String {
    let formatter = NumberFormatter()
    formatter.numberStyle = .currency
    formatter.currencyCode = code
    formatter.maximumFractionDigits = max(0, maxFractionDigits)
    formatter.minimumFractionDigits = min(2, formatter.maximumFractionDigits)
    return formatter.string(from: NSNumber(value: value)) ?? ""
}

for digits in [0, 1, 2, 4] {
    for value in [0.0, 0.0069, 12.5, 99.6, 1234.0, 2158.52] {
        for code in ["USD", "TRY"] {
            let produced = value.money(code: code, maxFractionDigits: digits)
            expect(produced == referenceMoney(value, code: code, maxFractionDigits: digits),
                   "money(\(value), \(code), maxFractionDigits: \(digits)) gave \(produced)")
            expect(!produced.isEmpty,
                   "money(\(value), \(code), maxFractionDigits: \(digits)) should not be empty")
        }
    }
}

// Varsayilan iki ondalik olmali; kazanc gosterimlerinin cogu bunu kullaniyor.
expect(12.5.money(code: "USD") == referenceMoney(12.5, code: "USD", maxFractionDigits: 2),
       "default maxFractionDigits should stay at two")

// Yapistirilan sayfada donem araligi ters yazilabilir. Eskiden bu satir
// `start...end` kurarken cokuyordu; artik aralik yok sayilip yil bugunden
// cikariliyor.
let reversedRange = """
Aug 31, 2026 - Dec 31, 2025
Saturday
January 17
Approved
Starfleet
15:20
15:22
2
"""
// now: 1 Haziran 2026, yani 17 Ocak geride kalmis bir gun.
let reversedSessions = try PastedTextImporter.parse(
    reversedRange, hourlyRate: 30, now: Date(timeIntervalSince1970: 1_780_272_000))
expect(reversedSessions.count == 1, "a reversed period range should not stop the import")
expect(Calendar.current.component(.year, from: reversedSessions[0].start) == 2026,
       "with the range ignored, the year comes from today")

print("All manual validation tests passed.")
