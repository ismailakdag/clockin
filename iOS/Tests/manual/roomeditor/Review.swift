import SwiftUI

@main struct RoomEditorReview: App {
    var body: some Scene { WindowGroup("Clockin Room Editor Review") { Review().frame(width:390,height:540) }.windowResizability(.contentSize) }
}
struct Review: View {
    @State private var draft = RoomArrangement()
    @State private var saved = RoomArrangement()
    @State private var selection: String? = "ataturk-portrait"
    @State private var feedback: String?
    @State private var dragging = false
    @State private var editing = true
    @State private var mirrored = false
    @State private var compact = false
    let room = WardrobeArt.home.rooms["cozy"]!
    let ids = ["round-rug","ataturk-portrait","turkish-flag","bookshelf","desk-monitor","bean-bag"]
    var layout: CompanionHomeLayout { mirrored ? .deskRight : .deskLeft }
    var items:[RoomPlacedItem] { ids.map { id in
        let info = WardrobeArt.home.items[id]!, image = WardrobeArt.decode(info.file,folder:"Home")!
        return .init(id:id,name:info.name,slot:info.slot,base:HomeSceneLayout.furnitureRect(info,in:room,imageSize:CGSize(width:image.width,height:image.height),layout:.deskLeft))
    } }
    var body:some View {
        VStack(spacing:14) {
            Text("Edit room").font(.title2.bold())
            HStack {
                Button("Cancel") { draft = saved; editing = false; feedback = nil }
                Button(editing ? "Save" : "Edit room") { if editing { saved = draft; editing = false } else { draft = saved; editing = true } }
                Button("Reset room") { draft.reset(room:"cozy") }.disabled(!editing)
            }
            RoomEditorCanvas(items:items,room:room,roomID:"cozy",layout:layout,arrangement:$draft,selectedID:$selection,feedback:$feedback,isDragging:$dragging) { value in
                scene(value)
            }.frame(width:compact ? 300 : 358).allowsHitTesting(editing)
            Text(feedback ?? (editing ? "Drag to arrange" : "Saved room")).foregroundStyle(feedback == nil ? Color.secondary : .red)
            Toggle("Room right",isOn:$mirrored)
            Toggle("Compact screen",isOn:$compact)
            Text("Draft: \(summary(draft))").font(.caption.monospaced())
            Text("Saved: \(summary(saved))").font(.caption.monospaced())
        }.padding(16).background(Color(red:0.045,green:0.07,blue:0.14)).preferredColorScheme(.dark)
    }
    func summary(_ value:RoomArrangement) -> String { value.rooms["cozy"]?.sorted { $0.key < $1.key }.map { "\($0.key):\(Int($0.value.x)),\(Int($0.value.y))" }.joined(separator:" / ") ?? "Default" }
    func scene(_ value:RoomArrangement) -> some View {
        GeometryReader { g in
            let scale = g.size.width/360
            ZStack(alignment:.topLeading) {
                Image(decorative:WardrobeArt.decode(room.file,folder:"Home")!,scale:1).resizable().interpolation(.none).frame(width:360,height:240).scaleEffect(x:mirrored ? -1 : 1,y:1)
                ForEach(items) { item in
                    let rect = RoomPlacement.rect(item,room:room,roomID:"cozy",arrangement:value,layout:layout)
                    Image(decorative:WardrobeArt.decode(WardrobeArt.home.items[item.id]!.file,folder:"Home")!,scale:1).resizable().interpolation(.none)
                        .frame(width:rect.width,height:rect.height).scaleEffect(x:mirrored && !HeritageArt.preservesOrientation(item.id) ? -1 : 1,y:1).position(x:rect.midX,y:rect.midY)
                }
            }.frame(width:360,height:240).scaleEffect(scale,anchor:.topLeading)
        }
    }
}
