import UIKit

/// Styring som i mange 3D-spill på mobil:
/// spaken står fast nede til venstre, å dra ellers på skjermen snur kameraet rundt Lowe,
/// og store knapper hugger, hopper og slår på byggingen.
/// Et kort trykk hvor som helst ellers på skjermen treffer tingen der: ta opp, legge fra seg, hugge. Når byggingen er på, setter et trykk en kloss der fingeren peker,
/// og å holde fingeren på en kloss tar den bort, som i Minecraft. En rad nederst velger hvilken kloss.
final class ControlsView: UIView, UIGestureRecognizerDelegate {
    /// Hvor spaken peker. x er mot høyre, y er framover. Lengden går fra 0 til 1.
    private(set) var move = SIMD2<Float>(0, 0)
    var onLook: ((CGFloat, CGFloat) -> Void)?
    var onChop: (() -> Void)?
    var onJump: (() -> Void)?
    var onBuild: (() -> Void)?
    /// Et kort trykk på høyre halvdel, med punktet på skjermen.
    var onTap: ((CGPoint) -> Void)?
    /// Fingeren holdes stille på høyre halvdel. Kommer igjen og igjen så lenge fingeren blir liggende.
    var onHold: ((CGPoint) -> Void)?
    var onPickBlock: ((Int) -> Void)?
    var onBackpack: (() -> Void)?

    private let stickRadius: CGFloat = 64
    private let stickBase = UIView()
    private let stickKnob = UIView()
    private let chopButton = UIView()
    private let jumpButton = UIView()
    private let buildButton = UIView()
    private let backpackButton = UIView()
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
    private var holdTimer: Timer?
    private var holdFired = false
    private var holdStart = Date()
    private var holdLastFire: Date?
    private var buildOn = false
    /// Klossene å velge mellom, nederst på midten når byggingen er på.
    private var hotbar: [UIView] = []
    private var selectedBlock = 0
    /// Når et trykk sist ble sendt videre. To veier kan melde det samme trykket, så det andre blir ignorert.
    private var lastTapFired: TimeInterval = 0
    /// Ekstra vei for trykk: en vanlig trykkgjenkjenner som ikke stjeler fingrene fra resten av styringen.
    /// Den fanger trykket selv om systemet avbryter berøringen i stedet for å avslutte den.
    private lazy var tapRecognizer: UITapGestureRecognizer = {
        let r = UITapGestureRecognizer(target: self, action: #selector(recognizedTap(_:)))
        r.cancelsTouchesInView = false
        r.delaysTouchesBegan = false
        r.delaysTouchesEnded = false
        r.delegate = self
        return r
    }()

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .clear
        isMultipleTouchEnabled = true
        isUserInteractionEnabled = true
        addGestureRecognizer(tapRecognizer)
        print("[Lowe] styringen er laget")

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
        styleButton(backpackButton, size: 70, color: .white)
        let bag = Icons.backpack(58)
        bag.frame.origin = CGPoint(x: 6, y: 5)
        backpackButton.layer.addSublayer(bag)
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
        buildOn = on
        hotbar.forEach { $0.isHidden = !on }
        axeLayer.isHidden = on
        blockLayer.isHidden = !on
        chopButton.backgroundColor = on ? Colors.sun : Colors.turquoise
        buildButton.backgroundColor = on ? Colors.turquoise : .white
    }

    /// Lager raden med klosser å velge mellom. Hver kloss er gitt med farge på toppen, venstre og høyre side.
    func setBlockChoices(_ choices: [(top: UIColor, left: UIColor, right: UIColor)], selected: Int) {
        hotbar.forEach { $0.removeFromSuperview() }
        hotbar = choices.map { colors in
            let slot = UIView(frame: CGRect(x: 0, y: 0, width: 58, height: 58))
            slot.layer.cornerRadius = 14
            slot.backgroundColor = UIColor(white: 0, alpha: 0.35)
            slot.layer.borderColor = UIColor(white: 1, alpha: 0.6).cgColor
            slot.layer.borderWidth = 3
            slot.isUserInteractionEnabled = false
            slot.layer.addSublayer(ControlsView.blockIcon(in: 58, plus: false, top: colors.top, left: colors.left, right: colors.right))
            slot.isHidden = !buildOn
            addSubview(slot)
            return slot
        }
        selectBlock(selected)
        setNeedsLayout()
    }

