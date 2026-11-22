import RealityKit
import UIKit

/// Byggeklosser som Lowe setter opp selv, omtrent som i Minecraft: klossene står i et rutenett
/// på en halv meter i alle retninger, og en ny kloss settes inntil en side av en annen kloss
/// eller på bakken. Lowe kan gå oppå klossene, hoppe opp på dem og klatre. Det som er bygd, huskes.
@MainActor
final class Builder {
    struct Cell: Hashable {
        let x: Int
        let y: Int
        let z: Int

        func moved(_ d: SIMD3<Int>) -> Cell { Cell(x: x + d.x, y: y + d.y, z: z + d.z) }
    }

    /// Klossene Lowe kan velge mellom.
    enum Kind: Int, CaseIterable {
        case plank, log, stone, turquoise, black

        var side: UIColor {
            switch self {
            case .plank: return Colors.barkLight
            case .log: return Colors.bark
            case .stone: return Colors.stone
            case .turquoise: return Colors.turquoise
            case .black: return Colors.ink
            }
        }

        var top: UIColor {
            switch self {
            case .plank: return Colors.wood
            case .log: return UIColor(hex: 0xD9AF72)
            case .stone: return UIColor(hex: 0xB7C0C6)
            case .turquoise: return UIColor(hex: 0x5ED9D6)
            case .black: return UIColor(hex: 0x3A3D44)
            }
        }

        var line: UIColor {
            switch self {
            case .plank: return Colors.barkLine
            case .log: return UIColor(hex: 0x5A361F)
            case .stone: return UIColor(hex: 0x7D8890)
            case .turquoise: return UIColor(hex: 0x179A9A)
            case .black: return UIColor(hex: 0x50545C)
            }
        }
    }

    /// Hva en stråle fra kameraet traff: en kloss (og hvilken side), eller bakken.
    enum Hit {
        case block(Cell, face: SIMD3<Int>)
        case ground(Cell)

        /// Ruta der en ny kloss havner om Lowe bygger her.
        var placeCell: Cell {
            switch self {
            case .block(let cell, let face): return cell.moved(face)
            case .ground(let cell): return cell
            }
        }
    }

    static let size: Float = 0.5
    let maxHeight = 12

    private let world: Entity
    private var blocks: [Cell: (kind: Kind, entity: Entity)] = [:]
    private let ghost: ModelEntity
    private let saveKey = "lowe.blocks3d"
    private let oldSaveKey = "lowe.blocks"

    init(world: Entity) {
        self.world = world
        ghost = Make.part(Make.box(Builder.size, Builder.size, Builder.size, r: 0.03), Colors.turquoise)
        ghost.components.set(OpacityComponent(opacity: 0.45))
        ghost.isEnabled = false
        world.addChild(ghost)
        load()
    }

    // MARK: Rutenett

    func cell(at p: SIMD3<Float>) -> Cell {
        Cell(x: Int((p.x / Builder.size).rounded(.down)),
             y: Int((p.y / Builder.size).rounded(.down)),
             z: Int((p.z / Builder.size).rounded(.down)))
    }

    /// Midten av ruta, også i høyden.
    func center(of cell: Cell) -> SIMD3<Float> {
        SIMD3(Float(cell.x) + 0.5, Float(cell.y) + 0.5, Float(cell.z) + 0.5) * Builder.size
    }

    func isSolid(_ cell: Cell) -> Bool { blocks[cell] != nil }

    private func level(_ y: Float) -> Int { Int((y / Builder.size).rounded(.down)) }

    /// Toppen av den høyeste klossen under føttene til Lowe, eller 0 på snøen.
    func groundHeight(at p: SIMD3<Float>, footY: Float) -> Float {
        let c = cell(at: p)
        var y = level(footY + 0.05) - 1
        while y >= 0 {
            if isSolid(Cell(x: c.x, y: y, z: c.z)) { return Float(y + 1) * Builder.size }
            y -= 1
        }
        return 0
    }

    /// Rutene kroppen til Lowe fyller når føttene er i høyden `footY`.
    private func bodyLevels(footY: Float) -> ClosedRange<Int> {
        level(footY + 0.05)...level(footY + 1.3)
    }

    /// Om det står en kloss der kroppen til Lowe ville vært.
    func blocked(at p: SIMD3<Float>, footY: Float) -> Bool {
        let c = cell(at: p)
        return bodyLevels(footY: footY).contains { isSolid(Cell(x: c.x, y: $0, z: c.z)) }
    }

    /// Om hodet til Lowe støter i en kloss over seg.
    func bumpsHead(at p: SIMD3<Float>, footY: Float) -> Bool {
        let c = cell(at: p)
        return isSolid(Cell(x: c.x, y: level(footY + 1.45), z: c.z))
    }

