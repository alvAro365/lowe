import UIKit

/// Styring som i mange 3D-spill på mobil:
/// venstre halvdel er en spak som dukker opp der tommelen trykker,
/// høyre halvdel drar kameraet rundt, og store knapper hugger, hopper og slår på byggingen.
/// Et kort trykk på høyre halvdel hugger også (eller setter en kloss når byggingen er på).
final class ControlsView: UIView {
    /// Hvor spaken peker. x er mot høyre, y er framover. Lengden går fra 0 til 1.
    private(set) var move = SIMD2<Float>(0, 0)
    var onLook: ((CGFloat, CGFloat) -> Void)?
    var onChop: (() -> Void)?
    var onJump: (() -> Void)?
    var onBuild: (() -> Void)?

    private let stickRadius: CGFloat = 64
    private let stickBase = UIView()
    private let stickKnob = UIView()
    private let chopButton = UIView()
    private let jumpButton = UIView()
    private let buildButton = UIView()
    private let axeLayer = ControlsView.axeIcon(in: 104)
    private let blockLayer = ControlsView.blockIcon(in: 104, plus: true)
    private let woodLabel = UILabel()
    private let woodIcon = UIView()
    /// Konglene Lowe har funnet, som en rad oppe til venstre.
    private var coneIcons: [UIView] = []
    private let coneShelf = UIView()
    private var conesFound = 0

    private var stickTouch: UITouch?
    private var stickCenter: CGPoint = .zero
    private var lookTouch: UITouch?
    private var lookLast: CGPoint = .zero
    private var lookTravel: CGFloat = 0
    private var lookStartTime: TimeInterval = 0

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .clear
        isMultipleTouchEnabled = true

        stickBase.frame.size = CGSize(width: stickRadius * 2, height: stickRadius * 2)
        stickBase.layer.cornerRadius = stickRadius
        stickBase.backgroundColor = UIColor(white: 1, alpha: 0.22)
        stickBase.layer.borderColor = UIColor(white: 1, alpha: 0.85).cgColor
        stickBase.layer.borderWidth = 4
        stickBase.isUserInteractionEnabled = false
        addSubview(stickBase)

        stickKnob.frame.size = CGSize(width: 66, height: 66)
        stickKnob.layer.cornerRadius = 33
        stickKnob.backgroundColor = Colors.turquoise
        stickKnob.layer.borderColor = Colors.ink.cgColor
        stickKnob.layer.borderWidth = 4
        stickKnob.isUserInteractionEnabled = false
        addSubview(stickKnob)

        styleButton(chopButton, size: 104, color: Colors.turquoise)
        chopButton.layer.addSublayer(axeLayer)
        chopButton.layer.addSublayer(blockLayer)
        blockLayer.isHidden = true
        styleButton(buildButton, size: 78, color: .white)
        buildButton.layer.addSublayer(ControlsView.blockIcon(in: 78, plus: false))

