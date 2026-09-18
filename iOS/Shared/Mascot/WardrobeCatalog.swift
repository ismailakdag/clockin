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
        .init(id: "flower", name: "Flower", slot: .hand, unlock: .coins(150)),
        .init(id: "backpack", name: "Backpack", slot: .back, unlock: .coins(300)),
        .init(id: "wings", name: "Wings", slot: .back, unlock: .coins(1500)),
        .init(id: "classic", name: "Classic", slot: .colorway, unlock: .free),
        .init(id: "mint", name: "Mint", slot: .colorway, unlock: .coins(200)),
        .init(id: "rose", name: "Rose", slot: .colorway, unlock: .coins(200)),
        .init(id: "midnight", name: "Midnight", slot: .colorway, unlock: .coins(500)),
        .init(id: "cozy", name: "Cozy", slot: .room, unlock: .free),
        .init(id: "studio", name: "Studio", slot: .room, unlock: .coins(750)),
        .init(id: "night", name: "Night", slot: .room, unlock: .coins(1000)),
        .init(id: "plant", name: "Plant", slot: .floorLeft, unlock: .coins(50)),
        .init(id: "lamp", name: "Lamp", slot: .floorRight, unlock: .coins(100)),
        .init(id: "poster", name: "Poster", slot: .wallLeft, unlock: .coins(100)),
        .init(id: "clock", name: "Wall clock", slot: .wallRight, unlock: .coins(150)),
        .init(id: "curtains", name: "Curtains", slot: .window, unlock: .coins(200)),
        .init(id: "round-rug", name: "Round rug", slot: .rug, unlock: .coins(150)),
        .init(id: "writing-desk", name: "Writing desk", slot: .desk, unlock: .coins(400)),
        .init(id: "bookshelf", name: "Bookshelf", slot: .shelf, unlock: .coins(300))
    ]
    static func item(_ id: String) -> WardrobeItem? { items.first { $0.id == id } }
}
