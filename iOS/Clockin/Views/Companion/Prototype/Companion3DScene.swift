import RealityKit
import UIKit
import Combine

/// An isolated, procedural look-development scene. No wardrobe or work data is read or written.
@available(iOS 18.0, *)
@MainActor
final class Companion3DScene: ObservableObject {
    enum Pose: String, CaseIterable { case hello = "Hello", focus = "Focus", celebrate = "Celebrate" }
    enum Outfit: String, CaseIterable { case classic = "Classic", beanie = "Beanie", wings = "Wings" }

    let anchor = AnchorEntity(world: .zero)
    let camera = PerspectiveCamera()
    let robot = Entity()
    let head = Entity()
    let leftArm = Entity()
    let rightArm = Entity()
    let beanie = Entity()
    let wings = Entity()
    let lamp = PointLight()
    private(set) var yaw: Float = 0.38
    private(set) var pose = Pose.hello
    private(set) var outfit = Outfit.classic

    private let ivory = UIColor(red: 0.92, green: 0.93, blue: 0.90, alpha: 1)
    private let orange = UIColor(red: 1, green: 0.39, blue: 0.055, alpha: 1)
    private let ink = UIColor(red: 0.025, green: 0.043, blue: 0.054, alpha: 1)
    private let teal = UIColor(red: 0.12, green: 0.40, blue: 0.42, alpha: 1)
    private let cyan = UIColor(red: 0.14, green: 0.88, blue: 1, alpha: 1)
    private var materials: [String: SimpleMaterial] = [:]

    init() {
        anchor.name = "CompanionPrototype"
        makeRoom()
        makeRobot()
        camera.camera.fieldOfViewInDegrees = 43
        anchor.addChild(camera)
        updateCamera()
        let key = DirectionalLight()
        key.light.color = UIColor(red: 1, green: 0.88, blue: 0.73, alpha: 1)
        key.light.intensity = 2200
        key.shadow = .init()
        key.look(at: [0, 0, 0], from: [-3, 6, 5], relativeTo: nil)
        anchor.addChild(key)
        let fill = PointLight()
        fill.light.color = UIColor(red: 0.78, green: 0.87, blue: 1, alpha: 1)
        fill.light.intensity = 700
        fill.light.attenuationRadius = 12
        fill.position = [3, 4, 4]
        anchor.addChild(fill)
        lamp.light.color = UIColor(red: 1, green: 0.67, blue: 0.30, alpha: 1)
        lamp.light.intensity = 110
        lamp.light.attenuationRadius = 4
        lamp.position = [-1.1, 1.5, 0.3]
        anchor.addChild(lamp)
        setPose(.hello, animated: false)
        setOutfit(.classic)
    }

    func install(in view: ARView) {
        view.environment.background = .color(UIColor(red: 0.95, green: 0.92, blue: 0.86, alpha: 1))
        view.environment.lighting.intensityExponent = 0.5
        view.renderOptions = [.disableMotionBlur, .disableDepthOfField, .disableCameraGrain]
        view.scene.addAnchor(anchor)
    }

    func setOutfit(_ value: Outfit) {
        outfit = value
        beanie.isEnabled = value == .beanie
        wings.isEnabled = value == .wings
    }

    func setPose(_ value: Pose, animated: Bool) {
        pose = value
        func move(_ entity: Entity, position: SIMD3<Float>? = nil, angle: Float, axis: SIMD3<Float>) {
            var target = entity.transform
            if let position { target.translation = position }
            target.rotation = simd_quatf(angle: angle, axis: axis)
            entity.stopAllAnimations(recursive: false)
            if animated { entity.move(to: target, relativeTo: entity.parent, duration: 0.42, timingFunction: .easeInOut) }
            else { entity.transform = target }
        }
        move(robot, position: value == .focus ? [-0.93, 0.04, -0.36] : [0.55, 0.04, 0.25],
             angle: value == .focus ? 0.12 : -0.10, axis: [0, 1, 0])
        move(head, angle: value == .focus ? 0.16 : -0.04, axis: [1, 0, 0])
        move(leftArm, angle: value == .celebrate ? -2.25 : -0.12, axis: [0, 0, 1])
        move(rightArm, angle: value == .focus ? 0.12 : 2.25, axis: [0, 0, 1])
        // Keep the hands above the desk during focus rather than inside its surface.
        if value == .focus {
            move(leftArm, angle: -1.10, axis: [1, 0, 0])
            move(rightArm, angle: -1.10, axis: [1, 0, 0])
        }
    }