        woodIcon.frame = CGRect(x: 0, y: 0, width: 34, height: 22)
        woodIcon.layer.cornerRadius = 11
        woodIcon.backgroundColor = Colors.bark
        woodIcon.layer.borderColor = Colors.ink.cgColor
        woodIcon.layer.borderWidth = 3
        let end = UIView(frame: CGRect(x: 20, y: 3, width: 12, height: 16))
        end.layer.cornerRadius = 6
        end.backgroundColor = Colors.wood
        woodIcon.addSubview(end)
        woodIcon.isUserInteractionEnabled = false
        addSubview(woodIcon)
        woodLabel.font = UIFont.systemFont(ofSize: 26, weight: .black)
        woodLabel.textColor = .white
        woodLabel.shadowColor = Colors.ink
        woodLabel.shadowOffset = CGSize(width: 0, height: 2)
        woodLabel.isUserInteractionEnabled = false
        addSubview(woodLabel)
        styleButton(jumpButton, size: 78, color: .white)
        let arrow = UIImageView(image: UIImage(systemName: "arrow.up",
                                               withConfiguration: UIImage.SymbolConfiguration(pointSize: 34, weight: .black)))
        arrow.tintColor = Colors.ink
        arrow.frame = jumpButton.bounds
        arrow.contentMode = .center
        jumpButton.addSubview(arrow)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) is not used") }

    private func styleButton(_ button: UIView, size: CGFloat, color: UIColor) {
        button.frame.size = CGSize(width: size, height: size)
        button.layer.cornerRadius = size / 2
        button.backgroundColor = color
        button.layer.borderColor = Colors.ink.cgColor
        button.layer.borderWidth = 4
        button.isUserInteractionEnabled = false
        addSubview(button)
    }

    /// Ei øks med turkist skaft er vanskelig å se på turkis knapp, så den tegnes svart og stål.
    private static func axeIcon(in size: CGFloat) -> CALayer {
        let layer = CALayer()
        layer.frame = CGRect(x: 0, y: 0, width: size, height: size)
        let handle = CAShapeLayer()
        handle.path = UIBezierPath(roundedRect: CGRect(x: -5, y: -30, width: 10, height: 62), cornerRadius: 5).cgPath
        handle.fillColor = Colors.ink.cgColor
        let head = CAShapeLayer()
        let p = UIBezierPath()
        p.move(to: CGPoint(x: -4, y: -30))
        p.addLine(to: CGPoint(x: 22, y: -38))
        p.addQuadCurve(to: CGPoint(x: 22, y: -6), controlPoint: CGPoint(x: 30, y: -22))
        p.addLine(to: CGPoint(x: -4, y: -12))
        p.close()
        head.path = p.cgPath
        head.fillColor = Colors.steel.cgColor
        head.strokeColor = Colors.ink.cgColor
        head.lineWidth = 3.5
        let group = CALayer()
        group.position = CGPoint(x: size / 2 - 2, y: size / 2 + 2)
        group.setAffineTransform(CGAffineTransform(rotationAngle: 0.5))
        group.addSublayer(handle)
        group.addSublayer(head)
        layer.addSublayer(group)
        return layer
    }

    /// Hvor mange vedstykker Lowe har å bygge med.
    func setWood(_ count: Int) {
        woodLabel.text = "\(count)"
        woodLabel.sizeToFit()
        setNeedsLayout()
    }

    /// I byggemodus viser den store knappen en kloss i stedet for øksa.
    func setBuildMode(_ on: Bool) {
        axeLayer.isHidden = on
        blockLayer.isHidden = !on
        chopButton.backgroundColor = on ? Colors.sun : Colors.turquoise
        buildButton.backgroundColor = on ? Colors.turquoise : .white
    }

    /// En trekloss sett litt ovenfra, med et pluss når den betyr «sett en kloss her».
    private static func blockIcon(in size: CGFloat, plus: Bool) -> CALayer {
        let layer = CALayer()
        layer.frame = CGRect(x: 0, y: 0, width: size, height: size)
        let s = size * 0.2
        let c = CGPoint(x: size / 2, y: size / 2 + s * 0.15)
        func face(_ points: [CGPoint], _ color: UIColor) {
            let shape = CAShapeLayer()
            let path = UIBezierPath()
            path.move(to: points[0])
            points.dropFirst().forEach { path.addLine(to: $0) }
            path.close()
            shape.path = path.cgPath
            shape.fillColor = color.cgColor
            shape.strokeColor = Colors.ink.cgColor
            shape.lineWidth = 3
            shape.lineJoin = .round
            layer.addSublayer(shape)
        }
        let top = CGPoint(x: c.x, y: c.y - s * 1.1)
        let left = CGPoint(x: c.x - s, y: c.y - s * 0.55)
        let right = CGPoint(x: c.x + s, y: c.y - s * 0.55)
        let mid = CGPoint(x: c.x, y: c.y)
        face([top, right, mid, left], Colors.wood)
        face([left, mid, CGPoint(x: mid.x, y: mid.y + s * 1.1), CGPoint(x: left.x, y: left.y + s * 1.1)], Colors.barkLight)
        face([mid, right, CGPoint(x: right.x, y: right.y + s * 1.1), CGPoint(x: mid.x, y: mid.y + s * 1.1)], Colors.bark)
        if plus {
            let p = CAShapeLayer()
            let path = UIBezierPath()
            let o = CGPoint(x: size * 0.74, y: size * 0.27)
            path.move(to: CGPoint(x: o.x - 9, y: o.y))
            path.addLine(to: CGPoint(x: o.x + 9, y: o.y))
            path.move(to: CGPoint(x: o.x, y: o.y - 9))
            path.addLine(to: CGPoint(x: o.x, y: o.y + 9))
            p.path = path.cgPath
            p.strokeColor = Colors.ink.cgColor
            p.lineWidth = 5
            p.lineCap = .round
            layer.addSublayer(p)
        }
        return layer
    }

    /// Konglene vises som små tegnede kongler: brune med skjell når de er funnet, og en lys skygge når de ikke er det.
    func setCones(found: Int, total: Int) {
        if coneIcons.count != total {
            coneIcons.forEach { $0.removeFromSuperview() }
            if coneShelf.superview == nil {
                coneShelf.backgroundColor = UIColor(white: 0, alpha: 0.28)
                coneShelf.isUserInteractionEnabled = false
                insertSubview(coneShelf, at: 0)
            }
            coneIcons = (0..<total).map { _ in
                let icon = UIView(frame: CGRect(x: 0, y: 0, width: 28, height: 38))
                icon.isUserInteractionEnabled = false
                let empty = ControlsView.pineconeLayer(found: false)
                let full = ControlsView.pineconeLayer(found: true)
                empty.name = "empty"
                full.name = "full"
                icon.layer.addSublayer(empty)
                icon.layer.addSublayer(full)
                addSubview(icon)
                return icon
            }
            setNeedsLayout()
        }
        for (i, icon) in coneIcons.enumerated() {
            for layer in icon.layer.sublayers ?? [] {
                layer.isHidden = (layer.name == "full") != (i < found)
            }
        }
        if found > conesFound, let icon = coneIcons[safe: found - 1] {
            icon.transform = CGAffineTransform(scaleX: 1.9, y: 1.9).rotated(by: 0.3)
            UIView.animate(withDuration: 0.45, delay: 0, usingSpringWithDamping: 0.45, initialSpringVelocity: 4) {
                icon.transform = .identity
            }
        }
        conesFound = found
    }

    /// En kongle tegnet i 28 x 38 punkter: en avlang kropp med rutete skjell og en liten stilk på toppen.
    private static func pineconeLayer(found: Bool) -> CALayer {
        let layer = CALayer()
        layer.frame = CGRect(x: 0, y: 0, width: 28, height: 38)
        let body = UIBezierPath()
        body.move(to: CGPoint(x: 14, y: 6))
        body.addCurve(to: CGPoint(x: 14, y: 36), controlPoint1: CGPoint(x: 30, y: 8), controlPoint2: CGPoint(x: 24, y: 30))
        body.addCurve(to: CGPoint(x: 14, y: 6), controlPoint1: CGPoint(x: 4, y: 30), controlPoint2: CGPoint(x: -2, y: 8))
        body.close()

        let stem = CAShapeLayer()
        let stemPath = UIBezierPath()
        stemPath.move(to: CGPoint(x: 14, y: 7))
        stemPath.addQuadCurve(to: CGPoint(x: 17, y: 1), controlPoint: CGPoint(x: 14, y: 3))
        stem.path = stemPath.cgPath
        stem.fillColor = nil
        stem.lineWidth = 3
        stem.lineCap = .round

        let shape = CAShapeLayer()
        shape.path = body.cgPath
        shape.lineWidth = 2.5

        // Skjellene: skrå streker begge veier, klippet til kroppen.
        let scales = CAShapeLayer()
        let lines = UIBezierPath()
        for k in stride(from: CGFloat(-30), through: 40, by: 7) {
            lines.move(to: CGPoint(x: k, y: 4))
            lines.addLine(to: CGPoint(x: k + 22, y: 40))
            lines.move(to: CGPoint(x: k + 22, y: 4))
            lines.addLine(to: CGPoint(x: k, y: 40))
        }
        scales.path = lines.cgPath
        scales.fillColor = nil
        scales.lineWidth = 1.8
        let clip = CAShapeLayer()
        clip.path = body.cgPath
        scales.mask = clip

        if found {
            shape.fillColor = UIColor(hex: 0xA8693A).cgColor
            shape.strokeColor = Colors.ink.cgColor
            scales.strokeColor = UIColor(hex: 0x5E3820).cgColor
            stem.strokeColor = Colors.ink.cgColor
        } else {
            shape.fillColor = UIColor(white: 1, alpha: 0.18).cgColor
            shape.strokeColor = UIColor(white: 1, alpha: 0.75).cgColor
            scales.strokeColor = UIColor(white: 1, alpha: 0.35).cgColor
            stem.strokeColor = UIColor(white: 1, alpha: 0.75).cgColor
        }
        layer.addSublayer(stem)
        layer.addSublayer(shape)
        layer.addSublayer(scales)
        return layer
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        let inset = safeAreaInsets
        for (i, icon) in coneIcons.enumerated() {
            icon.center = CGPoint(x: bounds.minX + inset.left + 34 + CGFloat(i) * 32,
                                  y: bounds.minY + inset.top + 32)
        }
        if let first = coneIcons.first, let last = coneIcons.last {
            coneShelf.frame = first.frame.union(last.frame).insetBy(dx: -10, dy: -5)
            coneShelf.layer.cornerRadius = coneShelf.bounds.height / 2
        }
        let margin: CGFloat = 26
        chopButton.center = CGPoint(x: bounds.maxX - inset.right - margin - 52,
                                    y: bounds.maxY - inset.bottom - margin - 52)
        jumpButton.center = CGPoint(x: chopButton.center.x - 112, y: chopButton.center.y + 12)
        buildButton.center = CGPoint(x: chopButton.center.x + 6, y: chopButton.center.y - 116)
        woodIcon.center = CGPoint(x: bounds.minX + inset.left + 36, y: bounds.minY + inset.top + 82)
        woodLabel.frame.origin = CGPoint(x: woodIcon.frame.maxX + 8, y: woodIcon.center.y - woodLabel.bounds.height / 2)
        if stickTouch == nil { placeStickAtRest() }
    }

    /// Når ingen holder spaken, står den svakt nede til venstre så Lowe ser hvor den er.
    private func placeStickAtRest() {
        let inset = safeAreaInsets
        let center = CGPoint(x: bounds.minX + inset.left + 40 + stickRadius,
                             y: bounds.maxY - inset.bottom - 30 - stickRadius)
        stickBase.center = center
        stickKnob.center = center
        stickBase.alpha = 0.5
        stickKnob.alpha = 0.5
    }

    // MARK: Berøring

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        for touch in touches {
            let p = touch.location(in: self)
            if hits(chopButton, p) {
                bounce(chopButton)
                onChop?()
            } else if hits(jumpButton, p) {
                bounce(jumpButton)
                onJump?()
            } else if hits(buildButton, p) {
                bounce(buildButton)
                onBuild?()
            } else if p.x < bounds.midX {
                guard stickTouch == nil else { continue }
                stickTouch = touch
                stickCenter = p
                stickBase.center = p
                stickKnob.center = p
                stickBase.alpha = 1
                stickKnob.alpha = 1
            } else if lookTouch == nil {
                lookTouch = touch
                lookLast = p
                lookTravel = 0
                lookStartTime = touch.timestamp
            }
        }
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        for touch in touches {
            let p = touch.location(in: self)
            if touch === stickTouch {
                var dx = p.x - stickCenter.x
                var dy = p.y - stickCenter.y
                let length = hypot(dx, dy)
                if length > stickRadius {
                    dx *= stickRadius / length
                    dy *= stickRadius / length
                }
                stickKnob.center = CGPoint(x: stickCenter.x + dx, y: stickCenter.y + dy)
                move = SIMD2(Float(dx / stickRadius), Float(-dy / stickRadius))
            } else if touch === lookTouch {
                let dx = p.x - lookLast.x
                let dy = p.y - lookLast.y
                lookLast = p
                lookTravel += hypot(dx, dy)
                onLook?(dx, dy)
            }
        }
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        finish(touches, tapCounts: true)
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        finish(touches, tapCounts: false)
    }

    private func finish(_ touches: Set<UITouch>, tapCounts: Bool) {
        for touch in touches {
            if touch === stickTouch {
                stickTouch = nil
                move = .zero
                UIView.animate(withDuration: 0.15) { self.placeStickAtRest() }
            } else if touch === lookTouch {
                lookTouch = nil
                if tapCounts && lookTravel < 12 && touch.timestamp - lookStartTime < 0.3 {
                    onChop?()
                }
            }
        }
    }

    private func hits(_ button: UIView, _ p: CGPoint) -> Bool {
        hypot(p.x - button.center.x, p.y - button.center.y) <= button.bounds.width / 2 + 14
    }

    private func bounce(_ button: UIView) {
        button.transform = CGAffineTransform(scaleX: 0.88, y: 0.88)
        UIView.animate(withDuration: 0.18) { button.transform = .identity }
    }
}

extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
