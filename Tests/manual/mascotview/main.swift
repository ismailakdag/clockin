// From the repository root: bash Tests/manual/mascotview/run
// Plays the real `ClockinMotionMascot` for every mood in a throwaway window
// (no app launch, no real data) and reads what Core Animation is showing:
// drawn clips keep changing, standing moods sway, a tap hop rises and lands
// smoothly, a hidden window stops, and playing costs almost no CPU.
// Writes Tests/manual/mascotview/preview.png: a hop filmstrip per mood.
import AppKit
import SwiftUI

@MainActor
final class AppDependencies {
    static let shared = AppDependencies()
    let store = ClockStore(fileURL: FileManager.default.temporaryDirectory
        .appendingPathComponent("unused-mascot-\(UUID().uuidString).json"))
    let exchangeRates = ExchangeRateStore()
}

var passed = 0
@MainActor func check(_ condition: Bool, _ message: String) {
    guard condition else {
        FileHandle.standardError.write(Data("FAILED: \(message)\n".utf8))
        exit(1)
    }
    passed += 1
    print("ok: \(message)")
}

func spin(_ seconds: TimeInterval) {
    RunLoop.main.run(until: Date(timeIntervalSinceNow: seconds))
}

func cpuSeconds() -> Double {
    var usage = rusage()
    getrusage(RUSAGE_SELF, &usage)
    return Double(usage.ru_utime.tv_sec) + Double(usage.ru_utime.tv_usec) / 1e6 + Double(usage.ru_stime.tv_sec) + Double(usage.ru_stime.tv_usec) / 1e6
}

@MainActor func findLayerView(in view: NSView) -> MascotLayerView? {
    if let match = view as? MascotLayerView { return match }
    for child in view.subviews { if let match = findLayerView(in: child) { return match } }
    return nil
}

