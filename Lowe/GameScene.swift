import SpriteKit

/// Hovedskjermen: Lowe hugger kubber, veden flyr til stabelen, og når stabelen er full
/// henter dagens dyr veden. Etter hver levering lyser en ny hytte opp i landsbyen.
/// Ingen tekst, ingen tall, ingen måte å tape på.
final class GameScene: SKScene {
    static func make() -> GameScene {
        let scene = GameScene(size: CGSize(width: 1180, height: 820))
        scene.scaleMode = .resizeFill
        return scene
    }

    // Området som alltid skal synes, i designkoordinater. Resten fylles av bakgrunnen.
    private let focus = CGRect(x: 80, y: 240, width: 1100, height: 509)
    private let logTop = CGPoint(x: 575, y: 500)
    private let visitorHome = CGPoint(x: 772, y: 652)
    private let slots: [CGPoint] = {
        var points: [CGPoint] = []
        for i in 0..<5 { points.append(CGPoint(x: 870 + CGFloat(i) * 60, y: 620)) }
        for i in 0..<4 { points.append(CGPoint(x: 900 + CGFloat(i) * 60, y: 562)) }
        for i in 0..<3 { points.append(CGPoint(x: 930 + CGFloat(i) * 60, y: 504)) }
        return points
    }()

    private let world = SKNode()
    private let lowe = LoweNode()
    private let visitor = SKNode()
    private let hint = Shape.node(Shape.ellipse(0, 0, 96, 40), stroke: Palette.turquoise, width: 7)
    private let pauseButton = HoldButton(holdTime: 3)
    private let starJar = StarJar()
    private var pauseMenu: PauseMenu?
    private lazy var feedback: Feedback = {
        let f = Feedback()
        f.scene = self
        return f
    }()

    private var state = SavedGame.load()
    private var built = false
    private var log: LogNode?
    private var pile: [SKNode] = []
    private var reserved = 0
    private var swingLocked = false
    private var celebrating = false
    private var lastInteraction: TimeInterval = 0
    private var village: VillageLayer?
    private var villageShownAt: TimeInterval = 0
    private var villageDone: (() -> Void)?

    private let tempName = "temp"

    // MARK: Oppsett

    override func didMove(to view: SKView) {
        backgroundColor = Palette.sky
        anchorPoint = .zero
        view.isMultipleTouchEnabled = false
        if !built {
            built = true
            feedback.muted = state.muted
            buildWorld()
            restore()
        }
        layoutWorld()
        lastInteraction = CACurrentMediaTime()
    }

    override func didChangeSize(_ oldSize: CGSize) {
        super.didChangeSize(oldSize)
        layoutWorld()
    }

    /// Skalerer designet så `focus` alltid får plass, og snur y-aksen.
    private func layoutWorld() {
        guard size.width > 0, size.height > 0 else { return }
        let s = min(size.width / focus.width, size.height / focus.height)
        world.xScale = s
        world.yScale = -s
        world.position = CGPoint(x: size.width / 2 - s * focus.midX,
                                 y: size.height / 2 + s * focus.midY)

        let insets = view?.safeAreaInsets ?? .zero
        let margin: CGFloat = 20
        pauseButton.position = CGPoint(x: insets.left + margin + pauseButton.radius,
                                       y: size.height - insets.top - margin - pauseButton.radius)
        starJar.position = CGPoint(x: size.width - insets.right - margin - 40,
                                   y: size.height - insets.top - margin - 44)
        pauseMenu?.position = CGPoint(x: size.width / 2, y: size.height / 2)
    }

    private func buildWorld() {
        addChild(world)
        world.addChild(Scenery.build())

        let block = Scenery.choppingBlock()
        block.zPosition = 5
        world.addChild(block)

        visitor.position = visitorHome
        visitor.zPosition = 4
        world.addChild(visitor)

        lowe.position = CGPoint(x: 250, y: 319)
        lowe.setScale(1.15)
        lowe.zPosition = 20
        world.addChild(lowe)

        hint.position = logTop
        hint.zPosition = 15
        hint.alpha = 0
        world.addChild(hint)

        pauseButton.zPosition = 500
        addChild(pauseButton)
        starJar.zPosition = 500
        addChild(starJar)
    }

