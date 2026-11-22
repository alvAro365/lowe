import SpriteKit

// Knapper og krukke som ligger oppå spillet, i skjermkoordinater (y peker opp).
// Tegningene ligger i en node med snudd y-akse, så stiene kan skrives som i designet.

@MainActor
private func flipped() -> SKNode {
    let n = SKNode()
    n.yScale = -1
    return n
}

// MARK: - Pauseknapp med foreldrelås

/// Pauseknappen. Må holdes inne en stund før den åpner, så barnet ikke åpner den ved et uhell.
final class HoldButton: SKNode {
    let radius: CGFloat = 30
    private let holdTime: TimeInterval
    private let ring = Shape.node(CGMutablePath(), stroke: Palette.turquoise, width: 7)
    private let face = SKNode()

    init(holdTime: TimeInterval) {
        self.holdTime = holdTime
        super.init()
        let art = flipped()
        art.addChild(Shape.node(Shape.circle(0, 0, radius), fill: SKColor(white: 1, alpha: 0.9), stroke: Palette.ink, width: 3))
        art.addChild(Shape.node(Shape.line(CGPoint(x: -7, y: -11), CGPoint(x: -7, y: 11)), stroke: Palette.ink, width: 5))
        art.addChild(Shape.node(Shape.line(CGPoint(x: 7, y: -11), CGPoint(x: 7, y: 11)), stroke: Palette.ink, width: 5))
        face.addChild(art)
        addChild(face)
        addChild(ring)
    }

    required init?(coder aDecoder: NSCoder) { fatalError("init(coder:) is not used") }

    /// Treffer et punkt i forelderens koordinater knappen? Litt romslig for små fingre.
    func hitTest(_ p: CGPoint) -> Bool {
        !isHidden && hypot(p.x - position.x, p.y - position.y) <= radius + 18
    }

    func beginHold(onComplete: @escaping () -> Void) {
        removeAction(forKey: "hold")
        let total = CGFloat(holdTime)
        face.run(.scale(to: 0.9, duration: 0.1))
        let fill = SKAction.customAction(withDuration: holdTime) { [weak self] _, elapsed in
            self?.setProgress(elapsed / total)
        }
        run(.sequence([
            fill,
            .run { [weak self] in
                self?.setProgress(0)
                self?.face.run(.scale(to: 1, duration: 0.1))
                onComplete()
            }
        ]), withKey: "hold")
    }

    func cancelHold() {
        guard action(forKey: "hold") != nil else { return }
        removeAction(forKey: "hold")
        setProgress(0)
        face.run(.scale(to: 1, duration: 0.1))
    }

    private func setProgress(_ fraction: CGFloat) {
        guard fraction > 0 else {
            ring.path = nil
            return
        }
        let p = CGMutablePath()
        p.addArc(center: .zero, radius: radius + 9, startAngle: .pi / 2,
                 endAngle: .pi / 2 - 2 * .pi * min(1, fraction), clockwise: true)
        ring.path = p
    }
}

// MARK: - Foreldremeny

/// Enkel meny for voksne: fortsett, lyd av/på og start på nytt.
final class PauseMenu: SKNode {
    enum Choice { case resume, toggleSound, reset }

    var onChoice: ((Choice) -> Void)?
    private var buttons: [(Choice, CGPoint)] = []
    private let soundIcon = SKNode()
    private let soundLabel = PauseMenu.label("")
    private let resetLabel = PauseMenu.label("Start på nytt")
    private let resetCircle: SKShapeNode
    private var resetArmed = false
    private let buttonRadius: CGFloat = 46

