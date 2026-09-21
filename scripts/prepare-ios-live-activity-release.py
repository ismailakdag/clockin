#!/usr/bin/env python3
"""Freeze the build-8 UI working tree and merge the Live Activity changes.

Pass the UI worktree explicitly: main is not the current iOS release baseline.
The source worktree is never modified. Conflicts abort before archive/upload.
"""
import argparse
import hashlib
import json
import re
from pathlib import Path
import shutil
import subprocess

parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument('--ui-source', type=Path, required=True)
parser.add_argument('--output', type=Path, required=True)
args = parser.parse_args()
repo = Path(__file__).resolve().parents[1]
ui = args.ui_source.resolve()
out = args.output.resolve()
assert (ui / 'docs/ios-testflight-0.2-8.md').is_file(), 'Missing release-8 provenance'
assert not out.exists(), 'Output must be a new directory'
source = out / 'source'
shutil.copytree(ui / 'iOS', source / 'iOS', ignore=shutil.ignore_patterns(
    'build', 'DerivedData', 'xcuserdata', '.DS_Store', 'Prototype'))

def replace_once(path, old, new):
    text = path.read_text()
    assert text.count(old) == 1, f'Unexpected source in {path}'
    path.write_text(text.replace(old, new, 1))

# Match the documented release-8 exclusions, leaving experiments in their worktree.
app = source / 'iOS/Clockin/ClockinApp.swift'
replace_once(app, '''        } else if #available(iOS 18.0, *), ProcessInfo.processInfo.arguments.contains("--companion-3d-preview") {
            Companion3DPreview()
''', '')
companion = source / 'iOS/Clockin/Views/Companion/CompanionView.swift'
replace_once(companion, '    @State private var showing3D = false\n', '')
replace_once(companion, ' && !showing3D', '')
replace_once(companion, '''                    if #available(iOS 18.0, *) {
                        Button { showing3D = true } label: {
                            Label("Try the 3D companion", systemImage: "cube.transparent")
                                .font(.subheadline.weight(.semibold)).frame(maxWidth: .infinity).padding(12)
                        }
                        .background(palette.surface, in: RoundedRectangle(cornerRadius: 14))
                        .accessibilityIdentifier("companion.preview3D")
                    }
''', '')
replace_once(companion, '''            .fullScreenCover(isPresented: $showing3D) {
                if #available(iOS 18.0, *) { Companion3DPreview() }
            }
''', '')
replace_once(companion, 'preview != nil || showing3D', 'preview != nil')

replace_once(companion, '    @State private var preview: WardrobeItem?', '    @State private var preview: WardrobeItem?\n    @State private var roomEditor: RoomEditorSession?')
replace_once(companion, '                    Label("\(wardrobe.balance.formatted()) focus coins", systemImage: "circle.circle.fill")', """                    if category == nil || category?.isHome == true {
                        Button { roomEditor = RoomEditorSession(state:wardrobe.state) } label: {
                            Label("Edit room",systemImage:"move.3d").frame(maxWidth:.infinity,minHeight:44)
                        }.buttonStyle(.bordered).accessibilityIdentifier("companion.editRoom")
                    }
                    Label("\(wardrobe.balance.formatted()) focus coins", systemImage: "circle.circle.fill")""")
replace_once(companion, '            .sheet(item: $preview) { item in CompanionHomePreview(item: item) }',
             '            .sheet(item: $preview) { item in CompanionHomePreview(item: item) }\n            .fullScreenCover(item:$roomEditor) { session in RoomEditorView(state:session.state) }')
replace_once(companion, '.celebrationBlocked(by: preview != nil)', '.celebrationBlocked(by: preview != nil || roomEditor != nil)')
replace_once(companion, 'visible && headerVisible && preview == nil && scenePhase', 'visible && headerVisible && preview == nil && roomEditor == nil && scenePhase')

base_revision = 'c871b11aa067ceecc8856a3f83bc3e1dcfba08e1'
merged = []
for rel in ['iOS/Config/Clockin-Info.plist', 'iOS/Config/Clockin.entitlements',
            'iOS/Shared/Core/ClockStore.swift', 'iOS/Shared/Intents/ClockIntents.swift',
            'iOS/Shared/Core/SessionOverlap.swift',
            'iOS/Clockin/Views/Goals/TodayGoalsCard.swift',
            'iOS/Clockin/Views/Momentum/MoneyMomentumView.swift',
            'iOS/Clockin/Views/Earnings/EarningsPeriod.swift',
            'iOS/Clockin/Views/Insights/InsightsPeriods.swift',
            'iOS/Clockin/Views/Insights/InsightsSnapshot.swift',
            'iOS/Clockin/Views/Insights/InsightsBadges.swift',
            'iOS/Clockin/Views/Insights/InsightsAggregateHeatmapView.swift',
            'iOS/Shared/Sync/ClockinActivityAttributes.swift', 'iOS/Shared/Sync/SessionMirror.swift',
            'iOS/ClockinWidgets/ClockinLiveActivity.swift', 'iOS/Clockin/PrivacyInfo.xcprivacy',
            'iOS/ClockinWidgets/PrivacyInfo.xcprivacy']:
    base = out / 'merge-base'
    base.write_bytes(subprocess.check_output(['git', '-C', str(repo), 'show', base_revision + ':' + rel]))
    result = subprocess.run(['git', 'merge-file', '-p', str(source / rel), str(base), str(repo / rel)], capture_output=True)
    assert result.returncode == 0, f'Merge conflict: {rel}'
    (source / rel).write_bytes(result.stdout)
    merged.append(rel)