    /// Henter fram skogen slik Lowe forlot den.
    private func restore() {
        setVisitor(state.visitor)
        starJar.setCount(state.stars % StarJar.capacity)
        let count = min(state.pileCount, slots.count) / 2 * 2
        for i in 0..<count {
            addPileEnd(at: i, animated: false)
        }
        reserved = count
        if count >= slots.count {
            world.run(.sequence([.wait(forDuration: 0.8), .run { [weak self] in self?.celebrate() }]), withKey: "celebrate")
        } else {
            spawnLog(after: 0.5)
        }
    }

    private func setVisitor(_ animal: Animal) {
        visitor.removeAllChildren()
        visitor.addChild(animal.build())
        visitor.xScale = -animal.visitorScale
        visitor.yScale = animal.visitorScale
        visitor.enumerateChildNodes(withName: "//eye") { eye, _ in
            eye.run(.repeatForever(.sequence([
                .wait(forDuration: 3, withRange: 3),
                .scaleY(to: 0.1, duration: 0.06),
                .wait(forDuration: 0.08),
                .scaleY(to: 1, duration: 0.06)
            ])))
        }
    }

    // MARK: Trykk

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first else { return }
        if let menu = pauseMenu {
            menu.handleTap(touch.location(in: menu))
            return
        }
        let p = touch.location(in: self)
        if pauseButton.hitTest(p) {
            pauseButton.beginHold { [weak self] in self?.openPause() }
            return
        }
        lastInteraction = CACurrentMediaTime()
        hideHint()
        if village != nil {
            if CACurrentMediaTime() - villageShownAt > 1.6 { hideVillage() }
            return
        }
        swingAxe()
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        pauseButton.cancelHold()
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        pauseButton.cancelHold()
    }

    private func swingAxe() {
        guard !swingLocked else { return }
        swingLocked = true
        lowe.removeAction(forKey: "swing")
        let start = lowe.swing
        let downTime: CGFloat = 0.09
        let upTime: CGFloat = 0.24
        let down = SKAction.customAction(withDuration: TimeInterval(downTime)) { node, elapsed in
            let t = min(1, elapsed / downTime)
            (node as? LoweNode)?.swing = start + (1 - start) * t * t
        }
        let up = SKAction.customAction(withDuration: TimeInterval(upTime)) { node, elapsed in
            let t = min(1, elapsed / upTime)
            (node as? LoweNode)?.swing = (1 - t) * (1 - t)
        }
        lowe.run(.sequence([
            down,
            .run { [weak self] in self?.axeHit() },
            .wait(forDuration: 0.05),
            .run { [weak self] in self?.swingLocked = false },
            up
        ]), withKey: "swing")
    }

    private func axeHit() {
        guard let log else {
            feedback.play(.whoosh)
            return
        }
        log.hits += 1
        burstChips()
        flashImpact()
        if log.hits >= log.hitsNeeded {
            split(log)
        } else {
            feedback.chop()
            log.updateCrack()
            log.squash()
            if Double.random(in: 0..<1) < 0.2 { spawnPinecone() }
        }
    }

    // MARK: Kubber og vedstabel

    private func spawnLog(after delay: TimeInterval) {
        world.run(.sequence([
            .wait(forDuration: delay),
            .run { [weak self] in self?.dropLog() }
        ]), withKey: "spawn")
    }

    private func dropLog() {
        guard log == nil, !celebrating else { return }
        // Av og til en kjempekubbe: flere slag, og den gir dobbelt så mye ved.
        let giant = reserved <= slots.count - 4 && Double.random(in: 0..<1) < 0.15
        let newLog = LogNode(hitsNeeded: giant ? 6 : Int.random(in: 2...4))
        newLog.position = CGPoint(x: logTop.x, y: logTop.y - 700)
        newLog.zPosition = 10
        newLog.name = tempName
        world.addChild(newLog)
        let drop = SKAction.moveTo(y: logTop.y, duration: giant ? 0.42 : 0.32)
        drop.timingMode = .easeIn
        newLog.run(.sequence([
            drop,
            .run { [weak self, weak newLog] in
                guard let self, let newLog else { return }
                self.log = newLog
                newLog.squash()
                self.feedback.land()
                if giant { self.lowe.cheer() }
                self.lastInteraction = CACurrentMediaTime()
            }
        ]))
    }

    private func split(_ log: LogNode) {
        self.log = nil
        feedback.split()
        let perHalf = log.isGiant ? 2 : 1
        let first = reserved
        reserved += perHalf * 2

        for (i, left) in [true, false].enumerated() {
            let half = log.makeHalf(left: left)
            let offset = log.halfOffset(left: left)
            let origin = CGPoint(x: log.position.x + offset.x, y: log.position.y + offset.y)
            half.position = origin
            half.zPosition = 12
            half.name = tempName
            world.addChild(half)

            let dir: CGFloat = left ? -1 : 1
            let popped = CGPoint(x: origin.x + dir * 34, y: origin.y - 26)
            let pop = SKAction.group([
                .move(to: popped, duration: 0.14),
                .rotate(byAngle: -dir * 0.5, duration: 0.14)
            ])
            pop.timingMode = .easeOut

            let indices = (0..<perHalf).map { first + i * perHalf + $0 }
            let target = slots[min(indices[0], slots.count - 1)]
            let path = CGMutablePath()
            path.move(to: popped)
            path.addQuadCurve(to: target, control: CGPoint(x: (popped.x + target.x) / 2,
                                                           y: min(popped.y, target.y) - 220))
            let fly = SKAction.group([
                .follow(path, asOffset: false, orientToPath: false, duration: 0.55),
                .rotate(byAngle: dir * .pi * 2, duration: 0.55),
                .scale(to: 0.6, duration: 0.55)
            ])
            fly.timingMode = .easeIn

            half.run(.sequence([
                pop,
                .wait(forDuration: 0.06 + Double(i) * 0.08),
                fly,
                .removeFromParent(),
                .run { [weak self] in
                    guard let self else { return }
                    for k in 0..<perHalf {
                        self.world.run(.sequence([
                            .wait(forDuration: Double(k) * 0.1),
                            .run { [weak self] in self?.landPiece() }
                        ]))
                    }
                }
            ]))
        }
        log.removeFromParent()

        if Double.random(in: 0..<1) < 0.25 { spawnSquirrel() }
        if reserved < slots.count {
            spawnLog(after: 0.45)
        }
    }

    /// Hver vedbit som lander legges på neste ledige plass, uansett rekkefølge de kommer i.
    private func landPiece() {
        guard pile.count < slots.count else { return }
        addPileEnd(at: pile.count, animated: true)
        feedback.stack()
        visitorHop()
        state.pileCount = pile.count
        state.save()
        if pile.count >= slots.count {
            celebrate()
        }
    }

    private func addPileEnd(at index: Int, animated: Bool) {
        let end = Scenery.logEnd()
        end.position = slots[index]
        end.zPosition = 6 + CGFloat(index) * 0.01
        world.addChild(end)
        pile.append(end)
        guard animated else { return }
        end.setScale(0.5)
        let grow = SKAction.sequence([.scale(to: 1.12, duration: 0.12), .scale(to: 1, duration: 0.08)])
        grow.timingMode = .easeOut
        end.run(grow)
    }

    // MARK: Feiring, stjerne og levering

    private func celebrate() {
        celebrating = true
        hideHint()
        feedback.celebrate()
        lowe.cheer()
        confetti(from: CGPoint(x: 990, y: 470))

        // Den store stjerna popper opp over stabelen og flyr opp i stjernekrukka.
        let starStart = CGPoint(x: 990, y: 400)
        let star = Scenery.bigStar()
        star.position = starStart
        star.zPosition = 30
        star.setScale(0)
        star.name = tempName
        world.addChild(star)
        star.run(.sequence([
            .group([.scale(to: 1.25, duration: 0.2), .rotate(byAngle: 0.6, duration: 0.2)]),
            .scale(to: 1, duration: 0.1),
            .wait(forDuration: 0.6),
            .removeFromParent(),
            .run { [weak self] in self?.flyStarToJar(from: starStart) }
        ]))

        world.run(.sequence([
            .wait(forDuration: 1.6),
            .run { [weak self] in self?.deliver() }
        ]), withKey: "celebrate")
    }

    private func flyStarToJar(from designPoint: CGPoint) {
        let start = world.convert(designPoint, to: self)
        let star = StarJar.star(radius: 40)
        star.position = start
        star.zPosition = 600
        star.name = tempName
        addChild(star)
        let end = starJar.position
        let path = CGMutablePath()
        path.move(to: start)
        path.addQuadCurve(to: end, control: CGPoint(x: (start.x + end.x) / 2, y: max(start.y, end.y) + 120))
        let fly = SKAction.group([
            .follow(path, asOffset: false, orientToPath: false, duration: 0.7),
            .scale(to: 0.3, duration: 0.7),
            .rotate(byAngle: .pi * 2, duration: 0.7)
        ])
        fly.timingMode = .easeInEaseOut
        star.run(.sequence([
            fly,
            .removeFromParent(),
            .run { [weak self] in
                guard let self else { return }
                self.state.stars += 1
                self.state.save()
                self.feedback.play(.pop)
                if self.starJar.addStar() {
                    self.feedback.celebrate()
                    self.starJar.celebrateFull { }
                }
            }
        ]))
    }

    /// Veden flyr bort til dyret, som drar hjem med den. Så vises landsbyen,
    /// og neste dyr kommer på besøk.
    private func deliver() {
        let animal = state.visitor
        let target = CGPoint(x: visitorHome.x, y: visitorHome.y - 50)
        let step = 0.07
        for (i, end) in pile.reversed().enumerated() {
            end.name = tempName
            let path = CGMutablePath()
            path.move(to: end.position)
            path.addQuadCurve(to: target, control: CGPoint(x: (end.position.x + target.x) / 2,
                                                           y: min(end.position.y, target.y) - 160))
            end.run(.sequence([
                .wait(forDuration: Double(i) * step),
                .group([
                    .follow(path, asOffset: false, orientToPath: false, duration: 0.4),
                    .scale(to: 0.3, duration: 0.4)
                ]),
                .removeFromParent(),
                .run { [weak self] in self?.feedback.play(.stack) }
            ]))
        }
        let waitForWood = Double(pile.count) * step + 0.45
        pile.removeAll()
        reserved = 0

        let hop = SKAction.sequence([.moveBy(x: 0, y: -24, duration: 0.12), .moveBy(x: 0, y: 24, duration: 0.12)])
        let walkBob = SKAction.repeat(.sequence([
            .moveBy(x: 0, y: -8, duration: 0.09), .moveBy(x: 0, y: 8, duration: 0.09)
        ]), count: 6)
        visitor.removeAction(forKey: "hop")
        visitor.run(.sequence([
            .wait(forDuration: waitForWood),
            hop, hop,
            .scaleX(to: animal.visitorScale, duration: 0.08),
            .group([.moveTo(x: 1500, duration: 1.05), walkBob]),
            .run { [weak self] in self?.finishDelivery(of: animal) }
        ]), withKey: "walk")
    }

    private func finishDelivery(of animal: Animal) {
        state.deliveries += 1
        state.pileCount = 0
        state.save()
        let isNewHome = state.deliveries <= Animal.allCases.count
        showVillage(newHome: isNewHome ? animal : nil) { [weak self] in
            self?.nextVisitorArrives()
        }
    }

    private func nextVisitorArrives() {
        setVisitor(state.visitor)
        visitor.position = CGPoint(x: 1500, y: visitorHome.y)
        let walkBob = SKAction.repeat(.sequence([
            .moveBy(x: 0, y: -8, duration: 0.09), .moveBy(x: 0, y: 8, duration: 0.09)
        ]), count: 6)
        visitor.run(.sequence([
            .group([.moveTo(x: visitorHome.x, duration: 1.05), walkBob]),
            .run { [weak self] in
                guard let self else { return }
                self.visitor.position = self.visitorHome
                self.celebrating = false
                self.spawnLog(after: 0.1)
            }
        ]), withKey: "walk")
    }

    // MARK: Landsbyen

    private func showVillage(newHome: Animal?, completion: @escaping () -> Void) {
        let builtBefore = state.homesBuilt - (newHome == nil ? 0 : 1)
        let layer = VillageLayer(built: builtBefore)
        layer.zPosition = 100
        layer.alpha = 0
        world.addChild(layer)
        village = layer
        villageDone = completion
        villageShownAt = CACurrentMediaTime()
        layer.run(.sequence([
            .fadeIn(withDuration: 0.6),
            .run { [weak self, weak layer] in
                guard let newHome, let layer else { return }
                self?.feedback.celebrate()
                layer.reveal(newHome)
            },
            .wait(forDuration: 3.4),
            .run { [weak self] in self?.hideVillage() }
        ]), withKey: "show")
    }

    private func hideVillage() {
        guard let layer = village else { return }
        village = nil
        layer.removeAction(forKey: "show")
        layer.run(.sequence([.fadeOut(withDuration: 0.5), .removeFromParent()]))
        let done = villageDone
        villageDone = nil
        world.run(.sequence([.wait(forDuration: 0.5), .run { done?() }]))
    }

    // MARK: Pause og foreldremeny

    private func openPause() {
        guard pauseMenu == nil else { return }
        world.isPaused = true
        hideHint()
        let menu = PauseMenu(size: size, muted: state.muted)
        menu.position = CGPoint(x: size.width / 2, y: size.height / 2)
        menu.zPosition = 1000
        menu.onChoice = { [weak self] choice in self?.handlePause(choice) }
        addChild(menu)
        pauseMenu = menu
        pauseButton.isHidden = true
    }

    private func handlePause(_ choice: PauseMenu.Choice) {
        switch choice {
        case .resume:
            closePause()
        case .toggleSound:
            state.muted.toggle()
            state.save()
            feedback.muted = state.muted
            pauseMenu?.setMuted(state.muted)
        case .reset:
            closePause()
            resetProgress()
        }
    }

    private func closePause() {
        pauseMenu?.removeFromParent()
        pauseMenu = nil
        world.isPaused = false
        pauseButton.isHidden = false
        lastInteraction = CACurrentMediaTime()
    }

    /// Starter skogen helt på nytt: tom stabel, ingen hytter, tom krukke, pinnsvinet først.
    private func resetProgress() {
        world.removeAllActions()
        for node in world.children where node.name == tempName { node.removeFromParent() }
        for node in children where node.name == tempName { node.removeFromParent() }
        log = nil
        pile.forEach { $0.removeFromParent() }
        pile.removeAll()
        reserved = 0
        village?.removeFromParent()
        village = nil
        villageDone = nil
        visitor.removeAllActions()
        visitor.position = visitorHome
        celebrating = false
        swingLocked = false

        let muted = state.muted
        state = SavedGame()
        state.muted = muted
        state.save()
        setVisitor(state.visitor)
        starJar.removeAllActions()
        starJar.setScale(1)
        starJar.zRotation = 0
        starJar.setCount(0)
        spawnLog(after: 0.6)
    }

    // MARK: Dyret ved stabelen

    private func visitorHop() {
        guard visitor.action(forKey: "walk") == nil, visitor.action(forKey: "hop") == nil else { return }
        visitor.run(.sequence([
            .moveBy(x: 0, y: -16, duration: 0.1),
            .moveBy(x: 0, y: 16, duration: 0.12)
        ]), withKey: "hop")
    }

    // MARK: Overraskelser

    /// Et ekorn hopper ut av kubben og løper sin vei.
    private func spawnSquirrel() {
        let squirrel = Scenery.squirrel()
        let dir: CGFloat = Bool.random() ? -1 : 1
        squirrel.name = tempName
        squirrel.position = CGPoint(x: logTop.x, y: logTop.y)
        squirrel.zPosition = 22
        squirrel.xScale = 0.1 * dir
        squirrel.yScale = 0.1
        world.addChild(squirrel)
        feedback.play(.squeak)

        let up = SKAction.group([
            .moveBy(x: 0, y: -70, duration: 0.18),
            .scaleX(to: dir, duration: 0.18),
            .scaleY(to: 1, duration: 0.18)
        ])
        up.timingMode = .easeOut
        let landing = CGPoint(x: logTop.x + dir * 140, y: 652)
        let arc = CGMutablePath()
        arc.move(to: CGPoint(x: logTop.x, y: logTop.y - 70))
        arc.addQuadCurve(to: landing, control: CGPoint(x: logTop.x + dir * 70, y: logTop.y - 150))
        let hops = SKAction.repeat(.sequence([
            .moveBy(x: dir * 60, y: -28, duration: 0.12),
            .moveBy(x: dir * 60, y: 28, duration: 0.12)
        ]), count: 8)
        squirrel.run(.sequence([
            up,
            .follow(arc, asOffset: false, orientToPath: false, duration: 0.35),
            hops,
            .removeFromParent()
        ]))
    }

    /// En kongle spretter av kubben og triller bortover snøen.
    private func spawnPinecone() {
        let cone = Scenery.pinecone()
        let dir: CGFloat = Bool.random() ? -1 : 1
        cone.name = tempName
        cone.position = CGPoint(x: logTop.x + dir * 20, y: logTop.y - 10)
        cone.zPosition = 22
        world.addChild(cone)
        feedback.play(.pop)

        var x = cone.position.x
        var y = cone.position.y
        var steps: [SKAction] = []
        let bounces: [(CGFloat, CGFloat, TimeInterval)] = [(120, 140, 0.45), (80, 50, 0.3), (45, 20, 0.2)]
        for (distance, height, time) in bounces {
            let path = CGMutablePath()
            path.move(to: CGPoint(x: x, y: y))
            let nx = x + dir * distance
            path.addQuadCurve(to: CGPoint(x: nx, y: 648), control: CGPoint(x: (x + nx) / 2, y: min(y, 648) - height))
            steps.append(.follow(path, asOffset: false, orientToPath: false, duration: time))
            x = nx
            y = 648
        }
        steps.append(.moveBy(x: dir * 50, y: 0, duration: 0.4))
        steps.append(.fadeOut(withDuration: 0.3))
        steps.append(.removeFromParent())
        cone.run(.group([.sequence(steps), .rotate(byAngle: -dir * 14, duration: 1.65)]))
    }

    // MARK: Effekter

    private func burstChips() {
        for _ in 0..<Int.random(in: 4...6) {
            let chip = Shape.node(Shape.rect(-7, -4, 14, 8, r: 2), fill: Palette.wood, stroke: Palette.bark, width: 2.5)
            chip.position = CGPoint(x: logTop.x + .random(in: -24...24), y: logTop.y - 6)
            chip.zPosition = 25
            chip.name = tempName
            world.addChild(chip)
            fling(chip,
                  velocity: CGVector(dx: .random(in: -340...340), dy: .random(in: -640 ... -380)),
                  gravity: 1800, duration: 0.8, spin: .random(in: -12...12))
        }
    }

    private func flashImpact() {
        let star = Scenery.impactStar()
        star.position = CGPoint(x: logTop.x + 15, y: logTop.y - 10)
        star.zPosition = 18
        star.setScale(0.5)
        star.name = tempName
        world.addChild(star)
        star.run(.sequence([
            .group([.scale(to: 1.1, duration: 0.08), .fadeAlpha(to: 1, duration: 0.08)]),
            .group([.scale(to: 1.3, duration: 0.14), .fadeOut(withDuration: 0.14)]),
            .removeFromParent()
        ]))

        for d in ["M470 330 Q560 340 620 420", "M500 300 Q600 316 660 400"] {
            let arc = Shape.svg(d, stroke: Palette.white, width: 7)
            arc.zPosition = 19
            arc.alpha = 0.9
            arc.name = tempName
            world.addChild(arc)
            arc.run(.sequence([.fadeOut(withDuration: 0.2), .removeFromParent()]))
        }
    }

    private func confetti(from origin: CGPoint) {
        let colors = [Palette.turquoise, Palette.ink, Palette.white, Palette.sun]
        for i in 0..<40 {
            let piece = Shape.node(Shape.rect(-8, -5, 16, 10, r: 2), fill: colors[i % colors.count],
                                   stroke: Palette.ink, width: 2)
            piece.position = origin
            piece.zPosition = 40
            piece.name = tempName
            world.addChild(piece)
            fling(piece,
                  velocity: CGVector(dx: .random(in: -560...560), dy: .random(in: -1000 ... -520)),
                  gravity: 1300, duration: 1.7, spin: .random(in: -10...10))
        }
    }

    /// Kaster en node i en bue og fjerner den etterpå. Designkoordinater: negativ dy er opp.
    private func fling(_ node: SKNode, velocity v: CGVector, gravity g: CGFloat, duration: TimeInterval, spin: CGFloat) {
        let p0 = node.position
        let move = SKAction.customAction(withDuration: duration) { n, elapsed in
            let t = elapsed
            n.position = CGPoint(x: p0.x + v.dx * t, y: p0.y + v.dy * t + 0.5 * g * t * t)
            n.zRotation = spin * t
        }
        node.run(.sequence([
            .group([move, .sequence([.wait(forDuration: duration * 0.6), .fadeOut(withDuration: duration * 0.4)])]),
            .removeFromParent()
        ]))
    }

    // MARK: Hint

    override func update(_ currentTime: TimeInterval) {
        guard log != nil, !celebrating, village == nil, pauseMenu == nil,
              hint.action(forKey: "pulse") == nil else { return }
        if CACurrentMediaTime() - lastInteraction > 4 {
            showHint()
        }
    }

    /// En turkis ring som pulserer rundt kubben når Lowe ikke har trykket på en stund.
    private func showHint() {
        hint.setScale(1)
        hint.alpha = 0
        hint.run(.repeatForever(.sequence([
            .group([.fadeAlpha(to: 0.9, duration: 0.5), .scale(to: 1.12, duration: 0.5)]),
            .group([.fadeAlpha(to: 0.25, duration: 0.5), .scale(to: 1, duration: 0.5)])
        ])), withKey: "pulse")
    }

    private func hideHint() {
        hint.removeAction(forKey: "pulse")
        hint.alpha = 0
        hint.setScale(1)
    }
}
