import SpriteKit

/// Landsbyen om natta, fra designtavla «Landsbyen om natta».
/// Vises etter hver levering. Den nye hytta lyser opp og dyret flytter inn.
final class VillageLayer: SKNode {
    private var cabins: [Animal: SKNode] = [:]
    private var ghosts: [Animal: SKNode] = [:]
    private var residents: [Animal: SKNode] = [:]

    private let nightSky = SKColor(hex: 0x1B2A3A)
    private let nightHill = SKColor(hex: 0x2C4256)
    private let nightTree = SKColor(hex: 0x16303A)
    private let nightSnow = SKColor(hex: 0xDDE7EE)
    private let nightSnowMid = SKColor(hex: 0xBFD0DB)

    /// `built`: hvor mange hytter som allerede står ferdig (i dyrenes rekkefølge).
    init(built: Int) {
        super.init()
        buildScenery()
        for animal in Animal.allCases {
            buildHome(for: animal, isBuilt: animal.rawValue < built)
        }
        buildFireAndLowe()
    }

    required init?(coder aDecoder: NSCoder) { fatalError("init(coder:) is not used") }

    private func buildScenery() {
        addChild(Shape.node(Shape.rect(-600, -600, 2380, 2020), fill: nightSky))

        let auroraPath = "M-400 220 Q200 120 420 200 Q640 280 860 160 Q1020 80 1580 150"
        let aurora = SKNode()
        aurora.addChild(Shape.svg(auroraPath, stroke: Palette.turquoise.withAlphaComponent(0.22), width: 56))
        aurora.addChild(Shape.svg(auroraPath, stroke: SKColor(hex: 0x6FF0D8, alpha: 0.5), width: 16))
        aurora.addChild(Shape.svg("M-300 300 Q260 230 480 280 Q700 330 900 250 Q1060 190 1580 240",
                                  stroke: Palette.turquoise.withAlphaComponent(0.18), width: 34))
        addChild(aurora)
        aurora.run(.repeatForever(.sequence([
            .group([.moveBy(x: 0, y: 12, duration: 3), .fadeAlpha(to: 0.7, duration: 3)]),
            .group([.moveBy(x: 0, y: -12, duration: 3), .fadeAlpha(to: 1, duration: 3)])
        ])))

        let stars: [(CGFloat, CGFloat)] = [(80, 70), (180, 40), (300, 90), (460, 50), (560, 110), (700, 60), (820, 40),
                                           (980, 70), (1100, 40), (1130, 260), (40, 330), (640, 360), (380, 340)]
        for (i, (x, y)) in stars.enumerated() {
            let star = Shape.node(Shape.circle(x, y, i % 2 == 0 ? 2.5 : 2), fill: Palette.white)
            addChild(star)
            star.run(.repeatForever(.sequence([
                .wait(forDuration: Double(i % 4) * 0.4),
                .fadeAlpha(to: 0.3, duration: 0.8),
                .fadeAlpha(to: 1, duration: 0.8)
            ])))
        }
        addChild(Shape.node(Shape.circle(1040, 320, 34), fill: SKColor(hex: 0xF3EFD8)))
        addChild(Shape.node(Shape.circle(1054, 310, 30), fill: nightSky))

        addChild(Shape.svg("M-600 520 Q240 440 480 500 Q720 450 940 500 Q1080 470 1780 490 L1780 1420 L-600 1420 Z", fill: nightHill, stroke: nil))
        for (x, y, s) in [(60, 520, 0.8), (240, 500, 0.65), (560, 500, 0.7), (700, 490, 0.6), (1140, 500, 0.8), (-90, 510, 0.7)]
            as [(CGFloat, CGFloat, CGFloat)] {
            let tree = Scenery.spruce(color: nightTree, snow: nightSnow, trunk: SKColor(hex: 0x0F2129))
            tree.position = CGPoint(x: x, y: y)
            tree.setScale(s)
            addChild(tree)
        }
        addChild(Shape.svg("M-600 590 Q300 560 600 580 Q900 600 1780 570 L1780 1420 L-600 1420 Z", fill: nightSnowMid, stroke: nil))
        addChild(Shape.svg("M-600 640 Q590 620 1780 648 L1780 1420 L-600 1420 Z", fill: nightSnow, stroke: nil))
    }

