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
    static let barkLight = UIColor(hex: 0x8A5A36)
    static let barkLine = UIColor(hex: 0x6B4227)
    static let stone = UIColor(hex: 0x9AA5AD)
    static let flame = UIColor(hex: 0xF2823A)
    static let night = UIColor(hex: 0x1B2A3A)
    static let aurora = UIColor(hex: 0x6FF0D8)
    static let moon = UIColor(hex: 0xF3EFD8)
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

    /// Like former deles, så skogen med mange trær ikke lager hundrevis av like modeller.
    private static var meshes: [String: MeshResource] = [:]

    private static func cached(_ key: String, _ make: () -> MeshResource) -> MeshResource {
        if let mesh = meshes[key] { return mesh }
        let mesh = make()
        meshes[key] = mesh
        return mesh
    }

    static func box(_ w: Float, _ h: Float, _ d: Float, r: Float = 0) -> MeshResource {
        cached("box \(w) \(h) \(d) \(r)") { .generateBox(size: [w, h, d], cornerRadius: r) }
    }

    static func sphere(_ r: Float) -> MeshResource {
        cached("sphere \(r)") { .generateSphere(radius: r) }
    }

    static func cylinder(_ h: Float, _ r: Float) -> MeshResource {
        cached("cylinder \(h) \(r)") { safe { .generateCylinder(height: h, radius: r) } }
    }

    static func cone(_ h: Float, _ r: Float) -> MeshResource {
        cached("cone \(h) \(r)") { safe { .generateCone(height: h, radius: r) } }
    }

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

@MainActor
extension Make {
    /// Stubben som blir igjen når et tre er felt.
    static func stump(scale s: Float) -> Entity {
        let stump = Entity()
        part(cylinder(0.22, 0.13), Colors.trunk, at: [0, 0.11, 0], in: stump)
        part(cylinder(0.012, 0.115), Colors.wood, at: [0, 0.222, 0], in: stump)
        part(cylinder(0.02, 0.1), Colors.white, at: [0, 0.235, 0], in: stump)
        stump.scale = [s, s, s]
        return stump
    }

    /// En stokk som ligger og kan trille. Den ligger langs x.
    static func lyingLog() -> Entity {
        let log = Entity()
        let wood = part(cylinder(0.7, 0.17), Colors.bark, in: log)
        wood.orientation = rotZ(.pi / 2)
        for x in [Float(0.351), -0.351] {
            let end = part(cylinder(0.006, 0.15), Colors.wood, at: [x, 0, 0], in: log)
            end.orientation = rotZ(.pi / 2)
        }
        return log
    }

    static func pinecone() -> Entity {
        let cone = Entity()
        let body = part(sphere(0.08), Colors.bark, at: [0, 0.12, 0], in: cone)
        body.scale = [1, 1.45, 1]
        let scaleColor = UIColor(hex: 0x5E3820)
        for i in 0..<8 {
            let a = Float(i) / 8 * 2 * .pi
            let y: Float = i % 2 == 0 ? 0.09 : 0.15
            let bit = part(Make.cone(0.05, 0.03), scaleColor, at: [cos(a) * 0.065, y, sin(a) * 0.065], in: cone)
            bit.orientation = simd_quatf(from: [0, 1, 0], to: simd_normalize(SIMD3<Float>(cos(a), -0.8, sin(a))))
        }
        part(cylinder(0.04, 0.012), Colors.trunk, at: [0, 0.25, 0], in: cone)
        return cone
    }

    /// Et ekorn med føttene i (0, 0, 0), som ser langs +z. Halen heter "tail".
    static func squirrel() -> Entity {
        let squirrel = Entity()
        let fur = UIColor(hex: 0xC2602E)
        let belly = UIColor(hex: 0xF6E2C8)
        let body = part(sphere(0.11), fur, at: [0, 0.14, 0], in: squirrel)
        body.scale = [0.9, 1.15, 1]
        let chest = part(sphere(0.07), belly, at: [0, 0.13, 0.06], in: squirrel)
        chest.scale = [0.9, 1.2, 0.7]
        part(sphere(0.085), fur, at: [0, 0.3, 0.05], in: squirrel)
        for x in [Float(0.045), -0.045] {
            let ear = part(cone(0.06, 0.022), fur, at: [x, 0.39, 0.03], in: squirrel)
            ear.orientation = rotZ(-x * 4)
            part(sphere(0.016), Colors.ink, at: [x, 0.32, 0.12], in: squirrel)
        }
        part(sphere(0.014), Colors.ink, at: [0, 0.29, 0.135], in: squirrel)
        let tail = Entity()
        tail.name = "tail"
        tail.position = [0, 0.1, -0.1]
        squirrel.addChild(tail)
        let big = part(sphere(0.1), fur, at: [0, 0.14, -0.05], in: tail)
        big.scale = [0.7, 1.6, 0.8]
        let tip = part(sphere(0.07), fur, at: [0, 0.3, 0.02], in: tail)
        tip.scale = [0.7, 1, 1]
        return squirrel
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