    func orbit(by delta: Float) {
        yaw = min(0.85, max(-0.35, yaw + delta))
        updateCamera()
    }

    func resetCamera() { yaw = 0.38; updateCamera() }

    private func updateCamera() {
        camera.look(at: [0, 1.0, 0], from: [sin(yaw) * 7.8, 4.3, cos(yaw) * 7.8], relativeTo: nil)
    }

    private func material(_ color: UIColor, metal: Bool = false) -> SimpleMaterial {
        let key = color.description + (metal ? "metal" : "matte")
        if let material = materials[key] { return material }
        let value = SimpleMaterial(color: color, roughness: metal ? 0.32 : 0.68, isMetallic: metal)
        materials[key] = value
        return value
    }

    @discardableResult
    private func box(_ parent: Entity, _ size: SIMD3<Float>, _ at: SIMD3<Float>, _ color: UIColor,
                     radius: Float = 0.025, metal: Bool = false) -> ModelEntity {
        let node = ModelEntity(mesh: .generateBox(size: size, cornerRadius: radius), materials: [material(color, metal: metal)])
        node.position = at; parent.addChild(node); return node
    }

    @discardableResult
    private func ball(_ parent: Entity, _ size: SIMD3<Float>, _ at: SIMD3<Float>, _ color: UIColor,
                      luminous: Bool = false) -> ModelEntity {
        let mesh = MeshResource.generateSphere(radius: 1)
        let node = luminous ? ModelEntity(mesh: mesh, materials: [UnlitMaterial(color: color)]) :
            ModelEntity(mesh: mesh, materials: [material(color)])
        node.scale = size; node.position = at; parent.addChild(node); return node
    }

    @discardableResult
    private func rod(_ parent: Entity, from start: SIMD3<Float>, to end: SIMD3<Float>, radius: Float,
                     color: UIColor, luminous: Bool = false) -> ModelEntity {
        let delta = end - start
        let mesh = MeshResource.generateCylinder(height: simd_length(delta), radius: radius)
        let node = luminous ? ModelEntity(mesh: mesh, materials: [UnlitMaterial(color: color)]) :
            ModelEntity(mesh: mesh, materials: [material(color)])
        node.position = (start + end) / 2
        node.orientation = simd_quatf(from: [0, 1, 0], to: simd_normalize(delta))
        parent.addChild(node); return node
    }

    private func arc(_ parent: Entity, center: SIMD3<Float>, radius: Float, start: Float, end: Float,
                     thickness: Float, color: UIColor, luminous: Bool = false, segments: Int = 16) {
        // One smooth mesh per curve instead of dozens of separate cylinders.
        var positions: [SIMD3<Float>] = [], normals: [SIMD3<Float>] = [], indices: [UInt32] = []
        let sides = 8
        for i in 0...segments {
            let angle = start + (end - start) * Float(i) / Float(segments)
            let radial = SIMD3<Float>(cos(angle), sin(angle), 0)
            for j in 0...sides {
                let around = Float(j) / Float(sides) * .pi * 2
                let normal = radial * cos(around) + SIMD3<Float>(0, 0, sin(around))
                positions.append(center + radial * radius + normal * thickness)
                normals.append(normal)
            }
        }
        for i in 0..<segments { for j in 0..<sides {
            let a = UInt32(i * (sides + 1) + j), b = a + UInt32(sides + 1)
            indices += [a, b, b + 1, a, b + 1, a + 1]
        } }
        var descriptor = MeshDescriptor(name: "Rounded curve")
        descriptor.positions = MeshBuffers.Positions(positions)
        descriptor.normals = MeshBuffers.Normals(normals)
        descriptor.primitives = .triangles(indices)
        guard let mesh = try? MeshResource.generate(from: [descriptor]) else { return }
        let node = luminous ? ModelEntity(mesh: mesh, materials: [UnlitMaterial(color: color)]) :
            ModelEntity(mesh: mesh, materials: [material(color)])
        parent.addChild(node)
    }

