import Combine
import RealityKit
import UIKit

/// Skogen i 3D. Spaken til venstre får Lowe til å gå, dra til høyre snur kameraet,
/// og knappene hugger og hopper. Tre hogg deler kubben, og vedstykkene flyr til stabelen.
/// Trærne rundt kan felles, og stokkene triller til stabben. Selve skogen ligger i Woods.
@MainActor
final class Forest: NSObject {
    private weak var view: ARView?
    private let world = AnchorEntity(world: .zero)
    private let camera = PerspectiveCamera()
    private let lowe = LoweFigure()
    private let sound = Sound()
    private let controls = ControlsView()
    private var updateSubscription: Cancellable?
    private var woods: Woods!

    private let blockPosition = SIMD3<Float>(0, 0, 0)
    private let pilePosition = SIMD3<Float>(2.3, 0, -0.7)
    private let logRestY: Float = 0.57
    private let chopDistance: Float = 0.8
    private let hitsNeeded = 3
    private let pileCapacity = 12
    private let walkSpeed: Float = 2.2

    // Lowe
    private var position = SIMD3<Float>(0, 0, 2.4)
    private var yaw: Float = .pi
    private var yawGoal: Float = .pi
    private var target: SIMD3<Float>?
    private var chopWhenArrived = false
    /// Treet Lowe hugger i, når han ikke står ved stabben.
    private var chopTree: Int?
    private var jumpHeight: Float = 0
    private var jumpSpeed: Float = 0
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
    /// Stokker fra felte trær som ligger ved stabben og venter på tur.
    private var waitingLogs: [Entity] = []
    private var pile: [Entity] = []
    private var reserved = 0

    // Dyret som venter ved vedstabelen
    private var visitor: Entity?
    private var visitorAnimal: Animal = .hedgehog
    private var visitorGoal: SIMD3<Float>?
    private var visitorArrived: (() -> Void)?
    private var visitorWaiting = false
    private var visitorYaw: Float = 0
    private var visitorPhase: Float = 0
    private var visitorHopTime: Float?
    /// Hvor mange stabler som er hentet til sammen. Huskes mellom gangene, så neste dyr kommer.
    private var deliveries = UserDefaults.standard.integer(forKey: "lowe.deliveries")
    private let visitorHome = SIMD3<Float>(9, 0, -8)
    private var waitSpot: SIMD3<Float> { pilePosition + [0.95 + visitorAnimal.size, 0, 0.5] }

    private var flyers: [Flyer] = []
    private var timers: [(time: Float, action: () -> Void)] = []
    private var time: Float = 0
    private var cameraFocus = SIMD3<Float>(0, 0.6, 2.4)
    /// Kameraet går i en kule rundt Lowe. Vinkel 0 betyr at det står bak ham mot +z.
    private var cameraYaw: Float = 0
    private var cameraPitch: Float = 0.5
    private let cameraDistance: Float = 6.4

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

        controls.frame = view.bounds
        controls.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        view.addSubview(controls)
        controls.onLook = { [weak self] dx, dy in self?.look(dx: Float(dx), dy: Float(dy)) }
        controls.onChop = { [weak self] in self?.chopPressed() }
        controls.onJump = { [weak self] in self?.jump() }
        controls.setCones(found: 0, total: 10)

        updateSubscription = view.scene.subscribe(to: SceneEvents.Update.self) { [weak self] event in
            let dt = Float(min(event.deltaTime, 1.0 / 20))
            MainActor.assumeIsolated {
                self?.tick(dt)
            }
        }
        after(0.6) { [weak self] in self?.dropLog() }
        after(1.2) { [weak self] in self?.visitorArrives() }
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

        Make.part(.generatePlane(width: 90, depth: 90), Colors.snow, in: world)

        woods = Woods(world: world, sound: sound, logArrivalSpot: blockPosition + [-1.1, 0, 0.2])
        woods.onLogArrived = { [weak self] log in self?.logArrived(log) }
        woods.onConeFound = { [weak self] found, total in self?.controls.setCones(found: found, total: total) }
        woods.onAllConesFound = { [weak self] in
            guard let self else { return }
            self.sound.play(.cheer)
            self.cheerTime = 0
            self.confetti(at: self.position + [0, 1.4, 0])
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

        lowe.root.position = position
        world.addChild(lowe.root)
        updateCamera(dt: 1)
    }

    // MARK: Styring