    init(size: CGSize, muted: Bool) {
        resetCircle = Shape.node(Shape.circle(0, 0, 46), fill: Palette.white, stroke: Palette.ink, width: 3)
        super.init()
        let dim = SKShapeNode(rect: CGRect(x: -size.width, y: -size.height, width: size.width * 2, height: size.height * 2))
        dim.fillColor = SKColor(white: 0, alpha: 0.45)
        dim.strokeColor = .clear
        addChild(dim)

        let panel = Shape.node(Shape.rect(-290, -150, 580, 300, r: 28), fill: Palette.snow, stroke: Palette.ink, width: 3)
        addChild(panel)
        let title = PauseMenu.label("Pause", size: 30)
        title.position = CGPoint(x: 0, y: 92)
        addChild(title)

        addButton(.resume, x: -180, circle: Shape.node(Shape.circle(0, 0, buttonRadius), fill: Palette.turquoise, stroke: Palette.ink, width: 3),
                  icon: PauseMenu.playIcon(), label: PauseMenu.label("Fortsett"))
        addButton(.toggleSound, x: 0, circle: Shape.node(Shape.circle(0, 0, buttonRadius), fill: Palette.white, stroke: Palette.ink, width: 3),
                  icon: soundIcon, label: soundLabel)
        addButton(.reset, x: 180, circle: resetCircle, icon: PauseMenu.restartIcon(), label: resetLabel)
        setMuted(muted)
    }

    required init?(coder aDecoder: NSCoder) { fatalError("init(coder:) is not used") }

    private func addButton(_ choice: Choice, x: CGFloat, circle: SKShapeNode, icon: SKNode, label: SKLabelNode) {
        let center = CGPoint(x: x, y: 4)
        circle.position = center
        addChild(circle)
        icon.position = center
        addChild(icon)
        label.position = CGPoint(x: x, y: -82)
        addChild(label)
        buttons.append((choice, center))
    }

    /// Punktet er i menyens egne koordinater.
    func handleTap(_ p: CGPoint) {
        for (choice, center) in buttons where hypot(p.x - center.x, p.y - center.y) <= buttonRadius + 14 {
            if choice == .reset && !resetArmed {
                armReset()
                return
            }
            onChoice?(choice)
            return
        }
    }

    func setMuted(_ muted: Bool) {
        soundIcon.removeAllChildren()
        soundIcon.addChild(PauseMenu.speakerIcon(muted: muted))
        soundLabel.text = muted ? "Lyd av" : "Lyd på"
    }

    /// Første trykk på «Start på nytt» spør bare. Andre trykk innen 3 sekunder gjør det.
    private func armReset() {
        resetArmed = true
        resetLabel.text = "Trykk igjen"
        resetCircle.fillColor = Palette.sun
        run(.sequence([
            .wait(forDuration: 3),
            .run { [weak self] in
                self?.resetArmed = false
                self?.resetLabel.text = "Start på nytt"
                self?.resetCircle.fillColor = Palette.white
            }
        ]), withKey: "disarm")
    }

    private static func label(_ text: String, size: CGFloat = 20) -> SKLabelNode {
        let l = SKLabelNode(fontNamed: "AvenirNext-Bold")
        l.text = text
        l.fontSize = size
        l.fontColor = Palette.ink
        l.verticalAlignmentMode = .center
        l.horizontalAlignmentMode = .center
        return l
    }

    private static func playIcon() -> SKNode {
        let art = flipped()
        art.addChild(Shape.svg("M-12 -18 L-12 18 L20 0 Z", fill: Palette.ink, width: 3))
        return art
    }

    private static func speakerIcon(muted: Bool) -> SKNode {
        let art = flipped()
        art.addChild(Shape.svg("M-22 -8 L-12 -8 L2 -20 L2 20 L-12 8 L-22 8 Z", fill: Palette.ink, width: 3))
        if muted {
            art.addChild(Shape.svg("M10 -10 L26 10 M26 -10 L10 10", stroke: Palette.ink, width: 4))
        } else {
            art.addChild(Shape.svg("M10 -8 Q16 0 10 8 M16 -16 Q28 0 16 16", stroke: Palette.ink, width: 4))
        }
        return art
    }

