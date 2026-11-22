import RealityKit
import UIKit

/// Skogsvennene som kommer og henter ved, i rekkefølgen de kommer.
/// Hvert dyr står med føttene i (0, 0, 0) og ser langs +z.
enum Animal: Int, CaseIterable {
    case hedgehog, fox, moose, bear, owl

    /// Omtrent hvor høyt dyret er, så veden kan fly til midt på det.
    var height: Float {
        switch self {
        case .hedgehog: return 0.45
        case .fox: return 0.75
        case .moose: return 1.9
        case .bear: return 1.25
        case .owl: return 0.7
        }
    }

    /// Hvor langt unna vedstabelen dyret står og venter.
    var size: Float {
        switch self {
        case .hedgehog: return 0.35
        case .fox: return 0.45
        case .moose: return 0.8
        case .bear: return 0.65
        case .owl: return 0.3
        }
    }

    /// Ugla og pinnsvinet hopper mer når de går.
    var bounce: Float {
        switch self {
        case .owl: return 0.16
        case .hedgehog: return 0.06
        default: return 0.04
        }
    }

    @MainActor
    func build() -> Entity {
        let root = Entity()
        let body = Entity()
        body.name = "body"
        root.addChild(body)
        switch self {
        case .hedgehog: AnimalModels.hedgehog(body)
        case .fox: AnimalModels.fox(body)
        case .moose: AnimalModels.moose(body)
        case .bear: AnimalModels.bear(body)
        case .owl: AnimalModels.owl(body)
        }
        return root
    }
}

/// Dyrene bygd av enkle former, i fargene fra 2D-designet.
@MainActor
enum AnimalModels {
    private static func part(_ mesh: MeshResource, _ color: UIColor, _ p: SIMD3<Float>, in parent: Entity,
                             scale: SIMD3<Float> = [1, 1, 1]) -> ModelEntity {
        let e = Make.part(mesh, color, at: p, in: parent)
        e.scale = scale
        return e
    }

    /// En kjegle som peker i retningen `dir` (kjegler peker opp langs +y fra start).
    private static func cone(_ h: Float, _ r: Float, _ color: UIColor, at p: SIMD3<Float>, pointing dir: SIMD3<Float>,
                             in parent: Entity) {
        let e = Make.part(Make.cone(h, r), color, at: p, in: parent)
        e.orientation = simd_quatf(from: [0, 1, 0], to: simd_normalize(dir))
    }

    private static func eyes(_ parent: Entity, y: Float, z: Float, spread: Float, r: Float = 0.03) {
        for x in [spread, -spread] {
            _ = part(Make.sphere(r), Colors.ink, [x, y, z], in: parent)
            _ = part(Make.sphere(r * 0.38), Colors.white, [x + r * 0.3, y + r * 0.35, z + r * 0.75], in: parent)
        }
    }

    static func hedgehog(_ b: Entity) {
        let spikes = UIColor(hex: 0x6B4A33)
        let face = UIColor(hex: 0xF0D5B0)
        let feet = UIColor(hex: 0x4A3324)
        _ = part(Make.sphere(0.24), spikes, [0, 0.22, -0.03], in: b, scale: [1, 0.8, 1.15])
        // Piggene stikker ut over ryggen.
        for i in 0..<14 {
            let a = Float(i) / 14 * 2 * .pi
            let ring = Float(i % 2 == 0 ? 0.5 : 0.85)
            let dir = SIMD3<Float>(cos(a) * ring, 0.75, sin(a) * ring - 0.25)
            let base = SIMD3<Float>(0, 0.24, -0.04) + simd_normalize(dir) * 0.18
            cone(0.14, 0.045, spikes, at: base, pointing: dir, in: b)
        }
        _ = part(Make.sphere(0.13), face, [0, 0.17, 0.2], in: b, scale: [1, 0.9, 1.1])
        cone(0.12, 0.07, face, at: [0, 0.15, 0.32], pointing: [0, -0.15, 1], in: b)
        _ = part(Make.sphere(0.03), Colors.ink, [0, 0.14, 0.39], in: b)
        eyes(b, y: 0.22, z: 0.29, spread: 0.06, r: 0.022)
        for (x, z) in [(Float(0.1), Float(0.12)), (-0.1, 0.12), (0.1, -0.15), (-0.1, -0.15)] {
            _ = part(Make.sphere(0.045), feet, [x, 0.03, z], in: b, scale: [1, 0.6, 1.3])
        }
    }

    static func fox(_ b: Entity) {
        let orange = UIColor(hex: 0xE8803A)
        let cream = UIColor(hex: 0xFFF7EE)
        for (x, z) in [(Float(0.09), Float(0.16)), (-0.09, 0.16), (0.09, -0.16), (-0.09, -0.16)] {
            _ = part(Make.box(0.07, 0.24, 0.07, r: 0.02), Colors.ink, [x, 0.12, z], in: b)
        }
        _ = part(Make.box(0.26, 0.24, 0.52, r: 0.1), orange, [0, 0.34, 0], in: b)
        _ = part(Make.box(0.16, 0.14, 0.3, r: 0.06), cream, [0, 0.28, 0.08], in: b)
        _ = part(Make.sphere(0.15), orange, [0, 0.54, 0.3], in: b)
        cone(0.16, 0.08, cream, at: [0, 0.5, 0.45], pointing: [0, -0.1, 1], in: b)
        _ = part(Make.sphere(0.028), Colors.ink, [0, 0.49, 0.53], in: b)
        for x in [Float(0.08), -0.08] {
            cone(0.13, 0.055, orange, at: [x, 0.69, 0.27], pointing: [x * 2, 1, 0], in: b)
        }
        eyes(b, y: 0.58, z: 0.43, spread: 0.06, r: 0.024)
        cone(0.4, 0.1, orange, at: [0, 0.4, -0.42], pointing: [0, 0.35, -1], in: b)
        _ = part(Make.sphere(0.06), cream, [0, 0.47, -0.6], in: b)
    }

