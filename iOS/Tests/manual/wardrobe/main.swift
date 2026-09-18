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
WardrobePalette.recolor(&pixels, map: colors["classic"]!.map)
check(pixels == original, "classic identity")
WardrobePalette.recolor(&pixels, map: colors["mint"]!.map)
check(pixels == [136,255,170,255, 34,136,68,255, 1,2,3,255, 255,255,255,0], "tiny RGBA test image remaps exact colors and preserves transparency")
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
let mapped = WardrobeArt.recolor(tiny, map: colors["mint"]!.map)
check(pixel(mapped, 0, 0) == [136,255,170,255], "actual PNG white pixel recolored")
check(pixel(mapped, 1, 0) == [34,136,68,255], "actual PNG accent recolored")
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
print("\(checks) wardrobe checks passed")
