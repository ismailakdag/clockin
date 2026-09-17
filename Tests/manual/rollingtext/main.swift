// Checks RollingText in a throwaway window: its size matches a plain Text,
// only changed characters roll, rising values roll up, falling ones down, the
// animation belongs to Core Animation, and Reduce Motion-style updates swap
// the characters without animating.
//
// swiftc -swift-version 6 Sources/Clockin/RollingText.swift Tests/manual/rollingtext/main.swift -o /tmp/clockin-rollingtext-tests && /tmp/clockin-rollingtext-tests
import AppKit
import SwiftUI

var passed = 0
@MainActor func check(_ condition: Bool, _ message: String) {
    guard condition else {
        FileHandle.standardError.write(Data("FAILED: \(message)\n".utf8))
        exit(1)
    }
    passed += 1
}
func spin(_ seconds: TimeInterval) { RunLoop.main.run(until: Date(timeIntervalSinceNow: seconds)) }

let app = NSApplication.shared
app.setActivationPolicy(.accessory)
app.finishLaunching()

// Width matches SwiftUI's own layout of the same string and font.
for (text, size, weight, design) in [("01:07:59", 36.0, Font.Weight.medium, Font.Design.default),
                                     ("$1,234.56", 20.0, .semibold, .rounded),
                                     ("₺1.168,81", 12.0, .regular, .monospaced)] {
    let font = RollingText.font(size: size, weight: weight, design: design)
    let rolling = RollingTextLayerView.size(of: text, font: font, tracking: 0)
    let plain = NSHostingView(rootView: Text(text).font(.system(size: size, weight: weight, design: design)).monospacedDigit().fixedSize())
    let fitting = plain.fittingSize
    check(abs(rolling.width - fitting.width) <= 1.5, "\(text): width \(rolling.width) vs Text \(fitting.width)")
    check(abs(rolling.height - fitting.height) <= 2, "\(text): height \(rolling.height) vs Text \(fitting.height)")
}

let window = NSWindow(contentRect: NSRect(x: 80, y: 80, width: 300, height: 80), styleMask: [.borderless], backing: .buffered, defer: false)
let view = RollingTextLayerView(frame: NSRect(x: 10, y: 10, width: 260, height: 50))
window.contentView = NSView(frame: window.contentRect(forFrameRect: window.frame))
window.contentView!.addSubview(view)
window.orderFrontRegardless()
let font = RollingText.font(size: 36, weight: .medium, design: .default)
let white = CGColor(gray: 1, alpha: 1)

func texts() -> [String] {
    (view.layer?.sublayers ?? []).compactMap { ($0 as? CATextLayer)?.string as? NSAttributedString }.map(\.string)
}
func rolling() -> [CATextLayer] {
    (view.layer?.sublayers ?? []).compactMap { $0 as? CATextLayer }.filter { $0.animation(forKey: "roll") != nil }
}

view.update(text: "01:07:59", value: 4079, font: font, tracking: 0, color: white, animated: true)
spin(0.1)
check(texts().joined() == "01:07:59", "first layout draws every character")
check(rolling().isEmpty, "the first layout does not animate")

view.update(text: "01:08:00", value: 4080, font: font, tracking: 0, color: white, animated: true)
let moving = rolling()
check(moving.count == 6, "three changed characters roll: three in, three out (got \(moving.count))")
let incoming = moving.filter { $0.opacity == 1 }
let outgoing = moving.filter { $0.opacity == 0 }
check(Set(incoming.compactMap { ($0.string as? NSAttributedString)?.string }) == ["8", "0"], "the new characters are 8, 0, 0")
check(incoming.count == 3 && outgoing.count == 3, "three enter and three leave")
spin(0.08)
if let entering = incoming.first, let presented = entering.presentation() {
    check(presented.position.y > entering.position.y + 1, "a rising value enters from below (flipped y \(presented.position.y) vs \(entering.position.y))")
    check(presented.opacity < 1, "entering characters fade in")
}
spin(0.5)
check(texts().joined() == "01:08:00", "after the roll only the new characters remain: \(texts())")
check(rolling().isEmpty, "the roll finishes")

view.update(text: "01:07:59", value: 4079, font: font, tracking: 0, color: white, animated: true)
if let entering = rolling().first(where: { $0.opacity == 1 }) {
    spin(0.08)
    check((entering.presentation()?.position.y ?? 0) < entering.position.y - 1, "a falling value enters from above")
} else { check(false, "a falling value rolls") }
spin(0.5)

view.update(text: "01:08:00", value: 4080, font: font, tracking: 0, color: white, animated: false)
check(rolling().isEmpty && texts().joined() == "01:08:00", "without animation the characters swap at once")
view.update(text: "10:08:00", value: 36480, font: font, tracking: 0, color: white, animated: true)
check(rolling().count == 4, "same length rolls only the changed digits")
spin(0.5)
view.update(text: "100:08:00", value: 360480, font: font, tracking: 0, color: white, animated: true)
check(rolling().isEmpty && texts().joined() == "100:08:00", "a longer string is laid out afresh")

// Cost: a second-by-second tick for five seconds stays cheap.
func cpu() -> Double {
    var usage = rusage(); getrusage(RUSAGE_SELF, &usage)
    return Double(usage.ru_utime.tv_sec + usage.ru_stime.tv_sec) + Double(usage.ru_utime.tv_usec + usage.ru_stime.tv_usec) / 1e6
}
let start = cpu()
for second in 0..<5 {
    view.update(text: String(format: "100:08:%02d", second + 1), value: Double(360481 + second), font: font, tracking: 0, color: white, animated: true)
    spin(1)
}
let percent = (cpu() - start) / 5 * 100
check(percent < 10, String(format: "ticking costs %.1f%% CPU", percent))
print(String(format: "%d rolling text checks passed (tick CPU %.1f%%)", passed, percent))
