import SpriteKit

/// Hovedskjermen: Love hugger kubber, veden flyr til stabelen, og når stabelen
/// er full henter pinnsvinet veden. Ingen tekst, ingen tall, ingen måte å tape på.
final class GameScene: SKScene {
    static func make() -> GameScene {
        let scene = GameScene(size: CGSize(width: 1180, height: 820))
        scene.scaleMode = .resizeFill
        return scene
    }

    // Området som alltid skal synes, i designkoordinater. Resten fylles av bakgrunnen.
    private let focus = CGRect(x: 80, y: 240, width: 1100, height: 509)
    private let logTop = CGPoint(x: 575, y: 500)
    private let hogHome = CGPoint(x: 772, y: 652)
    private let hogScale: CGFloat = 0.55
    private let slots: [CGPoint] = {
        var points: [CGPoint] = []
        for i in 0..<5 { points.append(CGPoint(x: 870 + CGFloat(i) * 60, y: 620)) }
        for i in 0..<4 { points.append(CGPoint(x: 900 + CGFloat(i) * 60, y: 562)) }
        for i in 0..<3 { points.append(CGPoint(x: 930 + CGFloat(i) * 60, y: 504)) }
        return points
    }()

    private let world = SKNode()
    private let love = LoveNode()
    private let hedgehog = SKNode()
    private let hint = Shape.node(Shape.ellipse(0, 0, 96, 40), stroke: Palette.turquoise, width: 7)
    private lazy var feedback: Feedback = {
        let f = Feedback()
        f.scene = self
        return f
    }()

    private var built = false
    private var log: LogNode?
    private var pile: [SKNode] = []
    private var reserved = 0
    private var swingLocked = false
    private var celebrating = false
    private var lastInteraction: TimeInterval = 0

    // MARK: Oppsett

    override func didMove(to view: SKView) {
        backgroundColor = Palette.sky
        anchorPoint = .zero
        view.isMultipleTouchEnabled = false
        if !built {
            built = true
            buildWorld()
            spawnLog(after: 0.5)
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
    }

    private func buildWorld() {
        addChild(world)
        world.addChild(Scenery.build())

        let block = Scenery.choppingBlock()
        block.zPosition = 5
        world.addChild(block)

        hedgehog.addChild(Hedgehog.build())
        hedgehog.position = hogHome
        hedgehog.xScale = -hogScale
        hedgehog.yScale = hogScale
        hedgehog.zPosition = 4
        world.addChild(hedgehog)
        hedgehogIdle()

        love.position = CGPoint(x: 250, y: 319)
        love.setScale(1.15)
        love.zPosition = 20
        world.addChild(love)

        hint.position = logTop
        hint.zPosition = 15
        hint.alpha = 0
        world.addChild(hint)
    }

    // MARK: Trykk

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        lastInteraction = CACurrentMediaTime()
        hideHint()
        swingAxe()
    }

    private func swingAxe() {
        guard !swingLocked else { return }
        swingLocked = true
        love.removeAction(forKey: "swing")
        let start = love.swing
        let downTime: CGFloat = 0.09
        let upTime: CGFloat = 0.24
        let down = SKAction.customAction(withDuration: TimeInterval(downTime)) { node, elapsed in
            let t = min(1, elapsed / downTime)
            (node as? LoveNode)?.swing = start + (1 - start) * t * t
        }
        let up = SKAction.customAction(withDuration: TimeInterval(upTime)) { node, elapsed in
            let t = min(1, elapsed / upTime)
            (node as? LoveNode)?.swing = (1 - t) * (1 - t)
        }
        love.run(.sequence([
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
        }
    }

    // MARK: Kubber og vedstabel

    private func spawnLog(after delay: TimeInterval) {
        run(.sequence([
            .wait(forDuration: delay),
            .run { [weak self] in self?.dropLog() }
        ]), withKey: "spawn")
    }

    private func dropLog() {
        guard log == nil, !celebrating else { return }
        let newLog = LogNode(hitsNeeded: Int.random(in: 2...4))
        newLog.position = CGPoint(x: logTop.x, y: logTop.y - 700)
        newLog.zPosition = 10
        world.addChild(newLog)
        let drop = SKAction.moveTo(y: logTop.y, duration: 0.32)
        drop.timingMode = .easeIn
        newLog.run(.sequence([
            drop,
            .run { [weak self, weak newLog] in
                guard let self, let newLog else { return }
                self.log = newLog
                newLog.squash()
                self.feedback.land()
                self.lastInteraction = CACurrentMediaTime()
            }
        ]))
    }

    private func split(_ log: LogNode) {
        self.log = nil
        feedback.split()
        let first = reserved
        reserved += 2

        for (i, left) in [true, false].enumerated() {
            let half = log.makeHalf(left: left)
            let offset = log.halfOffset(left: left)
            let origin = CGPoint(x: log.position.x + offset.x, y: log.position.y + offset.y)
            half.position = origin
            half.zPosition = 12
            world.addChild(half)

            let dir: CGFloat = left ? -1 : 1
            let popped = CGPoint(x: origin.x + dir * 34, y: origin.y - 26)
            let pop = SKAction.group([
                .move(to: popped, duration: 0.14),
                .rotate(byAngle: -dir * 0.5, duration: 0.14)
            ])
            pop.timingMode = .easeOut

            let slotIndex = first + i
            let target = slots[min(slotIndex, slots.count - 1)]
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
                .run { [weak self] in self?.landPiece(at: slotIndex) }
            ]))
        }
        log.removeFromParent()

