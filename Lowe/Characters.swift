import SpriteKit

// MARK: - Lowe

/// Lowe med øksa. `swing` går fra 0 (øksa på skulderen) til 1 (øksa treffer kubben).
final class LoweNode: SKNode {
    private let farArmOutline = Shape.node(CGMutablePath(), stroke: Palette.ink, width: 24)
    private let farArm = Shape.node(CGMutablePath(), stroke: Palette.turquoise, width: 16)
    private let nearArmOutline = Shape.node(CGMutablePath(), stroke: Palette.ink, width: 24)
    private let nearArm = Shape.node(CGMutablePath(), stroke: Palette.turquoise, width: 16)
    private let mitten = Shape.node(Shape.circle(0, 0, 12), fill: Palette.ink, stroke: Palette.ink)
    private let axe = SKNode()
    private let eyes = SKNode()
    private let body = SKNode()

    private let farShoulder = CGPoint(x: 72, y: 162)
    private let nearShoulder = CGPoint(x: 128, y: 160)
    private let handReady = CGPoint(x: 150, y: 150)
    private let handHit = CGPoint(x: 150, y: 175)
    private let angleReady = deg(-25)
    private let angleHit = deg(80)

    var swing: CGFloat = 0 { didSet { applySwing() } }

    override init() {
        super.init()
        buildBody()
        buildAxe()
        farArmOutline.zPosition = 1
        farArm.zPosition = 1.1
        nearArmOutline.zPosition = 1.2
        nearArm.zPosition = 1.3
        mitten.zPosition = 3
        for n in [farArmOutline, farArm, nearArmOutline, nearArm, mitten] { addChild(n) }
        applySwing()
        startIdle()
    }

    required init?(coder aDecoder: NSCoder) { fatalError("init(coder:) is not used") }

    private func buildBody() {
        let ink = Palette.ink
        body.addChild(Shape.node(Shape.rect(70, 268, 30, 20, r: 9), fill: ink, stroke: ink))
        body.addChild(Shape.node(Shape.rect(104, 268, 32, 20, r: 9), fill: ink, stroke: ink))
        body.addChild(Shape.node(Shape.rect(76, 210, 22, 64, r: 8), fill: Palette.inkSoft, stroke: ink))
        body.addChild(Shape.node(Shape.rect(104, 210, 22, 64, r: 8), fill: Palette.inkSoft, stroke: ink))

        let torso = SKNode()
        torso.addChild(Shape.svg("M62 222 Q58 150 100 146 Q142 150 138 222 Z", fill: Palette.turquoise))
        torso.addChild(Shape.node(Shape.line(CGPoint(x: 100, y: 160), CGPoint(x: 100, y: 220)), stroke: ink, width: 3))
        torso.addChild(Shape.svg("M84 150 L100 164 L116 150", stroke: Palette.turquoiseDeep, width: 3))
        body.addChild(torso)

        let head = SKNode()
        head.addChild(Shape.node(Shape.circle(100, 98, 54), fill: Palette.skin, stroke: ink))
        head.addChild(Shape.node(Shape.circle(76, 114, 9), fill: Palette.cheek))
        head.addChild(Shape.node(Shape.circle(124, 114, 9), fill: Palette.cheek))
        for x in [CGFloat(84), 120] {
            let eye = SKNode()
            eye.position = CGPoint(x: x, y: 102)
            eye.addChild(Shape.node(Shape.ellipse(0, 0, 5.5, 7), fill: ink))
            eye.addChild(Shape.node(Shape.circle(2, -3, 2), fill: Palette.white))
            eyes.addChild(eye)
        }
        head.addChild(eyes)
        head.addChild(Shape.svg("M92 120 Q104 130 114 119", width: 3.5))
        head.addChild(Shape.svg("M44 92 Q44 34 100 34 Q156 34 156 92 Z", fill: ink))
        head.addChild(Shape.node(Shape.rect(40, 80, 120, 22, r: 11), fill: Palette.inkSoft, stroke: ink))
        head.addChild(Shape.node(Shape.rect(48, 87, 104, 7), fill: Palette.turquoise))
        head.addChild(Shape.node(Shape.circle(100, 30, 15), fill: Palette.turquoise, stroke: ink))
        body.addChild(head)
        addChild(body)
    }

    private func buildAxe() {
        axe.addChild(Shape.node(Shape.line(CGPoint(x: 0, y: 10), CGPoint(x: 0, y: -150)), stroke: Palette.ink, width: 14))
        axe.addChild(Shape.node(Shape.line(CGPoint(x: 0, y: 10), CGPoint(x: 0, y: -150)), stroke: Palette.turquoise, width: 8))
        axe.addChild(Shape.svg("M-6 -158 L-6 -116 L30 -108 Q46 -136 30 -166 Z", fill: Palette.steel))
        axe.addChild(Shape.svg("M30 -160 Q40 -136 30 -114", stroke: Palette.white, width: 3))
        addChild(axe)
    }

    private func applySwing() {
        let t = max(0, min(1, swing))
        let hand = CGPoint(x: handReady.x + (handHit.x - handReady.x) * t,
                           y: handReady.y + (handHit.y - handReady.y) * t)
        let angle = angleReady + (angleHit - angleReady) * t
        axe.position = hand
        axe.zRotation = angle
        // Øksa ligger bak hodet når den hviler på skulderen, foran når den svinges.
        axe.zPosition = angle < deg(15) ? -1 : 2
        mitten.position = hand
        let far = Shape.line(farShoulder, hand)
        let near = Shape.line(nearShoulder, hand)
        farArmOutline.path = far
        farArm.path = far
        nearArmOutline.path = near
        nearArm.path = near
    }

