import Foundation

// Kimlikler sanat dosyalarinin kok adlariyla aynidir.
enum WardrobeCatalog {
    static let items: [WardrobeItem] = [
        .init(id: "cap", name: "Cap", slot: .head, unlock: .free),
        .init(id: "round-glasses", name: "Round glasses", slot: .face, unlock: .free),
        .init(id: "headphones", name: "Headphones", slot: .head, unlock: .hours(25)),
        .init(id: "mug", name: "Mug", slot: .hand, unlock: .hours(50)),
        .init(id: "cape", name: "Cape", slot: .back, unlock: .hours(100)),
        .init(id: "antenna", name: "Gold antenna", slot: .head, unlock: .hours(250)),
        .init(id: "crown", name: "Crown", slot: .head, unlock: .level(50)),
        .init(id: "wizard-hat", name: "Wizard hat", slot: .head, unlock: .streak(30)),
        .init(id: "bow-tie", name: "Bow tie", slot: .neck, unlock: .badge("first")),
        .init(id: "scarf", name: "Scarf", slot: .neck, unlock: .coins(50)),
        .init(id: "sunglasses", name: "Sunglasses", slot: .face, unlock: .coins(100)),
        .init(id: "balloon", name: "Balloon", slot: .hand, unlock: .coins(150)),
        .init(id: "backpack", name: "Backpack", slot: .back, unlock: .coins(300)),
        .init(id: "wings", name: "Wings", slot: .back, unlock: .coins(1500)),
        .init(id: "classic", name: "Classic", slot: .colorway, unlock: .free),
        .init(id: "mint", name: "Mint", slot: .colorway, unlock: .coins(200)),
        .init(id: "sunset", name: "Sunset", slot: .colorway, unlock: .coins(200)),
        .init(id: "midnight", name: "Midnight", slot: .colorway, unlock: .coins(500)),
        .init(id: "gold", name: "Gold", slot: .colorway, unlock: .coins(500)),
        .init(id: "stealth", name: "Stealth", slot: .colorway, unlock: .coins(500)),
        .init(id: "cozy", name: "Cozy", slot: .room, unlock: .free),
        .init(id: "studio", name: "Studio", slot: .room, unlock: .coins(750)),
        .init(id: "night", name: "Night", slot: .room, unlock: .coins(1000)),
        .init(id: "cat-bed", name: "Sleeping cat bed", slot: .floorLeft, unlock: .coins(50)),
        .init(id: "big-plant", name: "Big plant", slot: .floorRight, unlock: .coins(100)),
        .init(id: "poster", name: "Poster", slot: .wallLeft, unlock: .coins(100)),
        .init(id: "wall-clock", name: "Wall clock", slot: .wallRight, unlock: .coins(150)),
        .init(id: "potted-plant", name: "Potted plant", slot: .window, unlock: .coins(200)),
        .init(id: "round-rug", name: "Round rug", slot: .rug, unlock: .coins(150)),
        .init(id: "desk-monitor", name: "Desk and monitor", slot: .desk, unlock: .coins(400)),
        .init(id: "bookshelf", name: "Bookshelf", slot: .shelf, unlock: .coins(300))
    ]
    static func item(_ id: String) -> WardrobeItem? { items.first { $0.id == id } }
}
