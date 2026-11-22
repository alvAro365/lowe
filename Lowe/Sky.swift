import RealityKit
import UIKit

/// Dag og natt. Dagen varer i noen minutter, så kommer skumringen, og natta er blå og stille
/// med stjerner, måne og nordlys. Ingenting skummelt. Ved bålplassen kan Lowe tenne bål.
@MainActor
final class Sky {
    /// Hvor lang en hel dag og natt er, i sekunder.
    let cycleLength: Float = 360
    /// Bålplassen i lysningen.
    let firePosition = SIMD3<Float>(-2.6, 0, -2.0)
    private(set) var fireLit = false
    /// 1 er full dag, 0 er natt.
    private(set) var daylight: Float = 1

    private weak var view: ARView?
    private let sun: DirectionalLight
    private let dome = Entity()
    private var stars: [ModelEntity] = []
    private let moon: ModelEntity
    private var aurora: [ModelEntity] = []
    private let flames = Entity()
    private let fireLight = PointLight()
    private var phase: Float = 0.04
    private var time: Float = 0
    private var lastBackground: Float = -1

    private let daySky = Colors.sky
    private let duskSky = UIColor(hex: 0xF2B38A)
    private let nightSky = Colors.night

    init(world: Entity, view: ARView, sun: DirectionalLight) {
        self.view = view
        self.sun = sun
        world.addChild(dome)

        var random = SeededRandom(seed: 3)
        for _ in 0..<160 {
            let star = ModelEntity(mesh: Make.sphere(0.22), materials: [UnlitMaterial(color: .white)])
            let a = random.next(0, 2 * .pi)
            let up = random.next(0.25, 1.45)
            star.position = SIMD3(cos(a) * cos(up), sin(up), sin(a) * cos(up)) * 70
            let s = random.next(0.6, 1.4)
            star.scale = [s, s, s]
            dome.addChild(star)
            stars.append(star)
        }
        moon = ModelEntity(mesh: Make.sphere(3), materials: [UnlitMaterial(color: Colors.moon)])
        moon.position = [28, 38, -48]
        dome.addChild(moon)

        // Nordlyset: lange, tynne bånd i en bue over skogen mot nord.
        for i in 0..<30 {
            let a = -1.0 + Float(i) / 29 * 2.0
            let color = i % 3 == 0 ? Colors.turquoise : Colors.aurora
            let band = ModelEntity(mesh: Make.box(4.4, 11, 0.2), materials: [UnlitMaterial(color: color)])
            band.position = [sin(a) * 52, 26 + sin(Float(i) * 0.55) * 3.5, -cos(a) * 52]
            band.orientation = rotY(-a)
            dome.addChild(band)
            aurora.append(band)
        }
        buildFirePit(in: world)
        apply()
    }

    private func buildFirePit(in world: Entity) {
        let pit = Entity()
        pit.position = firePosition
        world.addChild(pit)
        for i in 0..<9 {
            let a = Float(i) / 9 * 2 * .pi
            let stone = Make.part(Make.sphere(0.12), Colors.stone, at: [cos(a) * 0.42, 0.05, sin(a) * 0.42], in: pit)
            stone.scale = [1.2, 0.7, 1]
        }
        for a in [Float(0.4), -0.5, 1.6] {
            let log = Make.part(Make.cylinder(0.6, 0.06), Colors.bark, at: [0, 0.08, 0], in: pit)
            log.orientation = rotY(a) * rotZ(.pi / 2 - 0.25)
        }
        pit.addChild(flames)
        flames.position = [0, 0.1, 0]
        Make.part(Make.cone(0.6, 0.22), Colors.flame, at: [0, 0.3, 0], in: flames)
        Make.part(Make.cone(0.42, 0.14), Colors.sun, at: [0.03, 0.24, 0.02], in: flames)
        Make.part(Make.cone(0.3, 0.09), Colors.flame, at: [-0.12, 0.17, 0.06], in: flames)
        flames.isEnabled = false

        fireLight.light.color = UIColor(hex: 0xFFB547)
        fireLight.light.intensity = 0
        fireLight.light.attenuationRadius = 8
        fireLight.position = [0, 0.9, 0]
        pit.addChild(fireLight)
    }