    private func look(dx: Float, dy: Float) {
        cameraYaw -= dx * 0.009
        cameraPitch = min(1.15, max(0.15, cameraPitch + dy * 0.005))
    }

    private func jump() {
        guard jumpHeight <= 0.001 else { return }
        jumpSpeed = 4.2
        sound.play(.whoosh, volume: 0.4)
    }

    /// Øksa svinges alltid. Står Lowe nær stabben, tar han et steg bort til den og hugger kubben.
    /// Står han nær et tre, går han bort til treet og hugger i det.
    private func chopPressed() {
        guard jumpHeight <= 0.001 else { return }
        if flatDistance(position, blockPosition) < 1.7 {
            chopTree = nil
            walkThenChop(to: chopSpot(), facing: blockPosition)
        } else if let tree = woods.nearestTree(to: position, within: 1.9) {
            chopTree = tree
            walkThenChop(to: woods.chopSpot(forTree: tree, from: position), facing: woods.treePosition(tree))
        } else {
            chopTree = nil
            startChop()
        }
    }

    private func walkThenChop(to spot: SIMD3<Float>, facing point: SIMD3<Float>) {
        if flatDistance(position, spot) < 0.15 {
            yawGoal = facing(point)
            startChop()
        } else {
            target = spot
            chopWhenArrived = true
        }
    }

    private func facing(_ point: SIMD3<Float>) -> Float {
        atan2(point.x - position.x, point.z - position.z)
    }

    /// Plassen foran stabben, på den siden Lowe står.
    private func chopSpot() -> SIMD3<Float> {
        var dir = SIMD2<Float>(position.x - blockPosition.x, position.z - blockPosition.z)
        if simd_length(dir) < 0.01 { dir = [0, 1] }
        dir = simd_normalize(dir)
        return SIMD3(blockPosition.x + dir.x * chopDistance, 0, blockPosition.z + dir.y * chopDistance)
    }

    /// Retningen Lowe skal se når han har gått fram for å hugge.
    private func chopFacing() -> Float {
        if let tree = chopTree { return facing(woods.treePosition(tree)) }
        return facing(blockPosition)
    }