    private func selectBlock(_ index: Int) {
        selectedBlock = index
        for (i, slot) in hotbar.enumerated() {
            let on = i == index
            slot.layer.borderColor = on ? Colors.turquoise.cgColor : UIColor(white: 1, alpha: 0.6).cgColor
            slot.layer.borderWidth = on ? 6 : 3
            slot.transform = on ? CGAffineTransform(scaleX: 1.15, y: 1.15) : .identity
        }
    }

    /// En trekloss sett litt ovenfra, med et pluss når den betyr «sett en kloss her».
    private static func blockIcon(in size: CGFloat, plus: Bool, top topColor: UIColor = Colors.wood,
                                  left leftColor: UIColor = Colors.barkLight, right rightColor: UIColor = Colors.bark) -> CALayer {
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
        face([top, right, mid, left], topColor)
        face([left, mid, CGPoint(x: mid.x, y: mid.y + s * 1.1), CGPoint(x: left.x, y: left.y + s * 1.1)], leftColor)
        face([mid, right, CGPoint(x: right.x, y: right.y + s * 1.1), CGPoint(x: mid.x, y: mid.y + s * 1.1)], rightColor)
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
    static func pineconeLayer(found: Bool) -> CALayer {
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
        backpackButton.center = CGPoint(x: bounds.maxX - inset.right - margin - 35, y: bounds.minY + inset.top + 46)
        woodIcon.center = CGPoint(x: bounds.minX + inset.left + 36, y: bounds.minY + inset.top + 82)
        woodLabel.frame.origin = CGPoint(x: woodIcon.frame.maxX + 8, y: woodIcon.center.y - woodLabel.bounds.height / 2)
        // Raden står mellom spaken og hoppeknappen.
        let left = inset.left + 40 + stickRadius * 2 + 12
        let right = jumpButton.frame.minX - 12
        let slotGap = min(76, (right - left - 58) / CGFloat(max(1, hotbar.count - 1)))
        let startX = (left + right) / 2 - CGFloat(hotbar.count - 1) * slotGap / 2
        for (i, slot) in hotbar.enumerated() {
            slot.center = CGPoint(x: startX + CGFloat(i) * slotGap, y: bounds.maxY - inset.bottom - 44)
        }
        if stickTouch == nil { placeStickAtRest() }
    }

    /// Spaken står alltid på samme sted nede til venstre.
    private var stickHome: CGPoint {
        let inset = safeAreaInsets
        return CGPoint(x: bounds.minX + inset.left + 40 + stickRadius,
                       y: bounds.maxY - inset.bottom - 30 - stickRadius)
    }

    /// Når ingen holder spaken, står den svakt på plassen sin.
    private func placeStickAtRest() {
        let center = stickHome
        stickBase.center = center
        stickKnob.center = center
        stickBase.alpha = 0.5
        stickKnob.alpha = 0.5
    }

    // MARK: Berøring

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        for touch in touches {
            let p = touch.location(in: self)
            print("[Lowe] finger ned \(p)")
            if let i = hotbar.firstIndex(where: { !$0.isHidden && $0.frame.insetBy(dx: -6, dy: -6).contains(p) }) {
                selectBlock(i)
                onPickBlock?(i)
            } else if hits(chopButton, p) {
                bounce(chopButton)
                onChop?()
            } else if hits(jumpButton, p) {
                bounce(jumpButton)
                onJump?()
            } else if hits(buildButton, p) {
                bounce(buildButton)
                onBuild?()
            } else if hits(backpackButton, p) {
                bounce(backpackButton)
                onBackpack?()
            } else if stickTouch == nil && hypot(p.x - stickHome.x, p.y - stickHome.y) <= stickRadius * 1.5 {
                // Spaken tar bare imot fingre som treffer den. Resten av skjermen er fri til å trykke på ting.
                stickTouch = touch
                stickCenter = stickHome
                stickBase.center = stickHome
                stickKnob.center = stickHome
                stickBase.alpha = 1
                stickKnob.alpha = 1
            } else {
                // En ny finger tar alltid over kameradraget. En gammel finger som aldri ble sluppet
                // (for eksempel fordi systemet tok den), skal ikke stenge for alle trykk etterpå.
                stopHold()
                lookTouch = touch
                lookLast = p
                lookTravel = 0
                lookStartTime = touch.timestamp
                startHold()
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
                if holdFired { continue }
                if lookTravel >= 12 { stopHold() }
                onLook?(dx, dy)
            }
        }
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        print("[Lowe] finger opp (\(touches.count))")
        finish(touches)
    }