    // MARK: Hytter

    private func buildHome(for animal: Animal, isBuilt: Bool) {
        let slot = animal.homeSlot
        let depth = slot.position.y * 0.001
        let ghost = VillageLayer.ghostCabin()
        ghost.zPosition = depth
        ghost.position = slot.position
        ghost.setScale(slot.scale)
        addChild(ghost)
        ghosts[animal] = ghost

        let cabin = VillageLayer.cabin(color: animal.cabinColor)
        cabin.zPosition = depth
        cabin.position = slot.position
        cabin.setScale(slot.scale)
        addChild(cabin)
        cabins[animal] = cabin

        let resident = animal.build()
        resident.position = CGPoint(x: slot.position.x + 46 * slot.scale, y: slot.position.y + 6)
        resident.setScale(0.3 * slot.scale)
        resident.zPosition = depth + 0.5
        addChild(resident)
        residents[animal] = resident

        if isBuilt {
            ghost.isHidden = true
            startSmoke(cabin)
        } else {
            cabin.isHidden = true
            resident.isHidden = true
        }
    }

    private static func cabin(color: SKColor) -> SKNode {
        let n = SKNode()
        n.addChild(Shape.node(Shape.rect(10, -90, 140, 90), fill: color, stroke: Palette.ink, width: 3.5))
        n.addChild(Shape.svg("M0 -86 L80 -150 L160 -86 Z", fill: Palette.inkSoft, width: 3.5))
        n.addChild(Shape.svg("M0 -86 L80 -150 L160 -86 L148 -78 L80 -132 L12 -78 Z", fill: SKColor(hex: 0xEEF4F7), width: 3))
        n.addChild(Shape.node(Shape.rect(110, -150, 20, 40), fill: Palette.trunk, stroke: Palette.ink, width: 3))
        n.addChild(Shape.node(Shape.rect(30, -60, 32, 60, r: 3), fill: Palette.trunk, stroke: Palette.ink, width: 3))
        let glow = Shape.node(Shape.ellipse(110, -52, 34, 28), fill: Palette.sun.withAlphaComponent(0.25))
        glow.name = "glow"
        n.addChild(glow)
        n.addChild(Shape.node(Shape.rect(90, -70, 40, 34, r: 3), fill: Palette.sun, stroke: Palette.ink, width: 3))
        return n
    }

    private static func ghostCabin() -> SKNode {
        let n = SKNode()
        let p = CGMutablePath()
        p.addRect(CGRect(x: 10, y: -90, width: 140, height: 90))
        p.move(to: CGPoint(x: 0, y: -86))
        p.addLine(to: CGPoint(x: 80, y: -150))
        p.addLine(to: CGPoint(x: 160, y: -86))
        p.addRect(CGRect(x: 30, y: -60, width: 32, height: 60))
        p.addRect(CGRect(x: 90, y: -70, width: 40, height: 34))
        let dashed = p.copy(dashingWithPhase: 0, lengths: [9, 9])
        n.addChild(Shape.node(dashed, stroke: SKColor(white: 1, alpha: 0.75), width: 3))
        return n
    }

    private func startSmoke(_ cabin: SKNode) {
        let puff = SKAction.run { [weak cabin] in
            guard let cabin else { return }
            let smoke = Shape.node(Shape.circle(0, 0, 10), fill: SKColor(white: 1, alpha: 0.6))
            smoke.position = CGPoint(x: 120, y: -156)
            cabin.addChild(smoke)
            smoke.run(.sequence([
                .group([
                    .moveBy(x: 18, y: -70, duration: 2.2),
                    .scale(to: 2, duration: 2.2),
                    .fadeOut(withDuration: 2.2)
                ]),
                .removeFromParent()
            ]))
        }
        cabin.run(.repeatForever(.sequence([puff, .wait(forDuration: 0.7)])), withKey: "smoke")
    }