base.unlink()
for rel in ['iOS/Shared/Sync/LiveActivityPush.swift', 'iOS/Shared/Sync/ClockinActivityState.swift',
            'iOS/Shared/Sync/LiveActivityPrivacy.swift', 'iOS/Clockin/Privacy/LiveActivityPrivacySection.swift']:
    (source / rel).parent.mkdir(parents=True, exist_ok=True)
    shutil.copy2(repo / rel, source / rel)
    merged.append(rel)
for rel in ['iOS/Shared/Sync/LiveActivityRegistrationStatus.swift', 'iOS/Clockin/Privacy/LiveActivitySetupView.swift',
            'iOS/Clockin/Views/Goals/MonthlyWorkPlan.swift', 'iOS/Clockin/Views/Goals/GoalsPaceView.swift',
            'iOS/Clockin/Views/Goals/ProgressHubView.swift', 'iOS/Clockin/Views/Insights/InsightsView.swift',
            'iOS/Clockin/Views/TodayLayout.swift',
            'iOS/Clockin/Views/CompactChimeCard.swift',
            'iOS/Clockin/Views/Goals/TodayPaceSummary.swift',
            'iOS/Clockin/Views/Insights/BadgeTier.swift',
            'iOS/Clockin/Views/Insights/SpaceBadgeGeometry.swift',
            'iOS/Clockin/Views/Insights/SpaceBadgeArt.swift',
            'iOS/Shared/Mascot/HeritageArt.swift',
            'iOS/Shared/Mascot/HomeSceneLayout.swift',
            'iOS/Shared/Mascot/RoomArrangement.swift',
            'iOS/Shared/Mascot/RoomPlacement.swift',
            'iOS/Clockin/Views/Companion/RoomEditorCanvas.swift',
            'iOS/Clockin/Views/Companion/RoomEditorView.swift',
            'iOS/Clockin/Views/Companion/CompanionHomeView.swift',
            'iOS/Shared/Mascot/Home/ataturk-portrait.jpg',
            'iOS/Shared/Mascot/Home/turkish-flag.svg',
            'iOS/Clockin/Views/Insights/PurchaseBadges.swift',
            'iOS/Clockin/Views/Insights/MonthWeek.swift',
            'iOS/Clockin/Views/Insights/InsightsBadgesView.swift',
            'iOS/Tests/manual/earnings/main.swift',
            'iOS/Tests/manual/insights/main.swift',
            'iOS/Tests/manual/badgetiers/main.swift',
            'iOS/Tests/manual/spaceart/main.swift',
            'iOS/Tests/manual/roomeditor/main.swift',
            'iOS/Tests/manual/workplan/main.swift',
            'iOS/Tests/manual/overlap/main.swift',
            'iOS/Clockin/Privacy/PrivacyPolicyBrowser.swift',
            'iOS/Clockin/Privacy/TimerPersistenceAlert.swift', 'iOS/Tests/manual/backups/main.swift']:
    (source / rel).parent.mkdir(parents=True, exist_ok=True)
    shutil.copy2(repo / rel, source / rel)
    merged.append(rel)
# The art regression harness must use the production renderer for the two vector/photo gifts.
wardrobe_tests = source / 'iOS/Tests/manual/wardrobe/main.swift'
replace_once(wardrobe_tests, 'func realImage(_ relative: String) -> CGImage {', '''func realImage(_ relative: String) -> CGImage {
    if let image = HeritageArt.render((relative as NSString).lastPathComponent,
                                      source: artRoot.appendingPathComponent(relative)) { return image }''')
replace_once(wardrobe_tests, 'let furniture = ["round-rug", "poster", "wall-clock", "bookshelf",',
             'let furniture = ["round-rug", "ataturk-portrait", "turkish-flag", "bookshelf",')
replace_once(wardrobe_tests, 'draw(image,x:x,y:p.y,w:Double(image.width),h:Double(image.height),mirror:layout.mirrored)',
             'draw(image,x:x,y:p.y,w:Double(image.width),h:Double(image.height),mirror:layout.mirrored && !HeritageArt.preservesOrientation(id))')
