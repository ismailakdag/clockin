#if DEBUG
import RealityKit
import Foundation

@available(iOS 18.0, *)
@MainActor
extension Companion3DScene {
    /// Opt-in simulator smoke test, run by --3d-checks. Uses no user data.
    func runSmokeChecks() {
        var checks = 0
        func check(_ value: Bool, _ name: String) {
            precondition(value, name)
            checks += 1
        }
        func count(_ entity: Entity) -> Int { 1 + entity.children.reduce(0) { $0 + count($1) } }
        let initialCount = count(anchor)
        check(beanie.parent === head, "Hat follows the head")
        check(wings.parent === robot, "Wings follow the body")
        check(leftArm.parent === robot && rightArm.parent === robot, "Both arms have body pivots")
        for _ in 0..<3 {
            for look in Outfit.allCases {
                setOutfit(look)
                check(beanie.isEnabled == (look == .beanie), "Beanie visibility")
                check(wings.isEnabled == (look == .wings), "Wing visibility")
                for mood in Pose.allCases {
                    setPose(mood, animated: false)
                    check(pose == mood, "Pose state")
                    check(robot.position.x == (mood == .focus ? -0.93 : 0.55), "Desk pose placement")
                    check(count(anchor) == initialCount, "Switching does not accumulate models")
                    let bounds = robot.visualBounds(relativeTo: anchor)
                    check(bounds.min.x.isFinite && bounds.max.y.isFinite && bounds.max.z.isFinite, "Finite robot bounds")
                    check(bounds.min.y > -0.05 && bounds.max.y < 2.7, "Robot remains above the floor and below the room top")
                }
            }
        }
        orbit(by: 1000); check(yaw == 0.85, "Right orbit is bounded")
        orbit(by: -1000); check(yaw == -0.35, "Left orbit is bounded")
        resetCamera(); check(yaw == 0.38, "Camera reset")
        lamp.isEnabled = false; check(!lamp.isEnabled, "Lamp off")
        lamp.isEnabled = true; check(lamp.isEnabled, "Lamp on")
        setOutfit(.classic); setPose(.hello, animated: false)
        let report = "\(checks) 3D scene checks passed; \(initialCount) entities. No user data read or written.\n"
        let documents = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        try? report.write(to: documents.appendingPathComponent("companion-3d-checks.txt"), atomically: true, encoding: .utf8)
        print(report)
    }
}
#endif