    private static func restartIcon() -> SKNode {
        let art = flipped()
        let arc = CGMutablePath()
        arc.addArc(center: .zero, radius: 18, startAngle: deg(-60), endAngle: deg(200), clockwise: false)
        art.addChild(Shape.node(arc, stroke: Palette.ink, width: 5))
        art.addChild(Shape.svg("M4 -26 L14 -14 L-1 -11 Z", fill: Palette.ink, width: 3))
        return art
    }
}

// MARK: - Stjernekrukka

/// Krukke øverst til høyre. Hver full vedstabel gir en stjerne. Fem stjerner fyller krukka.
final class StarJar: SKNode {
    static let capacity = 5
    private var slots: [SKShapeNode] = []
    private let glass: SKShapeNode
    private(set) var count = 0

    override init() {
        glass = Shape.svg("M-30 -26 Q-34 -26 -34 -18 L-34 30 Q-34 42 -22 42 L22 42 Q34 42 34 30 L34 -18 Q34 -26 30 -26 Z",
                          fill: SKColor(white: 1, alpha: 0.55), stroke: Palette.ink, width: 3)
        super.init()
        let art = flipped()
        art.addChild(glass)
        art.addChild(Shape.node(Shape.rect(-28, -40, 56, 16, r: 5), fill: Palette.turquoise, stroke: Palette.ink, width: 3))
        let positions = [CGPoint(x: -15, y: 26), CGPoint(x: 15, y: 26), CGPoint(x: -15, y: 2), CGPoint(x: 15, y: 2), CGPoint(x: 0, y: -14)]
        for p in positions {
            let star = StarJar.star(radius: 12)
            star.position = p
            star.fillColor = .clear
            star.strokeColor = SKColor(white: 0, alpha: 0.18)
            star.lineWidth = 2
            art.addChild(star)
            slots.append(star)
        }
        addChild(art)
    }

    required init?(coder aDecoder: NSCoder) { fatalError("init(coder:) is not used") }

    static func star(radius r: CGFloat) -> SKShapeNode {
        let p = CGMutablePath()
        for i in 0..<10 {
            let a = -CGFloat.pi / 2 + CGFloat(i) * .pi / 5
            let rr = i % 2 == 0 ? r : r * 0.45
            let pt = CGPoint(x: cos(a) * rr, y: sin(a) * rr)
            if i == 0 { p.move(to: pt) } else { p.addLine(to: pt) }
        }
        p.closeSubpath()
        return Shape.node(p, fill: Palette.sun, stroke: Palette.ink, width: 2.5)
    }

    func setCount(_ n: Int) {
        count = max(0, min(StarJar.capacity, n))
        for (i, slot) in slots.enumerated() {
            let filled = i < count
            slot.fillColor = filled ? Palette.sun : .clear
            slot.strokeColor = filled ? Palette.ink : SKColor(white: 0, alpha: 0.18)
            slot.lineWidth = filled ? 2.5 : 2
        }
    }

    /// En stjerne lander i krukka. Gir `true` når krukka ble full.
    @discardableResult
    func addStar() -> Bool {
        setCount(count + 1)
        if let slot = slots[safe: count - 1] {
            slot.setScale(0.3)
            slot.run(.sequence([.scale(to: 1.3, duration: 0.12), .scale(to: 1, duration: 0.1)]))
        }
        run(.sequence([.scale(to: 1.15, duration: 0.1), .scale(to: 1, duration: 0.12)]))
        return count >= StarJar.capacity
    }

    /// Full krukke: den gløder og rister litt, så tømmes den for neste runde.
    func celebrateFull(then done: @escaping () -> Void) {
        let wiggle = SKAction.sequence([
            .rotate(toAngle: 0.15, duration: 0.08), .rotate(toAngle: -0.15, duration: 0.16), .rotate(toAngle: 0, duration: 0.08)
        ])
        run(.sequence([
            .repeat(wiggle, count: 3),
            .wait(forDuration: 0.6),
            .run { [weak self] in self?.setCount(0) },
            .run(done)
        ]))
    }
}

extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
