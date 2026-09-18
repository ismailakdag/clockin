import SwiftUI

struct CompanionView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.palette) private var palette
    @Environment(\.scenePhase) private var scenePhase
    @EnvironmentObject private var store: ClockStore
    @ObservedObject private var wardrobe = WardrobeStore.shared
    @State private var tab = "Outfit"
    @State private var purchase: WardrobeItem?
    @State private var reaction: MascotTap?
    @State private var visible = false
    @State private var headerVisible = false
    @State private var purchaseError = false
    private let columns = [GridItem(.adaptive(minimum: 140), spacing: 10)]

    var body: some View {
        NavigationStack {
            GeometryReader { viewport in
            let viewportHeight = viewport.size.height
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    CompanionHomeView(reaction: reaction)
                        .frame(height: 260)
                        .background(palette.surface, in: RoundedRectangle(cornerRadius: 20))
                        .environment(\.clockinContentActive, visible && headerVisible && purchase == nil && !purchaseError && scenePhase == .active)
                        .onGeometryChange(for: Bool.self) { proxy in
                            let frame = proxy.frame(in: .named("companionScroll"))
                            return frame.maxY > 0 && frame.minY < viewportHeight
                        } action: { headerVisible = $0 }
                        .onDisappear { headerVisible = false }
                    Label("\(wardrobe.balance.formatted()) focus coins", systemImage: "circle.circle.fill")
                        .font(.title3.bold()).foregroundStyle(palette.accent)
                    DisclosureGroup("How coins work") {
                        Text("Earn 10 coins per completed hour. Each session is rounded down to whole minutes; those minutes are added together, then divided by six. Earn 25 per day meeting your current daily goal, 50 per badge achieved in your archive, and 100 per level, including level 1. Running sessions do not earn coins yet. Editing the archive or daily goal recalculates earnings. Purchases stay owned and your balance never drops below zero.")
                            .font(.footnote).foregroundStyle(.secondary).padding(.top, 8)
                    }
                    Picker("Companion", selection: $tab) {
                        ForEach(["Outfit", "Home", "Shop"], id: \.self) { Text($0) }
                    }.pickerStyle(.segmented)
                    if tab == "Shop" {
                        grid(WardrobeCatalog.items.filter { $0.unlock.price != nil && WardrobeArt.available($0) }
                            .sorted { ($0.unlock.price ?? 0, $0.id) < ($1.unlock.price ?? 0, $1.id) })
                    } else {
                        ForEach(tab == "Outfit" ? WardrobeSlot.outfit : [.room] + WardrobeSlot.furniture, id: \.self) { slot in
                            VStack(alignment: .leading, spacing: 10) {
                                Text(title(slot)).font(.headline)
                                if slot != .room {
                                    Button(slot == .colorway ? "Classic" : "None") { wardrobe.clear(slot); react() }
                                        .buttonStyle(.bordered).buttonPressHaptic(false)
                                }
                                grid(WardrobeCatalog.items.filter { $0.slot == slot && WardrobeArt.available($0) })
                            }
                        }
                    }
                }.padding(16)
            }
            .coordinateSpace(name: "companionScroll")
            }
            .background(palette.background)
            .navigationTitle("Companion")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
            .confirmationDialog("Buy \(purchase?.name ?? "item")?", isPresented: Binding(
                get: { purchase != nil }, set: { if !$0 { purchase = nil } }), titleVisibility: .visible) {
                if let item = purchase {
                    Button("Buy for \(item.unlock.price ?? 0) coins") {
                        CelebrationCenter.shared.refresh(store: store)
                        if wardrobe.buy(item) { react() } else { purchaseError = true }
                        purchase = nil
                    }
                }
                Button("Cancel", role: .cancel) { purchase = nil }
            } message: { Text("Balance: \(wardrobe.balance) coins. This item will be equipped.") }
            .alert("Not enough coins", isPresented: $purchaseError) { Button("OK", role: .cancel) {} }
        }
        .tint(palette.accent).fontDesign(palette.fontDesign).preferredColorScheme(palette.colorScheme)
        .onAppear { visible = true }
        .onDisappear { visible = false; reaction = nil }
        .celebrationBlocked(by: purchase != nil || purchaseError)
    }

    private func grid(_ items: [WardrobeItem]) -> some View {
        LazyVGrid(columns: columns, alignment: .leading, spacing: 10) {
            ForEach(items) { item in
                let owned = wardrobe.state.owned.contains(item.id)
                Button {
                    if owned { wardrobe.equip(item); react() } else { purchase = item }
                } label: {
                    VStack(alignment: .leading, spacing: 8) {
                        WardrobeThumbnail(item: item).frame(height: 58).frame(maxWidth: .infinity)
                        Text(item.name).font(.subheadline.bold())
                        Label(owned ? (wardrobe.selected(item) ? "Equipped" : "Owned") : item.unlock.label,
                              systemImage: owned ? (wardrobe.selected(item) ? "checkmark.circle.fill" : "checkmark") : "lock.fill")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, minHeight: 110, alignment: .leading).padding(12)
                    .background(wardrobe.selected(item) ? palette.accent.opacity(0.15) : palette.surface,
                                in: RoundedRectangle(cornerRadius: 12))
                }
                .buttonStyle(.plain).buttonPressHaptic(false)
                .disabled(!owned && (item.unlock.price == nil || (item.unlock.price ?? 0) > wardrobe.balance))
                .accessibilityElement(children: .combine)
            }
        }
    }

    private func react() {
        Haptics.play(.companionReaction)
        reaction = MascotTap(id: (reaction?.id ?? 0) + 1, reaction: .wiggle)
    }
    private func title(_ slot: WardrobeSlot) -> String {
        switch slot {
        case .floorLeft: "Floor left"
        case .floorRight: "Floor right"
        case .wallLeft: "Wall left"
        case .wallRight: "Wall right"
        default: slot.rawValue.capitalized
        }
    }
}

private struct WardrobeThumbnail: View {
    let item: WardrobeItem
    @State private var image: CGImage?
    var body: some View {
        Group {
            if let image { Image(decorative: image, scale: 1).resizable().interpolation(.none).scaledToFit() }
            else { Image(systemName: item.slot == .colorway ? "paintpalette" : "square.dashed").foregroundStyle(.secondary) }
        }
        .task(id: item.id) {
            let item = item
            let decoded = await Task.detached(priority: .utility) {
                if item.slot == .colorway {
                    return await WardrobeFrameCache.shared.image("h01", colorway: item.id)
                }
                if item.slot == .room { return WardrobeArt.home.rooms[item.id].flatMap { WardrobeArt.decode($0.file, folder: "Home") } }
                if WardrobeSlot.furniture.contains(item.slot) { return WardrobeArt.home.items[item.id].flatMap { WardrobeArt.decode($0.file, folder: "Home") } }
                return WardrobeArt.decode(item.id + ".png", folder: "Wardrobe")
            }.value
            guard !Task.isCancelled else { return }
            image = decoded
        }
    }
}