# Keep the offline scene proof on the same placements and full working sprite as SwiftUI.
proof = wardrobe_tests.read_text()
start = proof.index('// Offline scene proof')
end = proof.index('// A sprite can fit', start)
scene = proof[start:end]
scene = scene.replace('layout: CompanionHomeLayout) {', 'layout: CompanionHomeLayout, deskID: String = "desk-monitor") {', 1)
scene = scene.replace('"bookshelf", "desk-monitor",', '"bookshelf", deskID,')
scene = scene.replace('        let p=WardrobeGeometry.origin(pivot:item.pivot,anchor:room.slots[item.slot]!,degrees:0)\n        let x=layout.mirrored ? 360-p.x-Double(image.width):p.x', '        let rect = HomeSceneLayout.furnitureRect(item, in: room,\n            imageSize: CGSize(width: image.width, height: image.height), layout: layout)\n        let p = WardrobePoint(rect.minX, rect.minY), x = rect.minX')
scene = scene.replace('Double(image.width)', 'rect.width').replace('Double(image.height)', 'rect.height')
a = scene.index('    if activity == .working {')
b = scene.index('    let frame: String', a)
scene = scene[:a] + scene[b:]
scene = scene.replace('    let robot=WardrobeArt.composite(robot:realImage("Frames/"+frame+".png"),parts:overlays,size:314)!', '    let original = realImage("Frames/"+frame+".png")\n    let pose = activity == .working ? WardrobeArt.seatedWorkingFrame(original, seated: realImage("Frames/c01.png")) : original\n    let robot=WardrobeArt.composite(robot:pose,parts:overlays,size:314)!')
scene = scene.replace('    if activity == .working { context.clip(to:CGRect(x:0,y:0,width:360,height:room.slots["desk"]!.y)) }\n', '')
a = scene.index('    if activity == .working {')
b = scene.index('    savePNG', a)
scene = scene[:a] + scene[b:]
scene = scene.replace('+layout.rawValue+".png"', '+layout.rawValue+"-"+deskID+".png"')
scene = scene.replace('activity.center(in:room,layout:layout)',
    'activity.center(in:room,layout:layout,furniture:Dictionary(uniqueKeysWithValues:furniture.map { (realHome.items[$0]!.slot,$0) }))')
scene = scene.replace('draw(robot,x:-side/2,y:-side/2,w:side,h:side)',
                      'draw(robot,x:-side/2,y:-side/2,w:side,h:side,mirror:HomeSceneLayout.mirrorsCompanion(activity, layout:layout))')
scene = scene.replace('for layout in CompanionHomeLayout.allCases { homeProof(roomID:roomID,activity:activity,layout:layout) }', 'for layout in CompanionHomeLayout.allCases {\n            for desk in (activity == .working ? ["desk-monitor", "desk-lamp", "record-player"] : ["desk-monitor"]) {\n                homeProof(roomID:roomID,activity:activity,layout:layout,deskID:desk)\n            }\n        }')
proof = proof[:start] + scene + proof[end:]
# Background features matter too: fitting the outer canvas alone is insufficient.
checks = """
for (roomID, room) in realHome.rooms {
    for layout in CompanionHomeLayout.allCases {
        for seat in [[:], ["floorRight":"bean-bag"]] {
            let expected = CompanionHomeActivity.working.center(in:room,layout:layout,furniture:seat)
            for desk in ["", "desk-monitor", "desk-lamp", "record-player"] {
                var equipped = seat
                if !desk.isEmpty { equipped["desk"] = desk }
                let activity = CompanionHomeActivity.resolve(working:true,paused:false,elapsed:60,tired:false,furniture:equipped)
                let actual = activity.center(in:room,layout:layout,furniture:equipped)
                check(activity == .working, "working pose does not require a desk")
                check(actual.x == expected.x && actual.y == expected.y, "changing desk cannot move companion")
            }
            let rest = CompanionHomeActivity.resolve(working:false,paused:false,elapsed:0,tired:false,furniture:seat)
            check(rest == .relaxing, "idle companion sits with or without bean bag")
        }
        check(HomeSceneLayout.mirrorsCompanion(.working,layout:layout) == (layout == .deskLeft), "typing faces selected room direction")
        check(HomeSceneLayout.mirrorsCompanion(.relaxing,layout:layout) == (layout == .deskRight), "resting faces selected room direction")
        let wall = CGRect(x:22,y:24,width:316,height:142)
        let window = CGRect(x:layout.mirrored ? 26 : 234,y:27,width:100,height:101)
        for id in ["ataturk-portrait", "turkish-flag"] {
            let item = realHome.items[id]!, image = realImage("Home/"+item.file)
            let rect = HomeSceneLayout.furnitureRect(item, in:room,
                imageSize:CGSize(width:image.width,height:image.height),layout:layout)
            check(wall.contains(rect), "wall art clears ceiling and trim: \(roomID)/\(id)/\(layout)")
            check(!rect.intersects(window), "wall art clears window: \(roomID)/\(id)/\(layout)")
        }
        for id in ["desk-monitor", "desk-lamp", "record-player"] {
            let item = realHome.items[id]!, image = realImage("Home/"+item.file)
            let rect = HomeSceneLayout.furnitureRect(item, in:room,
                imageSize:CGSize(width:image.width,height:image.height),layout:layout)
            let shelf = realHome.items["bookshelf"]!, shelfImage = realImage("Home/"+shelf.file)
            let shelfRect = HomeSceneLayout.furnitureRect(shelf,in:room,
                imageSize:CGSize(width:shelfImage.width,height:shelfImage.height),layout:layout)
            check(abs(rect.minY-shelfRect.maxY-8) < 0.01, "decorative desk clears bookshelf by eight points")
            check(abs(rect.midX-shelfRect.midX) < 0.01, "desk centered below bookshelf")
            check(abs(rect.maxY-room.floorY) < 0.01, "desk feet meet back-wall floor")
            check(abs(rect.width/rect.height-Double(image.width)/Double(image.height)) < 0.001, "desk artwork preserves proportions")
        }
    }
}
"""
proof = proof.replace('// Offline scene proof', checks + '\n// Offline scene proof', 1)
proof = proof.replace('== .idle, "missing furniture falls back to standing"', '== .relaxing, "missing furniture rests on floor"')
proof = proof.replace('long active session stays at desk', 'long active session keeps working')
a = proof.index('for room in realHome.rooms.values {\n    for layout in CompanionHomeLayout.allCases {\n        let rect = CompanionHomeActivity.working.legsRect')
b = proof.index('let cache = WardrobeFrameCache', a)
proof = proof[:a] + proof[b:]
wardrobe_tests.write_text(proof)