/// Renders what is on screen now, animations included.
@MainActor func filmFrame(_ view: NSView) -> CGImage {
    let side = 120, scale = 2
    let context = CGContext(data: nil, width: side * scale, height: side * scale, bitsPerComponent: 8, bytesPerRow: side * scale * 4,
                            space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
    context.scaleBy(x: CGFloat(scale), y: CGFloat(scale))
    // The hosting view's layer tree is flipped relative to Core Graphics.
    if view.isFlipped {
        context.translateBy(x: 0, y: CGFloat(side))
        context.scaleBy(x: 1, y: -1)
    }
    (view.layer!.presentation() ?? view.layer!).render(in: context)
    return context.makeImage()!
}

@MainActor final class ReactionBox: ObservableObject {
    @Published var tap: MascotTap?
    func click(_ reaction: MascotReaction) { tap = MascotTap(id: (tap?.id ?? 0) + 1, reaction: reaction) }
}

struct ReactionHost: View {
    let mood: MascotMood
    @ObservedObject var box: ReactionBox
    var body: some View {
        ClockinMotionMascot(mood: mood, tap: box.tap)
            .frame(width: 120, height: 120)
    }
}

let app = NSApplication.shared
app.setActivationPolicy(.accessory)
app.finishLaunching()
check(MascotFrames.shared.library != nil, "the app bundle has the mascot clip manifest")

var strips: [[CGImage]] = []
var info: [String] = []

// The angry frames ship only in the iPhone app (MascotMotion.swift is shared);
// the Mac app never shows that mood.
for mood in MascotMood.allCases where mood != .angry {
    let window = NSWindow(contentRect: NSRect(x: 80, y: 80, width: 120, height: 120), styleMask: [.borderless], backing: .buffered, defer: false)
    window.isOpaque = false
    window.backgroundColor = .clear
    let box = ReactionBox()
    let hosting = NSHostingView(rootView: ReactionHost(mood: mood, box: box))
    window.contentView = hosting
    window.orderFrontRegardless()
    spin(1.0)
    guard let layers = findLayerView(in: hosting) else { check(false, "\(mood): the mascot is drawn with layers"); exit(1) }
    let clips = MascotFrames.shared.library![mood]
    check(layers.bodyContents != nil, "\(mood): the rest frame is showing")

    // Drawn clips and sway over six seconds.
    var shownFrames = Set<ObjectIdentifier>()
    var swayLifts: [Double] = []
    for _ in 0..<120 {
        spin(0.05)
        if let image = layers.bodyContents { shownFrames.insert(ObjectIdentifier(image)) }
        swayLifts.append(layers.presentedSwayTransform.m42)
    }
    check(shownFrames.count > 1, "\(mood): drawn clips play (\(shownFrames.count) different frames in 6 s)")
    let swayRange = (swayLifts.max() ?? 0) - (swayLifts.min() ?? 0)
    if clips.standing {
        check(swayRange > 0.3 && swayRange < 2, "\(mood): a standing mascot sways gently (\(String(format: "%.2f", swayRange)) pt)")
    } else {
        check(swayRange < 0.01, "\(mood): a sitting mascot does not sway")
    }

    // CPU while playing, nothing sampling: Core Animation plays the motion.
    let cpuStart = cpuSeconds(), wallStart = Date()
    spin(5)
    let cpu = (cpuSeconds() - cpuStart) / Date().timeIntervalSince(wallStart) * 100
    info.append("\(mood.rawValue): \(String(format: "%.1f", cpu))% CPU while playing")
    check(cpu < 8, "\(mood): playing costs little CPU (\(String(format: "%.1f", cpu))%)")

    // A click hop (the wave reaction, height 0.9), sampled at 60 fps.
    box.click(.wave)
    var lifts: [Double] = []
    var film: [CGImage] = []
    let hopStart = Date()
    while Date().timeIntervalSince(hopStart) < 1.3 {
        spin(1.0 / 60)
        lifts.append(layers.presentedBodyTransform.m42)
        if film.count < 12, lifts.count % 6 == 1 { film.append(filmFrame(hosting)) }
    }
    strips.append(film)
    let peak = lifts.max() ?? 0
    // 6.5% × 0.9 × 1.08 of 120 pt.
    check(peak > 6.5 && peak < 9, "\(mood): a click hop rises \(String(format: "%.1f", peak)) pt, about 6% of the mascot")
    // The take-off is fast by design (about 150 pt/s at 120 pt); a jump would
    // show as a step far larger than that speed allows between samples.
    let steps = zip(lifts, lifts.dropFirst()).map { abs($0 - $1) }
    check((steps.max() ?? 0) < 3.5, "\(mood): the hop moves smoothly (largest step \(String(format: "%.2f", steps.max() ?? 0)) pt between 60 fps samples)")
    check(abs(lifts.last ?? 1) < 0.05, "\(mood): the mascot lands back on the ground")
    check(lifts.contains { $0 < -0.5 }, "\(mood): the hop dips into its landing squash")

    // The other click motions: a shake, a squash and a double hop.
    box.click(.wiggle)
    var turns: [Double] = []
    for _ in 0..<50 { spin(1.0 / 60); let t = layers.presentedReactionTransform; turns.append(atan2(t.m12, t.m11) * 180 / .pi) }
    check((turns.map(abs).max() ?? 0) > 4, "\(mood): a wiggle click shakes the mascot (up to \(String(format: "%.1f", turns.map(abs).max() ?? 0))°)")
    spin(0.3)
    box.click(.squash)
    var squashes: [Double] = []
    for _ in 0..<45 { spin(1.0 / 60); squashes.append(layers.presentedReactionTransform.m22) }
    check((squashes.min() ?? 1) < 0.92 && abs(layers.presentedReactionTransform.m22 - 1) < 0.02, "\(mood): a squash click flattens and settles")
    spin(0.3)
    box.click(.doubleHop)
    var doubleLifts: [Double] = []
    let doubleStart = Date()
    while Date().timeIntervalSince(doubleStart) < 2.1 { spin(1.0 / 60); doubleLifts.append(layers.presentedBodyTransform.m42) }
    var takeoffs = 0
    for (a, b) in zip(doubleLifts, doubleLifts.dropFirst()) where a < 3 && b >= 3 { takeoffs += 1 }
    check(takeoffs == 2, "\(mood): a double-hop click hops twice (\(takeoffs))")

    // Hidden: the drawn frames stop; shown again: they resume.
    window.orderOut(nil)
    spin(0.5)
    let hiddenFrame = layers.bodyContents.map(ObjectIdentifier.init)
    var hiddenChanged = false
    let hiddenCPUStart = cpuSeconds(), hiddenWall = Date()
    for _ in 0..<30 {
        spin(0.1)
        if layers.bodyContents.map(ObjectIdentifier.init) != hiddenFrame { hiddenChanged = true }
    }
    let hiddenCPU = (cpuSeconds() - hiddenCPUStart) / Date().timeIntervalSince(hiddenWall) * 100
    check(!hiddenChanged, "\(mood): a hidden window stops swapping frames")
    info.append("\(mood.rawValue): \(String(format: "%.1f", hiddenCPU))% CPU while hidden")
    window.orderFrontRegardless()
    var resumed = Set<ObjectIdentifier>()
    for _ in 0..<80 {
        spin(0.1)
        if let image = layers.bodyContents { resumed.insert(ObjectIdentifier(image)) }
        if resumed.count > 1 { break }
    }
    check(resumed.count > 1, "\(mood): showing the window again resumes the clips")
    window.orderOut(nil)
}

let cell = 120 * 2, columns = strips.map(\.count).max() ?? 1
let sheet = CGContext(data: nil, width: columns * cell, height: strips.count * cell, bitsPerComponent: 8, bytesPerRow: columns * cell * 4,
                      space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
sheet.setFillColor(CGColor(red: 0.07, green: 0.08, blue: 0.1, alpha: 1))
sheet.fill(CGRect(x: 0, y: 0, width: columns * cell, height: strips.count * cell))
for (row, strip) in strips.enumerated() {
    for (column, image) in strip.enumerated() {
        sheet.draw(image, in: CGRect(x: column * cell, y: (strips.count - 1 - row) * cell, width: cell, height: cell))
    }
}
let destination = CGImageDestinationCreateWithURL(URL(fileURLWithPath: "Tests/manual/mascotview/preview.png") as CFURL, "public.png" as CFString, 1, nil)!
CGImageDestinationAddImage(destination, sheet.makeImage()!, nil)
CGImageDestinationFinalize(destination)

info.forEach { print("info: \($0)") }
print("\(passed) mascot view checks passed")
