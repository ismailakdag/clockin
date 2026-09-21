import SwiftUI
import SceneKit

/// Native scene exported from the reviewed GLB. No network or runtime glTF dependency.
@MainActor
struct ClockinRobotView: View {
    var onTap: (() -> Void)?
    var animationEnabled = true
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.clockinContentActive) private var contentActive
    @State private var appeared = false
    @State private var lowPower = ProcessInfo.processInfo.isLowPowerModeEnabled
    @State private var wave = 0
    @State private var failed = false

    var body: some View {
        Group {
            if failed {
                ClockinMascotStage(state: .idle)
            } else {
                RobotSceneView(moving: animationEnabled && appeared && contentActive && scenePhase == .active && !reduceMotion && !lowPower,
                               wave: wave, failed: $failed)
                    .contentShape(Rectangle())
                    .onTapGesture { interact() }
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel("Focus companion")
                    .accessibilityHint(onTap == nil ? "Waves hello" : "Opens a larger view")
                    .accessibilityAddTraits(.isButton)
                    .accessibilityAction { interact() }
            }
        }
        .onAppear { appeared = true }
        .onDisappear { appeared = false }
        .onReceive(NotificationCenter.default.publisher(for: .NSProcessInfoPowerStateDidChange)) { _ in
            lowPower = ProcessInfo.processInfo.isLowPowerModeEnabled
        }
    }
    private func interact() {
        Haptics.play(.companionReaction)
        if let onTap { onTap() } else { wave += 1 }
    }
}

@MainActor
struct ClockinRobotDetail: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            GeometryReader { geometry in
                VStack(spacing: 16) {
                    Spacer(minLength: 0)
                    ClockinRobotView()
                        .frame(width: max(1, min(geometry.size.width - 32, geometry.size.height - 100)),
                               height: max(1, min(geometry.size.width - 32, geometry.size.height - 100)))
                    Text("Tap your companion to wave")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Spacer(minLength: 0)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .navigationTitle("Focus companion")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
    }
}

@MainActor
private struct RobotSceneView: UIViewRepresentable {
    let moving: Bool
    let wave: Int
    @Binding var failed: Bool

    final class Coordinator {
        var wave = 0
        var loadFailed = false
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeUIView(context: Context) -> SCNView {
        let view = SCNView(frame: .zero)
        view.backgroundColor = .clear
        view.isOpaque = false
        view.isUserInteractionEnabled = false
        view.preferredFramesPerSecond = 30
        view.antialiasingMode = .multisampling2X
        do {
            guard let url = Bundle.main.url(forResource: "ClockinRobot", withExtension: "scn") else {
                throw CocoaError(.fileNoSuchFile)
            }
            let scene = try SCNScene(url: url, options: nil)
            let camera = SCNNode()
            camera.camera = SCNCamera()
            camera.camera?.usesOrthographicProjection = true
            camera.camera?.orthographicScale = 1.04
            camera.camera?.zNear = 0.1
            camera.camera?.zFar = 20
            camera.position = SCNVector3(0, 0.85, 4)
            scene.rootNode.addChildNode(camera)
            view.pointOfView = camera
            let ambient = SCNNode()
            ambient.light = SCNLight()
            ambient.light?.type = .ambient
            ambient.light?.intensity = 650
            scene.rootNode.addChildNode(ambient)
            let key = SCNNode()
            key.light = SCNLight()
            key.light?.type = .directional
            key.light?.intensity = 1100
            key.eulerAngles = SCNVector3(-0.4, -0.5, 0)
            scene.rootNode.addChildNode(key)
            scene.rootNode.enumerateChildNodes { node, _ in
                node.animationPlayer(forKey: "wave")?.play()
            }
            view.scene = scene
        } catch {
            context.coordinator.loadFailed = true
        }
        return view
    }

    func updateUIView(_ view: SCNView, context: Context) {
        if context.coordinator.loadFailed {
            // SwiftUI state must not be changed synchronously during view updates.
            let failure = $failed
            Task { @MainActor in failure.wrappedValue = true }
            return
        }
        if context.coordinator.wave != wave {
            context.coordinator.wave = wave
            if moving {
                view.scene?.rootNode.enumerateChildNodes { node, _ in
                    let player = node.animationPlayer(forKey: "wave")
                    player?.stop()
                    player?.play()
                }
            }
        }
        view.scene?.rootNode.enumerateChildNodes { node, _ in
            node.animationPlayer(forKey: "wave")?.paused = !moving
        }
        view.isPlaying = moving
        view.rendersContinuously = moving
    }

    static func dismantleUIView(_ view: SCNView, coordinator: Coordinator) {
        view.isPlaying = false
        view.rendersContinuously = false
        view.scene = nil
    }
}
