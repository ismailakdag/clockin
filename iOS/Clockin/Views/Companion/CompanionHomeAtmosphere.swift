import SwiftUI
import UIKit

struct CompanionFurnitureImage: UIViewRepresentable {
    let image: CGImage
    let mirrored: Bool
    let swaying: Bool
    func makeUIView(context: Context) -> FurnitureLayerView { FurnitureLayerView() }
    func updateUIView(_ view: FurnitureLayerView, context: Context) { view.configure(image, mirrored: mirrored, swaying: swaying) }
    static func dismantleUIView(_ view: FurnitureLayerView, coordinator: ()) { view.art.removeAllAnimations() }
}

final class FurnitureLayerView: UIView {
    let art = CALayer()
    override init(frame: CGRect) {
        super.init(frame: frame)
        isUserInteractionEnabled = false
        art.anchorPoint = CGPoint(x: 0.5,y: 1)
        art.magnificationFilter = .nearest; art.minificationFilter = .nearest
        layer.addSublayer(art)
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
    override func layoutSubviews() {
        super.layoutSubviews()
        CATransaction.begin(); CATransaction.setDisableActions(true)
        art.bounds = bounds; art.position = CGPoint(x: bounds.midX,y: bounds.maxY)
        CATransaction.commit()
    }
    func configure(_ image: CGImage, mirrored: Bool, swaying: Bool) {
        CATransaction.begin(); CATransaction.setDisableActions(true)
        art.contents = image; art.transform = CATransform3DMakeScale(mirrored ? -1 : 1,1,1)
        CATransaction.commit()
        if swaying {
            guard art.animation(forKey: "leaves") == nil else { return }
            let sway = CABasicAnimation(keyPath: "transform.rotation.z")
            sway.fromValue = -0.012; sway.toValue = 0.012
            sway.duration = 4; sway.autoreverses = true; sway.repeatCount = .infinity
            sway.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            MascotAnimationRate.sway.apply(to: sway)
            art.add(sway,forKey: "leaves")
        } else { art.removeAllAnimations() }
    }
}

struct CompanionHomeAtmosphere: UIViewRepresentable {
    let state: WardrobeState
    let room: WardrobeRoom
    let light: CompanionHomeLight
    let moving: Bool
    func makeUIView(context: Context) -> HomeAtmosphereLayerView { HomeAtmosphereLayerView() }
    func updateUIView(_ view: HomeAtmosphereLayerView, context: Context) { view.configure(state: state, room: room, light: light, moving: moving) }
    static func dismantleUIView(_ view: HomeAtmosphereLayerView, coordinator: ()) { view.stop() }
}

final class HomeAtmosphereLayerView: UIView {
    private var key = ""
    override init(frame: CGRect) { super.init(frame: frame); isUserInteractionEnabled = false }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
    func stop() { layer.sublayers?.forEach { $0.removeAllAnimations() } }
    func configure(state: WardrobeState, room: WardrobeRoom, light: CompanionHomeLight, moving: Bool) {
        let next = "\(state.room)/\(state.homeLayout)/\(state.homeLampOn)/\(light)/\(moving)/" + state.furniture.values.sorted().joined(separator: "/")
        guard next != key else { return }
        key = next; stop(); layer.sublayers?.forEach { $0.removeFromSuperlayer() }
        func x(_ value: Double) -> Double { state.homeLayout.x(value) }
        func glow(_ px: Double, _ py: Double, radius: Double, strength: Float) {
            let glow = CAGradientLayer()
            glow.type = .radial
            glow.colors = [UIColor(red:1,green:0.78,blue:0.35,alpha:0.32).cgColor,UIColor.clear.cgColor]
            glow.startPoint = CGPoint(x:0.5,y:0.5); glow.endPoint = CGPoint(x:1,y:1)
            glow.frame = CGRect(x:x(px)-radius,y:py-radius,width:radius*2,height:radius*2)
            glow.opacity = strength
            layer.addSublayer(glow)
        }
        if state.homeLampOn {
            glow(176,44,radius:48,strength:light == .day ? 0.45 : 1)
            if state.furniture["floorLeft"] == "floor-lamp", let anchor = room.slots["floorLeft"] {
                glow(anchor.x,anchor.y-84,radius:48,strength:0.8)
            }
            if state.furniture["desk"] == "desk-lamp", let anchor = room.slots["desk"] {
                glow(anchor.x+7,anchor.y-39,radius:40,strength:0.8)
            }
        }
        var sources = [WardrobePoint]()
        if state.furniture["floorLeft"] == "coffee-machine", let anchor = room.slots["floorLeft"] { sources.append(.init(anchor.x,anchor.y-61)) }
        if state.furniture["desk"] == "desk-monitor", let anchor = room.slots["desk"] { sources.append(.init(anchor.x-39,anchor.y-25)) }
        for source in sources {
            for index in 0..<3 {
                let steam = CAShapeLayer()
                let path = UIBezierPath()
                path.move(to: CGPoint(x:0,y:0))
                path.addCurve(to:CGPoint(x:1,y:-11),controlPoint1:CGPoint(x:-5,y:-3),controlPoint2:CGPoint(x:5,y:-7))
                steam.path = path.cgPath; steam.strokeColor = UIColor.white.withAlphaComponent(0.5).cgColor
                steam.fillColor = nil; steam.lineWidth = 1
                steam.position = CGPoint(x:x(source.x + Double(index*4-4)),y:source.y)
                steam.opacity = moving ? 0 : 0.18
                layer.addSublayer(steam)
                if moving {
                    let rise = CABasicAnimation(keyPath:"transform.translation.y"); rise.fromValue = 3; rise.toValue = -10
                    let fade = CAKeyframeAnimation(keyPath:"opacity"); fade.values = [0,0.45,0]; fade.keyTimes = [0,0.3,1]
                    let group = CAAnimationGroup(); group.animations = [rise,fade]; group.duration = 3.6
                    group.beginTime = CACurrentMediaTime()+Double(index)*0.85; group.repeatCount = .infinity
                    MascotAnimationRate.sway.apply(to:group); steam.add(group,forKey:"steam")
                }
            }
        }
    }
}