    private func startIdle() {
        body.run(.repeatForever(.sequence([
            .scaleY(to: 1.012, duration: 1.2),
            .scaleY(to: 1.0, duration: 1.2)
        ])), withKey: "breathe")
        blinkLater()
    }

    private func blinkLater() {
        run(.sequence([
            .wait(forDuration: 2.5, withRange: 2.5),
            .run { [weak self] in
                guard let self else { return }
                self.eyes.run(.sequence([
                    .scaleY(to: 0.1, duration: 0.06), .wait(forDuration: 0.08), .scaleY(to: 1, duration: 0.06)
                ]))
                self.blinkLater()
            }
        ]), withKey: "blink")
    }

    /// Lite hopp av glede.
    func cheer() {
        guard action(forKey: "cheer") == nil else { return }
        let base = position
        let hop = SKAction.sequence([
            .moveTo(y: base.y - 36, duration: 0.16),
            .moveTo(y: base.y, duration: 0.16)
        ])
        hop.timingMode = .easeOut
        run(.sequence([hop, hop]), withKey: "cheer")
    }
}

// MARK: - Kubben

/// En kubbe som står på hoggestabben. (0, 0) er midten av toppen.
final class LogNode: SKNode {
    let hitsNeeded: Int
    var isGiant: Bool { hitsNeeded >= 6 }
    var hits = 0
    let width: CGFloat
    private let height: CGFloat = 90
    private let crack = Shape.node(CGMutablePath(), stroke: Palette.crack, width: 4.5)
    private let content = SKNode()

    init(hitsNeeded: Int) {
        self.hitsNeeded = hitsNeeded
        self.width = 104 + CGFloat(hitsNeeded - 2) * 18
        super.init()
        addChild(content)
        let w2 = width / 2
        content.addChild(Shape.svg("M\(-w2) 0 L\(-w2) 90 Q0 108 \(w2) 90 L\(w2) 0 Z", fill: Palette.barkLight, width: 3.5))
        content.addChild(Shape.svg("M\(-w2 + 22) 20 L\(-w2 + 22) 60 M\(w2 - 22) 16 L\(w2 - 22) 80 M\(w2 - 9) 30 L\(w2 - 9) 52", stroke: Palette.barkLine, width: 3))
        content.addChild(Shape.node(Shape.ellipse(0, 0, w2, 17), fill: Palette.wood, stroke: Palette.ink, width: 3.5))
        content.addChild(Shape.node(Shape.ellipse(0, 0, w2 * 0.66, 11), stroke: Palette.ring, width: 2.5))
        content.addChild(Shape.node(Shape.ellipse(0, 0, w2 * 0.3, 5), stroke: Palette.ring, width: 2.5))
        content.addChild(crack)
    }

    required init?(coder aDecoder: NSCoder) { fatalError("init(coder:) is not used") }

    /// Sprekken vokser for hvert slag.
    func updateCrack() {
        let points = [CGPoint(x: 5, y: 10), CGPoint(x: -5, y: 36), CGPoint(x: 9, y: 54), CGPoint(x: -1, y: 86)]
        let fraction = CGFloat(hits) / CGFloat(hitsNeeded)
        let p = CGMutablePath()
        p.move(to: points[0])
        let segments = CGFloat(points.count - 1) * fraction
        for i in 1..<points.count {
            let s = segments - CGFloat(i - 1)
            if s <= 0 { break }
            let a = points[i - 1], b = points[i]
            let k = min(1, s)
            p.addLine(to: CGPoint(x: a.x + (b.x - a.x) * k, y: a.y + (b.y - a.y) * k))
        }
        crack.path = p
    }

    func squash() {
        content.removeAction(forKey: "squash")
        content.run(.sequence([
            .group([.scaleX(to: 1.06, duration: 0.05), .scaleY(to: 0.9, duration: 0.05)]),
            .group([.scaleX(to: 1, duration: 0.12), .scaleY(to: 1, duration: 0.12)])
        ]), withKey: "squash")
    }

    /// Den ene halvdelen av kubben etter at den har sprukket. Origo er midt i halvdelen;
    /// `halfOffset(left:)` sier hvor den står i forhold til kubbens origo.
    func makeHalf(left: Bool) -> SKNode {
        let n = SKNode()
        let inner = SKNode()
        let w2 = width / 2
        inner.position = CGPoint(x: left ? w2 / 2 : -w2 / 2, y: -height / 2)
        n.addChild(inner)
        let x0: CGFloat = left ? -w2 : 0
        inner.addChild(Shape.node(Shape.rect(x0, 0, w2, height), fill: Palette.barkLight, stroke: Palette.ink, width: 3.5))
        inner.addChild(Shape.node(Shape.rect(left ? -12 : 0, 2, 12, height - 4), fill: Palette.wood))
        let top = CGMutablePath()
        let squish = CGAffineTransform(scaleX: 1, y: 17 / w2)
        top.move(to: CGPoint(x: 0, y: -w2), transform: squish)
        top.addArc(center: .zero, radius: w2, startAngle: -.pi / 2, endAngle: .pi / 2, clockwise: left, transform: squish)
        top.closeSubpath()
        inner.addChild(Shape.node(top, fill: Palette.wood, stroke: Palette.ink, width: 3.5))
        return n
    }

    func halfOffset(left: Bool) -> CGPoint {
        CGPoint(x: left ? -width / 4 : width / 4, y: height / 2)
    }
}
