import Combine
import RealityKit
import UIKit

/// Skogen i 3D. Trykk på snøen, så går Lowe dit. Trykk på hoggestabben, så går han bort
/// og hugger. Tre hogg deler kubben, og vedstykkene flyr til stabelen.
@MainActor
final class Forest: NSObject {
    private weak var view: ARView?
    private let world = AnchorEntity(world: .zero)
    private let camera = PerspectiveCamera()
    private let lowe = LoweFigure()
    private let sound = Sound()
    private var marker: ModelEntity?
    private var updateSubscription: Cancellable?

    private let blockPosition = SIMD3<Float>(0, 0, 0)
    private let pilePosition = SIMD3<Float>(2.3, 0, -0.7)
    private let logRestY: Float = 0.57
    private let chopDistance: Float = 0.8
    private let hitsNeeded = 3
    private let pileCapacity = 12
    private let walkSpeed: Float = 2.2
    private let forestRadius: Float = 7.5

    // Lowe
    private var position = SIMD3<Float>(0, 0, 2.4)
    private var yaw: Float = .pi
    private var yawGoal: Float = .pi
    private var target: SIMD3<Float>?
    private var chopWhenArrived = false
    /// Hvor fingeren holdes nå, når Lowe følger den.
    private var holdLocation: CGPoint?
    private var holdStartLocation: CGPoint = .zero
    private var holdStartTime: Float = 0
    private var walkPhase: Float = 0
    private var walkAmount: Float = 0
    private var chopTime: Float?
    private var chopQueued = false
    private var hitDone = false
    private var cheerTime: Float?

    // Kubbe og stabel
    private var log: Entity?
    private var logIncoming = false
    private var logHits = 0
    private var pile: [Entity] = []
    private var reserved = 0

    private var flyers: [Flyer] = []
    private var timers: [(time: Float, action: () -> Void)] = []
    private var time: Float = 0
    private var cameraFocus = SIMD3<Float>(0, 0.6, 2.4)
    private let cameraOffset = SIMD3<Float>(0, 4.4, 6.0)

    /// Noe som flyr i en bue: flis, vedstykker, konfetti og kubber som faller ned.
    private struct Flyer {
        let entity: Entity
        var velocity: SIMD3<Float>
        let gravity: Float
        let spin: SIMD3<Float>
        let duration: Float
        var age: Float = 0
        /// Hvor den skal ende. `nil` betyr at den forsvinner når tida er ute.
        let target: SIMD3<Float>?
        let onEnd: (() -> Void)?
    }

