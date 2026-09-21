import RealityKit
import SwiftUI

@available(iOS 18.0, *)
struct Companion3DPreview: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @StateObject private var world = Companion3DScene()
    @State private var pose = Companion3DScene.Pose.hello
    @State private var outfit = Companion3DScene.Outfit.classic
    @State private var lampOn = true
    @State private var prepared = false
    private let paper = Color(red: 0.95, green: 0.92, blue: 0.86)
    private let accent = Color(red: 0.12, green: 0.40, blue: 0.42)

    init() {
        #if DEBUG
        let args = ProcessInfo.processInfo.arguments
        let look: Companion3DScene.Outfit = args.contains("--3d-wings") ? .wings : args.contains("--3d-beanie") ? .beanie : .classic
        let mood: Companion3DScene.Pose = args.contains("--3d-focus") ? .focus : args.contains("--3d-celebrate") ? .celebrate : .hello
        _outfit = State(initialValue: look); _pose = State(initialValue: mood)
        #endif
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("A little world of your own.").font(.title2.bold())
                        Text("Try the first 3D companion. Drag the room to look around.")
                            .font(.subheadline).foregroundStyle(.secondary)
                    }.padding(.horizontal, 20)
                    Group {
                        if scenePhase == .active { Companion3DCanvas(world: world) }
                        else { paper }
                    }
                    .frame(height: 430)
                    .accessibilityLabel("3D companion in a wooden room")
                    .accessibilityHint("Use the camera buttons below to rotate the room")
                    HStack {
                        cameraButton("Look left", symbol: "arrow.uturn.left") { world.orbit(by: -0.2) }
                        Spacer()
                        Button("Reset view") { world.resetCamera() }.font(.subheadline.weight(.medium))
                        Spacer()
                        cameraButton("Look right", symbol: "arrow.uturn.right") { world.orbit(by: 0.2) }
                    }.padding(.horizontal, 24)
                    VStack(alignment: .leading, spacing: 16) {
                        Text("OUTFIT").font(.caption.weight(.semibold)).foregroundStyle(.secondary)
                        Picker("Outfit", selection: $outfit) {
                            ForEach(Companion3DScene.Outfit.allCases, id: \.self) { Text($0.rawValue).tag($0) }
                        }.pickerStyle(.segmented).accessibilityIdentifier("companion3D.outfit")
                        Text("MOOD").font(.caption.weight(.semibold)).foregroundStyle(.secondary)
                        Picker("Mood", selection: $pose) {
                            ForEach(Companion3DScene.Pose.allCases, id: \.self) { Text($0.rawValue).tag($0) }
                        }.pickerStyle(.segmented).accessibilityIdentifier("companion3D.pose")
                        Toggle("Warm lamp", isOn: $lampOn)
                        Text("Design preview · Your companion, purchases and focus coins are unchanged.")
                            .font(.footnote).foregroundStyle(.secondary)
                    }
                    .padding(20)
                    .background(.white.opacity(0.65), in: RoundedRectangle(cornerRadius: 24))
                    .padding(.horizontal, 16)
                }.padding(.vertical, 16)
            }
            .background(paper)
            .navigationTitle("3D preview")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
        }
        .tint(accent).preferredColorScheme(.light)
        .onAppear {
            guard !prepared else { return }
            prepared = true
            #if DEBUG
            let args = ProcessInfo.processInfo.arguments
            if args.contains("--3d-checks") { world.runSmokeChecks() }
            if args.contains("--3d-side") { world.orbit(by: 0.4) }
            #endif
            world.setOutfit(outfit); world.setPose(pose, animated: false)
        }
        .onChange(of: outfit) { _, value in world.setOutfit(value) }
        .onChange(of: pose) { _, value in world.setPose(value, animated: !reduceMotion) }
        .onChange(of: lampOn) { _, value in world.lamp.isEnabled = value }
        .onChange(of: scenePhase) { _, phase in
            if phase != .active { world.setPose(pose, animated: false) }
        }
    }

    private func cameraButton(_ label: String, symbol: String, action: @escaping () -> Void) -> some View {
        Button(action: action) { Image(systemName: symbol).frame(width: 44, height: 44) }
            .background(.white.opacity(0.65), in: Circle()).accessibilityLabel(label)
    }
}

@available(iOS 18.0, *)
private struct Companion3DCanvas: UIViewRepresentable {
    let world: Companion3DScene
    func makeCoordinator() -> Coordinator { Coordinator(world: world) }
    func makeUIView(context: Context) -> ARView {
        let view = ARView(frame: .zero, cameraMode: .nonAR, automaticallyConfigureSession: false)
        world.install(in: view)
        view.addGestureRecognizer(UIPanGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.drag(_:))))
        return view
    }
    func updateUIView(_ view: ARView, context: Context) {}
    static func dismantleUIView(_ view: ARView, coordinator: Coordinator) {
        coordinator.world.anchor.stopAllAnimations(recursive: true)
        view.scene.anchors.removeAll()
    }
    @MainActor final class Coordinator: NSObject {
        let world: Companion3DScene
        init(world: Companion3DScene) { self.world = world }
        @objc func drag(_ gesture: UIPanGestureRecognizer) {
            let delta = gesture.translation(in: gesture.view)
            world.orbit(by: -Float(delta.x) * 0.006)
            gesture.setTranslation(.zero, in: gesture.view)
        }
    }
}