merged.append('iOS/Tests/manual/wardrobe/main.swift')

# Free heritage room gifts. Asset files are local; no new runtime network requests.
catalog = source / 'iOS/Shared/Mascot/WardrobeCatalog.swift'
replace_once(catalog, '    static let items: [WardrobeItem] = [', '''    static let items: [WardrobeItem] = [
        .init(id: "ataturk-portrait", name: "Atatürk portrait", slot: .wallLeft, unlock: .free),
        .init(id: "turkish-flag", name: "Turkish flag", slot: .wallRight, unlock: .free),''')
replace_once(catalog, 'case "poster", "wall-clock", "certificate", "guitar":',
             'case "poster", "wall-clock", "certificate", "guitar", "ataturk-portrait", "turkish-flag":')
merged.append('iOS/Shared/Mascot/WardrobeCatalog.swift')
home = source / 'iOS/Shared/Mascot/Home/home-items.json'
home_manifest = json.loads(home.read_text())
home_manifest['items'].update({
    'ataturk-portrait': {'file': 'ataturk-portrait.jpg', 'name': 'Atatürk portrait', 'slot': 'wallLeft', 'pivot': [30, 40]},
    'turkish-flag': {'file': 'turkish-flag.svg', 'name': 'Turkish flag', 'slot': 'wallRight', 'pivot': [36, 26]}
})
home.write_text(json.dumps(home_manifest, indent=2, ensure_ascii=False) + '\n')
merged.append('iOS/Shared/Mascot/Home/home-items.json')
art = source / 'iOS/Shared/Mascot/WardrobeArt.swift'
replace_once(art, '    static func decode(_ file: String, folder: String) -> CGImage? {', '''    static func decode(_ file: String, folder: String) -> CGImage? {
        if folder == "Home", ["ataturk-portrait.jpg", "turkish-flag.svg"].contains(file) {
            return HeritageArt.render(file, source: url(file, folder: folder))
        }''')
merged.append('iOS/Shared/Mascot/WardrobeArt.swift')
wardrobe_model = source / 'iOS/Shared/Mascot/Wardrobe.swift'
replace_once(wardrobe_model, '    var homeLampOn = true', '    var homeLampOn = true\n    var homeArrangement = RoomArrangement()')
replace_once(wardrobe_model, 'case owned, equipped, colorway, room, furniture, seeded, homeLayout, homeLampOn',
             'case owned, equipped, colorway, room, furniture, seeded, homeLayout, homeLampOn, homeArrangement')
replace_once(wardrobe_model, '        homeLampOn = try values.decodeIfPresent(Bool.self, forKey: .homeLampOn) ?? true',
             '        homeLampOn = try values.decodeIfPresent(Bool.self, forKey: .homeLampOn) ?? true\n        homeArrangement = (try? values.decode(RoomArrangement.self, forKey: .homeArrangement)) ?? .init()')

replace_once(wardrobe_model, 'if working && furniture["desk"] != nil { return .working }',
             'if working { return .working }')
replace_once(wardrobe_model, '        return .idle\n', '        return .relaxing\n')
replace_once(wardrobe_model, 'case .working: "At the desk"', 'case .working: "Working"')
replace_once(wardrobe_model, 'self == .deskLeft ? "Desk left" : "Desk right"',
             'self == .deskLeft ? "Room left" : "Room right"')
replace_once(wardrobe_model, 'func center(in room: WardrobeRoom, layout: CompanionHomeLayout)',
             'func center(in room: WardrobeRoom, layout: CompanionHomeLayout, furniture: [String:String] = [:], roomID: String = "", arrangement: RoomArrangement = .init())')
replace_once(wardrobe_model, """            let desk = room.slots["desk"] ?? .init(142,158)
            // The desktop fixes the upper pose independently of its feet.
            point = .init(desk.x + 20, desk.y + 34 - side * (0.86 - 0.5))""", """            return HomeSceneLayout.seatedCenter(in: room, layout: layout, side: side, feet: mood.feet, furniture: furniture, roomID: roomID, arrangement: arrangement)""")
replace_once(wardrobe_model, """            let seat = room.slots["floorRight"] ?? .init(302,224)
            point = .init(seat.x, seat.y - 12 - side * (mood.feet - 0.5))""", """            return HomeSceneLayout.seatedCenter(in: room, layout: layout, side: side, feet: mood.feet, furniture: furniture, roomID: roomID, arrangement: arrangement)""")