    /// Klosser rundt Lowe som er i veien for kroppen, som sirkler han ikke kan gå inn i.
    func obstacles(near p: SIMD3<Float>, footY: Float) -> [(SIMD3<Float>, Float)] {
        let here = cell(at: p)
        let levels = bodyLevels(footY: footY)
        var result: [(SIMD3<Float>, Float)] = []
        for dx in -2...2 {
            for dz in -2...2 where dx != 0 || dz != 0 {
                let x = here.x + dx, z = here.z + dz
                guard levels.contains(where: { isSolid(Cell(x: x, y: $0, z: z)) }) else { continue }
                result.append((center(of: Cell(x: x, y: 0, z: z)) * [1, 0, 1], Builder.size * 0.62 + 0.18))
            }
        }
        return result
    }

    /// Om en ny kloss i ruta ville kommet borti Lowe.
    func overlapsBody(_ cell: Cell, at p: SIMD3<Float>, footY: Float) -> Bool {
        let c = center(of: cell)
        let reach = Builder.size / 2 + 0.2
        return abs(c.x - p.x) < reach && abs(c.z - p.z) < reach && bodyLevels(footY: footY).contains(cell.y)
    }

    // MARK: Sikte

    /// Følger en stråle gjennom rutenettet og finner den første klossen, eller bakken.
    func raycast(from origin: SIMD3<Float>, direction: SIMD3<Float>, maxDistance: Float) -> Hit? {
        let dir = simd_normalize(direction)
        let o = origin / Builder.size
        var c = SIMD3<Int>(Int(o.x.rounded(.down)), Int(o.y.rounded(.down)), Int(o.z.rounded(.down)))
        let step = SIMD3<Int>(dir.x >= 0 ? 1 : -1, dir.y >= 0 ? 1 : -1, dir.z >= 0 ? 1 : -1)
        func boundary(_ i: Int, _ s: Int, _ p: Float, _ d: Float) -> Float {
            guard abs(d) > 1e-6 else { return .infinity }
            let next = Float(s > 0 ? i + 1 : i)
            return (next - p) / d
        }
        var tMax = SIMD3<Float>(boundary(c.x, step.x, o.x, dir.x),
                                boundary(c.y, step.y, o.y, dir.y),
                                boundary(c.z, step.z, o.z, dir.z))
        let tDelta = SIMD3<Float>(abs(dir.x) > 1e-6 ? 1 / abs(dir.x) : .infinity,
                                  abs(dir.y) > 1e-6 ? 1 / abs(dir.y) : .infinity,
                                  abs(dir.z) > 1e-6 ? 1 / abs(dir.z) : .infinity)
        let limit = maxDistance / Builder.size
        var face = SIMD3<Int>(0, 0, 0)
        var t: Float = 0
        while t <= limit {
            if c.y < 0 {
                // Strålen har gått ned i snøen: Lowe bygger på bakken.
                let tGround = -o.y / dir.y
                let g = o + dir * tGround
                return .ground(Cell(x: Int(g.x.rounded(.down)), y: 0, z: Int(g.z.rounded(.down))))
            }
            let cell = Cell(x: c.x, y: c.y, z: c.z)
            if isSolid(cell) { return .block(cell, face: face) }
            if tMax.x < tMax.y && tMax.x < tMax.z {
                t = tMax.x; c.x += step.x; tMax.x += tDelta.x; face = [-step.x, 0, 0]
            } else if tMax.y < tMax.z {
                t = tMax.y; c.y += step.y; tMax.y += tDelta.y; face = [0, -step.y, 0]
            } else {
                t = tMax.z; c.z += step.z; tMax.z += tDelta.z; face = [0, 0, -step.z]
            }
        }
        return nil
    }

    /// Ruta foran Lowe der den store knappen setter neste kloss: fra rett under føttene og oppover.
    /// Står han på et tårn, blir det en bro ut; står han på bakken, blir det et tårn foran ham.
    func frontCell(from p: SIMD3<Float>, footY: Float, yaw: Float) -> Cell? {
        let front = cell(at: p + [sin(yaw) * 0.8, 0, cos(yaw) * 0.8])
        let foot = level(footY + 0.05)
        for y in max(0, foot - 1)...(foot + 2) {
            let c = Cell(x: front.x, y: y, z: front.z)
            if !isSolid(c) { return y < maxHeight ? c : nil }
        }
        return nil
    }

    /// Klossen foran Lowe som øksa treffer: ved føttene, ved brystet eller rett under kanten.
    func frontBlock(from p: SIMD3<Float>, footY: Float, yaw: Float) -> Cell? {
        let front = cell(at: p + [sin(yaw) * 0.8, 0, cos(yaw) * 0.8])
        let foot = level(footY + 0.05)
        for y in [foot, foot + 1, foot - 1, foot + 2] where y >= 0 {
            let c = Cell(x: front.x, y: y, z: front.z)
            if isSolid(c) { return c }
        }
        return nil
    }

