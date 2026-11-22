import RealityKit
import UIKit

/// Den store skogen rundt lysningen: trær Lowe kan felle, stier, kongler å finne,
/// ekorn som piler av gårde og snø som daler.
@MainActor
final class Woods {
    /// Hvor langt fra midten Lowe kan gå.
    let radius: Float = 20

    /// Lowe fant en kongle. Gir hvor mange som er funnet og hvor mange det er.
    var onConeFound: ((Int, Int) -> Void)?
    /// Alle konglene er funnet.
    var onAllConesFound: (() -> Void)?

    private let world: Entity
    private let sound: Sound
    private var time: Float = 0
    private var timers: [(time: Float, action: () -> Void)] = []

    private let hitsToFell = 4
    private let regrowDelay: Float = 30

    private final class Tree {
        enum State {
            case standing
            case falling(t: Float, axis: SIMD3<Float>, dir: SIMD2<Float>)
            case gone(regrowAt: Float)
            case growing(t: Float)
        }
        let entity: Entity
        let position: SIMD3<Float>
        let scale: Float
        var hits = 0
        var state: State = .standing
        var wobble: Float?
        var stump: Entity?
        var faded = false

        init(entity: Entity, position: SIMD3<Float>, scale: Float) {
            self.entity = entity
            self.position = position
            self.scale = scale
        }

        var isStanding: Bool {
            if case .standing = state { return true }
            return false
        }
    }

    private struct Cone {
        let entity: Entity
        let base: SIMD3<Float>
        let phase: Float
    }

    private final class Squirrel {
        let entity: Entity
        var goal: SIMD3<Float>?
        var yaw: Float = 0
        var phase: Float = 0
        init(entity: Entity) { self.entity = entity }
    }

    private struct Puff {
        let entity: Entity
        var velocity: SIMD3<Float>
        var age: Float = 0
        let life: Float
    }

    private struct Flake {
        let entity: Entity
        let speed: Float
        let phase: Float
    }

    private var trees: [Tree] = []
    /// Stokker fra felte trær som ligger på bakken og venter på at Lowe bærer dem.
    private var looseLogs: [Entity] = []
    private var cones: [Cone] = []
    /// Steiner i snøen som Lowe kan plukke opp. En ny stein dukker opp igjen etter en stund.
    private var stones: [Entity] = []
    private let stoneRespawn: Float = 60
    private var conesFound = 0
    private let coneCount = 10
    private var coneRound: UInt64 = 0
    private var squirrels: [Squirrel] = []
    private var puffs: [Puff] = []
    private var flakes: [Flake] = []

    /// Stiene går ut fra lysningen. Den første går dit dyrene bor.
    private let paths: [[SIMD2<Float>]] = [
        [[1, -1], [4, -3], [7, -6], [9, -8], [12, -13], [13, -19]],
        [[-1, 1.5], [-5, 3], [-9, 2.5], [-13, 4.5], [-18, 6]],
        [[1.5, 2.5], [4, 6], [8, 9], [11, 13], [16, 15]],
        [[-1.5, -2], [-4, -6], [-3, -11], [-6, -15], [-8, -19]],
    ]

    init(world: Entity, sound: Sound) {
        self.world = world
        self.sound = sound
        buildPaths()
        plantTrees()
        placeCones()
        placeStones()
        placeSquirrels()
        makeSnow()
    }

    // MARK: Oppbygging

    private func buildPaths() {
        for path in paths {
            for (a, b) in zip(path, path.dropFirst()) {
                let d = b - a
                let length = simd_length(d)
                let strip = Make.part(Make.box(1.3, 0.01, length + 0.4), Colors.snowShade, in: world)
                strip.position = [(a.x + b.x) / 2, 0.004, (a.y + b.y) / 2]
                strip.orientation = rotY(atan2(d.x, d.y))
            }
        }
    }

    private func plantTrees() {
        var random = SeededRandom(seed: 11)
        var spots: [SIMD2<Float>] = []
        var attempts = 0
        while spots.count < 85 && attempts < 5000 {
            attempts += 1
            let p = SIMD2<Float>(random.next(-radius - 1, radius + 1), random.next(-radius - 1, radius + 1))
            let r = simd_length(p)
            if r < 4.8 || r > radius + 1 { continue }
            if distanceToPaths(p) < 1.5 { continue }
            if spots.contains(where: { simd_distance($0, p) < 2.0 }) { continue }
            spots.append(p)
        }
        for p in spots {
            let s = random.next(0.85, 1.45)
            let entity = Make.spruce(scale: s)
            let position = SIMD3<Float>(p.x, 0, p.y)
            entity.position = position
            world.addChild(entity)
            trees.append(Tree(entity: entity, position: position, scale: s))
        }
        // En tett ring av trær helt ytterst, så skogen ser ut til å fortsette.
        let ring = 44
        for i in 0..<ring {
            let angle = Float(i) / Float(ring) * 2 * .pi + random.next(-0.05, 0.05)
            let r = random.next(radius + 3, radius + 7)
            let tree = Make.spruce(scale: random.next(1.2, 1.8))
            tree.position = [cos(angle) * r, 0, sin(angle) * r]
            world.addChild(tree)
        }
    }

