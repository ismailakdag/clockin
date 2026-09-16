// swiftc -swift-version 6 Sources/Clockin/MascotMotion.swift Tests/manual/mascotmotion/main.swift -o /tmp/clockin-mascotmotion-tests && /tmp/clockin-mascotmotion-tests
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

/// Deterministic, so the checks never flake.
struct SplitMix: RandomNumberGenerator {
    var state: UInt64
    mutating func next() -> UInt64 {
        state &+= 0x9E3779B97F4A7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58476D1CE4E5B9
        z = (z ^ (z >> 27)) &* 0x94D049BB133111EB
        return z ^ (z >> 31)
    }
}

// The manifest the app ships, when present; otherwise a small sample.
let shipped = URL(fileURLWithPath: "Sources/Clockin/Assets/Mascot/loops/mascot-clips.json")
let sample = """
{"hello":{"rest":"h01","standing":true,"clips":{"blink":[["h01",0],["h10",100],["h01",0]],"glow":[["h01",0],["h08",160],["h01",0]]},"weights":{"blink":3,"glow":1,"hop":2,"missing":5}},
 "celebrate":{"rest":"e01","standing":true,"clips":{"blink":[["e01",0],["e07",160],["e01",0]]},"weights":{"blink":1,"hop":1}},
 "coffee":{"rest":"c01","standing":false,"clips":{"base":[["c01",1000],["c01",0]],"steam":[["c01",0],["c02",220],["c01",0]]},"weights":{"steam":1,"hop":4}},
 "working":{"rest":"t01","standing":false,"clips":{"base":[["t01",160],["t11",160],["t01",0]],"blink":[["t01",0],["t08",100],["t01",0]]},"weights":{"blink":1}}}
"""
let library = try MascotLibrary(data: Data(sample.utf8))
check(library[.hello].clips["blink"]?[1] == MascotStep("h10", 100), "steps decode from [frame, ms] pairs")
check(library[.hello].frames == ["h01", "h10", "h08"], "a mood knows every frame it can show")
check(library[.working].base?.last?.frame == "t01" && library[.hello].base == nil, "base cycles are only on typing and coffee")
check((try? MascotLibrary(data: Data(#"{"hello":{"rest":"h01","standing":true,"clips":{},"weights":{}}}"#.utf8))) == nil, "a manifest missing a mood is rejected")
if let data = try? Data(contentsOf: shipped) {
    let real = try MascotLibrary(data: data)
    check(MascotMood.allCases.allSatisfy { !real[$0].clips.isEmpty }, "the shipped manifest decodes with clips for every mood")
    check(real[.hello].standing && real[.celebrate].standing && !real[.coffee].standing && !real[.working].standing, "only hello and celebrate stand and sway")
}

// Director.
var random = SplitMix(state: 42)
var hello = MascotDirector(library[.hello])
var counts: [String: Int] = [:]
var previous: MascotEvent?
var repeated = false
for _ in 0..<30_000 {
    guard let event = hello.next(using: &random) else { continue }
    if event == previous || (previous.map { if case .hop = $0, case .hop = event { return true } else { return false } } ?? false) { repeated = true }
    previous = event
    switch event {
    case .clip(let name): counts[name, default: 0] += 1
    case .hop(let height):
        counts["hop", default: 0] += 1
        if !(0.8...1.1).contains(height) { repeated = true }
    }
}
check(!repeated, "the same event never plays twice in a row, and hop heights stay in range")
check(counts["missing"] == nil, "weights naming a missing clip are ignored")
check(Set(counts.keys) == ["blink", "glow", "hop"], "every available event gets played")
check(counts["blink"]! > counts["hop"]! && counts["hop"]! > counts["glow"]!, "heavier events play more often: \(counts)")

var coffee = MascotDirector(library[.coffee])
check((0..<200).allSatisfy { _ in coffee.next(using: &random).map { if case .hop = $0 { false } else { true } } ?? true }, "sitting moods never hop")
var skipped = 0
for _ in 0..<10_000 where coffee.skipsEvent(using: &random) { skipped += 1 }
check((4000...5000).contains(skipped), "base moods skip about 45% of event slots: \(skipped)")
check(!MascotDirector(library[.hello]).skipsEvent(using: &random), "moods without a base never skip")
let delays = (0..<1000).map { _ in hello.restDelay(using: &random) }
check(delays.allSatisfy { (0.7...2.1).contains($0) }, "rests between events last 0.7–2.1 s")

// Easing.
let ease = CubicBezier(0.25, 0.1, 0.25, 1)
check(abs(ease(0.5) - 0.8024) < 0.001, "cubic-bezier matches CSS ease at 0.5")
check(ease(0) == 0 && abs(ease(1) - 1) < 1e-9, "curves start at 0 and end at 1")
check(CubicBezier.linear(0.37) == 0.37, "linear is the identity")
let outSamples = stride(from: 0.0, through: 1.0, by: 0.01).map { CubicBezier.out($0) }
check(zip(outSamples, outSamples.dropFirst()).allSatisfy { $0 <= $1 + 1e-9 }, "ease-out never goes backwards")

// Hop.
check(MascotMotion.hop(progress: 0, height: 1) == .rest && MascotMotion.hop(progress: 1, height: 1) == .rest, "a hop starts and ends at rest")
let peak = MascotMotion.hop(progress: 0.56, height: 1)
check(abs(peak.offsetY + 0.065 * 1.08) < 1e-9, "the hop peaks at 7% of the mascot's height")
check(abs(MascotMotion.hop(progress: 0.8, height: 1).scaleY - 0.88) < 1e-9, "landing squashes to 88%")
check(abs(MascotMotion.hop(progress: 0.5, height: 1).shadowOpacity - 0.35) < 1e-9, "the shadow fades while the mascot is in the air")
check(abs(MascotMotion.hop(progress: 0.56, height: 1.15).offsetY) > abs(peak.offsetY), "a reaction hop goes higher")
/// The largest change between neighbouring samples of a hop.
func largestStep(samples: Int) -> Double {
    var jump = 0.0
    var last = MascotMotion.hop(progress: 0, height: 1.1)
    for step in 1...samples {
        let pose = MascotMotion.hop(progress: Double(step) / Double(samples), height: 1.1)
        jump = max(jump, abs(pose.offsetY - last.offsetY), abs(pose.scaleX - last.scaleX), abs(pose.scaleY - last.scaleY),
                   abs(pose.shadowScaleX - last.shadowScaleX), abs(pose.shadowOpacity - last.shadowOpacity))
        last = pose
    }
    return jump
}
// A jump would stay the same size however finely it is sampled; a steep but
// continuous curve halves when the samples double.
let coarse = largestStep(samples: 2000), fine = largestStep(samples: 4000)
check(coarse < 0.005 && fine < coarse * 0.6, "a hop is continuous, with no jumps: \(coarse) then \(fine)")
check(abs(MascotMotion.hopDuration(height: 1) - 0.94) < 1e-9, "a hop lasts 820 + 120 × height ms")

// Sway and pop.
let start = MascotMotion.sway(time: 0), end = MascotMotion.sway(time: MascotMotion.swayPeriod)
check(abs(start.offsetY) < 1e-9 && abs(start.rotationDegrees) < 1e-9 && abs(end.offsetY) < 1e-9 && abs(end.rotationDegrees) < 1e-9, "a sway cycle starts and ends at rest")
let swaySamples = stride(from: 0.0, to: MascotMotion.swayPeriod, by: 0.01).map { MascotMotion.sway(time: $0) }
check(swaySamples.allSatisfy { $0.offsetY <= 0 && $0.offsetY >= -0.0111 && abs($0.rotationDegrees) <= 0.8 + 1e-9 }, "sway rises at most 1.1% and rocks at most 0.8°")
check(abs(MascotMotion.pop(progress: 0) - 0.9) < 1e-9 && abs(MascotMotion.pop(progress: 0.6) - 1.035) < 1e-9 && abs(MascotMotion.pop(progress: 1) - 1) < 1e-9, "the pose-change pop goes 0.9 → 1.035 → 1")

let combined = MascotMotion.pose(hopProgress: 0.56, hopHeight: 1, swayTime: 1.3, swayWeight: 1, popProgress: 0.6)
check(abs(combined.offsetY - (peak.offsetY + MascotMotion.sway(time: 1.3).offsetY)) < 1e-9 && abs(combined.scaleY - 1.035) < 1e-9, "hop, sway and pop combine")
check(MascotMotion.pose(hopProgress: nil, hopHeight: 1, swayTime: nil, swayWeight: 1, popProgress: nil) == .rest, "with nothing playing the mascot is at rest")
check(MascotMood.allCases.allSatisfy { (0.8...0.9).contains($0.feet) }, "every mood's feet sit near the bottom of the frame")

// Click reactions.
var reactionRandom = SplitMix(state: 7)
var lastReaction: MascotReaction?
var seenReactions = Set<MascotReaction>()
var repeatedReaction = false
for _ in 0..<600 {
    let next = MascotReaction.pick(after: lastReaction, using: &reactionRandom)
    if next == lastReaction { repeatedReaction = true }
    seenReactions.insert(next)
    lastReaction = next
}
check(!repeatedReaction, "two clicks in a row never get the same reaction")
check(seenReactions.count == MascotReaction.allCases.count && MascotReaction.allCases.count >= 6, "clicks cycle through all \(MascotReaction.allCases.count) reactions")
check(MascotReaction.wave.mood(from: .working) == .hello && MascotReaction.wave.mood(from: .hello) == nil, "wave switches to the waving pose unless it is already waving")
check(MascotReaction.busy.mood(from: .working) == .coffee && MascotReaction.busy.mood(from: .hello) == .working, "busy types, or has coffee while typing")
check(MascotReaction.cheer.mood(from: .coffee) == .celebrate && MascotReaction.wiggle.mood(from: .coffee) == nil, "cheer celebrates; wiggle keeps the pose")
if let data = try? Data(contentsOf: shipped) {
    let real = try MascotLibrary(data: data)
    var clipRandom = SplitMix(state: 3)
    var everyReactionHasClip = true
    for reaction in MascotReaction.allCases {
        for current in MascotMood.allCases {
            let target = reaction.mood(from: current) ?? current
            if reaction.clip(in: target, clips: real[target], using: &clipRandom) == nil { everyReactionHasClip = false; print("no clip:", reaction, target) }
        }
    }
    check(everyReactionHasClip, "every reaction has a drawn clip in every pose it can show")
}
let wiggleSamples = stride(from: 0.0, through: 1.0, by: 0.005).map { MascotMotion.wiggle(progress: $0) }
check(abs(wiggleSamples.first!) < 1e-9 && abs(wiggleSamples.last!) < 1e-9 && wiggleSamples.map(abs).max()! > 5 && wiggleSamples.map(abs).max()! <= 9, "a wiggle swings up to 9° and ends at rest")
let squashStart = MascotMotion.squash(progress: 0), squashEnd = MascotMotion.squash(progress: 1)
let squashSamples = stride(from: 0.0, through: 1.0, by: 0.005).map { MascotMotion.squash(progress: $0) }
check(abs(squashStart.scaleX - 1) < 1e-9 && abs(squashEnd.scaleX - 1) < 0.01 && abs(squashEnd.scaleY - 1) < 0.01, "a squash starts at rest and settles back")
check(squashSamples.map(\.scaleY).min()! < 0.9 && squashSamples.map(\.scaleX).max()! > 1.08, "a squash visibly flattens and widens")

print("\(passed) mascot motion checks passed")
