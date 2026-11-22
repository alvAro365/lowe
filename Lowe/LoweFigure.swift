import RealityKit
import UIKit

/// Lowe i 3D, bygd av enkle former: svart lue med turkis bånd, turkis jakke og svarte bukser.
/// Han ser langs +z. Høyre side er -x.
@MainActor
final class LoweFigure {
    let root = Entity()
    private let body = Entity()
    private let leftLeg = Entity()
    private let rightLeg = Entity()
    private let leftArm = Entity()
    private let rightArm = Entity()
    private let axe = Entity()
    private var eyes: [Entity] = []

    private let carryTilt: Float = -2.4

    init() {
        root.addChild(body)

        for (leg, x) in [(leftLeg, Float(0.1)), (rightLeg, -0.1)] {
            leg.position = [x, 0.45, 0]
            body.addChild(leg)
            Make.part(Make.box(0.15, 0.42, 0.17, r: 0.04), Colors.ink, at: [0, -0.21, 0], in: leg)
            Make.part(Make.box(0.17, 0.08, 0.24, r: 0.035), Colors.ink, at: [0, -0.41, 0.03], in: leg)
        }

        Make.part(Make.box(0.44, 0.44, 0.3, r: 0.08), Colors.turquoise, at: [0, 0.66, 0], in: body)
        Make.part(Make.box(0.46, 0.06, 0.32, r: 0.02), Colors.ink, at: [0, 0.47, 0], in: body)

        Make.part(Make.sphere(0.21), Colors.skin, at: [0, 1.06, 0], in: body)
        for x in [Float(0.075), -0.075] {
            let eye = Make.part(Make.sphere(0.026), Colors.ink, at: [x, 1.08, 0.19], in: body)
            eyes.append(eye)
            Make.part(Make.sphere(0.032), Colors.cheek, at: [x * 1.65, 1.0, 0.165], in: body)
        }
        Make.part(Make.box(0.07, 0.015, 0.02, r: 0.007), Colors.ink, at: [0, 0.98, 0.205], in: body)

        let hat = Make.part(Make.sphere(0.225), Colors.ink, at: [0, 1.13, -0.01], in: body)
        hat.scale = [1, 0.78, 1]
        Make.part(Make.cylinder(0.055, 0.228), Colors.turquoise, at: [0, 1.12, -0.01], in: body)
        Make.part(Make.sphere(0.065), Colors.turquoise, at: [0, 1.33, -0.01], in: body)

        for (arm, x) in [(leftArm, Float(0.28)), (rightArm, -0.28)] {
            arm.position = [x, 0.83, 0]
            body.addChild(arm)
            Make.part(Make.box(0.12, 0.38, 0.13, r: 0.05), Colors.turquoise, at: [0, -0.19, 0], in: arm)
            Make.part(Make.sphere(0.068), Colors.ink, at: [0, -0.4, 0], in: arm)
        }

        // Øksa sitter i høyre hånd. Bladet peker mot -z i øksas egen retning.
        axe.position = [0, -0.4, 0]
        rightArm.addChild(axe)
        Make.part(Make.cylinder(0.56, 0.026), Colors.turquoise, at: [0, -0.24, 0], in: axe)
        Make.part(Make.box(0.05, 0.14, 0.12, r: 0.01), Colors.ink, at: [0, -0.47, 0.02], in: axe)
        Make.part(Make.box(0.035, 0.15, 0.1, r: 0.005), Colors.steel, at: [0, -0.47, -0.08], in: axe)
    }

    /// `chop` og `cheer` går fra 0 til 1 mens de pågår.
    func pose(walkPhase: Float, walk: Float, chop: Float?, cheer: Float?, carrying: Bool = false, time: Float) {
        let swing = sin(walkPhase) * 0.6 * walk
        leftLeg.orientation = rotX(swing)
        rightLeg.orientation = rotX(-swing)

        var lift = abs(sin(walkPhase)) * 0.05 * walk + sin(time * 2.2) * 0.008
        var raise: Float = 0
        var roll: Float = 0
        var tilt = carryTilt
        if let c = chop {
            (raise, roll, tilt) = chopPose(c)
        }
        var leftRaise = raise + swing * 0.8
        var rightRaise = raise - swing * 0.8
        var leftRoll = -roll
        var rightRoll = roll
        if let c = cheer {
            let up = sin(Float.pi * min(1, max(0, c)))
            lift += up * 0.35
            leftRaise = max(leftRaise, up * 2.7)
            rightRaise = max(rightRaise, up * 2.7)
            leftRoll -= up * 0.3
            rightRoll += up * 0.3
        }
        if carrying { leftRaise = 2.75; rightRaise = 2.75; leftRoll = 0.3; rightRoll = -0.3 }
        axe.isEnabled = !carrying
        body.position.y = lift
        leftArm.orientation = rotX(-leftRaise) * rotZ(leftRoll)
        rightArm.orientation = rotX(-rightRaise) * rotZ(rightRoll)
        // Øksa holdes rett i hogget selv om armen er vridd innover.
        axe.orientation = rotZ(-rightRoll) * rotX(tilt)

        let blink: Float = fmod(time, 3.7) < 0.12 ? 0.15 : 1
        for eye in eyes { eye.scale = [1, blink, 1] }
    }

    /// Løfter øksa høyt, hogger ned i kubben (ved 0.6) og går tilbake til å bære den.
    private func chopPose(_ c: Float) -> (raise: Float, roll: Float, tilt: Float) {
        func smooth(_ x: Float) -> Float {
            let t = max(0, min(1, x))
            return t * t * (3 - 2 * t)
        }
        let high: Float = 2.9
        let hit: Float = 1.35
        let inward: Float = 0.5
        if c < 0.45 {
            let t = smooth(c / 0.45)
            return (high * t, inward * t, carryTilt * (1 - smooth(c / 0.3)))
        }
        if c < 0.6 {
            let t = (c - 0.45) / 0.15
            return (high + (hit - high) * t * t, inward, 0)
        }
        if c < 0.72 {
            return (hit, inward, 0)
        }
        let t = smooth((c - 0.72) / 0.28)
        return (hit * (1 - t), inward * (1 - t), carryTilt * t)
    }
}