    private func distanceToPaths(_ p: SIMD2<Float>) -> Float {
        var best = Float.greatestFiniteMagnitude
        for path in paths {
            for (a, b) in zip(path, path.dropFirst()) {
                let ab = b - a
                let t = max(0, min(1, simd_dot(p - a, ab) / simd_dot(ab, ab)))
                best = min(best, simd_distance(p, a + ab * t))
            }
        }
        return best
    }

    private func placeCones() {
        var random = SeededRandom(seed: 100 + coneRound)
        coneRound += 1
        var spots: [SIMD2<Float>] = []
        var attempts = 0
        while spots.count < coneCount && attempts < 3000 {
            attempts += 1
            let p = SIMD2<Float>(random.next(-radius + 1, radius - 1), random.next(-radius + 1, radius - 1))
            let r = simd_length(p)
            if r < 5 || r > radius - 1 { continue }
            if trees.contains(where: { simd_distance(SIMD2($0.position.x, $0.position.z), p) < 1.1 }) { continue }
            if spots.contains(where: { simd_distance($0, p) < 4 }) { continue }
            spots.append(p)
        }
        for (i, p) in spots.enumerated() {
            let entity = Make.pinecone()
            let base = SIMD3<Float>(p.x, 0, p.y)
            entity.position = base
            entity.scale = [1.4, 1.4, 1.4]
            world.addChild(entity)
            cones.append(Cone(entity: entity, base: base, phase: Float(i)))
        }
    }

    private func placeStones() {
        var random = SeededRandom(seed: 77)
        var spots: [SIMD2<Float>] = []
        var attempts = 0
        while spots.count < 16 && attempts < 3000 {
            attempts += 1
            let p = SIMD2<Float>(random.next(-radius + 1, radius - 1), random.next(-radius + 1, radius - 1))
            let r = simd_length(p)
            if r < 3.5 || r > radius - 1 { continue }
            if trees.contains(where: { simd_distance(SIMD2($0.position.x, $0.position.z), p) < 1.0 }) { continue }
            if spots.contains(where: { simd_distance($0, p) < 2.5 }) { continue }
            spots.append(p)
        }
        for p in spots { addStone(at: SIMD3(p.x, 0, p.y)) }
    }

    private func addStone(at p: SIMD3<Float>) {
        let stone = Make.stone()
        stone.position = p
        stone.orientation = rotY(p.x * 3.1 + p.z)
        world.addChild(stone)
        stones.append(stone)
    }

    /// Steinene som ligger i snøen.
    var allStones: [Entity] { stones }

    /// Lowe tar steinen. Den forsvinner med et lite snøpuff, og en ny kommer på samme sted senere.
    func takeStone(_ stone: Entity) {
        guard let i = stones.firstIndex(where: { $0 === stone }) else { return }
        stones.remove(at: i)
        let p = stone.position
        puff(at: p + [0, 0.1, 0], count: 5, spread: 0.2, up: 1.2)
        stone.removeFromParent()
        after(stoneRespawn) { [weak self] in self?.addStone(at: p) }
    }

    private func placeSquirrels() {
        for i in 0..<4 {
            let squirrel = Squirrel(entity: Make.squirrel())
            squirrel.entity.position = spotNearTree(index: i * 17 + 3)
            squirrel.entity.scale = [1.3, 1.3, 1.3]
            world.addChild(squirrel.entity)
            squirrels.append(squirrel)
        }
    }

    /// Et sted ved foten av et tre, der et ekorn kan sitte.
    private func spotNearTree(index: Int) -> SIMD3<Float> {
        guard !trees.isEmpty else { return [6, 0, 6] }
        let tree = trees[index % trees.count]
        let out = simd_normalize(SIMD2<Float>(-tree.position.x, -tree.position.z) + [0.001, 0])
        return tree.position + [out.x * 0.7, 0, out.y * 0.7]
    }