replace_once(wardrobe_model, '            point = .init(bed.x - 7, bed.y - 28)', """            let delta = HomeSceneLayout.attachmentOffset("companion-bed",in:room,layout:layout,roomID:roomID,arrangement:arrangement)
            return .init(layout.x(bed.x - 7) + delta.x, bed.y - 28 + delta.y)""")
# Remove the obsolete separate-leg positioning now that the full pose is used.
model_text = wardrobe_model.read_text()
a = model_text.index('    func legsRect(')
b = model_text.index('    func center(', a)
wardrobe_model.write_text(model_text[:a] + model_text[b:])
preview = source / 'iOS/Clockin/Views/Companion/CompanionHomePreview.swift'
replace_once(preview, '                Text("At home").tag(Optional(CompanionHomeActivity.idle))\n', '')
replace_once(preview, '                if draft.furniture["desk"] != nil { Text("At the desk").tag(Optional(CompanionHomeActivity.working)) }',
             '                Text("Working").tag(Optional(CompanionHomeActivity.working))')
replace_once(preview, '                if draft.furniture["floorRight"] == "bean-bag" { Text("Taking a break").tag(Optional(CompanionHomeActivity.relaxing)) }',
             '                Text("Taking a break").tag(Optional(CompanionHomeActivity.relaxing))')
merged.append('iOS/Clockin/Views/Companion/CompanionHomePreview.swift')
atmosphere = source / 'iOS/Clockin/Views/Companion/CompanionHomeAtmosphere.swift'
replace_once(atmosphere, """            if state.furniture["desk"] == "desk-lamp", let anchor = room.slots["desk"] {
                glow(anchor.x+7,anchor.y-39,radius:40,strength:0.8)
            }""", """            if state.furniture["desk"] == "desk-lamp" {
                let rect = HomeSceneLayout.decorativeDeskRect(in: room, imageSize: CGSize(width:110,height:112), layout:.deskLeft)
                let scale = rect.height / 112
                glow(rect.minX+59*scale,rect.minY+19*scale,radius:30,strength:0.8)
            }""")
replace_once(atmosphere, '        if state.furniture["desk"] == "desk-monitor", let anchor = room.slots["desk"] { sources.append(.init(anchor.x-39,anchor.y-25)) }',
             """        if state.furniture["desk"] == "desk-monitor" {
            let rect = HomeSceneLayout.decorativeDeskRect(in: room, imageSize: CGSize(width:110,height:104), layout:.deskLeft)
            let scale = rect.height / 104
            sources.append(.init(rect.minX+13*scale,rect.minY+25*scale))
        }""")
replace_once(atmosphere, '    private var key = ""', '    private var key = ""\n    private var arrangement = RoomArrangement()')
replace_once(atmosphere, '        guard next != key else { return }', '        guard next != key || arrangement != state.homeArrangement else { return }\n        arrangement = state.homeArrangement')
replace_once(atmosphere, '        func x(_ value: Double)', """        func placed(_ id: String, _ size: CGSize) -> CGRect {
            guard let item = WardrobeArt.home.items[id] else { return .zero }
            return HomeSceneLayout.furnitureRect(item,in:room,imageSize:size,layout:.deskLeft,
                roomID:state.room,arrangement:state.homeArrangement)
        }
        func x(_ value: Double)""")
replace_once(atmosphere, 'HomeSceneLayout.decorativeDeskRect(in: room, imageSize: CGSize(width:110,height:112), layout:.deskLeft)', 'placed("desk-lamp",CGSize(width:110,height:112))')
replace_once(atmosphere, 'HomeSceneLayout.decorativeDeskRect(in: room, imageSize: CGSize(width:110,height:104), layout:.deskLeft)', 'placed("desk-monitor",CGSize(width:110,height:104))')
replace_once(atmosphere, '            if state.furniture["floorLeft"] == "floor-lamp", let anchor = room.slots["floorLeft"] {\n                glow(anchor.x,anchor.y-84,radius:48,strength:0.8)', '            if state.furniture["floorLeft"] == "floor-lamp" {\n                let rect = placed("floor-lamp",CGSize(width:58,height:106))\n                glow(rect.minX+28,rect.minY+18,radius:48,strength:0.8)')
replace_once(atmosphere, '        if state.furniture["floorLeft"] == "coffee-machine", let anchor = room.slots["floorLeft"] { sources.append(.init(anchor.x,anchor.y-61)) }', '        if state.furniture["floorLeft"] == "coffee-machine" {\n            let rect = placed("coffee-machine",CGSize(width:58,height:80))\n            sources.append(.init(rect.minX+28,rect.minY+17))\n        }')
merged.append('iOS/Clockin/Views/Companion/CompanionHomeAtmosphere.swift')
merged.append('iOS/Shared/Mascot/Wardrobe.swift')

replace_once(app, '            entryView\n', '            entryView\n                .liveActivitySetup()\n                .timerPersistenceAlert()\n')
merged.append('iOS/Clockin/ClockinApp.swift')
replace_once(source / 'iOS/Clockin/Privacy/LiveActivitySetupView.swift',
             '            // Release integration: block celebrations while the guide is visible.',
             '            .celebrationBlocked(by: showing)')