    /// Viser en gjennomsiktig turkis kloss der neste kloss havner, eller skjuler den.
    func showGhost(at cell: Cell?) {
        guard let cell else {
            ghost.isEnabled = false
            return
        }
        ghost.isEnabled = true
        ghost.position = center(of: cell)
    }

    // MARK: Bygge og rive

    @discardableResult
    func place(_ kind: Kind, at cell: Cell) -> Bool {
        guard cell.y >= 0, cell.y < maxHeight, !isSolid(cell) else { return false }
        let block = Builder.block(kind)
        block.position = center(of: cell)
        world.addChild(block)
        blocks[cell] = (kind, block)
        save()
        block.scale = [0.3, 0.3, 0.3]
        block.move(to: Transform(scale: [1, 1, 1], rotation: block.orientation, translation: block.position),
                   relativeTo: block.parent, duration: 0.15)
        return true
    }

    /// Tar bort klossen i ruta. Gir midten av den, eller nil om ruta var tom.
    func remove(at cell: Cell) -> SIMD3<Float>? {
        guard let removed = blocks.removeValue(forKey: cell) else { return nil }
        let entity = removed.entity
        let p = entity.position
        entity.move(to: Transform(scale: [0.05, 0.05, 0.05], rotation: entity.orientation, translation: p),
                    relativeTo: entity.parent, duration: 0.12)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.13) { [weak entity] in entity?.removeFromParent() }
        save()
        return p
    }

    private static func block(_ kind: Kind) -> Entity {
        let block = Entity()
        Make.part(Make.box(size, size, size, r: 0.025), kind.side, in: block)
        Make.part(Make.box(size * 0.86, 0.012, size * 0.86, r: 0.01), kind.top, at: [0, size / 2 + 0.002, 0], in: block)
        switch kind {
        case .plank, .log:
            for z in [Float(1), -1] {
                Make.part(Make.box(size * 0.9, 0.02, 0.006), kind.line, at: [0, 0.06, z * (size / 2 + 0.002)], in: block)
                Make.part(Make.box(size * 0.9, 0.02, 0.006), kind.line, at: [0, -0.1, z * (size / 2 + 0.002)], in: block)
            }
            if kind == .log {
                Make.part(Make.box(size * 0.4, 0.014, size * 0.4, r: 0.01), kind.line, at: [0, size / 2 + 0.006, 0], in: block)
            }
        case .stone:
            for (x, y) in [(Float(-0.12), Float(0.1)), (0.1, -0.05), (-0.04, -0.14), (0.13, 0.13)] {
                for z in [Float(1), -1] {
                    Make.part(Make.box(0.09, 0.06, 0.006, r: 0.002), kind.line, at: [x, y, z * (size / 2 + 0.002)], in: block)
                }
            }
        case .turquoise, .black:
            for z in [Float(1), -1] {
                Make.part(Make.box(size * 0.7, size * 0.7, 0.006, r: 0.02), kind.line, at: [0, 0, z * (size / 2 + 0.002)], in: block)
            }
        }
        return block
    }

    // MARK: Lagring

    private func save() {
        var numbers: [Int] = []
        for (cell, block) in blocks {
            numbers += [cell.x, cell.y, cell.z, block.kind.rawValue]
        }
        UserDefaults.standard.set(numbers, forKey: saveKey)
    }

    private func load() {
        if let numbers = UserDefaults.standard.array(forKey: saveKey) as? [Int] {
            var i = 0
            while i + 3 < numbers.count {
                let cell = Cell(x: numbers[i], y: numbers[i + 1], z: numbers[i + 2])
                add(Kind(rawValue: numbers[i + 3]) ?? .plank, at: cell)
                i += 4
            }
        } else if let numbers = UserDefaults.standard.array(forKey: oldSaveKey) as? [Int] {
            // Klossene fra før var tårn: rute og høyde. De blir lyse og mørke planker som før.
            var i = 0
            while i + 2 < numbers.count {
                for y in 0..<min(numbers[i + 2], maxHeight) {
                    add(y % 2 == 0 ? .plank : .log, at: Cell(x: numbers[i], y: y, z: numbers[i + 1]))
                }
                i += 3
            }
            save()
            UserDefaults.standard.removeObject(forKey: oldSaveKey)
        }
    }

    private func add(_ kind: Kind, at cell: Cell) {
        guard blocks[cell] == nil else { return }
        let block = Builder.block(kind)
        block.position = center(of: cell)
        world.addChild(block)
        blocks[cell] = (kind, block)
    }
}