    private func makeSnow() {
        var random = SeededRandom(seed: 5)
        for i in 0..<140 {
            let flake = Make.part(Make.sphere(0.028), Colors.white, in: world)
            flake.position = [random.next(-9, 9), random.next(0, 7), random.next(-9, 9)]
            flakes.append(Flake(entity: flake, speed: random.next(0.5, 1.0), phase: Float(i) * 0.7))
        }
    }

    // MARK: Det Forest spør om

    /// Det Lowe ikke kan gå gjennom: trær som står, og stubber.
    func obstacles(near p: SIMD3<Float>) -> [(SIMD3<Float>, Float)] {
        var result: [(SIMD3<Float>, Float)] = []
        for tree in trees where abs(tree.position.x - p.x) < 2 && abs(tree.position.z - p.z) < 2 {
            switch tree.state {
            case .standing, .falling, .growing:
                result.append((tree.position, 0.38 * tree.scale))
            case .gone:
                if tree.stump != nil { result.append((tree.position, 0.25 * tree.scale)) }
            }
        }
        return result
    }

    /// Det nærmeste treet som står, innen `reach` meter.
    func nearestTree(to p: SIMD3<Float>, within reach: Float) -> Int? {
        var best: (Int, Float)?
        for (i, tree) in trees.enumerated() where tree.isStanding {
            let d = flatDistance(tree.position, p)
            if d < reach && d < (best?.1 ?? .greatestFiniteMagnitude) { best = (i, d) }
        }
        return best?.0
    }

    func treePosition(_ index: Int) -> SIMD3<Float> { trees[index].position }

    /// Hvor Lowe skal stå for å hugge treet, på den siden han kommer fra.
    func chopSpot(forTree index: Int, from p: SIMD3<Float>) -> SIMD3<Float> {
        let tree = trees[index]
        var dir = SIMD2<Float>(p.x - tree.position.x, p.z - tree.position.z)
        if simd_length(dir) < 0.01 { dir = [0, 1] }
        dir = simd_normalize(dir)
        let distance = 0.62 + 0.12 * tree.scale
        return tree.position + [dir.x * distance, 0, dir.y * distance]
    }

    /// Den nærmeste stokken på bakken innen `reach` meter.
    /// Stokkene som ligger i snøen og kan bæres.
    var allLooseLogs: [Entity] { looseLogs }

    func nearestLooseLog(to p: SIMD3<Float>, within reach: Float) -> Entity? {
        looseLogs.min { flatDistance($0.position, p) < flatDistance($1.position, p) }
            .flatMap { flatDistance($0.position, p) < reach ? $0 : nil }
    }

    /// Lowe løfter opp stokken.
    func take(_ log: Entity) {
        looseLogs.removeAll { $0 === log }
    }

    /// Lowe legger stokken fra seg på bakken.
    func putDown(_ log: Entity) {
        looseLogs.append(log)
        puff(at: log.position, count: 4, spread: 0.3, up: 0.6)
    }

    func canHit(tree index: Int, from p: SIMD3<Float>) -> Bool {
        index < trees.count && trees[index].isStanding && flatDistance(trees[index].position, p) < 1.3
    }

    /// Et hogg i treet. Etter fire hogg faller det vekk fra Lowe. Gir `true` når treet faller.
    @discardableResult
    func hit(tree index: Int, from p: SIMD3<Float>) -> Bool {
        let tree = trees[index]
        guard tree.isStanding else { return false }
        tree.hits += 1
        tree.wobble = 0
        puff(at: tree.position + [0, 2.0 * tree.scale, 0], count: 6, spread: 0.8 * tree.scale, up: 0.2)
        guard tree.hits >= hitsToFell else { return false }
        var dir = SIMD2<Float>(tree.position.x - p.x, tree.position.z - p.z)
        if simd_length(dir) < 0.01 { dir = [0, -1] }
        dir = simd_normalize(dir)
        tree.state = .falling(t: 0, axis: [dir.y, 0, -dir.x], dir: dir)
        sound.play(.split)
        return true
    }

    // MARK: Hver ramme

    func update(_ dt: Float, lowe: SIMD3<Float>, camera: SIMD3<Float>) {
        time += dt
        let due = timers.filter { $0.time <= time }
        if !due.isEmpty {
            timers.removeAll { $0.time <= time }
            due.forEach { $0.action() }
        }
        updateTrees(dt, lowe: lowe, camera: camera)
        updateCones(dt, lowe: lowe)
        updateSquirrels(dt, lowe: lowe)
        updatePuffs(dt)
        updateSnow(dt, around: lowe)
    }