    private func makeRobot() {
        anchor.addChild(robot); robot.name = "Robot"
        for side: Float in [-1, 1] {
            box(robot, [0.27, 0.05, 0.37], [side * 0.17, 0.04, 0.06], orange)
            box(robot, [0.26, 0.19, 0.37], [side * 0.17, 0.145, 0.06], ivory, radius: 0.075)
            box(robot, [0.17, 0.27, 0.19], [side * 0.17, 0.35, 0], ivory, radius: 0.07)
            ball(robot, [0.10, 0.09, 0.10], [side * 0.17, 0.50, 0], ink)
            ball(robot, [0.055, 0.055, 0.025], [side * 0.17, 0.51, 0.09], orange)
            box(robot, [0.20, 0.27, 0.23], [side * 0.15, 0.66, 0], ivory, radius: 0.08)
        }
        box(robot, [0.47, 0.19, 0.30], [0, 0.84, 0], ink, radius: 0.07)
        box(robot, [0.44, 0.14, 0.34], [0, 0.88, 0.03], ivory, radius: 0.06)
        box(robot, [0.57, 0.43, 0.39], [0, 1.14, 0], ivory, radius: 0.13)
        ball(robot, [0.15, 0.15, 0.055], [0, 1.14, 0.195], orange)
        ball(robot, [0.119, 0.119, 0.064], [0, 1.14, 0.226], ink)
        ball(robot, [0.085, 0.085, 0.047], [0, 1.14, 0.269], cyan, luminous: true)
        ball(robot, [0.045, 0.045, 0.027], [-0.014, 1.16, 0.30], .white, luminous: true)
        box(robot, [0.20, 0.10, 0.21], [0, 1.40, 0], ink, radius: 0.03)
        head.position = [0, 1.77, 0]; robot.addChild(head); head.name = "Head"
        box(head, [0.80, 0.68, 0.65], .zero, ivory, radius: 0.24)
        // Build the curvature in full depth, then flatten it. A thin box would
        // clamp its bevel to the depth and leave the screen almost rectangular.
        let visor = box(head, [0.65, 0.47, 0.36], [0, -0.01, 0.30], ink, radius: 0.17)
        visor.scale.z = 0.28
        for side: Float in [-1, 1] {
            ball(head, [0.067, 0.16, 0.14], [side * 0.405, 0, 0], orange)
            arc(head, center: [side * 0.145, -0.015, 0.358], radius: 0.065,
                start: 0.12, end: .pi - 0.12, thickness: 0.017, color: cyan, luminous: true)
        }
        arc(head, center: [0, -0.07, 0.36], radius: 0.07, start: .pi * 1.20, end: .pi * 1.80,
            thickness: 0.009, color: cyan, luminous: true)
        rod(head, from: [0, 0.32, 0], to: [0, 0.48, 0], radius: 0.021, color: ink)
        ball(head, [0.065, 0.065, 0.065], [0, 0.51, 0], orange)
        for (side, arm) in [(-1 as Float, leftArm), (1 as Float, rightArm)] {
            arm.name = side < 0 ? "LeftArm" : "RightArm"
            arm.position = [side * 0.36, 1.29, 0]; robot.addChild(arm)
            ball(arm, [0.10, 0.10, 0.11], .zero, ink)
            box(arm, [0.18, 0.26, 0.21], [0, -0.15, 0], ivory, radius: 0.075)
            ball(arm, [0.082, 0.082, 0.082], [0, -0.31, 0], ink)
            box(arm, [0.17, 0.23, 0.21], [0, -0.44, 0], ivory, radius: 0.065)
            ball(arm, [0.03, 0.06, 0.06], [side * 0.085, -0.43, 0], orange)
            box(arm, [0.15, 0.13, 0.17], [0, -0.60, 0], ink, radius: 0.05)
            for finger in -1...1 {
                box(arm, [0.037, 0.07, 0.08], [Float(finger) * 0.045, -0.67, 0.02], ivory, radius: 0.018)
            }
        }
        head.addChild(beanie); beanie.name = "Beanie"
        ball(beanie, [0.42, 0.24, 0.34], [0, 0.24, 0], teal)
        box(beanie, [0.84, 0.105, 0.67], [0, 0.22, 0], teal, radius: 0.048)
        for x in -7...7 {
            box(beanie, [0.012, 0.075, 0.012], [Float(x) * 0.049, 0.22, 0.335],
                UIColor(red: 0.22, green: 0.52, blue: 0.53, alpha: 1), radius: 0.005)
        }
        robot.addChild(wings); wings.name = "Wings"
        wings.position = [0, 1.10, -0.23]
        for side: Float in [-1, 1] {
            for feather in 0..<4 {
                let featherNode = ball(wings, [0.40 - Float(feather) * 0.035, 0.085, 0.047],
                    [side * (0.45 - Float(feather) * 0.03), 0.12 - Float(feather) * 0.085, 0], ivory)
                featherNode.orientation = simd_quatf(angle: side * (0.43 - Float(feather) * 0.14), axis: [0, 0, 1])
            }
            ball(wings, [0.08, 0.13, 0.07], [side * 0.22, 0, 0.025], orange)
        }
    }