    /// Den nye hytta bygges og lyser opp, og dyret flytter inn.
    func reveal(_ animal: Animal) {
        guard let cabin = cabins[animal], let ghost = ghosts[animal], let resident = residents[animal] else { return }
        let scale = animal.homeSlot.scale
        ghost.run(.sequence([.fadeOut(withDuration: 0.3), .hide()]))

        cabin.isHidden = false
        cabin.setScale(0.1)
        cabin.run(.sequence([
            .scale(to: scale * 1.15, duration: 0.25),
            .scale(to: scale, duration: 0.12)
        ]))
        startSmoke(cabin)
        if let glow = cabin.childNode(withName: "glow") {
            glow.run(.repeat(.sequence([.fadeAlpha(to: 0.2, duration: 0.2), .fadeAlpha(to: 1, duration: 0.2)]), count: 4))
        }

        let center = CGPoint(x: animal.homeSlot.position.x + 80 * scale, y: animal.homeSlot.position.y - 100 * scale)
        let colors = [Palette.turquoise, Palette.sun, Palette.white]
        for i in 0..<10 {
            let sparkle = Scenery.sparkle(color: colors[i % colors.count])
            sparkle.position = center
            sparkle.zPosition = 5
            sparkle.setScale(0.2)
            addChild(sparkle)
            let angle = CGFloat(i) / 10 * 2 * .pi
            sparkle.run(.sequence([
                .group([
                    .moveBy(x: cos(angle) * 120 * scale, y: sin(angle) * 90 * scale, duration: 0.6),
                    .scale(to: 1, duration: 0.3),
                    .rotate(byAngle: 2, duration: 0.6)
                ]),
                .fadeOut(withDuration: 0.3),
                .removeFromParent()
            ]))
        }

        let finalScale = 0.3 * scale
        resident.isHidden = false
        resident.setScale(0)
        resident.run(.sequence([
            .wait(forDuration: 0.5),
            .scale(to: finalScale * 1.2, duration: 0.15),
            .scale(to: finalScale, duration: 0.1),
            .moveBy(x: 0, y: -12, duration: 0.12),
            .moveBy(x: 0, y: 12, duration: 0.12)
        ]))
    }

    // MARK: Bål og Lowe

    private func buildFireAndLowe() {
        let fire = SKNode()
        fire.zPosition = 3
        fire.addChild(Shape.node(Shape.circle(590, 640, 110), fill: SKColor(hex: 0xFFB547, alpha: 0.14)))
        fire.addChild(Shape.node(Shape.circle(590, 640, 60), fill: SKColor(hex: 0xFFB547, alpha: 0.2)))
        let flames = SKNode()
        flames.position = CGPoint(x: 590, y: 668)
        flames.addChild(Shape.svg("M0 -78 Q30 -48 22 -18 Q10 0 0 0 Q-20 0 -24 -18 Q-30 -48 0 -78 Z", fill: SKColor(hex: 0xF2823A), width: 3))
        flames.addChild(Shape.svg("M0 -54 Q16 -32 10 -14 Q4 -6 -2 -6 Q-12 -8 -12 -20 Q-12 -36 0 -54 Z", fill: Palette.sun, stroke: nil))
        fire.addChild(flames)
        flames.run(.repeatForever(.sequence([
            .scaleY(to: 1.12, duration: 0.18), .scaleY(to: 0.94, duration: 0.22), .scaleY(to: 1.05, duration: 0.16)
        ])))
        let logA = Shape.node(Shape.rect(-42, -7, 84, 14, r: 7), fill: Palette.bark, stroke: Palette.ink, width: 3)
        logA.position = CGPoint(x: 590, y: 669)
        logA.zRotation = deg(12)
        let logB = Shape.node(Shape.rect(-42, -7, 84, 14, r: 7), fill: Palette.barkLight, stroke: Palette.ink, width: 3)
        logB.position = CGPoint(x: 590, y: 669)
        logB.zRotation = deg(-12)
        fire.addChild(logA)
        fire.addChild(logB)
        addChild(fire)

        let lowe = LoweNode()
        lowe.position = CGPoint(x: 430, y: 470)
        lowe.setScale(0.62)
        lowe.zPosition = 4
        addChild(lowe)
    }
}
