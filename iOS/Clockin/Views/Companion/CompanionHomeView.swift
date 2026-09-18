import SwiftUI

struct CompanionHomeView: View {
    var reaction: MascotTap? = nil
    @ObservedObject private var wardrobe = WardrobeStore.shared
    @EnvironmentObject private var store: ClockStore
    @ObservedObject private var celebrations = CelebrationCenter.shared
    @ObservedObject private var nudges = NudgeController.shared
    @AppStorage(NudgePlanner.toneKey) private var tone = NudgeTone.grumpy.rawValue
    @AppStorage("Clockin.MascotEnabled") private var enabled = true
    @State private var images: [String: CGImage] = [:]

    private var mood: MascotMood {
        celebrations.companionState(running: store.running, angry: nudges.mood?.isAngry == true,
                                    friendly: tone == NudgeTone.friendly.rawValue).mood
    }

    var body: some View {
        GeometryReader { geometry in
            let scale = min(geometry.size.width / 360, geometry.size.height / 240)
            let room = WardrobeArt.home.rooms[wardrobe.state.room]
            let spot = room?.mascotSpot ?? WardrobePoint(180, 220)
            ZStack(alignment: .topLeading) {
                if let room, let background = images[room.file] {
                    Image(decorative: background, scale: 1).resizable().interpolation(.none)
                        .frame(width: 360 * scale, height: 240 * scale)
                }
                ForEach(WardrobeSlot.furniture, id: \.self) { slot in
                    if let id = wardrobe.state.furniture[slot.rawValue],
                       let item = WardrobeArt.home.items[id], item.slot == slot.rawValue,
                       let anchor = room?.slots[slot.rawValue], let image = images[item.file] {
                        let origin = WardrobeGeometry.origin(pivot: item.pivot, anchor: anchor, degrees: 0)
                        Image(decorative: image, scale: 1).resizable().interpolation(.none)
                            .frame(width: CGFloat(image.width) * scale, height: CGFloat(image.height) * scale)
                            .offset(x: origin.x * scale, y: origin.y * scale)
                    }
                }
                if enabled {
                    ClockinMotionMascot(mood: mood, tap: reaction)
                        .frame(width: 180 * scale, height: 180 * scale)
                        .offset(x: spot.x * scale - 90 * scale, y: spot.y * scale - 180 * scale * mood.feet)
                }
            }
            .frame(width: 360 * scale, height: 240 * scale)
            .position(x: geometry.size.width / 2, y: geometry.size.height / 2)
        }
        .accessibilityLabel("Companion home")
        .task(id: wardrobe.state.room + wardrobe.state.furniture.values.sorted().joined(separator: "/")) {
            let state = wardrobe.state
            let decoded = await Task.detached(priority: .utility) {
                var result: [String: CGImage] = [:]
                if let room = WardrobeArt.home.rooms[state.room] {
                    result[room.file] = WardrobeArt.decode(room.file, folder: "Home")
                }
                for id in state.furniture.values {
                    if let item = WardrobeArt.home.items[id] { result[item.file] = WardrobeArt.decode(item.file, folder: "Home") }
                }
                return result
            }.value
            guard !Task.isCancelled else { return }
            images = decoded
        }
    }
}