        if reserved < slots.count {
            spawnLog(after: 0.45)
        }
    }

    private func landPiece(at index: Int) {
        guard index < slots.count else { return }
        let end = Scenery.logEnd()
        end.position = slots[index]
        end.zPosition = 6 + CGFloat(index) * 0.01
        end.setScale(0.5)
        world.addChild(end)
        pile.append(end)
        let grow = SKAction.sequence([.scale(to: 1.12, duration: 0.12), .scale(to: 1, duration: 0.08)])
        grow.timingMode = .easeOut
        end.run(grow)
        feedback.stack()
        hedgehogHop()
        if pile.count >= slots.count {
            celebrate()
        }
    }

    // MARK: Feiring og levering

    private func celebrate() {
        celebrating = true
        hideHint()
        feedback.celebrate()
        love.cheer()
        confetti(from: CGPoint(x: 990, y: 470))

        let star = Scenery.bigStar()
        star.position = CGPoint(x: 990, y: 400)
        star.zPosition = 30
        star.setScale(0)
        world.addChild(star)
        star.run(.sequence([
            .group([.scale(to: 1.25, duration: 0.2), .rotate(byAngle: 0.6, duration: 0.2)]),
            .scale(to: 1, duration: 0.1),
            .wait(forDuration: 0.9),
            .group([.scale(to: 0.2, duration: 0.25), .fadeOut(withDuration: 0.25)]),
            .removeFromParent()
        ]))

        run(.sequence([
            .wait(forDuration: 1.4),
            .run { [weak self] in self?.deliver() }
        ]))
    }

    /// Veden flyr bort til pinnsvinet, som drar hjem med den og kommer tilbake.
    private func deliver() {
        let target = CGPoint(x: hogHome.x, y: hogHome.y - 50)
        let step = 0.07
        for (i, end) in pile.reversed().enumerated() {
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
        let away = SKAction.group([.moveTo(x: 1500, duration: 1.05), walkBob])
        let back = SKAction.group([.moveTo(x: hogHome.x, duration: 1.05), walkBob])
        hedgehog.removeAction(forKey: "hop")
        hedgehog.run(.sequence([
            .wait(forDuration: waitForWood),
            hop, hop,
            .scaleX(to: hogScale, duration: 0.08),
            away,
            .wait(forDuration: 0.5),
            .scaleX(to: -hogScale, duration: 0.01),
            back,
            .run { [weak self] in
                guard let self else { return }
                self.celebrating = false
                self.spawnLog(after: 0.1)
            }
        ]), withKey: "walk")
    }

    // MARK: Pinnsvinet

    private func hedgehogIdle() {
        guard let eye = hedgehog.childNode(withName: "//eye") else { return }
        eye.run(.repeatForever(.sequence([
            .wait(forDuration: 3, withRange: 3),
            .scaleY(to: 0.1, duration: 0.06),
            .wait(forDuration: 0.08),
            .scaleY(to: 1, duration: 0.06)
        ])))
    }

    private func hedgehogHop() {
        guard hedgehog.action(forKey: "walk") == nil, hedgehog.action(forKey: "hop") == nil else { return }
        hedgehog.run(.sequence([
            .moveBy(x: 0, y: -16, duration: 0.1),
            .moveBy(x: 0, y: 16, duration: 0.12)
        ]), withKey: "hop")
    }

    // MARK: Effekter

    private func burstChips() {
        for _ in 0..<Int.random(in: 4...6) {
            let chip = Shape.node(Shape.rect(-7, -4, 14, 8, r: 2), fill: Palette.wood, stroke: Palette.bark, width: 2.5)
            chip.position = CGPoint(x: logTop.x + .random(in: -24...24), y: logTop.y - 6)
            chip.zPosition = 25
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
        guard log != nil, !celebrating, hint.action(forKey: "pulse") == nil else { return }
        if CACurrentMediaTime() - lastInteraction > 4 {
            showHint()
        }
    }

    /// En turkis ring som pulserer rundt kubben når Love ikke har trykket på en stund.
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
