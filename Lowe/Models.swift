import RealityKit
import UIKit

/// Samme farger som i 2D-spillet.
enum Colors {
    static let ink = UIColor(hex: 0x1D1F24)
    static let turquoise = UIColor(hex: 0x1FC2C2)
    static let sky = UIColor(hex: 0xCDEBEF)
    static let snow = UIColor(hex: 0xF4F7F8)
    static let snowShade = UIColor(hex: 0xDCE7EC)
    static let spruce = UIColor(hex: 0x2E5E55)
    static let spruceMid = UIColor(hex: 0x3F7A6E)
    static let trunk = UIColor(hex: 0x5A3A24)
    static let bark = UIColor(hex: 0x7A4A2B)
    static let wood = UIColor(hex: 0xF0CE94)
    static let skin = UIColor(hex: 0xF4CBA6)
    static let cheek = UIColor(hex: 0xF2A08F)
    static let steel = UIColor(hex: 0xBFC8CF)
    static let sun = UIColor(hex: 0xFFD66B)
    static let white = UIColor.white
}

extension UIColor {
    convenience init(hex: UInt32) {
        self.init(red: CGFloat((hex >> 16) & 0xFF) / 255,
                  green: CGFloat((hex >> 8) & 0xFF) / 255,
                  blue: CGFloat(hex & 0xFF) / 255,
                  alpha: 1)
    }
}

func rotX(_ a: Float) -> simd_quatf { simd_quatf(angle: a, axis: [1, 0, 0]) }
func rotY(_ a: Float) -> simd_quatf { simd_quatf(angle: a, axis: [0, 1, 0]) }
func rotZ(_ a: Float) -> simd_quatf { simd_quatf(angle: a, axis: [0, 0, 1]) }

/// Enkle byggeklosser: alt i 3D-forsøket er laget av bokser, kuler, sylindre og kjegler.
@MainActor
enum Make {
    static func material(_ color: UIColor) -> SimpleMaterial {
        SimpleMaterial(color: color, roughness: 0.85, isMetallic: false)
    }

    @discardableResult
    static func part(_ mesh: MeshResource, _ color: UIColor, at p: SIMD3<Float> = .zero, in parent: Entity? = nil) -> ModelEntity {
        let e = ModelEntity(mesh: mesh, materials: [material(color)])
        e.position = p
        parent?.addChild(e)
        return e
    }

    static func box(_ w: Float, _ h: Float, _ d: Float, r: Float = 0) -> MeshResource {
        .generateBox(size: [w, h, d], cornerRadius: r)
    }

    static func sphere(_ r: Float) -> MeshResource { .generateSphere(radius: r) }
    static func cylinder(_ h: Float, _ r: Float) -> MeshResource { safe { .generateCylinder(height: h, radius: r) } }
    static func cone(_ h: Float, _ r: Float) -> MeshResource { safe { .generateCone(height: h, radius: r) } }

    private static func safe(_ make: () throws -> MeshResource) -> MeshResource {
        (try? make()) ?? .generateBox(size: 0.01)
    }

    // MARK: Skogen

    static func spruce(scale s: Float) -> Entity {
        let tree = Entity()
        part(cylinder(0.5, 0.12), Colors.trunk, at: [0, 0.25, 0], in: tree)
        let layers: [(base: Float, height: Float, radius: Float)] = [(0.4, 1.2, 0.95), (1.0, 1.0, 0.75), (1.55, 0.85, 0.52)]
        for (i, layer) in layers.enumerated() {
            part(cone(layer.height, layer.radius), i == 1 ? Colors.spruceMid : Colors.spruce,
                 at: [0, layer.base + layer.height / 2, 0], in: tree)
        }
        let top = layers[2].base + layers[2].height
        part(cone(0.34, 0.22), Colors.white, at: [0, top - 0.17, 0], in: tree)
        tree.scale = [s, s, s]
        return tree
    }

    static func snowMound(radius r: Float) -> Entity {
        let m = part(sphere(r), Colors.snowShade)
        m.scale = [1, 0.32, 1]
        return m
    }

    static func choppingBlock() -> Entity {
        let block = Entity()
        part(cylinder(0.4, 0.32), Colors.bark, at: [0, 0.2, 0], in: block)
        part(cylinder(0.02, 0.29), Colors.wood, at: [0, 0.405, 0], in: block)
        return block
    }

    /// Kubben som står på stabben. (0, 0, 0) er midten.
    static func log() -> Entity {
        let log = Entity()
        part(cylinder(0.32, 0.18), Colors.bark, in: log)
        part(cylinder(0.012, 0.16), Colors.wood, at: [0, 0.162, 0], in: log)
        return log
    }

    /// Et vedstykke som ligger langs z, med lyse endeflater mot kameraet.
    static func piece() -> Entity {
        let piece = Entity()
        let wood = part(cylinder(0.46, 0.1), Colors.bark, in: piece)
        wood.orientation = rotX(.pi / 2)
        for z in [Float(0.231), -0.231] {
            let end = part(cylinder(0.006, 0.088), Colors.wood, at: [0, 0, z], in: piece)
            end.orientation = rotX(.pi / 2)
        }
        return piece
    }
}

/// Fast tilfeldighet, så skogen ser lik ut hver gang.
struct SeededRandom {
    private var state: UInt64

    init(seed: UInt64) { state = seed }

    mutating func next(_ low: Float, _ high: Float) -> Float {
        state = state &* 6364136223846793005 &+ 1442695040888963407
        let unit = Float(state >> 40) / Float(1 << 24)
        return low + (high - low) * unit
    }
}