replace_once(source / 'iOS/Clockin/Views/SettingsView.swift',
             '                dataSection', '''                LiveActivityPrivacySection(
                    openSetup: { openPrivacySheet(.liveActivitySetup) },
                    openPolicy: { openPrivacySheet(.privacyPolicy) }
                )
                dataSection''')
settings = source / 'iOS/Clockin/Views/SettingsView.swift'
replace_once(settings, '    case guide\n', '    case guide\n    case liveActivitySetup\n    case privacyPolicy\n')
replace_once(settings, '                    case .guide: UsageGuideView()', '''                    case .guide: UsageGuideView()
                    case .liveActivitySetup: LiveActivitySetupView()
                    case .privacyPolicy: PrivacyPolicyBrowser()''')
replace_once(settings, '    private var paySection: some View {', '''    private func openPrivacySheet(_ destination: SettingsSheet) {
        commitEarlierRate()
        commitRate()
        rateIsFocused = false
        earlierRateIsFocused = false
        if pendingRate == nil { sheet = destination }
    }

    private var paySection: some View {''')
merged.append('iOS/Clockin/Views/SettingsView.swift')
# Today layout changes reuse owned UI fragments while keeping release-only tools and companion sheets.
dashboard = source / 'iOS/Clockin/Views/DashboardView.swift'
main_dashboard = (repo / 'iOS/Clockin/Views/DashboardView.swift').read_text()
def owned_dashboard_block(start, end):
    return main_dashboard[main_dashboard.index(start):main_dashboard.index(end)]
replace_once(dashboard, '    case customize\n', '    case customize\n    case liveActivitySetup\n')
replace_once(dashboard, '        case .customize: "customize"',
             '        case .customize: "customize"\n        case .liveActivitySetup: "live-activity-setup"')
replace_once(dashboard, '                case .customize: DashboardCustomizationView()',
             '                case .customize: DashboardCustomizationView()\n                case .liveActivitySetup: LiveActivitySetupView()')
replace_once(dashboard, '    let isSelected: Bool',
             owned_dashboard_block('    @AppStorage("Clockin.Today.Show.summary")', '    let isSelected: Bool') + '    let isSelected: Bool')
replace_once(dashboard, '                    if mascotEnabled {',
             '                    TodayQuickLinks(open: openQuickLink)\n                    if mascotEnabled && showCompanionCard {')
replace_once(dashboard, '                            TodayCard(now: now)',
             '                            if showSummary { TodayTotalsCard(now: now) }')
replace_once(dashboard, '                            TodayGoalsCard(now: now, showInsights: showInsights, setGoals: setGoals)',
             '                            if showGoals { TodayGoalsCard(now: now, showInsights: showInsights, setGoals: setGoals) }')
replace_once(dashboard, '''                    MoneyMomentumView()
                    if store.currencyCode == "USD" {
                        exchangeCard
                    }
                    recentSection
                    Button("Customize Today", systemImage: "slider.horizontal.3") { sheet = .customize }
                        .font(.footnote.weight(.medium)).frame(minHeight: 44)
                        .accessibilityIdentifier("dashboard.customize")''', '''                    if showMomentum { MoneyMomentumView() }
                    if showRecent { recentSection }
                    if store.currencyCode == "USD" && showExchange { exchangeCard }''')
replace_once(dashboard, '    private func routeReminderEnd() {',
             owned_dashboard_block('    private func openQuickLink', '    private func routeReminderEnd') + '    private func routeReminderEnd() {')
replace_once(dashboard, '            Button { sheet = .settings } label: {',
             owned_dashboard_block('            Button { sheet = .customize } label: {', '            Button { sheet = .settings } label: {') + '            Button { sheet = .settings } label: {')
dashboard_text = dashboard.read_text()
start = dashboard_text.index('    private var exchangeCard:')
end = dashboard_text.index('    @ViewBuilder private var recentSection:', start)
dashboard_text = dashboard_text[:start] + owned_dashboard_block('    private var exchangeCard:', '    @ViewBuilder private var recentSection:') + dashboard_text[end:]
start = dashboard_text.index('private struct TodayCard:')
end = dashboard_text.index('private extension View {', start)
dashboard.write_text(dashboard_text[:start] + dashboard_text[end:])
replace_once(dashboard, 'store.sessions.prefix(5)', 'store.sessions.prefix(3)')
replace_once(dashboard, 'SectionTitle("RECENT SESSIONS")', 'SectionTitle("LAST 3 SESSIONS")')
merged.append('iOS/Clockin/Views/DashboardView.swift')
shortcuts = source / 'iOS/Clockin/Views/DashboardShortcuts.swift'
replace_once(shortcuts, '''struct DashboardPinOptions: View {
    var body: some View {
        Form {
''', '''struct DashboardPinOptions: View {
    var body: some View {
        Form {
            TodayCustomizationSections()
''')
replace_once(shortcuts, 'DashboardChimeCard { open(.chime) }', 'CompactChimeCard { open(.chime) }')
shortcut_text = shortcuts.read_text()
start = shortcut_text.index('private struct DashboardChimeCard:')
end = shortcut_text.index('private struct DashboardReminderCard:', start)
shortcuts.write_text(shortcut_text[:start] + shortcut_text[end:])
merged.append('iOS/Clockin/Views/DashboardShortcuts.swift')

