import UIKit

/// Styring som i mange 3D-spill på mobil:
/// venstre halvdel er en spak som dukker opp der tommelen trykker,
/// høyre halvdel drar kameraet rundt, og to store knapper hugger og hopper.
/// Et kort trykk på høyre halvdel hugger også.
final class ControlsView: UIView {
    /// Hvor spaken peker. x er mot høyre, y er framover. Lengden går fra 0 til 1.
    private(set) var move = SIMD2<Float>(0, 0)
    var onLook: ((CGFloat, CGFloat) -> Void)?
    var onChop: (() -> Void)?
    var onJump: (() -> Void)?

    private let stickRadius: CGFloat = 64
    private let stickBase = UIView()
    private let stickKnob = UIView()
    private let chopButton = UIView()
    private let jumpButton = UIView()
    /// Konglene Lowe har funnet, som en rad oppe til venstre.
    private var coneIcons: [UIView] = []
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
        chopButton.layer.addSublayer(ControlsView.axeIcon(in: 104))
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

    func setCones(found: Int, total: Int) {
        if coneIcons.count != total {
            coneIcons.forEach { $0.removeFromSuperview() }
            coneIcons = (0..<total).map { _ in
                let icon = UIView(frame: CGRect(x: 0, y: 0, width: 22, height: 30))
                icon.layer.cornerRadius = 11
                icon.layer.borderWidth = 3
                icon.layer.borderColor = Colors.bark.cgColor
                icon.isUserInteractionEnabled = false
                addSubview(icon)
                return icon
            }
            setNeedsLayout()
        }
        for (i, icon) in coneIcons.enumerated() {
            icon.backgroundColor = i < found ? Colors.bark : UIColor(white: 1, alpha: 0.35)
        }
        if found > conesFound, let icon = coneIcons[safe: found - 1] {
            icon.transform = CGAffineTransform(scaleX: 1.6, y: 1.6)
            UIView.animate(withDuration: 0.25) { icon.transform = .identity }
        }
        conesFound = found
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        let inset = safeAreaInsets
        for (i, icon) in coneIcons.enumerated() {
            icon.center = CGPoint(x: bounds.minX + inset.left + 30 + CGFloat(i) * 30,
                                  y: bounds.minY + inset.top + 32)
        }
        let margin: CGFloat = 26
        chopButton.center = CGPoint(x: bounds.maxX - inset.right - margin - 52,
                                    y: bounds.maxY - inset.bottom - margin - 52)
        jumpButton.center = CGPoint(x: chopButton.center.x - 112, y: chopButton.center.y + 12)
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