    private func updateTrees(_ dt: Float, lowe: SIMD3<Float>, camera: SIMD3<Float>) {
        for tree in trees {
            switch tree.state {
            case .standing:
                if let w = tree.wobble {
                    let t = w + dt / 0.4
                    tree.wobble = t < 1 ? t : nil
                    let angle = sin(t * .pi * 4) * 0.05 * (1 - t)
                    tree.entity.orientation = rotZ(angle)
                } else {
                    tree.entity.orientation = rotY(0)
                }
            case let .falling(t, axis, dir):
                let next = t + dt / 1.1
                if next >= 1 {
                    tree.entity.orientation = simd_quatf(angle: .pi / 2 - 0.06, axis: simd_normalize(axis))
                    treeLanded(tree, dir: dir)
                } else {
                    tree.state = .falling(t: next, axis: axis, dir: dir)
                    tree.entity.orientation = simd_quatf(angle: (.pi / 2 - 0.06) * next * next, axis: simd_normalize(axis))
                }
            case let .gone(regrowAt):
                if time >= regrowAt {
                    tree.stump?.removeFromParent()
                    tree.stump = nil
                    tree.hits = 0
                    tree.entity.orientation = rotY(0)
                    tree.entity.scale = [0.01, 0.01, 0.01]
                    world.addChild(tree.entity)
                    tree.state = .growing(t: 0)
                }
            case let .growing(t):
                let next = t + dt / 2.5
                let s = tree.scale * min(1, next) * (next < 1 ? 1 + 0.08 * sin(next * .pi) : 1)
                tree.entity.scale = [s, s, s]
                tree.state = next >= 1 ? .standing : .growing(t: next)
            }
        }
        fadeTreesBetween(camera: camera, lowe: lowe)
    }

    private func treeLanded(_ tree: Tree, dir: SIMD2<Float>) {
        sound.play(.land)
        sound.buzz(strong: true)
        let length = 2.4 * tree.scale
        for k in 1...4 {
            let along = Float(k) / 4 * length
            puff(at: tree.position + [dir.x * along, 0.3, dir.y * along], count: 5, spread: 0.6, up: 1.2)
        }
        tree.entity.removeFromParent()
        let stump = Make.stump(scale: tree.scale)
        stump.position = tree.position
        world.addChild(stump)
        tree.stump = stump
        tree.state = .gone(regrowAt: time + regrowDelay)

        // Stokken blir liggende der treet falt, langs stammen, til Lowe bærer den bort.
        let log = Make.lyingLog()
        log.position = tree.position + [dir.x * length * 0.45, 0.17, dir.y * length * 0.45]
        log.orientation = rotY(atan2(-dir.y, dir.x))
        world.addChild(log)
        looseLogs.append(log)
    }

    /// Trær mellom kameraet og Lowe blir gjennomsiktige, så Lowe aldri forsvinner bak et tre.
    private func fadeTreesBetween(camera: SIMD3<Float>, lowe: SIMD3<Float>) {
        let a = SIMD2<Float>(camera.x, camera.z)
        let b = SIMD2<Float>(lowe.x, lowe.z)
        let ab = b - a
        let lengthSquared = max(0.01, simd_dot(ab, ab))
        for tree in trees {
            let p = SIMD2<Float>(tree.position.x, tree.position.z)
            let t = simd_dot(p - a, ab) / lengthSquared
            let closest = a + ab * max(0, min(1, t))
            let shouldFade = t > -0.1 && t < 0.95 && simd_distance(p, closest) < 0.9 * tree.scale
            guard shouldFade != tree.faded else { continue }
            tree.faded = shouldFade
            if shouldFade {
                tree.entity.components.set(OpacityComponent(opacity: 0.25))
            } else {
                tree.entity.components.remove(OpacityComponent.self)
            }
        }
    }

    private func updateCones(_ dt: Float, lowe: SIMD3<Float>) {
        for i in cones.indices.reversed() {
            let cone = cones[i]
            let bob = 0.08 + 0.06 * sin(time * 2.5 + cone.phase)
            cone.entity.position = cone.base + [0, bob, 0]
            cone.entity.orientation = rotY(time * 1.2 + cone.phase)
            if flatDistance(cone.base, lowe) < 0.8 {
                cones.remove(at: i)
                collect(cone)
            }
        }
    }