    /// Holder målet innenfor lysningen og utenfor stabben og vedstabelen.
    private func keepClear(_ p: SIMD3<Float>) -> SIMD3<Float> {
        var q = SIMD3<Float>(p.x, 0, p.z)
        let fromCenter = SIMD2<Float>(q.x, q.z)
        if simd_length(fromCenter) > woods.radius {
            let c = simd_normalize(fromCenter) * woods.radius
            q = SIMD3(c.x, 0, c.y)
        }
        var obstacles: [(SIMD3<Float>, Float)] = [(blockPosition, 0.6), (pilePosition, 0.95)]
        if let visitor { obstacles.append((visitor.position, visitorAnimal.size + 0.3)) }
        obstacles += woods.obstacles(near: q)
        for (center, radius) in obstacles {
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
        if let tree = chopTree, woods.canHit(tree: tree, from: position) {
            sound.play(.chop)
            sound.buzz()
            burstChips(at: woods.treePosition(tree) + [0, 0.55, 0])
            woods.hit(tree: tree, from: position)
            return
        }
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

    /// Ny kubbe på stabben: først stokker fra felte trær, ellers faller en ned fra himmelen.
    private func dropLog() {
        guard log == nil, !logIncoming, reserved + 2 <= pileCapacity else { return }
        logIncoming = true
        let end = blockPosition + [0, logRestY, 0]
        if !waitingLogs.isEmpty {
            let lying = waitingLogs.removeFirst()
            arrangeWaitingLogs()
            let d: Float = 0.55
            let g: Float = 12
            var v = (end - lying.position) / d
            v.y = (end.y - lying.position.y + 0.5 * g * d * d) / d
            launch(lying, velocity: v, gravity: g, duration: d, target: end, spin: [0, 0, 6]) { [weak self, weak lying] in
                lying?.removeFromParent()
                guard let self else { return }
                let newLog = Make.log()
                newLog.position = end
                self.world.addChild(newLog)
                self.logLanded(newLog)
            }
            return
        }
        let newLog = Make.log()
        let start = blockPosition + [0, 4.5, 0]
        newLog.position = start
        world.addChild(newLog)
        let g: Float = 14
        let duration = sqrt(2 * (start.y - end.y) / g)
        launch(newLog, velocity: .zero, gravity: g, duration: duration, target: end) { [weak self, weak newLog] in
            guard let self, let newLog else { return }
            self.logLanded(newLog)
        }
    }

    private func logLanded(_ newLog: Entity) {
        log = newLog
        logIncoming = false
        logHits = 0
        sound.play(.land)
        sound.buzz(strong: true)
        newLog.scale = [1.1, 0.85, 1.1]
        after(0.1) { [weak newLog] in newLog?.scale = [1, 1, 1] }
    }

    /// En stokk fra et felt tre har trillet fram og legges ved siden av stabben.
    private func logArrived(_ lying: Entity) {
        lying.orientation = rotY(0)
        waitingLogs.append(lying)
        arrangeWaitingLogs()
        sound.play(.stack, volume: 0.7)
        dropLog()
    }

    private func arrangeWaitingLogs() {
        for (i, lying) in waitingLogs.enumerated() {
            lying.position = blockPosition + [-1.1, 0.17 + Float(i / 3) * 0.32, 0.35 - Float(i % 3) * 0.36]
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
        if visitorWaiting { visitorHopTime = 0 }
        if pile.count >= pileCapacity {
            after(0.3) { [weak self] in self?.pileFull() }
        }
    }

    /// Full stabel: Lowe hopper av glede, det regner konfetti, og dyret henter veden.
    private func pileFull() {
        sound.play(.cheer)
        cheerTime = 0
        confetti(at: pilePosition + [0, 0.8, 0])
        after(1.4) { [weak self] in self?.deliverWoodIfReady() }
    }

    private func confetti(at p: SIMD3<Float>) {
        let colors = [Colors.turquoise, Colors.ink, Colors.white, Colors.sun]
        for i in 0..<36 {
            let bit = Make.part(Make.box(0.07, 0.015, 0.05), colors[i % colors.count], in: world)
            bit.position = p
            launch(bit, velocity: [Float.random(in: -2.5...2.5), Float.random(in: 4...7), Float.random(in: -2.5...2.5)],
                   gravity: 7, duration: 1.6, target: nil,
                   spin: [Float.random(in: -10...10), Float.random(in: -10...10), 0])
        }
    }

    // MARK: Dyrene

    /// Neste dyr i rekka kommer gående ut av skogen og stiller seg ved vedstabelen.
    private func visitorArrives() {
        guard visitor == nil else { return }
        visitorAnimal = Animal.allCases[deliveries % Animal.allCases.count]
        let animal = visitorAnimal.build()
        animal.position = visitorHome
        world.addChild(animal)
        visitor = animal
        visitorWaiting = false
        walkVisitor(to: waitSpot) { [weak self] in
            guard let self else { return }
            self.visitorWaiting = true
            self.visitorHopTime = 0
            if self.pile.count >= self.pileCapacity {
                self.after(0.4) { [weak self] in self?.deliverWoodIfReady() }
            }
        }
    }

    /// Veden flyr fra stabelen til dyret, som hopper av glede og går hjem med den.
    private func deliverWoodIfReady() {
        guard visitorWaiting, let visitor, pile.count >= pileCapacity else { return }
        visitorWaiting = false
        deliveries += 1
        UserDefaults.standard.set(deliveries, forKey: "lowe.deliveries")

        let target = visitor.position + [0, visitorAnimal.height * 0.6, 0]
        let step: Float = 0.07
        for (i, piece) in pile.enumerated() {
            after(Float(i) * step) { [weak self, weak piece] in
                guard let self, let piece else { return }
                let d: Float = 0.5
                let g: Float = 10
                var v = (target - piece.position) / d
                v.y = (target.y - piece.position.y + 0.5 * g * d * d) / d
                self.launch(piece, velocity: v, gravity: g, duration: d, target: target, spin: [4, 0, 3]) { [weak self, weak piece] in
                    piece?.removeFromParent()
                    self?.sound.play(.stack, volume: 0.6)
                    self?.visitorHopTime = 0
                }
            }
        }
        let woodTime = Float(pile.count) * step + 0.6
        pile.removeAll()
        reserved = 0
        after(woodTime + 0.6) { [weak self] in self?.visitorLeaves() }
        after(0.8) { [weak self] in self?.dropLog() }
    }

    private func visitorLeaves() {
        walkVisitor(to: visitorHome) { [weak self] in
            guard let self else { return }
            self.visitor?.removeFromParent()
            self.visitor = nil
            self.after(1.0) { [weak self] in self?.visitorArrives() }
        }
    }

    private func walkVisitor(to goal: SIMD3<Float>, then arrived: @escaping () -> Void) {
        visitorGoal = goal
        visitorArrived = arrived
    }

    private func updateVisitor(_ dt: Float) {
        guard let visitor else { return }
        var moving = false
        if let goal = visitorGoal {
            var delta = goal - visitor.position
            delta.y = 0
            let distance = simd_length(delta)
            if distance < 0.03 {
                visitor.position = goal
                visitorGoal = nil
                let done = visitorArrived
                visitorArrived = nil
                done?()
            } else {
                visitor.position += delta / distance * min(distance, 1.8 * dt)
                visitorYaw = turn(visitorYaw, toward: atan2(delta.x, delta.z), by: dt * 8)
                moving = true
            }
        } else {
            // Mens det venter, følger dyret Lowe med blikket.
            let toLowe = position - visitor.position
            visitorYaw = turn(visitorYaw, toward: atan2(toLowe.x, toLowe.z), by: dt * 4)
        }
        visitor.orientation = rotY(visitorYaw)

        var lift: Float = 0
        if moving {
            visitorPhase += dt * 12
            lift = abs(sin(visitorPhase)) * visitorAnimal.bounce * 2
        }
        if let hop = visitorHopTime {
            let t = hop + dt / 0.35
            visitorHopTime = t < 1 ? t : nil
            lift += sin(Float.pi * min(1, t)) * 0.22
        }
        visitor.findEntity(named: "body")?.position.y = lift
    }

    private func turn(_ angle: Float, toward goal: Float, by amount: Float) -> Float {
        var d = goal - angle
        d = atan2(sin(d), cos(d))
        return angle + d * min(1, amount)
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

        lowe.root.position = position + [0, jumpHeight, 0]
        lowe.root.orientation = rotY(yaw)
        lowe.pose(walkPhase: walkPhase, walk: walkAmount, chop: chop, cheer: cheer, time: time)

        updateVisitor(dt)
        updateFlyers(dt)
        updateCamera(dt: dt)
        woods.update(dt, lowe: position, camera: camera.position(relativeTo: nil))
    }

    private func moveLowe(_ dt: Float) {
        var speed: Float = 0
        let stick = controls.move
        let push = min(1, simd_length(stick))
        if push > 0.12 {
            // Spaken styrer ut fra hvor kameraet ser: opp på spaken er bort fra kameraet.
            target = nil
            chopWhenArrived = false
            let forward = SIMD2<Float>(-sin(cameraYaw), -cos(cameraYaw))
            let right = SIMD2<Float>(cos(cameraYaw), -sin(cameraYaw))
            let dir = simd_normalize(right * stick.x + forward * stick.y)
            speed = walkSpeed * push
            position += SIMD3(dir.x, 0, dir.y) * speed * dt
            position = keepClear(position)
            yawGoal = atan2(dir.x, dir.y)
        } else if let goal = target {
            var delta = goal - position
            delta.y = 0
            let distance = simd_length(delta)
            if distance < 0.03 {
                position = goal
                target = nil
                if chopWhenArrived {
                    chopWhenArrived = false
                    yawGoal = chopFacing()
                    startChop()
                }
            } else {
                speed = walkSpeed
                position += delta / distance * min(distance, walkSpeed * dt)
                yawGoal = atan2(delta.x, delta.z)
            }
        }
        var turn = yawGoal - yaw
        turn = atan2(sin(turn), cos(turn))
        yaw += turn * min(1, dt * 12)

        if jumpHeight > 0 || jumpSpeed > 0 {
            jumpSpeed -= 12 * dt
            jumpHeight += jumpSpeed * dt
            if jumpHeight <= 0 {
                jumpHeight = 0
                jumpSpeed = 0
                sound.play(.land, volume: 0.35)
            }
        }

        let moving = min(1, speed / walkSpeed) * (jumpHeight > 0 ? 0.3 : 1)
        walkAmount += (moving - walkAmount) * min(1, dt * 10)
        walkPhase += dt * 10 * walkAmount
    }

    private func updateCamera(dt: Float) {
        let focus = position + [0, 0.7, 0]
        cameraFocus += (focus - cameraFocus) * min(1, dt * 5)
        let offset = SIMD3<Float>(sin(cameraYaw) * cos(cameraPitch),
                                  sin(cameraPitch),
                                  cos(cameraYaw) * cos(cameraPitch)) * cameraDistance
        camera.look(at: cameraFocus, from: cameraFocus + offset, relativeTo: nil)
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
