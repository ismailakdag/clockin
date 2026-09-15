import Foundation

var passed = 0
@MainActor func check(_ condition: Bool, _ message: String) {
    guard condition else {
        FileHandle.standardError.write(Data("FAILED: \(message)\n".utf8))
        exit(1)
    }
    passed += 1
    print("ok: \(message)")
}

func status(running: Bool = true, paused: Bool = false, elapsed: TimeInterval = 4062, earnings: Double = 28.2,
            currency: String = "USD", rate: Double? = 41.2, today: TimeInterval = 7200, month: TimeInterval = 72000,
            daily: Double = 0, monthly: Double = 0, fields: MenuBarStatus.Fields = .init()) -> MenuBarStatus {
    MenuBarStatus.make(isRunning: running, isPaused: paused, sessionElapsed: elapsed, sessionEarnings: earnings,
                       currencyCode: currency, tryRate: rate, todayDuration: today, monthDuration: month,
                       dailyGoalHours: daily, monthlyGoalHours: monthly, fields: fields)
}

// Not clocked in: icon only, whatever was worked earlier today.
let idle = status(running: false, today: 3 * 3600)
check(idle.state == .idle && idle.text == nil, "not clocked in shows only the idle icon, no 0m or $0")
var everything = MenuBarStatus.Fields(); everything.goal = true
check(status(running: false, daily: 8, fields: everything).text == nil, "not even goal percentages when idle")

// Clocked in: the session timer counts.
let running = status()
check(running.state == .running, "a running session uses the running icon")
check(running.text?.hasPrefix("01:07") == true, "the session timer leads, as hours and minutes by default")
check(!(running.text ?? "").contains("T "), "no T prefix")
check(running.text?.contains("$28") == true && (running.text?.contains("₺1.162") == true || running.text?.contains("₺1,162") == true), "earnings and the lira equivalent follow")

var withSeconds = MenuBarStatus.Fields(); withSeconds.seconds = true
check(status(fields: withSeconds).text?.hasPrefix("01:07:42") == true, "seconds appear when chosen")

let paused = status(paused: true)
check(paused.state == .paused && paused.text == running.text, "paused keeps the frozen timer and uses the paused icon")

var nothing = MenuBarStatus.Fields(); nothing.hours = false; nothing.earnings = false; nothing.tryEquivalent = false
check(status(fields: nothing).text == nil && status(fields: nothing).state == .running, "with every field off a running session is icon only")

check(!(status(currency: "EUR").text ?? "").contains("₺"), "the lira equivalent is only for USD accounts")
check(!(status(rate: nil).text ?? "").contains("₺"), "no lira equivalent before a rate is known")

var goals = MenuBarStatus.Fields(); goals.goal = true
check(status(today: 4 * 3600, daily: 8, fields: goals).text?.contains("D 50%") == true, "daily goal percent while running")
check(MenuBarStatus.goalPercent(99 * 3600, goal: 1) == 999, "goal percent is capped")

print("\(passed) menu bar status checks passed")