    static func moose(_ b: Entity) {
        let fur = UIColor(hex: 0x7A5236)
        let leg = UIColor(hex: 0x6A452C)
        let snout = UIColor(hex: 0x9C6E4C)
        let antler = UIColor(hex: 0xE9D3A8)
        for (x, z) in [(Float(0.17), Float(0.32)), (-0.17, 0.32), (0.17, -0.32), (-0.17, -0.32)] {
            _ = part(Make.box(0.12, 0.85, 0.12, r: 0.04), leg, [x, 0.42, z], in: b)
        }
        _ = part(Make.box(0.5, 0.5, 1.0, r: 0.18), fur, [0, 1.08, 0], in: b)
        let neck = part(Make.box(0.22, 0.45, 0.24, r: 0.08), fur, [0, 1.36, 0.42], in: b)
        neck.orientation = rotX(0.5)
        _ = part(Make.box(0.26, 0.28, 0.5, r: 0.1), fur, [0, 1.55, 0.62], in: b)
        _ = part(Make.box(0.24, 0.2, 0.2, r: 0.08), snout, [0, 1.5, 0.86], in: b)
        for x in [Float(0.05), -0.05] {
            _ = part(Make.sphere(0.022), Colors.ink, [x, 1.53, 0.96], in: b)
        }
        eyes(b, y: 1.62, z: 0.78, spread: 0.11, r: 0.03)
        for side in [Float(1), -1] {
            _ = part(Make.box(0.1, 0.08, 0.06, r: 0.03), fur, [side * 0.17, 1.7, 0.56], in: b)
            let palm = part(Make.box(0.38, 0.05, 0.24, r: 0.02), antler, [side * 0.3, 1.82, 0.5], in: b)
            palm.orientation = rotZ(side * 0.35)
            for k in 0..<3 {
                let tine = Make.part(Make.cone(0.14, 0.03), antler, at: [side * (0.22 + Float(k) * 0.1), 1.92 + Float(k) * 0.035, 0.42 + Float(k) * 0.05], in: b)
                tine.orientation = rotZ(-side * 0.2)
            }
        }
    }

    static func bear(_ b: Entity) {
        let fur = UIColor(hex: 0x6E4B33)
        let belly = UIColor(hex: 0xA07A56)
        let muzzle = UIColor(hex: 0xC9A27A)
        for (x, z) in [(Float(0.2), Float(0.2)), (-0.2, 0.2), (0.2, -0.22), (-0.2, -0.22)] {
            _ = part(Make.cylinder(0.32, 0.1), fur, [x, 0.16, z], in: b)
        }
        _ = part(Make.sphere(0.38), fur, [0, 0.55, 0], in: b, scale: [1, 0.9, 1.25])
        _ = part(Make.sphere(0.25), belly, [0, 0.5, 0.2], in: b, scale: [1, 0.9, 1])
        _ = part(Make.sphere(0.25), fur, [0, 0.95, 0.38], in: b)
        for x in [Float(0.17), -0.17] {
            _ = part(Make.sphere(0.08), fur, [x, 1.15, 0.32], in: b)
            _ = part(Make.sphere(0.045), muzzle, [x, 1.15, 0.37], in: b)
        }
        _ = part(Make.sphere(0.12), muzzle, [0, 0.9, 0.6], in: b, scale: [1, 0.8, 1])
        _ = part(Make.sphere(0.045), Colors.ink, [0, 0.93, 0.71], in: b, scale: [1.3, 0.9, 1])
        eyes(b, y: 1.01, z: 0.59, spread: 0.09, r: 0.03)
    }

    static func owl(_ b: Entity) {
        let feather = UIColor(hex: 0x8C7A6B)
        let wing = UIColor(hex: 0x6F5F52)
        let chest = UIColor(hex: 0xD9C7AE)
        let face = UIColor(hex: 0xF3E7D3)
        let beak = UIColor(hex: 0xF2A23A)
        for x in [Float(0.07), -0.07] {
            _ = part(Make.box(0.06, 0.04, 0.09, r: 0.015), beak, [x, 0.02, 0.06], in: b)
        }
        _ = part(Make.sphere(0.24), feather, [0, 0.34, 0], in: b, scale: [1, 1.25, 0.95])
        _ = part(Make.sphere(0.16), chest, [0, 0.27, 0.11], in: b, scale: [1, 1.1, 0.8])
        for side in [Float(1), -1] {
            _ = part(Make.sphere(0.12), wing, [side * 0.21, 0.3, -0.02], in: b, scale: [0.5, 1.3, 1])
            cone(0.12, 0.05, feather, at: [side * 0.12, 0.66, 0], pointing: [side * 0.4, 1, 0], in: b)
            let disc = part(Make.cylinder(0.02, 0.085), face, [side * 0.09, 0.47, 0.19], in: b)
            disc.orientation = rotX(.pi / 2)
            _ = part(Make.sphere(0.045), Colors.ink, [side * 0.09, 0.47, 0.205], in: b)
            _ = part(Make.sphere(0.015), Colors.white, [side * 0.09 + 0.015, 0.485, 0.245], in: b)
        }
        cone(0.08, 0.035, beak, at: [0, 0.4, 0.22], pointing: [0, -0.6, 1], in: b)
    }
}
