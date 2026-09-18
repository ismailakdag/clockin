import Foundation
import CoreGraphics
import ImageIO

var checks = 0
@MainActor func check(_ value: @autoclosure () -> Bool, _ message: String) {
    guard value() else { fatalError("FAIL: \(message)") }
    checks += 1
    print("ok \(message)")
}
func fixture<T: Decodable>(_ file: String, _ type: T.Type) -> T {
    let url = URL(fileURLWithPath: #filePath).deletingLastPathComponent().appendingPathComponent("fixtures/" + file)
    return try! JSONDecoder().decode(type, from: Data(contentsOf: url))
}
var calendar = Calendar(identifier: .gregorian)
calendar.timeZone = TimeZone(secondsFromGMT: 0)!
let start = Date(timeIntervalSince1970: 1_700_006_400)
@MainActor func session(_ day: Int, _ duration: Double) -> WorkSession {
    let date = calendar.date(byAdding: .day, value: day, to: start)!
    return WorkSession(id: UUID(), start: date, end: date.addingTimeInterval(duration), duration: duration,
                       note: "Synthetic", hourlyRate: 0, source: "Clockin")
}
let archive = [session(0, 8 * 3600 + 59), session(1, 8 * 3600), session(2, 8 * 3600)]
let earning = WardrobeEarnings(sessions: archive, dailyGoal: 8, now: start.addingTimeInterval(3 * 86400), calendar: calendar)
check(earning.goalDays == 3, "three completed goal days")
check(earning.progress.level == 6, "archive level from hours and streak XP")
check(earning.progress.streak == 3, "archive streak")
check(earning.progress.badges == Set(["first", "ten", "streak", "marathon", "ultra", "fullday"]), "archive badges")
check(earning.coins == 240 + 75 + 300 + 600, "hours plus goals plus badges plus all reached levels")
check(WardrobeEarnings(sessions: archive, dailyGoal: 8, now: start.addingTimeInterval(100 * 86400), calendar: calendar).coins == earning.coins, "streak coins survive calendar drift")
check(WardrobeEarnings(sessions: [], dailyGoal: 0, now: start, calendar: calendar).coins == 100, "level one earns 100")
check(WardrobeCoins.earned(durations: [359, 359], goalDays: 0, badges: 0, level: 0) == 1, "floor each session to minutes then combine")
check(WardrobeCoins.earned(durations: [59, 59, 59, 59, 59, 59], goalDays: 0, badges: 0, level: 0) == 0, "seconds never pool into minutes")
check(WardrobeCoins.earned(durations: [.nan, .infinity, -60], goalDays: -1, badges: -1, level: -1) == 0, "invalid coin inputs are safe")
check(Set(WardrobeCatalog.items.map(\.id)).count == WardrobeCatalog.items.count, "unique catalog ids")
let allBadges = Set(InsightsSnapshot(sessions: [], sessionEarnings: [:], now: start, calendar: calendar).badges.map(\.id))
for item in WardrobeCatalog.items {
    switch item.unlock {
    case .free: check(true, "\(item.id) free rule")
    case .coins(let n): check((50...1500).contains(n), "\(item.id) valid price")
    case .hours(let n), .level(let n), .streak(let n): check(n > 0, "\(item.id) valid milestone")
    case .badge(let id): check(allBadges.contains(id), "\(item.id) valid badge")
    }
}
var state = WardrobeState()
check(state.unlock(.init(hours: 100), legacy: "cape").isEmpty, "seed silently")
check(state.seeded && state.owned.isSuperset(of: ["classic", "cozy", "cap", "round-glasses", "headphones", "mug", "cape"]), "seed owns earned items")
check(state.equipped["back"] == "cape", "legacy cape migrated")
check(!state.owned.contains("mint"), "coins do not auto unlock purchases")
check(state.unlock(.init()).isEmpty && state.owned.contains("cape"), "milestone ownership remains after archive shrinks")
check(state.unlock(.init(hours: 250)) == ["antenna"], "new milestone only reported once")
check(state.unlock(.init(hours: 250)).isEmpty, "no repeat unlock")
for (id, slot, hours) in [("headphones", "head", 25.0), ("mug", "hand", 50.0), ("cape", "back", 100.0), ("antenna", "head", 250.0)] {
    var migrated = WardrobeState()
    _ = migrated.unlock(.init(hours: hours), legacy: id)
    check(migrated.equipped[slot] == id, "legacy \(id) migration")
}
for legacy in ["None", "unknown"] {
    var migrated = WardrobeState(); _ = migrated.unlock(.init(hours: 250), legacy: legacy)
    check(migrated.equipped.isEmpty, "\(legacy) no equipped item")
}
var auto = WardrobeState(); _ = auto.unlock(.init(hours: 100), legacy: "Auto")
check(auto.equipped["back"] == "cape", "Auto migrates highest earned accessory")
var historical = WardrobeState()
_ = historical.unlock(.init(), legacy: "cape", legacyOwned: ["headphones", "mug", "invalid"])
check(historical.equipped["back"] == "cape", "stored selection remains owned after archive reduction")
check(historical.owned.isSuperset(of: ["headphones", "mug", "cape"]) && !historical.owned.contains("invalid"), "legacy seen ownership migrates known ids only")
var ledger: [WardrobePurchase] = []
let scarf = WardrobeCatalog.item("scarf")!
check(!state.buy(scarf, earned: 49, ledger: &ledger, now: start), "insufficient balance cannot buy")
check(state.buy(scarf, earned: 100, ledger: &ledger, now: start), "purchase succeeds")
check(ledger == [.init(itemID: "scarf", cost: 50, date: start)], "ledger records cost id and date")
check(state.equipped["neck"] == "scarf" && state.owned.contains("scarf"), "purchase equips and owns")
check(WardrobeCoins.balance(earned: 100, ledger: ledger) == 50, "purchase deducted")
check(!state.buy(scarf, earned: 100, ledger: &ledger, now: start), "duplicate purchase refused")
check(!state.buy(WardrobeCatalog.item("crown")!, earned: 10000, ledger: &ledger, now: start), "milestone cannot be purchased")
check(WardrobeCoins.balance(earned: 0, ledger: ledger) == 0, "deleted archive never negative")
check(WardrobeCoins.balance(earned: 100, ledger: [.init(itemID: "bad", cost: -50, date: start)]) == 100, "negative ledger does not mint coins")
let anchors = fixture("mascot-anchors.json", [String: WardrobeAnchors].self)
let sprites = fixture("wardrobe-sprites.json", [String: WardrobeSprite].self)
check(WardrobeGeometry.placement(sprite: sprites["cap"]!, frame: anchors["h01"]!) == WardrobePoint(147, 52), "pivot lands on upright anchor")
let tilted = WardrobeGeometry.placement(sprite: sprites["cap"]!, frame: anchors["t01"]!)!
check(abs(tilted.x - 168) < 0.0001 && abs(tilted.y - 52) < 0.0001, "pivot rotates about anchor at 90 degrees")
check(WardrobeGeometry.placement(sprite: sprites["mug"]!, frame: anchors["t01"]!) == nil, "hand hidden without handR")
check(WardrobeGeometry.placement(sprite: sprites["mug"]!, frame: anchors["h01"]!) == WardrobePoint(208, 166), "handR placement")
check(sprites["cape"]!.layer == "back", "cape renders behind")
let colors = fixture("colorways.json", [String: WardrobeColorway].self)
var pixels: [UInt8] = [255,255,255,255, 255,136,0,255, 1,2,3,255, 255,255,255,0]
let original = pixels
WardrobePalette.recolor(&pixels, colorway: colors["classic"]!)
check(pixels == original, "classic identity")
WardrobePalette.recolor(&pixels, colorway: colors["mint"]!)
check(pixels == [231,255,240,255, 230,159,99,255, 1,2,3,255, 255,255,255,0], "tiny RGBA test image classifies shades and preserves transparency")
let artRoot = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
    .deletingLastPathComponent().deletingLastPathComponent().appendingPathComponent("Shared/Mascot")
func real<T: Decodable>(_ path: String, _ type: T.Type) -> T {
    try! JSONDecoder().decode(type, from: Data(contentsOf: artRoot.appendingPathComponent(path)))
}
let realColors = real("Frames/colorways.json", [String: WardrobeColorway].self)
let realAnchors = real("Frames/mascot-anchors.json", [String: WardrobeAnchors].self)
let realSprites = real("Wardrobe/wardrobe-sprites.json", [String: WardrobeSprite].self)
let realHome = real("Home/home-items.json", WardrobeHome.self)
check((try! Data(contentsOf: artRoot.appendingPathComponent("Frames/colorways.json"))).count < 20_000, "real colorway file under 20 KB")
for (id, way) in realColors {
    check(Set(way.rules.map(\.kind)) == Set(["shell", "highlights", "grays", "joints", "accents", "glow"]), "\(id) has all six classes")
    var sample: [UInt8] = [175,175,175,255, 232,232,232,255, 79,70,65,255, 255,119,26,128]
    let before = sample
    WardrobePalette.recolor(&sample, colorway: way)
    check(Array(sample[8..<12]) == Array(before[8..<12]), "\(id) visor untouched")
    check(sample[15] == 128, "\(id) partial alpha preserved")
    if id == "classic" { check(sample == before, "real classic identity") }
    else { check(sample[0..<3] != sample[4..<7], "\(id) shadow and shell shading stay distinct") }
}
for item in WardrobeCatalog.items {
    let file: String
    switch item.slot {
    case .colorway:
        check(realColors[item.id] != nil, "catalog colorway \(item.id)")
        continue
    case .room:
        check(realHome.rooms[item.id] != nil, "catalog room \(item.id)")
        file = "Home/" + realHome.rooms[item.id]!.file
    default:
        if WardrobeSlot.furniture.contains(item.slot) {
            check(realHome.items[item.id]?.slot == item.slot.rawValue, "catalog furniture id and slot \(item.id)")
            file = "Home/" + realHome.items[item.id]!.file
        } else {
            check(realSprites[item.id]?.slot == item.slot.rawValue, "catalog sprite id and slot \(item.id)")
            file = "Wardrobe/" + item.id + ".png"
        }
    }
    check(FileManager.default.fileExists(atPath: artRoot.appendingPathComponent(file).path), "catalog asset \(file)")
}
let home = fixture("home-items.json", WardrobeHome.self)
let plant = home.items["plant"]!, room = home.rooms["cozy"]!
check(WardrobeGeometry.origin(pivot: plant.pivot, anchor: room.slots[plant.slot]!, degrees: 0) == WardrobePoint(32, 200), "furniture pivot on room slot")
check(room.mascotSpot == WardrobePoint(180, 220), "feet spot decoded")
check(room.slots["desk"] == nil, "missing room slot omitted")
let suite = "Clockin.WardrobeTests.\(UUID())"
let defaults = UserDefaults(suiteName: suite)!
defer { defaults.removePersistentDomain(forName: suite) }
defaults.set(state.json, forKey: WardrobeState.stateKey)
defaults.set(String(data: try! JSONEncoder().encode(ledger), encoding: .utf8), forKey: WardrobeState.ledgerKey)
defaults.set(false, forKey: WardrobeState.deskKey)
let extra = WardrobeBackupSection(defaults: defaults)
var data = ClockinData(); data.sessions = archive
let backup = try! extra.adding(to: JSONEncoder().encode(data))
check((try! JSONDecoder().decode(ClockinData.self, from: backup)).sessions == archive, "wardrobe does not change ClockinData")
let restored = try! WardrobeBackupSection.read(from: backup)!
check(restored == extra, "backup optional section round trip")
defaults.removePersistentDomain(forName: suite)
restored.restore(to: defaults)
check(WardrobeState.decode(defaults.string(forKey: WardrobeState.stateKey)) == state, "restore outfit ownership and seed")
check(defaults.bool(forKey: WardrobeState.deskKey) == false, "restore desk preference")
check(try! WardrobeBackupSection.read(from: JSONEncoder().encode(data)) == nil, "old backups have no wardrobe")
check(WardrobeState.decode("broken") == WardrobeState(), "malformed state degrades safely")

func testImage(_ name: String) -> CGImage {
    let url = URL(fileURLWithPath: #filePath).deletingLastPathComponent().appendingPathComponent("fixtures/" + name)
    let source = CGImageSourceCreateWithURL(url as CFURL, nil)!
    return CGImageSourceCreateImageAtIndex(source, 0, nil)!
}
func pixel(_ image: CGImage, _ x: Int, _ y: Int) -> [UInt8] {
    var rgba = [UInt8](repeating: 0, count: image.width * image.height * 4)
    rgba.withUnsafeMutableBytes { bytes in
        let context = CGContext(data: bytes.baseAddress, width: image.width, height: image.height, bitsPerComponent: 8,
                                bytesPerRow: image.width * 4, space: CGColorSpaceCreateDeviceRGB(),
                                bitmapInfo: CGBitmapInfo.byteOrder32Big.rawValue | CGImageAlphaInfo.premultipliedLast.rawValue)!
        context.interpolationQuality = .none
        context.draw(image, in: CGRect(x: 0, y: 0, width: image.width, height: image.height))
    }
    let offset = (y * image.width + x) * 4
    return Array(rgba[offset..<(offset + 4)])
}
let tiny = testImage("tiny.png")
let mapped = WardrobeArt.recolor(tiny, colorway: colors["mint"]!)
check(pixel(mapped, 0, 0) == [231,255,240,255], "actual PNG white pixel recolored")
check(pixel(mapped, 1, 0) == [230,159,99,255], "actual PNG accent recolored")
check(pixel(mapped, 0, 1) == [0,0,255,255], "actual PNG unmapped pixel unchanged")
check(pixel(mapped, 1, 1)[3] == 0, "actual PNG transparency retained")
let red = testImage("overlay.png")
let part = WardrobeOverlay(id: "test", image: red, origin: WardrobePoint(0, 0), tilt: 0, behind: false)
let front = WardrobeArt.composite(robot: tiny, parts: [part], size: 314)!
check(pixel(front, 0, 0) == [255,0,0,255], "front layer draws over robot")
check(pixel(front, 3, 3) == [255,255,255,255], "sprite cropped bounds do not stretch")
let back = WardrobeOverlay(id: "test", image: red, origin: WardrobePoint(0, 0), tilt: 0, behind: true)
check(pixel(WardrobeArt.composite(robot: tiny, parts: [back], size: 314)!, 0, 0) == [255,255,255,255], "back layer draws behind robot")
let transparentPart = WardrobeOverlay(id: "test", image: red, origin: WardrobePoint(200, 200), tilt: 0, behind: true)
check(pixel(WardrobeArt.composite(robot: tiny, parts: [transparentPart], size: 314)!, 200, 200) == [255,0,0,255], "back layer visible through transparent robot")
let still = WardrobeArt.composite(robot: tiny, parts: [], size: 80)!
check(still.width == 80 && still.height == 80, "widget composite rendered at requested size")
check(pixel(still, 0, 0) == [255,255,255,255] && pixel(still, 79, 0) == [255,136,0,255], "widget preserves top-left orientation and nearest colors")
check(WardrobeArt.composite(robot: tiny, parts: [], size: 0) == nil, "invalid composite size safe")
check(WardrobeArt.url("../escape.png", folder: "Home") == nil, "manifest filenames cannot escape resource folder")
check(WardrobeArt.overlays(frame: "missing", outfit: state, images: [:]).isEmpty, "missing frame anchors hide overlays")
var queue = CelebrationQueue()
queue.wardrobeUnlocked(first: true, names: ["Cap", "Cape"])
check(queue.pending == [.wardrobe(name: "Outfits, coins and home", introductory: true)], "one first-run banner")
queue = CelebrationQueue()
queue.wardrobeUnlocked(first: false, names: ["A", "B", "C", "D", "E"])
check(queue.pending.count == 4, "new items limited to three plus summary")
queue.presentNext(active: true, blocked: true, companionVisible: true, now: 0)
check(queue.current == nil && queue.pending.count == 4, "wardrobe banners wait for modal dismissal")
queue.presentNext(active: true, blocked: false, companionVisible: true, now: 0)
check(queue.current == .wardrobe(name: "A", introductory: false), "wardrobe banner presented by shared queue")

func realImage(_ relative: String) -> CGImage {
    let source = CGImageSourceCreateWithURL(artRoot.appendingPathComponent(relative) as CFURL, nil)!
    return CGImageSourceCreateImageAtIndex(source, 0, nil)!
}
@MainActor func savePNG(_ image: CGImage, _ path: String) {
    let destination = CGImageDestinationCreateWithURL(URL(fileURLWithPath: path) as CFURL, "public.png" as CFString, 1, nil)!
    CGImageDestinationAddImage(destination, image, nil)
    check(CGImageDestinationFinalize(destination), "PNG proof \(path)")
}
let artImages = realSprites.keys.reduce(into: [String: CGImage]()) { $0[$1] = realImage("Wardrobe/" + $1 + ".png") }
var dressed = WardrobeState()
dressed.equipped = ["head":"headphones", "face":"round-glasses", "neck":"scarf", "back":"wings", "hand":"mug"]
dressed.colorway = "mint"
for frame in realAnchors.keys.sorted() {
    let overlays = WardrobeArt.overlays(frame: frame, outfit: dressed, images: artImages, anchorManifest: realAnchors, spriteManifest: realSprites)
    check(overlays.contains { $0.id == "mug" } == (realAnchors[frame]!.handR != nil), "real null hand composition \(frame)")
    for overlay in overlays {
        let expected = ["headphones", "round-glasses"].contains(overlay.id) ? realAnchors[frame]!.tilt : 0
        check(overlay.tilt == expected, "real slot rotation \(frame)/\(overlay.id)")
    }
    let antenna = realSprites["antenna"]!, antennaImage = artImages["antenna"]!
    let origin = WardrobeGeometry.placement(sprite: antenna, frame: realAnchors[frame]!)!
    let angle = realAnchors[frame]!.tilt * .pi / 180
    for (x, y) in [(0.0,0.0), (Double(antennaImage.width),0.0), (0.0,Double(antennaImage.height)), (Double(antennaImage.width),Double(antennaImage.height))] {
        let px = origin.x + x * cos(angle) - y * sin(angle)
        let py = origin.y + x * sin(angle) + y * cos(angle)
        check((0...314).contains(px) && (0...314).contains(py), "antenna stays in canvas \(frame)")
    }
    let base = realImage("Frames/" + frame + ".png")
    let robot = WardrobeArt.recolor(base, colorway: realColors["mint"]!)
    let image = WardrobeArt.composite(robot: robot, parts: overlays, size: 314)!
    check(image.width == 314, "real composition \(frame)")
    if ["h01","t01","c07","e01"].contains(frame) { savePNG(image, "/tmp/clockin-app-composition-" + frame + ".png") }
}
for id in ["pose2", "pose3", "pose4"] {
    let poseURL = artRoot.deletingLastPathComponent().deletingLastPathComponent()
        .appendingPathComponent("Clockin/Assets.xcassets/" + id + ".imageset/" + id + ".png")
    let poseSource = CGImageSourceCreateWithURL(poseURL as CFURL, nil)!
    let pose = CGImageSourceCreateImageAtIndex(poseSource, 0, nil)!
    let recolored = WardrobeArt.recolor(pose, colorway: realColors["mint"]!)
    check(recolored !== pose && recolored.width == pose.width, "fixed pose real image recolors \(id)")
    check(realAnchors[id] == nil, "fixed pose deliberately has no anchors \(id)")
    check(WardrobeArt.overlays(frame: id, outfit: dressed, images: artImages, anchorManifest: realAnchors, spriteManifest: realSprites).isEmpty, "fixed pose hides all overlays \(id)")
}
let classicBase = realImage("Frames/h01.png")
check(WardrobeArt.recolor(classicBase, colorway: realColors["classic"]!) === classicBase, "classic CGImage is identical without pixel work")


let cache = WardrobeFrameCache(decode: { _, _ in
    precondition(!Thread.isMainThread, "Frame decode must leave main thread")
    return WardrobeArt.recolor(classicBase, colorway: realColors["mint"]!)
})
async let cachedFirst = cache.image("synthetic", colorway: "classic")
async let cachedSecond = cache.image("synthetic", colorway: "classic")
let cachedPair = await (cachedFirst, cachedSecond)
check(cachedPair.0 !== classicBase && cachedPair.0 != nil && cachedPair.0 === cachedPair.1, "concurrent frame requests share cached image off main thread")
print("\(checks) wardrobe checks passed including real art integration and cache")