    private func collect(_ cone: Cone) {
        sound.play(.pop)
        sound.buzz()
        conesFound += 1
        puff(at: cone.entity.position + [0, 0.2, 0], count: 6, spread: 0.3, up: 1.5)
        cone.entity.removeFromParent()
        onConeFound?(conesFound, coneCount)
        if cones.isEmpty {
            onAllConesFound?()
            after(3) { [weak self] in
                guard let self else { return }
                self.conesFound = 0
                self.placeCones()
                self.onConeFound?(0, self.coneCount)
            }
        }
    }

    private func updateSquirrels(_ dt: Float, lowe: SIMD3<Float>) {
        for (n, squirrel) in squirrels.enumerated() {
            let entity = squirrel.entity
            if let goal = squirrel.goal {
                var delta = goal - entity.position
                delta.y = 0
                let distance = simd_length(delta)
                if distance < 0.05 {
                    entity.position = goal
                    squirrel.goal = nil
                } else {
                    entity.position += delta / distance * min(distance, 4.5 * dt)
                    entity.position.y = 0
                    squirrel.yaw = atan2(delta.x, delta.z)
                    squirrel.phase += dt * 16
                    entity.position.y = abs(sin(squirrel.phase)) * 0.25
                }
            } else {
                entity.position.y = 0
                let toLowe = lowe - entity.position
                squirrel.yaw = atan2(toLowe.x, toLowe.z)
                // Kommer Lowe for nær, piler ekornet til et annet tre.
                if flatDistance(lowe, entity.position) < 2.6 {
                    squirrel.goal = fleeSpot(from: lowe, squirrel: n)
                    sound.play(.squeak, volume: 0.6)
                }
            }
            entity.orientation = rotY(squirrel.yaw)
            entity.findEntity(named: "tail")?.orientation = rotX(-0.25 + 0.15 * sin(time * 6 + Float(n)))
        }
    }

    private func fleeSpot(from lowe: SIMD3<Float>, squirrel n: Int) -> SIMD3<Float> {
        let here = squirrels[n].entity.position
        for k in 0..<trees.count {
            let candidate = spotNearTree(index: (Int(time * 7) + n * 13 + k * 5) % max(1, trees.count))
            let fromHere = flatDistance(candidate, here)
            if fromHere > 5 && fromHere < 12 && flatDistance(candidate, lowe) > 5 {
                return candidate
            }
        }
        return here + [6, 0, 0]
    }

    // MARK: Små effekter

    private func puff(at p: SIMD3<Float>, count: Int, spread: Float, up: Float) {
        for _ in 0..<count {
            let bit = Make.part(Make.sphere(0.07), Colors.white, in: world)
            bit.position = p + [Float.random(in: -spread...spread), Float.random(in: 0...spread * 0.5),
                                Float.random(in: -spread...spread)]
            let v = SIMD3<Float>(Float.random(in: -0.6...0.6), Float.random(in: 0.2...1) * up, Float.random(in: -0.6...0.6))
            puffs.append(Puff(entity: bit, velocity: v, life: Float.random(in: 0.6...1.0)))
        }
    }

    private func updatePuffs(_ dt: Float) {
        for i in puffs.indices.reversed() {
            var puff = puffs[i]
            puff.age += dt
            puff.velocity.y -= 1.5 * dt
            puff.entity.position += puff.velocity * dt
            let grow = 1 + puff.age * 2
            let fade = max(0.01, 1 - puff.age / puff.life)
            puff.entity.scale = SIMD3(repeating: grow * fade)
            if puff.age >= puff.life {
                puff.entity.removeFromParent()
                puffs.remove(at: i)
            } else {
                puffs[i] = puff
            }
        }
    }

    /// Snøfnuggene daler rundt Lowe og begynner på nytt oppe når de når bakken.
    private func updateSnow(_ dt: Float, around center: SIMD3<Float>) {
        for flake in flakes {
            var p = flake.entity.position
            p.y -= flake.speed * dt
            p.x += sin(time * 0.9 + flake.phase) * 0.25 * dt
            if p.y < 0 { p.y += 7 }
            if p.x - center.x > 9 { p.x -= 18 }
            if p.x - center.x < -9 { p.x += 18 }
            if p.z - center.z > 9 { p.z -= 18 }
            if p.z - center.z < -9 { p.z += 18 }
            flake.entity.position = p
        }
    }

    // MARK: Hjelpere

    private func flatDistance(_ a: SIMD3<Float>, _ b: SIMD3<Float>) -> Float {
        simd_length(SIMD2<Float>(a.x - b.x, a.z - b.z))
    }

    private func after(_ delay: Float, _ action: @escaping () -> Void) {
        timers.append((time + delay, action))
    }
}