    private func makeRoom() {
        let wood = UIColor(red: 0.56, green: 0.34, blue: 0.18, alpha: 1)
        let honey = UIColor(red: 0.70, green: 0.48, blue: 0.28, alpha: 1)
        box(anchor, [3.8, 0.20, 3.0], [0, -0.12, 0], wood, radius: 0.10)
        for i in 0..<10 {
            let tint = CGFloat(i % 3) * 0.018
            let plank = UIColor(red: 0.67 + tint, green: 0.44 + tint, blue: 0.26 + tint, alpha: 1)
            box(anchor, [3.65, 0.035, 0.282], [0, 0, Float(i) * 0.292 - 1.31], plank, radius: 0.012)
            box(anchor, [3.7, 0.217, 0.11], [0, Float(i) * 0.225 + 0.14, -1.46], plank, radius: 0.012)
            box(anchor, [0.11, 0.217, 2.88], [-1.84, Float(i) * 0.225 + 0.14, 0], plank, radius: 0.012)
        }
        box(anchor, [3.8, 0.12, 0.18], [0, 2.37, -1.46], wood, radius: 0.055)
        box(anchor, [0.18, 0.12, 2.97], [-1.84, 2.37, 0], wood, radius: 0.055)
        box(anchor, [3.63, 0.12, 0.09], [0, 0.13, -1.37], wood)
        // Round scenic window mounted just in front of the back planks.
        let window = ModelEntity(mesh: .generateCylinder(height: 0.06, radius: 0.49),
                                 materials: [UnlitMaterial(color: UIColor(red: 0.51, green: 0.77, blue: 0.81, alpha: 1))])
        window.orientation = simd_quatf(angle: .pi / 2, axis: [1, 0, 0])
        window.position = [0.65, 1.64, -1.36]; anchor.addChild(window)
        arc(anchor, center: [0.65, 1.64, -1.31], radius: 0.51, start: 0, end: .pi * 2,
            thickness: 0.055, color: wood, segments: 40)
        ball(anchor, [0.09, 0.09, 0.015], [0.84, 1.83, -1.31], UIColor(red: 1, green: 0.9, blue: 0.53, alpha: 1), luminous: true)
        box(anchor, [0.045, 0.97, 0.055], [0.65, 1.64, -1.26], honey, radius: 0.012)
        box(anchor, [0.96, 0.045, 0.055], [0.65, 1.64, -1.26], honey, radius: 0.012)
        box(anchor, [1.17, 0.075, 0.23], [0.65, 1.1, -1.26], honey)
        box(anchor, [2.5, 0.025, 1.45], [0.18, 0.027, 0.29], teal, radius: 0.10)
        box(anchor, [2.34, 0.008, 1.29], [0.18, 0.045, 0.29], UIColor(red: 0.49, green: 0.62, blue: 0.57, alpha: 1), radius: 0.09)
        let desk = Entity(); desk.name = "Desk"; desk.position = [-0.96, 0, 0.48]; anchor.addChild(desk)
        box(desk, [1.36, 0.10, 0.76], [0, 0.91, 0], honey, radius: 0.045)
        for x: Float in [-0.57, 0.57] { for z: Float in [-0.25, 0.25] {
            box(desk, [0.09, 0.87, 0.09], [x, 0.46, z], wood)
        } }
        box(desk, [0.50, 0.035, 0.34], [-0.07, 0.982, -0.05], .darkGray, radius: 0.016, metal: true)
        let lid = box(desk, [0.50, 0.34, 0.025], [-0.07, 1.15, 0.08], .darkGray, radius: 0.018, metal: true)
        lid.orientation = simd_quatf(angle: -0.18, axis: [1, 0, 0])
        box(lid, [0.43, 0.27, 0.012], [0, 0, -0.019], ink, radius: 0.012)
        ball(lid, [0.055, 0.055, 0.007], [0, 0, 0.02], teal)
        let cup = ModelEntity(mesh: .generateCylinder(height: 0.16, radius: 0.064), materials: [material(teal)])
        cup.position = [0.39, 1.04, -0.08]; desk.addChild(cup)
        arc(desk, center: [0.465, 1.04, -0.08], radius: 0.044, start: -.pi / 2, end: .pi / 2,
            thickness: 0.013, color: teal)
        rod(desk, from: [-0.52, 0.97, -0.22], to: [-0.52, 1.42, -0.22], radius: 0.018, color: orange)
        ball(desk, [0.12, 0.035, 0.10], [-0.52, 0.98, -0.22], orange)
        ball(desk, [0.13, 0.08, 0.11], [-0.52, 1.43, -0.22], orange)
        // Pot and leaves, each a real mesh with depth.
        let pot = ModelEntity(mesh: .generateCylinder(height: 0.27, radius: 0.18), materials: [material(ivory)])
        pot.position = [1.30, 0.17, -0.86]; anchor.addChild(pot)
        for i in 0..<7 {
            let angle = Float(i) * 2.399
            let end = SIMD3<Float>(1.30 + cos(angle) * 0.22, 0.52 + Float(i % 3) * 0.13, -0.86 + sin(angle) * 0.18)
            rod(anchor, from: [1.30, 0.27, -0.86], to: end, radius: 0.013, color: .brown)
            let leaf = ball(anchor, [0.10, 0.23, 0.035], end, UIColor(red: 0.20, green: 0.39 + CGFloat(i % 3) * 0.05, blue: 0.17, alpha: 1))
            leaf.orientation = simd_quatf(angle: angle, axis: [0, 1, 0]) * simd_quatf(angle: 0.5, axis: [0, 0, 1])
        }
        box(anchor, [0.85, 0.08, 0.24], [-1.01, 1.82, -1.28], honey)
        for i in 0..<4 {
            box(anchor, [0.09, 0.24 + Float(i % 2) * 0.04, 0.14], [-1.22 + Float(i) * 0.12, 1.98, -1.28], i % 2 == 0 ? teal : ivory, radius: 0.007)
        }
    }
}