    /// Tenner bålet. Det brenner natta gjennom og slukner når det blir lyst.
    func lightFire() {
        guard !fireLit else { return }
        fireLit = true
        flames.isEnabled = true
        flames.scale = [0.2, 0.2, 0.2]
    }

    func update(_ dt: Float, around center: SIMD3<Float>) {
        time += dt
        phase = (phase + dt / cycleLength).truncatingRemainder(dividingBy: 1)
        let before = daylight
        daylight = Sky.daylight(at: phase)
        // Bålet slukner når morgenen er helt kommet.
        if fireLit && before < 1 && daylight >= 1 {
            fireLit = false
            flames.isEnabled = false
        }
        dome.position = [center.x, 0, center.z]
        apply()

        if fireLit {
            let grow = min(1, flames.scale.x + dt * 2)
            let flicker = 1 + 0.12 * sin(time * 17) + 0.06 * sin(time * 29)
            flames.scale = [grow, grow * flicker, grow]
            fireLight.light.intensity = 9000 * grow * (0.9 + 0.1 * flicker)
        } else {
            fireLight.light.intensity = 0
        }
    }

    /// 0 til 0,58 er dag, så skumring, natt fra 0,66 til 0,92, og så morgen.
    private static func daylight(at phase: Float) -> Float {
        func smooth(_ x: Float) -> Float { x * x * (3 - 2 * x) }
        switch phase {
        case ..<0.58: return 1
        case ..<0.66: return 1 - smooth((phase - 0.58) / 0.08)
        case ..<0.92: return 0
        default: return smooth((phase - 0.92) / 0.08)
        }
    }

    private func apply() {
        let d = daylight
        let dark = 1 - d
        sun.light.intensity = 600 + 2000 * d
        sun.light.color = mix(UIColor(hex: 0x9FB4FF), UIColor(hex: 0xFFF6E8), d)
        view?.environment.lighting.intensityExponent = -1.3 * dark

        if abs(d - lastBackground) > 0.01 {
            lastBackground = d
            let sky = d > 0.5 ? mix(duskSky, daySky, (d - 0.5) * 2) : mix(nightSky, duskSky, d * 2)
            view?.environment.background = .color(sky)
        }

        let showNight = dark > 0.02
        dome.isEnabled = showNight
        guard showNight else { return }
        for (i, star) in stars.enumerated() {
            let twinkle = 0.75 + 0.25 * sin(time * 2 + Float(i))
            star.components.set(OpacityComponent(opacity: dark * twinkle))
        }
        moon.components.set(OpacityComponent(opacity: dark))
        for (i, band) in aurora.enumerated() {
            let wave = 0.3 + 0.2 * sin(time * 0.7 + Float(i) * 0.35)
            band.components.set(OpacityComponent(opacity: dark * wave))
            band.position.y = 26 + sin(Float(i) * 0.55 + time * 0.3) * 3.5
        }
    }

    private func mix(_ a: UIColor, _ b: UIColor, _ t: Float) -> UIColor {
        var ar: CGFloat = 0, ag: CGFloat = 0, ab: CGFloat = 0, aa: CGFloat = 0
        var br: CGFloat = 0, bg: CGFloat = 0, bb: CGFloat = 0, ba: CGFloat = 0
        a.getRed(&ar, green: &ag, blue: &ab, alpha: &aa)
        b.getRed(&br, green: &bg, blue: &bb, alpha: &ba)
        let k = CGFloat(max(0, min(1, t)))
        return UIColor(red: ar + (br - ar) * k, green: ag + (bg - ag) * k, blue: ab + (bb - ab) * k, alpha: 1)
    }
}
