import Foundation

var passed = 0
@MainActor func check(_ condition: @autoclosure () -> Bool, _ message: String) {
    guard condition() else {
        FileHandle.standardError.write(Data("FAILED: \(message)\n".utf8))
        exit(1)
    }
    passed += 1
    print("ok: \(message)")
}

func close(_ a: Double, _ b: Double) -> Bool { abs(a - b) < 0.000_1 }

let t0 = Date(timeIntervalSince1970: 1_000_000)
func at(_ seconds: TimeInterval) -> Date { t0.addingTimeInterval(seconds) }

// Onceki calismadan olculmus sureler: toplam 100 saniye.
let expected: [UpdateProgress.Step: TimeInterval] = [
    .fetch: 5, .buildAppleSilicon: 40, .buildIntel: 40, .package: 10, .install: 5,
]

var progress = UpdateProgress(expected: expected)
check(progress.step == nil && progress.fraction(at: at(30)) == 0, "nothing moves before the first step")

progress.consume("From https://github.com/ismailakdag/clockin", at: at(0))
check(progress.step == nil, "ordinary output is not a step")

progress.consume("::clockin-step fetch", at: at(0))
check(progress.step == .fetch && progress.stepNumber == 1, "a step marker starts that step")
check(progress.fraction(at: at(0)) == 0, "a step that just started has no progress")

progress.consume("::clockin-step build-arm64", at: at(5))
check(progress.measured[.fetch] == 5, "the finished step's real duration is measured")
check(close(progress.fraction(at: at(5)), 0.05), "the build starts after the fetch's share of the time")

check(close(progress.fraction(at: at(25)), 0.05 + 0.40 * 0.45), "halfway through the expected build time is 45% of the build")
check(close(progress.fraction(at: at(45)), 0.05 + 0.40 * 0.9), "at the expected time the build shows 90%, not done")

let late = progress.fraction(at: at(85))
let later = progress.fraction(at: at(485))
check(late > progress.fraction(at: at(45)) && later > late, "a build that runs long keeps moving")
check(later < 0.05 + 0.40, "and never reaches the next step on its own")

// Sayac satirlari bir saniyede sona gelir ama asil derleme son adimda gecer.
progress.consume("[22/23] Linking Clockin", at: at(6))
check(close(progress.fraction(at: at(6)), 0.05 + 0.40 * 0.9 / 40), "build counters do not jump the bar")

progress.consume("::clockin-step build-x86_64", at: at(20))
check(progress.measured[.buildAppleSilicon] == 15, "a build shorter than expected is measured as such")
check(close(progress.fraction(at: at(20)), 0.45), "a step that ends early jumps to the next step's start")

progress.consume("::clockin-step something-new", at: at(21))
check(progress.step == .buildIntel && progress.stepStartedAt == at(20), "an unknown step name changes nothing")

progress.consume("::clockin-step install", at: at(60))
check(progress.stepNumber == 5 && close(progress.fraction(at: at(60)), 0.95), "the last step starts at its share")

progress.consume("::clockin-error Local changes conflict with the latest version.", at: at(61))
check(progress.errorMessage == "Local changes conflict with the latest version.", "an error marker carries a readable reason")

let unmeasured = UpdateProgress()
check(unmeasured.expectedDuration(of: .buildIntel) == UpdateProgress.Step.buildIntel.defaultDuration,
      "without a previous run the default estimate is used")
check(UpdateProgress(expected: [.fetch: 0]).expectedDuration(of: .fetch) == 0.5,
      "a zero measurement cannot divide by zero")

check(UpdateProgress.share(elapsed: 0, expected: 10) == 0, "no time, no share")
check(close(UpdateProgress.share(elapsed: 10, expected: 10), 0.9), "the eased share is continuous at the expected time")
check(UpdateProgress.share(elapsed: 1_000_000, expected: 10) < 1, "the eased share never reaches the whole step")

print("\(passed) update progress checks passed")
