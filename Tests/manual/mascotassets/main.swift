// Run from the package root:
// swiftc -swift-version 6 Tests/manual/mascotassets/main.swift -o /tmp/clockin-mascotassets-tests && /tmp/clockin-mascotassets-tests
// If sandboxed, set CLANG_MODULE_CACHE_PATH to a writable temporary directory.
// Optional first argument overrides the website companion directory.
import Foundation
import CoreGraphics
import ImageIO
import UniformTypeIdentifiers

struct Frame: Decodable, Equatable {
    let id: String
    let ms: Int
    init(from decoder: any Decoder) throws {
        var values = try decoder.unkeyedContainer()
        id = try values.decode(String.self)
        ms = try values.decode(Int.self)
        guard values.isAtEnd else {
            throw DecodingError.dataCorruptedError(in: values, debugDescription: "Expected [id, ms]")
        }
    }
}
struct Mood: Decodable {
    let rest: String
    let standing: Bool
    let clips: [String: [Frame]]
    let weights: [String: Double]
}
struct WebsiteMood: Decodable {
    let rest: String
    let clips: [String: [Frame]]
    let bakedHopFrames: [String]
}
struct Failure: Error, CustomStringConvertible { let description: String }
struct Checks {
    var count = 0
    mutating func check(_ condition: Bool, _ message: String) throws {
        guard condition else { throw Failure(description: message) }
        count += 1
    }
}
func files(_ directory: URL) -> [URL] {
    (FileManager.default.enumerator(at: directory, includingPropertiesForKeys: [.isRegularFileKey])?.allObjects as? [URL] ?? [])
        .filter { (try? $0.resourceValues(forKeys: [.isRegularFileKey]).isRegularFile) == true }
}
// Decode into explicit RGBA bytes. The first scanline is the image's top row.
// Fully opaque (alpha 255) ignores translucent antialiasing fringes, not body pixels.
func lowestOpaqueRow(_ image: CGImage) throws -> Int {
    let width = image.width, height = image.height
    var pixels = [UInt8](repeating: 0, count: width * height * 4)
    try pixels.withUnsafeMutableBytes { buffer in
        guard let context = CGContext(data: buffer.baseAddress, width: width, height: height,
                                      bitsPerComponent: 8, bytesPerRow: width * 4,
                                      space: CGColorSpace(name: CGColorSpace.sRGB)!,
                                      bitmapInfo: CGBitmapInfo.byteOrder32Big.rawValue | CGImageAlphaInfo.premultipliedLast.rawValue) else {
            throw Failure(description: "Cannot allocate PNG decoder")
        }
        context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
    }
    for y in stride(from: height - 1, through: 0, by: -1) {
        if (0..<width).contains(where: { pixels[(y * width + $0) * 4 + 3] == 255 }) { return y }
    }
    throw Failure(description: "Frame has no fully opaque pixels")
}
func run() throws {
    var checks = Checks()
    let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
    let assets = root.appendingPathComponent("Sources/Clockin/Assets")
    let loops = assets.appendingPathComponent("Mascot/loops")
    let website = URL(fileURLWithPath: CommandLine.arguments.dropFirst().first ?? "/Users/erdemincedere/Clockin/clockin-main/website/dist/assets/companion")
    let data = try Data(contentsOf: loops.appendingPathComponent("mascot-clips.json"))
    let manifest = try JSONDecoder().decode([String: Mood].self, from: data)
    let original = try JSONDecoder().decode([String: WebsiteMood].self, from: Data(contentsOf: website.appendingPathComponent("clips.json")))
    let expectedWeights: [String: [String: Double]] = [
        "hello": ["blink": 3, "antennaDip": 2, "glow": 1.5, "blinkAntennaDip": 1, "glowAntennaDip": 1, "hop": 2.4],
        "celebrate": ["hipLeft": 2, "hipRight": 2, "blink": 2, "antennaDip": 1.5, "glow": 1, "blinkAntennaDip": 1, "hop": 3],
        "coffee": ["steam": 3, "blink": 2, "antennaDip": 1.5, "action": 2.5, "actionAntennaDip": 1],
        "working": ["keyPress": 4, "antennaDipTyping": 1.5, "blink": 2, "blinkAntennaDip": 1, "antennaDip": 1]
    ]
    try checks.check(Set(manifest.keys) == Set(expectedWeights.keys), "Expected exactly four moods")
    try checks.check(Set(original.keys) == Set(manifest.keys), "Website mood keys differ")
    let raw = try JSONSerialization.jsonObject(with: data) as! [String: [String: Any]]
    let allAssets = files(assets)
    var names = Set<String>()
    for file in allAssets {
        try checks.check(names.insert(file.lastPathComponent).inserted, "Duplicate filename: \(file.lastPathComponent)")
    }
    let baked = Set(original.values.flatMap(\.bakedHopFrames))
    var shipped = Set<String>()
    for file in files(loops) where file.pathExtension == "png" {
        let id = file.deletingPathExtension().lastPathComponent
        shipped.insert(id)
        try checks.check(!baked.contains(id), "Baked hop shipped: \(id)")
    }
    for id in baked {
        try checks.check(!names.contains("\(id).png"), "Baked hop shipped outside loops: \(id)")
    }
    var allReferences = Set<String>()
    for name in manifest.keys.sorted() {
        let mood = manifest[name]!
        try checks.check(Set(raw[name]!.keys) == ["rest", "standing", "clips", "weights"], "Unexpected schema: \(name)")
        try checks.check(!mood.rest.isEmpty && !mood.clips.isEmpty && !mood.weights.isEmpty, "Empty mood: \(name)")
        try checks.check(mood.standing == (name == "hello" || name == "celebrate"), "Wrong standing flag: \(name)")
        try checks.check(mood.weights == expectedWeights[name], "Wrong weights: \(name)")
        try checks.check(mood.rest == original[name]!.rest && mood.clips == original[name]!.clips, "Website clip data changed: \(name)")
        var references: Set<String> = [mood.rest]
        for (key, clip) in mood.clips {
            try checks.check(!clip.isEmpty, "Empty clip: \(name).\(key)")
            try checks.check(clip.first?.id == mood.rest, "Clip must start on rest: \(name).\(key)")
            try checks.check(clip.last?.id == mood.rest && clip.last?.ms == 0, "Clip must end on rest with ms 0: \(name).\(key)")
            if key == "base" {
                try checks.check(clip.last?.id == clip.first?.id, "Base does not loop back: \(name)")
            }
            for frame in clip {
                try checks.check(frame.ms >= 0, "Negative duration: \(name).\(key)")
                references.insert(frame.id)
            }
        }
        for key in mood.weights.keys where key != "hop" {
            try checks.check(mood.clips[key] != nil, "Weight names missing clip: \(name).\(key)")
        }
        var rows: [String: Int] = [:]
        for id in references.sorted() {
            try checks.check(!baked.contains(id), "Baked hop referenced: \(id)")
            let path = loops.appendingPathComponent(name).appendingPathComponent("\(id).png")
            try checks.check(FileManager.default.fileExists(atPath: path.path), "Missing frame: \(path.path)")
            guard let source = CGImageSourceCreateWithURL(path as CFURL, nil),
                  let image = CGImageSourceCreateImageAtIndex(source, 0, nil) else {
                throw Failure(description: "Cannot decode PNG: \(id)")
            }
            try checks.check(CGImageSourceGetType(source) == UTType.png.identifier as CFString, "Not PNG: \(id)")
            try checks.check(image.width == 314 && image.height == 314, "Wrong dimensions: \(id)")
            try checks.check([CGImageAlphaInfo.first, .last, .premultipliedFirst, .premultipliedLast].contains(image.alphaInfo), "Missing alpha: \(id)")
            rows[id] = try lowestOpaqueRow(image)
        }
        let restRow = rows[mood.rest]!
        for id in references.sorted() {
            try checks.check(abs(rows[id]! - restRow) <= 2, "Vertical jitter: \(id) lowest opaque row \(rows[id]!), rest \(mood.rest) row \(restRow)")
        }
        print("\(name): \(references.count) frames; lowest opaque rows \(rows.values.min()!)–\(rows.values.max()!), rest \(restRow)")
        allReferences.formUnion(references)
    }
    try checks.check(shipped == allReferences, "Shipped frames differ from references: \(shipped.symmetricDifference(allReferences).sorted())")
    print("\(checks.count) mascot asset checks passed")
}
do { try run() } catch {
    FileHandle.standardError.write(Data("Mascot asset check failed: \(error)\n".utf8))
    exit(1)
}
