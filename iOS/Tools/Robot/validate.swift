import SceneKit

let url = URL(fileURLWithPath: CommandLine.arguments[1])
let scene = try SCNScene(url: url, options: nil)
var animatedBones = 0
var skinnedMeshes = 0
var triangles = 0
scene.rootNode.enumerateChildNodes { node, _ in
    if let player = node.animationPlayer(forKey: "wave") {
        animatedBones += 1
        precondition(player.animation.duration > 4 && player.animation.duration < 4.3)
        let group = CAAnimation(scnAnimation: player.animation) as! CAAnimationGroup
        precondition(group.animations?.count == 2)
        for track in group.animations! {
            let track = track as! CAKeyframeAnimation
            precondition(["position", "orientation"].contains(track.keyPath!))
            precondition(!(track.values ?? []).isEmpty)
        }
    }
    if let skin = node.skinner {
        skinnedMeshes += 1
        precondition(skin.bones.count == 28)
        guard let geometry = node.geometry else { preconditionFailure("Missing geometry") }
        triangles += geometry.elements.reduce(0) { $0 + $1.primitiveCount }
        precondition(geometry.firstMaterial?.diffuse.contents != nil)
        precondition(!geometry.sources(for: .color).isEmpty)
    }
}
precondition(animatedBones == 28 && skinnedMeshes == 1 && triangles == 31_105)
print("PASS: 28 animated bones, 31,105 triangles, vertex tint, material and skinned mesh preserved")