    /// Systemet kan avbryte en berøring i stedet for å avslutte den. Et kort, stille trykk teller likevel.
    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        print("[Lowe] finger avbrutt (\(touches.count))")
        finish(touches)
    }

    private func finish(_ touches: Set<UITouch>) {
        for touch in touches {
            if touch === stickTouch {
                stickTouch = nil
                move = .zero
                UIView.animate(withDuration: 0.15) { self.placeStickAtRest() }
            } else if touch === lookTouch {
                lookTouch = nil
                let fired = holdFired
                stopHold()
                let time = touch.timestamp - lookStartTime
                if fired {
                    print("[Lowe] ikke trykk: fingeren holdt en kloss")
                } else if lookTravel >= 24 {
                    print("[Lowe] ikke trykk: fingeren dro \(Int(lookTravel)) punkter")
                } else if time >= 0.8 {
                    print("[Lowe] ikke trykk: fingeren lå i \(String(format: "%.2f", time)) s")
                } else {
                    fireTap(at: touch.location(in: self), from: "berøring")
                }
            } else {
                print("[Lowe] finger opp som ikke var kamerafingeren")
            }
        }
    }

    @objc private func recognizedTap(_ recognizer: UITapGestureRecognizer) {
        guard recognizer.state == .ended else { return }
        fireTap(at: recognizer.location(in: self), from: "gjenkjenner")
    }

    /// Gjenkjenneren skal bare se fingre som ikke treffer knapper, spaken eller klossraden.
    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldReceive touch: UITouch) -> Bool {
        !isOnControl(touch.location(in: self))
    }

    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer,
                           shouldRecognizeSimultaneouslyWith other: UIGestureRecognizer) -> Bool { true }

    private func isOnControl(_ p: CGPoint) -> Bool {
        hotbar.contains(where: { !$0.isHidden && $0.frame.insetBy(dx: -6, dy: -6).contains(p) })
            || hits(chopButton, p) || hits(jumpButton, p) || hits(buildButton, p) || hits(backpackButton, p)
            || hypot(p.x - stickHome.x, p.y - stickHome.y) <= stickRadius * 1.5
    }

    /// Sender trykket videre én gang, og viser en liten ring der fingeren traff.
    private func fireTap(at p: CGPoint, from source: String) {
        let now = ProcessInfo.processInfo.systemUptime
        guard now - lastTapFired > 0.3 else {
            print("[Lowe] trykk fra \(source) var allerede sendt")
            return
        }
        lastTapFired = now
        print("[Lowe] TRYKK fra \(source) på \(p), sendes videre: \(onTap != nil)")
        showRing(at: p)
        onTap?(p)
    }

    private func showRing(at p: CGPoint) {
        let ring = UIView(frame: CGRect(x: 0, y: 0, width: 36, height: 36))
        ring.center = p
        ring.layer.cornerRadius = 18
        ring.layer.borderWidth = 3
        ring.layer.borderColor = Colors.turquoise.cgColor
        ring.isUserInteractionEnabled = false
        addSubview(ring)
        UIView.animate(withDuration: 0.35, animations: {
            ring.transform = CGAffineTransform(scaleX: 1.8, y: 1.8)
            ring.alpha = 0
        }) { _ in ring.removeFromSuperview() }
    }

    /// Når byggingen er på og fingeren blir liggende stille, tas klossen under fingeren bort,
    /// og så en til så lenge fingeren blir liggende.
    private func startHold() {
        stopHold()
        guard buildOn else { return }
        holdStart = Date()
        holdLastFire = nil
        holdTimer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.holdTick() }
        }
    }

    private func holdTick() {
        guard lookTouch != nil else { return }
        let now = Date()
        let since = now.timeIntervalSince(holdLastFire ?? holdStart)
        guard since > 0.4 else { return }
        holdLastFire = now
        holdFired = true
        lastTapFired = ProcessInfo.processInfo.systemUptime + 0.5
        onHold?(lookLast)
    }

    private func stopHold() {
        holdTimer?.invalidate()
        holdTimer = nil
        holdFired = false
    }

    /// Slipper spaken og kameradraget, for eksempel når ryggsekken åpnes over styringen.
    func reset() {
        stickTouch = nil
        lookTouch = nil
        move = .zero
        stopHold()
        placeStickAtRest()
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