# Merge guide topics independently so release-only companion and currency guidance survives.
guide = source / 'iOS/Clockin/Views/Guide/UsageGuideView.swift'
main_guide = (repo / 'iOS/Clockin/Views/Guide/UsageGuideView.swift').read_text()
def topic_block(text, title):
    pattern = r'                    topic\("' + re.escape(title) + r'"[^\n]*\n[^\n]*\n'
    matches = re.findall(pattern, text)
    assert len(matches) == 1, f'Expected guide topic: {title}'
    return matches[0]
for title in ['Overlap warnings', 'Level and badges']:
    replace_once(guide, topic_block(guide.read_text(), title), topic_block(main_guide, title))
replace_once(guide, topic_block(guide.read_text(), 'Insights'),
             topic_block(main_guide, 'Goals & Pace') + topic_block(main_guide, 'Progress'))
replace_once(guide, 'A monthly goal adds a dashed line from zero on the 1st to the goal on the last day, plus percent and remaining hours. ', '')
replace_once(guide, "The hours projection uses Insights' average completed work over the same window.",
             'Monthly targets and hour forecasts live in Progress > Goals.')
replace_once(guide, 'Past months show final numbers without a projection, using your current goal for comparison.',
             'Past months show final numbers.')
replace_once(guide, 'open Badges > Companion', 'open Progress > Badges > Companion')
replace_once(guide, "The text row on Today's card opens Insights.", "The text row on Today's card opens Progress > Badges.")
replace_once(guide, 'New badge banners open Badges when tapped', 'New badge banners open Progress > Badges when tapped')
replace_once(guide, 'Choose W for a calendar week,',
             'Choose W for days 1–7, 8–14, 15–21, 22–28 or the remaining days of each month,')
replace_once(guide, 'Home lets you choose a room and place furniture in fixed slots.', 'Choose home items, then tap Edit room to drag them into place. Arrows fine-tune; Save keeps your layout, Cancel discards changes, and Reset room restores the preset. Each room remembers its layout.')
merged.append('iOS/Clockin/Views/Guide/UsageGuideView.swift')

# Keep release currency conversion and money outlook while moving hour goals into Progress.
month_view = source / 'iOS/Clockin/Views/Earnings/MonthPerformanceView.swift'
month_text = month_view.read_text()
start = month_text.index('            if let goal = performance.goal {')
end = month_text.index('            Text(comparison)', start)
month_text = month_text[:start] + month_text[end:]
start = month_text.index('            ForEach(performance.target)')
end = month_text.index('\n        }\n        .chartXScale', start)
month_text = month_text[:start] + month_text[end:]
month_view.write_text(month_text)
replace_once(month_view, 'if performance.duration > 0 || performance.goal != nil', 'if performance.duration > 0')
replace_once(month_view, 'max(performance.duration, performance.goal?.target ?? 0)', 'performance.duration')
replace_once(month_view, 'Monthly hours and goal pace', 'Monthly worked hours')
month_text = month_view.read_text()
start = month_text.index('                Text("Hours: daily bars')
end = month_text.index('\n                    .font', start)
month_view.write_text(month_text[:start] + '                Text("Hours: daily bars and cumulative solid line.")' + month_text[end:])
merged.append('iOS/Clockin/Views/Earnings/MonthPerformanceView.swift')

# Progress owns navigation while retaining the release UI's celebration/companion lifecycle.
root_view = source / 'iOS/Clockin/Views/RootView.swift'
replace_once(root_view, '    case insights\n    case badges', '    case progress')
replace_once(root_view, '    @State private var goalEditorRequest = false',
             '    @State private var goalEditorRequest = false\n    @State private var progressSection: ProgressSection = .goals')
replace_once(root_view, '                tab = .badges',
             '                progressSection = .badges\n                tab = .progress')
root_text = root_view.read_text()
main_root = (repo / 'iOS/Clockin/Views/RootView.swift').read_text()
start_marker = '    private var tabs: some View {'
end_marker = '    private func updateChimes'
tabs = main_root[main_root.index(start_marker):main_root.index(end_marker)]
tabs = tabs.replace('deskSummary == nil, showHistory:',
    'deskSummary == nil && !celebrations.hasBlockingPresentation && (celebrations.event == nil || celebrations.event?.isReaction == true), showHistory:')
tabs = tabs.replace('tab == .progress && !showsDeskMode)',
    'tab == .progress && !showsDeskMode && !celebrations.hasBlockingPresentation && !showsCelebration)')
root_view.write_text(root_text[:root_text.index(start_marker)] + tabs + root_text[root_text.index(end_marker):])
merged.append('iOS/Clockin/Views/RootView.swift')

badges = source / 'iOS/Clockin/Views/Badges/BadgesView.swift'
replace_once(badges, '        NavigationStack {', '        Group {')
replace_once(badges, '                            levelCard(stats)\n                            InsightsBadgesView(badges: stats.badges)',
             '                            InsightsBadgesView(badges: stats.badges)\n                            DisclosureGroup("Level & XP") { levelCard(stats) }')
