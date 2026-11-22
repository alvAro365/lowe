import RealityKit
import UIKit

/// Byggeklosser av tre som Lowe setter opp selv: hytter, gjerder og tårn.
/// Klossene står i et rutenett på en halv meter og stables oppå hverandre.
/// Lowe kan hoppe opp på en kloss og klatre videre. Det som er bygd, huskes.
@MainActor
final class Builder {
    struct Cell: Hashable {
        let x: Int
        let z: Int
    }

    static let size: Float = 0.5
    let maxHeight = 8

    private let world: Entity
    private var columns: [Cell: [Entity]] = [:]
    private let ghost: ModelEntity
    private let saveKey = "lowe.blocks"

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
        Cell(x: Int((p.x / Builder.size).rounded(.down)), z: Int((p.z / Builder.size).rounded(.down)))
    }

    func center(of cell: Cell) -> SIMD3<Float> {
        SIMD3((Float(cell.x) + 0.5) * Builder.size, 0, (Float(cell.z) + 0.5) * Builder.size)
    }

    func height(of cell: Cell) -> Int { columns[cell]?.count ?? 0 }

    /// Hvor høyt bakken er der Lowe står: toppen av klossene under ham.
    func groundHeight(at p: SIMD3<Float>) -> Float {
        Float(height(of: cell(at: p))) * Builder.size
    }

    /// Klosser som er for høye til å gå rett inn i fra høyden `footY`.
    func obstacles(near p: SIMD3<Float>, footY: Float) -> [(SIMD3<Float>, Float)] {
        let here = cell(at: p)
        var result: [(SIMD3<Float>, Float)] = []
        for dx in -2...2 {
            for dz in -2...2 {
                let c = Cell(x: here.x + dx, z: here.z + dz)
                guard c != here, Float(height(of: c)) * Builder.size > footY + 0.3 else { continue }
                result.append((center(of: c), Builder.size * 0.62 + 0.18))
            }
        }
        return result
    }

    // MARK: Bygge og rive

    /// Ruta foran Lowe, der neste kloss havner.
    func targetCell(from p: SIMD3<Float>, yaw: Float) -> Cell {
        cell(at: p + [sin(yaw) * 0.8, 0, cos(yaw) * 0.8])
    }

    /// Viser en turkis kloss der neste kloss havner, eller skjuler den.
    func showGhost(at cell: Cell?) {
        guard let cell, height(of: cell) < maxHeight else {
            ghost.isEnabled = false
            return
        }
        ghost.isEnabled = true
        ghost.position = center(of: cell) + [0, (Float(height(of: cell)) + 0.5) * Builder.size, 0]
    }

    @discardableResult
    func place(at cell: Cell) -> Bool {
        let level = height(of: cell)
        guard level < maxHeight else { return false }
        let block = Builder.block(level: level)
        block.position = center(of: cell) + [0, (Float(level) + 0.5) * Builder.size, 0]
        world.addChild(block)
        columns[cell, default: []].append(block)
        save()
        block.scale = [0.3, 0.3, 0.3]
        block.move(to: Transform(scale: [1, 1, 1], rotation: block.orientation, translation: block.position),
                   relativeTo: block.parent, duration: 0.15)
        return true
    }

    /// Tar den øverste klossen i ruta. Gir posisjonen den sto på, eller nil om ruta var tom.
    func removeTop(at cell: Cell) -> SIMD3<Float>? {
        guard var column = columns[cell], let top = column.popLast() else { return nil }
        let p = top.position
        top.removeFromParent()
        columns[cell] = column.isEmpty ? nil : column
        save()
        return p
    }

    private static func block(level: Int) -> Entity {
        let block = Entity()
        let side = level % 2 == 0 ? Colors.barkLight : Colors.bark
        Make.part(Make.box(size, size, size, r: 0.025), side, in: block)
        Make.part(Make.box(size * 0.86, 0.012, size * 0.86, r: 0.01), Colors.wood, at: [0, size / 2 + 0.002, 0], in: block)
        for z in [Float(1), -1] {
            Make.part(Make.box(size * 0.9, 0.02, 0.006), Colors.barkLine, at: [0, 0.06, z * (size / 2 + 0.002)], in: block)
            Make.part(Make.box(size * 0.9, 0.02, 0.006), Colors.barkLine, at: [0, -0.1, z * (size / 2 + 0.002)], in: block)
        }
        return block
    }

    // MARK: Lagring

    private func save() {
        var numbers: [Int] = []
        for (cell, column) in columns where !column.isEmpty {
            numbers += [cell.x, cell.z, column.count]
        }
        UserDefaults.standard.set(numbers, forKey: saveKey)
    }

    private func load() {
        guard let numbers = UserDefaults.standard.array(forKey: saveKey) as? [Int] else { return }
        var i = 0
        while i + 2 < numbers.count {
            let cell = Cell(x: numbers[i], z: numbers[i + 1])
            for level in 0..<min(numbers[i + 2], maxHeight) {
                let block = Builder.block(level: level)
                block.position = center(of: cell) + [0, (Float(level) + 0.5) * Builder.size, 0]
                world.addChild(block)
                columns[cell, default: []].append(block)
            }
            i += 3
        }
    }
}