    func attach(to view: ARView) {
        self.view = view
        view.environment.background = .color(Colors.sky)
        view.scene.addAnchor(world)
        buildScene()

        // Ett trykk som starter med en gang, og som følger fingeren så lenge den holdes nede.
        let press = UILongPressGestureRecognizer(target: self, action: #selector(pressed(_:)))
        press.minimumPressDuration = 0
        press.allowableMovement = .greatestFiniteMagnitude
        view.addGestureRecognizer(press)

        updateSubscription = view.scene.subscribe(to: SceneEvents.Update.self) { [weak self] event in
            let dt = Float(min(event.deltaTime, 1.0 / 20))
            MainActor.assumeIsolated {
                self?.tick(dt)
            }
        }
        after(0.6) { [weak self] in self?.dropLog() }
    }

    // MARK: Scenen

    private func buildScene() {
        let sun = DirectionalLight()
        sun.light.intensity = 2600
        sun.light.color = UIColor(hex: 0xFFF6E8)
        sun.shadow = DirectionalLightComponent.Shadow(maximumDistance: 16, depthBias: 2)
        sun.look(at: .zero, from: [-4, 9, 5], relativeTo: nil)
        world.addChild(sun)

        camera.camera.fieldOfViewInDegrees = 45
        world.addChild(camera)

        Make.part(.generatePlane(width: 60, depth: 60), Colors.snow, in: world)

        // Trærne står i en ring rundt lysningen, med noen få nærmere.
        var random = SeededRandom(seed: 7)
        let ring = 30
        for i in 0..<ring {
            let angle = Float(i) / Float(ring) * 2 * .pi + random.next(-0.07, 0.07)
            let radius = random.next(8.5, 13)
            let tree = Make.spruce(scale: random.next(0.9, 1.5))
            tree.position = [cos(angle) * radius, 0, sin(angle) * radius]
            world.addChild(tree)
        }
        let nearTrees: [(Float, Float, Float)] = [(-3.6, -2.8, 1.1), (4.4, -3.4, 1.25), (-5.2, 1.4, 1.0),
                                                  (5.6, 2.6, 0.95), (-1.8, -5.6, 1.3), (1.6, -6.2, 1.15)]
        for (x, z, s) in nearTrees {
            let tree = Make.spruce(scale: s)
            tree.position = [x, 0, z]
            world.addChild(tree)
        }
        for (x, z, r) in [(-2.4, 1.2, 0.6), (3.4, 1.6, 0.8), (-4.2, -1.0, 0.7), (1.0, -3.4, 0.5), (-0.6, 4.6, 0.7)] as [(Float, Float, Float)] {
            let mound = Make.snowMound(radius: r)
            mound.position = [x, 0, z]
            world.addChild(mound)
        }

        let block = Make.choppingBlock()
        block.position = blockPosition
        world.addChild(block)

        for z in [Float(0.2), -0.2] {
            Make.part(Make.box(1.4, 0.08, 0.14, r: 0.02), Colors.trunk, at: pilePosition + [0, 0.04, z], in: world)
        }

        let ringMarker = Make.part(Make.cylinder(0.015, 0.22), Colors.turquoise, in: world)
        ringMarker.isEnabled = false
        marker = ringMarker

        lowe.root.position = position
        world.addChild(lowe.root)
        updateCamera(dt: 1)
    }

    // MARK: Trykk

    /// Hold fingeren nede, så går Lowe mot den og stopper når du slipper.
    /// Et kort trykk får ham til å gå dit. Trykk på stabben, så hugger han.
    @objc private func pressed(_ gesture: UILongPressGestureRecognizer) {
        guard let view else { return }
        let location = gesture.location(in: view)
        switch gesture.state {
        case .began:
            holdStartLocation = location
            holdStartTime = time
            holdLocation = nil
            guard let p = groundPoint(location, in: view) else { return }
            if flatDistance(p, blockPosition) < 0.9 {
                chopPressed()
                return
            }
            holdLocation = location
            walk(to: keepClear(p), chop: false)
        case .changed:
            if holdLocation != nil { holdLocation = location }
        case .ended, .cancelled, .failed:
            guard holdLocation != nil else { return }
            holdLocation = nil
            let moved = hypot(location.x - holdStartLocation.x, location.y - holdStartLocation.y)
            let quickTap = time - holdStartTime < 0.3 && moved < 24
            if quickTap {
                marker?.isEnabled = target != nil
            } else {
                target = nil
                marker?.isEnabled = false
            }
        default:
            break
        }
    }

    private func chopPressed() {
        let spot = chopSpot()
        if target == nil && flatDistance(position, spot) < 0.12 {
            yawGoal = facingBlock()
            startChop()
        } else {
            walk(to: spot, chop: true)
        }
    }

    /// Mens fingeren holdes nede, flyttes målet dit fingeren peker, også når kameraet glir etter.
    private func followFinger() {
        guard let location = holdLocation, let view, let p = groundPoint(location, in: view) else { return }
        walk(to: keepClear(p), chop: false)
    }

    /// Finner punktet på snøen under fingeren, ut fra kameraets plassering og synsvinkel.
    private func groundPoint(_ point: CGPoint, in view: ARView) -> SIMD3<Float>? {
        let size = view.bounds.size
        guard size.width > 0, size.height > 0 else { return nil }
        let aspect = Float(size.width / size.height)
        let tanHalf = tan(camera.camera.fieldOfViewInDegrees * .pi / 360)
        let nx = Float(point.x / size.width) * 2 - 1
        let ny = 1 - Float(point.y / size.height) * 2
        let local = SIMD3<Float>(nx * tanHalf * aspect, ny * tanHalf, -1)
        let origin = camera.position(relativeTo: nil)
        let direction = camera.orientation(relativeTo: nil).act(local)
        guard direction.y < -0.01 else { return nil }
        let t = -origin.y / direction.y
        return origin + direction * t
    }

    private func walk(to point: SIMD3<Float>, chop: Bool) {
        target = SIMD3(point.x, 0, point.z)
        chopWhenArrived = chop
        chopQueued = false
        if let marker {
            marker.position = SIMD3(point.x, 0.01, point.z)
            marker.isEnabled = holdLocation == nil
        }
    }

    /// Plassen foran stabben, på den siden Lowe står.
    private func chopSpot() -> SIMD3<Float> {
        var dir = SIMD2<Float>(position.x - blockPosition.x, position.z - blockPosition.z)
        if simd_length(dir) < 0.01 { dir = [0, 1] }
        dir = simd_normalize(dir)
        return SIMD3(blockPosition.x + dir.x * chopDistance, 0, blockPosition.z + dir.y * chopDistance)
    }

    private func facingBlock() -> Float {
        atan2(blockPosition.x - position.x, blockPosition.z - position.z)
    }

    /// Holder målet innenfor lysningen og utenfor stabben og vedstabelen.
    private func keepClear(_ p: SIMD3<Float>) -> SIMD3<Float> {
        var q = SIMD3<Float>(p.x, 0, p.z)
        let fromCenter = SIMD2<Float>(q.x, q.z)
        if simd_length(fromCenter) > forestRadius {
            let c = simd_normalize(fromCenter) * forestRadius
            q = SIMD3(c.x, 0, c.y)
        }
        for (center, radius) in [(blockPosition, Float(0.6)), (pilePosition, Float(0.95))] {
            let d = SIMD2<Float>(q.x - center.x, q.z - center.z)
            let len = simd_length(d)
            if len < radius {
                let dir = len < 0.01 ? SIMD2<Float>(0, 1) : d / len
                q = SIMD3(center.x + dir.x * radius, 0, center.z + dir.y * radius)
            }
        }
        return q
    }

    private func flatDistance(_ a: SIMD3<Float>, _ b: SIMD3<Float>) -> Float {
        simd_length(SIMD2<Float>(a.x - b.x, a.z - b.z))
    }

    // MARK: Hugging

    private func startChop() {
        if chopTime != nil {
            chopQueued = true
            return
        }
        chopTime = 0
        hitDone = false
    }

    private func axeHit() {
        let atBlock = abs(flatDistance(position, blockPosition) - chopDistance) < 0.25
        guard atBlock, let log else {
            sound.play(.whoosh, volume: 0.7)
            return
        }
        logHits += 1
        sound.play(.chop)
        sound.buzz()
        burstChips(at: log.position + [0, 0.16, 0])
        log.scale = [1.08, 0.86, 1.08]
        after(0.09) { [weak log] in log?.scale = [1, 1, 1] }
        if logHits >= hitsNeeded {
            split(log)
        }
    }

    private func dropLog() {
        guard log == nil, !logIncoming, reserved + 2 <= pileCapacity else { return }
        logIncoming = true
        let newLog = Make.log()
        let start = blockPosition + [0, 4.5, 0]
        let end = blockPosition + [0, logRestY, 0]
        newLog.position = start
        world.addChild(newLog)
        let g: Float = 14
        let duration = sqrt(2 * (start.y - end.y) / g)
        launch(newLog, velocity: .zero, gravity: g, duration: duration, target: end) { [weak self, weak newLog] in
            guard let self, let newLog else { return }
            self.log = newLog
            self.logIncoming = false
            self.logHits = 0
            self.sound.play(.land)
            self.sound.buzz(strong: true)
            newLog.scale = [1.1, 0.85, 1.1]
            self.after(0.1) { [weak newLog] in newLog?.scale = [1, 1, 1] }
        }
    }

    private func split(_ log: Entity) {
        self.log = nil
        sound.play(.split)
        sound.buzz(strong: true)
        let origin = log.position
        log.removeFromParent()

        for side in [Float(-1), 1] {
            let half = Make.piece()
            half.position = origin + [side * 0.1, 0, 0]
            half.orientation = rotX(.pi / 2)
            world.addChild(half)
            let slot = reserved
            reserved += 1
            let end = pileSlot(slot)
            let duration: Float = 0.9 + (side > 0 ? 0.12 : 0)
            let g: Float = 12
            var v = (end - half.position) / duration
            v.y = (end.y - half.position.y + 0.5 * g * duration * duration) / duration
            launch(half, velocity: v, gravity: g, duration: duration, target: end,
                   spin: [side * 9, 0, side * 5]) { [weak self, weak half] in
                guard let self, let half else { return }
                half.orientation = simd_quatf(angle: 0, axis: [0, 1, 0])
                self.landPiece(half)
            }
        }
        if reserved + 2 <= pileCapacity {
            after(0.7) { [weak self] in self?.dropLog() }
        }
    }

    private func pileSlot(_ index: Int) -> SIMD3<Float> {
        var row = 0
        var rowStart = 0
        var rowCount = 5
        while index >= rowStart + rowCount && rowCount > 1 {
            rowStart += rowCount
            rowCount -= 1
            row += 1
        }
        let i = Float(index - rowStart)
        let x = (i - Float(rowCount - 1) / 2) * 0.22
        let y = 0.08 + 0.1 + Float(row) * 0.185
        return pilePosition + [x, y, 0]
    }

    private func landPiece(_ piece: Entity) {
        pile.append(piece)
        sound.play(.stack)
        piece.scale = [1.15, 1.15, 1.15]
        after(0.1) { [weak piece] in piece?.scale = [1, 1, 1] }
        if pile.count >= pileCapacity {
            after(0.3) { [weak self] in self?.pileFull() }
        }
    }

    /// Full stabel: Lowe hopper av glede, det regner konfetti, og stabelen tømmes.
    private func pileFull() {
        sound.play(.cheer)
        cheerTime = 0
        let colors = [Colors.turquoise, Colors.ink, Colors.white, Colors.sun]
        for i in 0..<36 {
            let bit = Make.part(Make.box(0.07, 0.015, 0.05), colors[i % colors.count], in: world)
            bit.position = pilePosition + [0, 0.8, 0]
            launch(bit, velocity: [Float.random(in: -2.5...2.5), Float.random(in: 4...7), Float.random(in: -2.5...2.5)],
                   gravity: 7, duration: 1.6, target: nil,
                   spin: [Float.random(in: -10...10), Float.random(in: -10...10), 0])
        }
        after(1.6) { [weak self] in self?.clearPile() }
    }

    private func clearPile() {
        for (i, piece) in pile.enumerated() {
            let v: SIMD3<Float> = [Float.random(in: -1.5...1.5), Float.random(in: 5...7), Float.random(in: -2.5 ... -1)]
            after(Float(i) * 0.04) { [weak self, weak piece] in
                guard let self, let piece else { return }
                self.launch(piece, velocity: v, gravity: 9, duration: 0.9, target: nil, spin: [6, 0, 4])
            }
        }
        pile.removeAll()
        reserved = 0
        after(0.8) { [weak self] in self?.dropLog() }
    }

    private func burstChips(at p: SIMD3<Float>) {
        for _ in 0..<6 {
            let chip = Make.part(Make.box(0.06, 0.03, 0.04), Colors.wood, in: world)
            chip.position = p
            launch(chip, velocity: [Float.random(in: -1.8...1.8), Float.random(in: 2...3.5), Float.random(in: -1.8...1.8)],
                   gravity: 10, duration: 0.7, target: nil,
                   spin: [Float.random(in: -14...14), Float.random(in: -14...14), 0])
        }
    }

    // MARK: Hver ramme

    private func tick(_ dt: Float) {
        time += dt
        runTimers()
        followFinger()
        moveLowe(dt)

        var chop: Float?
        if var c = chopTime {
            c += dt / 0.55
            if c >= 0.6 && !hitDone {
                hitDone = true
                axeHit()
            }
            if c >= 1 {
                chopTime = nil
                if chopQueued && target == nil {
                    chopQueued = false
                    startChop()
                }
            } else {
                chopTime = c
                chop = c
            }
        }
        var cheer: Float?
        if let c = cheerTime {
            let next = c + dt / 0.8
            cheerTime = next < 1 ? next : nil
            cheer = cheerTime
        }

        lowe.root.position = position
        lowe.root.orientation = rotY(yaw)
        lowe.pose(walkPhase: walkPhase, walk: walkAmount, chop: chop, cheer: cheer, time: time)

        updateFlyers(dt)
        updateCamera(dt: dt)
        if let marker, marker.isEnabled {
            let s = 1 + 0.15 * sin(time * 8)
            marker.scale = [s, 1, s]
        }
    }

    private func moveLowe(_ dt: Float) {
        var moving: Float = 0
        if let goal = target {
            var delta = goal - position
            delta.y = 0
            let distance = simd_length(delta)
            if holdLocation != nil && distance < 0.25 {
                // Fingeren er rett ved Lowe: han blir stående og venter.
            } else if distance < 0.03 {
                position = goal
                target = nil
                marker?.isEnabled = false
                if chopWhenArrived {
                    chopWhenArrived = false
                    yawGoal = facingBlock()
                    startChop()
                }
            } else {
                position += delta / distance * min(distance, walkSpeed * dt)
                yawGoal = atan2(delta.x, delta.z)
                moving = 1
            }
        }
        var turn = yawGoal - yaw
        turn = atan2(sin(turn), cos(turn))
        yaw += turn * min(1, dt * 12)

        walkAmount += (moving - walkAmount) * min(1, dt * 10)
        walkPhase += dt * 10 * walkAmount
    }

    private func updateCamera(dt: Float) {
        let focus = position + [0, 0.6, 0]
        cameraFocus += (focus - cameraFocus) * min(1, dt * 3)
        camera.look(at: cameraFocus, from: cameraFocus + cameraOffset, relativeTo: nil)
    }

    private func launch(_ entity: Entity, velocity: SIMD3<Float>, gravity: Float, duration: Float,
                        target: SIMD3<Float>?, spin: SIMD3<Float> = .zero, onEnd: (() -> Void)? = nil) {
        flyers.append(Flyer(entity: entity, velocity: velocity, gravity: gravity, spin: spin,
                            duration: duration, target: target, onEnd: onEnd))
    }

    private func updateFlyers(_ dt: Float) {
        var finished: [Flyer] = []
        for i in flyers.indices.reversed() {
            var f = flyers[i]
            f.age += dt
            f.velocity.y -= f.gravity * dt
            f.entity.position += f.velocity * dt
            if f.spin != .zero {
                let angle = simd_length(f.spin) * dt
                f.entity.orientation = simd_quatf(angle: angle, axis: simd_normalize(f.spin)) * f.entity.orientation
            }
            if f.target == nil && f.age > f.duration * 0.6 {
                let fade = max(0.01, 1 - (f.age - f.duration * 0.6) / (f.duration * 0.4))
                f.entity.scale = [fade, fade, fade]
            }
            if f.age >= f.duration {
                flyers.remove(at: i)
                finished.append(f)
            } else {
                flyers[i] = f
            }
        }
        for f in finished {
            if let end = f.target {
                f.entity.position = end
            } else {
                f.entity.removeFromParent()
            }
            f.onEnd?()
        }
    }

    // MARK: Tidtaker

    /// Kjører noe litt senere, i takt med spillet.
    private func after(_ delay: Float, _ action: @escaping () -> Void) {
        timers.append((time + delay, action))
    }

    private func runTimers() {
        let due = timers.filter { $0.time <= time }
        guard !due.isEmpty else { return }
        timers.removeAll { $0.time <= time }
        due.forEach { $0.action() }
    }
}