replace_once(badges, 'Goals do not add XP. They are yours to set, so a level built on them would not mean the same thing for everyone.',
             'Personal goals do not add XP.')
replace_once(badges, '            .navigationTitle("Badges")\n', '')
replace_once(source / 'iOS/Clockin/Views/Insights/InsightsBadgesView.swift',
             '        // Release integration: block celebrations while a badge is open.',
             '        .celebrationBlocked(by: selectedBadge != nil)')
# A successful purchase refreshes the shared snapshot and celebration queue immediately.
wardrobe_store = source / 'iOS/Clockin/Views/Companion/WardrobeStore.swift'
replace_once(wardrobe_store, """        guard state.buy(item, earned: earned, ledger: &ledger, now: .now) else { return false }
        persist(); SessionMirror.shared.refreshCompanion()""", """        guard state.buy(item, earned: earned, ledger: &ledger, now: .now) else { return false }
        persist(); SessionMirror.shared.refresh()""")
replace_once(wardrobe_store, '    func setHomeLayout(', """    func setRoomArrangement(_ draft: RoomArrangement, room: String) {
        // Merge only this room; a refresh or purchase must not be overwritten.
        state.homeArrangement.merge(room:room,from:draft)
        persist()
    }
    func setHomeLayout(""")
merged.append('iOS/Clockin/Views/Companion/WardrobeStore.swift')
merged.append('iOS/Clockin/Views/Badges/BadgesView.swift')

reports = source / 'iOS/Clockin/Views/Insights/InsightsView.swift'
replace_once(reports, '                  dailyGoal: dailyGoal, monthlyGoal: monthlyGoal)',
             '                  dailyGoal: dailyGoal, monthlyGoal: monthlyGoal)\n        collectionBadges = PurchaseBadges.make(ledger: WardrobeStore.shared.ledger)')
replace_once(reports, '    @EnvironmentObject private var store: ClockStore',
             '    @EnvironmentObject private var store: ClockStore\n    @ObservedObject private var celebrations = CelebrationCenter.shared')
replace_once(reports, '''        TimelineView(.periodic(from: .now, by: 60)) { context in
            let stats = InsightsSnapshot(store: store, now: context.date,
                                         dailyGoal: dailyGoalHours, monthlyGoal: monthlyGoalHours)
            reportsContent(stats, now: context.date)
        }''', '''        Group {
            if let stats = celebrations.snapshot {
                reportsContent(stats, now: celebrations.snapshotDate)
            }
        }''')
replace_once(reports, '        // Release integration: block celebrations while sharing reports.',
             '        .celebrationBlocked(by: shareSnapshot != nil)')

copy_edits = {
    'iOS/Clockin/Views/Companion/CompanionView.swift': {
        'Earn 10 coins per completed hour. Each session is rounded down to whole minutes; those minutes are added together, then divided by six. Earn 25 per day meeting your current daily goal, 50 per badge achieved in your archive, and 100 per level, including level 1. Running sessions do not earn coins yet. Editing the archive or daily goal recalculates earnings. Purchases stay owned and your balance never drops below zero.':
        '10 coins/hour, 25/goal day, 50/work badge, 100/level. Saved work only; minutes round down. Edits recalculate coins. Purchased items stay yours.'
    },
    'iOS/Clockin/Views/Companion/CompanionHomePreview.swift': {
        'Preview freely. Your items and coins stay unchanged until you choose.': 'Try it before you choose.',
        'Unlock this item by reaching its milestone. You can still try it on.': 'Reach the milestone to unlock.',
        'Keep focusing to earn more coins. You can still preview this item.': 'Keep working to earn more coins.'
    },
    'iOS/Clockin/Views/SettingsView.swift': {
        'Turn the phone sideways for a large timer that keeps the screen on while you work. Turn it off to keep Clockin upright.':
        'Turn sideways for a large, always-on work timer.'
    },
}
for rel, replacements in copy_edits.items():
    for old, new in replacements.items():
        replace_once(source / rel, old, new)
    if rel not in merged: merged.append(rel)

mirror = (source / 'iOS/Shared/Sync/SessionMirror.swift').read_text()
for required in ['companionSubscriptions', 'func refreshCompanion()', 'snapshot.wardrobeJSON',
                 'CelebrationCenter.shared.refresh(store: store)', 'LiveActivityPush.shared.observe(activity)']:
    assert required in mirror, f'Lost integration: {required}'

manifest = {str(p.relative_to(source)): hashlib.sha256(p.read_bytes()).hexdigest()
            for p in sorted(source.rglob('*')) if p.is_file()}
(out / 'source-manifest.json').write_text(json.dumps(manifest, indent=2) + '\n')
(out / 'provenance.json').write_text(json.dumps({
    'ui_source': str(ui), 'ui_head': subprocess.check_output(['git', '-C', str(ui), 'rev-parse', 'HEAD'], text=True).strip(),
    'includes_ui_working_tree': True, 'live_activity_base': base_revision,
    'merged_files': merged, 'excluded': ['Prototype', '3D companion presentation and launch route']
}, indent=2) + '\n')
print(f'Frozen {len(manifest)} files at {source}; UI and companion hooks preserved.')
