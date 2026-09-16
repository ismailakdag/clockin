#!/usr/bin/env swift
// Run from the package root:
// swift tools/mascot-frames/main.swift /Users/erdemincedere/Clockin/clockin-main/website/dist/assets/companion
// Uses CoreGraphics high-quality downsampling; optionally losslessly optimizes with pngcrush.
import Foundation
import CoreGraphics
import ImageIO
import UniformTypeIdentifiers

struct AssetError: Error, CustomStringConvertible { let description: String }
func require(_ value: Bool, _ message: String) throws {
    if !value { throw AssetError(description: message) }
}
let fm = FileManager.default
let root = URL(fileURLWithPath: fm.currentDirectoryPath)
let source = URL(fileURLWithPath: CommandLine.arguments.dropFirst().first ?? "/Users/erdemincedere/Clockin/clockin-main/website/dist/assets/companion")
let assets = root.appendingPathComponent("Sources/Clockin/Assets")
let output = assets.appendingPathComponent("Mascot/loops")
let weights: [String: [String: Double]] = [
    "hello": ["blink": 3, "antennaDip": 2, "glow": 1.5, "blinkAntennaDip": 1, "glowAntennaDip": 1, "hop": 2.4],
    "celebrate": ["hipLeft": 2, "hipRight": 2, "blink": 2, "antennaDip": 1.5, "glow": 1, "blinkAntennaDip": 1, "hop": 3],
    "coffee": ["steam": 3, "blink": 2, "antennaDip": 1.5, "action": 2.5, "actionAntennaDip": 1],
    "working": ["keyPress": 4, "antennaDipTyping": 1.5, "blink": 2, "blinkAntennaDip": 1, "antennaDip": 1]
]
func files(_ directory: URL) -> [URL] {
    (fm.enumerator(at: directory, includingPropertiesForKeys: [.isRegularFileKey])?.allObjects as? [URL] ?? [])
        .filter { (try? $0.resourceValues(forKeys: [.isRegularFileKey]).isRegularFile) == true }
}
let optimizer = ["/opt/homebrew/bin/pngcrush", "/usr/local/bin/pngcrush", "/Applications/Xcode.app/Contents/Developer/usr/bin/pngcrush"]
    .first { fm.isExecutableFile(atPath: $0) }
// Build in a temporary directory so a failed conversion leaves existing assets intact.
let staging = fm.temporaryDirectory.appendingPathComponent("clockin-mascot-\(UUID().uuidString)")
try fm.createDirectory(at: staging, withIntermediateDirectories: true)
defer { try? fm.removeItem(at: staging) }
guard var manifest = try JSONSerialization.jsonObject(with: Data(contentsOf: source.appendingPathComponent("clips.json"))) as? [String: [String: Any]] else {
    throw AssetError(description: "Invalid website manifest")
}
try require(Set(manifest.keys) == Set(weights.keys), "Expected exactly four moods")
var count = 0
for mood in manifest.keys.sorted() {
    guard var entry = manifest[mood], let folder = entry["folder"] as? String,
          let rest = entry["rest"] as? String, let clips = entry["clips"] as? [String: [[Any]]],
          let baked = entry["bakedHopFrames"] as? [String] else {
        throw AssetError(description: "Invalid mood: \(mood)")
    }
    var ids: Set<String> = [rest]
    for clip in clips.values {
        for frame in clip {
            guard frame.count == 2, let id = frame[0] as? String, frame[1] is NSNumber else {
                throw AssetError(description: "Invalid clip in \(mood)")
            }
            ids.insert(id)
        }
    }
    try require(ids.isDisjoint(with: baked), "Clip references baked hop in \(mood)")
    let directory = staging.appendingPathComponent(mood)
    try fm.createDirectory(at: directory, withIntermediateDirectories: true)
    for id in ids.sorted() {
        try require(id.range(of: "^[hect][0-9]{2}$", options: .regularExpression) != nil, "Unsafe frame ID \(id)")
        let input = source.appendingPathComponent(folder).appendingPathComponent("\(id).png")
        guard let imageSource = CGImageSourceCreateWithURL(input as CFURL, nil),
              let original = CGImageSourceCreateImageAtIndex(imageSource, 0, nil),
              let context = CGContext(data: nil, width: 314, height: 314, bitsPerComponent: 8, bytesPerRow: 314 * 4,
                                      space: CGColorSpace(name: CGColorSpace.sRGB)!,
                                      bitmapInfo: CGBitmapInfo.byteOrder32Big.rawValue | CGImageAlphaInfo.premultipliedLast.rawValue) else {
            throw AssetError(description: "Cannot decode \(input.path)")
        }
        try require(original.width == 627 && original.height == 627, "Unexpected source size: \(id)")
        context.interpolationQuality = .high
        context.draw(original, in: CGRect(x: 0, y: 0, width: 314, height: 314))
        let target = directory.appendingPathComponent("\(id).png")
        guard let resized = context.makeImage(),
              let destination = CGImageDestinationCreateWithURL(target as CFURL, UTType.png.identifier as CFString, 1, nil) else {
            throw AssetError(description: "Cannot encode \(id)")
        }
        CGImageDestinationAddImage(destination, resized, nil)
        try require(CGImageDestinationFinalize(destination), "PNG write failed: \(id)")
        if let optimizer {
            let optimized = directory.appendingPathComponent("\(id).optimized.png")
            let task = Process()
            task.executableURL = URL(fileURLWithPath: optimizer)
            task.arguments = ["-q", target.path, optimized.path]
            task.standardOutput = FileHandle.nullDevice
            task.standardError = FileHandle.nullDevice
            try task.run(); task.waitUntilExit()
            try require(task.terminationStatus == 0, "pngcrush failed: \(id)")
            if try Data(contentsOf: optimized).count < Data(contentsOf: target).count {
                try fm.removeItem(at: target)
                try fm.moveItem(at: optimized, to: target)
            } else { try fm.removeItem(at: optimized) }
        }
        count += 1
    }
    entry.removeValue(forKey: "folder")
    entry.removeValue(forKey: "bakedHopFrames")
    entry.removeValue(forKey: "loop")
    entry["weights"] = weights[mood]!
    entry["standing"] = mood == "hello" || mood == "celebrate"
    manifest[mood] = entry
}
let json = try JSONSerialization.data(withJSONObject: manifest, options: [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes])
try (json + Data([10])).write(to: staging.appendingPathComponent("mascot-clips.json"))
let existing = files(assets).filter { !$0.path.hasPrefix(output.path + "/") }
var names = Set<String>()
for file in existing + files(staging) {
    try require(names.insert(file.lastPathComponent).inserted, "Resource filename collision: \(file.lastPathComponent)")
}
if fm.fileExists(atPath: output.path) { try fm.removeItem(at: output) }
try fm.createDirectory(at: output.deletingLastPathComponent(), withIntermediateDirectories: true)
try fm.moveItem(at: staging, to: output)
let total = try files(output).reduce(0) { try $0 + Data(contentsOf: $1).count }
print("Generated \(count) frames (314×314 RGBA) and manifest: \(total) bytes; optimizer: \(optimizer ?? "none")")
