import RealityKit
import UIKit

/// Det Lowe samler i ryggsekken.
enum Resource: Int, CaseIterable {
    case wood, cone, stone
}

/// Ting Lowe kan lage av det han har samlet, og sette ut i skogen.
enum Thing: Int, CaseIterable {
    case sled, lantern, birdhouse

    /// Hva tingen koster.
    var recipe: [(Resource, Int)] {
        switch self {
        case .sled: return [(.wood, 4), (.stone, 1)]
        case .lantern: return [(.wood, 1), (.stone, 2)]
        case .birdhouse: return [(.wood, 3), (.cone, 2)]
        }
    }
}

/// Ryggsekken: kongler, steiner og tingene Lowe har laget. Veden telles i Forest. Alt huskes.
@MainActor
final class Backpack {
    var cones = UserDefaults.standard.integer(forKey: "lowe.bag.cones") {
        didSet { UserDefaults.standard.set(cones, forKey: "lowe.bag.cones") }
    }
    var stones = UserDefaults.standard.integer(forKey: "lowe.bag.stones") {
        didSet { UserDefaults.standard.set(stones, forKey: "lowe.bag.stones") }
    }
    private var things: [Int] = UserDefaults.standard.array(forKey: "lowe.bag.things") as? [Int] ?? []

    func count(of thing: Thing) -> Int {
        things.indices.contains(thing.rawValue) ? things[thing.rawValue] : 0
    }

    func add(_ thing: Thing, _ amount: Int = 1) {
        while things.count <= thing.rawValue { things.append(0) }
        things[thing.rawValue] = max(0, things[thing.rawValue] + amount)
        UserDefaults.standard.set(things, forKey: "lowe.bag.things")
    }
}

// MARK: Tingene i skogen

/// Tingene Lowe har satt ut: lykter som lyser om natta, fuglekasser med en fugl, og akebrett.
/// Hvor de står, huskes.
@MainActor
final class PlacedThings {
    final class Placed {
        let thing: Thing
        let entity: Entity
        let light: PointLight?
        let bird: Entity?
        let phase: Float

        init(thing: Thing, entity: Entity, light: PointLight?, bird: Entity?, phase: Float) {
            self.thing = thing
            self.entity = entity
            self.light = light
            self.bird = bird
            self.phase = phase
        }
    }

    private let world: Entity
    private(set) var placed: [Placed] = []
    private var time: Float = 0
    private let saveKey = "lowe.things"

    init(world: Entity) {
        self.world = world
        load()
    }

    @discardableResult
    func place(_ thing: Thing, at p: SIMD3<Float>, yaw: Float, save shouldSave: Bool = true) -> Entity {
        let entity = ThingModels.build(thing)
        entity.position = p
        entity.orientation = rotY(yaw)
        world.addChild(entity)
        var light: PointLight?
        if thing == .lantern {
            let l = PointLight()
            l.light.color = UIColor(hex: 0xFFC56B)
            l.light.intensity = 0
            l.light.attenuationRadius = 5
            l.position = [0, 0.35, 0]
            entity.addChild(l)
            light = l
        }
        let bird = entity.findEntity(named: "bird")
        placed.append(Placed(thing: thing, entity: entity, light: light, bird: bird, phase: Float(placed.count) * 1.7))
        if shouldSave {
            save()
            entity.scale = [0.3, 0.3, 0.3]
            entity.move(to: Transform(scale: [1, 1, 1], rotation: entity.orientation, translation: p),
                        relativeTo: entity.parent, duration: 0.2)
        }
        return entity
    }

    /// Tar tingen bort fra skogen og gir hva det var.
    func remove(_ entity: Entity) -> Thing? {
        guard let i = placed.firstIndex(where: { $0.entity === entity }) else { return nil }
        let thing = placed[i].thing
        placed.remove(at: i)
        entity.removeFromParent()
        save()
        return thing
    }

    /// Akebrett, lykter og fuglekasser er i veien for Lowe, men ikke mye.
    func obstacles(near p: SIMD3<Float>) -> [(SIMD3<Float>, Float)] {
        placed.compactMap { item in
            guard item.thing != .sled else { return nil }
            let q = item.entity.position
            guard abs(q.x - p.x) < 2, abs(q.z - p.z) < 2 else { return nil }
            return (SIMD3(q.x, 0, q.z), item.thing == .birdhouse ? 0.3 : 0.2)
        }
    }

    func update(_ dt: Float, daylight: Float) {
        time += dt
        for item in placed {
            if let light = item.light {
                let flicker = 1 + 0.06 * sin(time * 11 + item.phase)
                light.light.intensity = (300 + 4000 * (1 - daylight)) * flicker
            }
            if let bird = item.bird {
                // Fuglen sitter på pinnen, vipper og hopper litt, og tar en liten runde nå og da.
                let cycle = fmod(time + item.phase * 3, 9)
                if cycle > 7.5 {
                    let a = (cycle - 7.5) / 1.5 * 2 * .pi
                    bird.position = [sin(a) * 0.45, 1.36 + sin(a / 2) * 0.35, 0.22 + (cos(a) - 1) * 0.45 * -0.5]
                    bird.orientation = rotY(a + .pi / 2)
                } else {
                    let hop = max(0, sin(time * 5 + item.phase)) * (cycle.truncatingRemainder(dividingBy: 3) < 0.6 ? 0.06 : 0)
                    bird.position = [0, 1.36 + hop, 0.22]
                    bird.orientation = rotY(sin(time * 1.3 + item.phase) * 0.6)
                }
            }
        }
    }

    private func save() {
        var numbers: [Int] = []
        for item in placed {
            let p = item.entity.position
            let yaw = 2 * atan2(item.entity.orientation.imag.y, item.entity.orientation.real)
            numbers += [item.thing.rawValue, Int(p.x * 100), Int(p.y * 100), Int(p.z * 100), Int(yaw * 100)]
        }
        UserDefaults.standard.set(numbers, forKey: saveKey)
    }

    private func load() {
        guard let numbers = UserDefaults.standard.array(forKey: saveKey) as? [Int] else { return }
        var i = 0
        while i + 4 < numbers.count {
            if let thing = Thing(rawValue: numbers[i]) {
                let p = SIMD3<Float>(Float(numbers[i + 1]), Float(numbers[i + 2]), Float(numbers[i + 3])) / 100
                place(thing, at: p, yaw: Float(numbers[i + 4]) / 100, save: false)
            }
            i += 5
        }
    }
}

/// Tingene bygd av enkle former. Alle står med bunnen i (0, 0, 0) og ser langs +z.
@MainActor
enum ThingModels {
    static func build(_ thing: Thing) -> Entity {
        switch thing {
        case .sled: return sled()
        case .lantern: return lantern()
        case .birdhouse: return birdhouse()
        }
    }

    /// Et akebrett av tre med svarte meier som bøyer seg opp foran, og et turkis tau.
    static func sled() -> Entity {
        let sled = Entity()
        Make.part(Make.box(0.42, 0.05, 0.86, r: 0.02), Colors.wood, at: [0, 0.13, -0.02], in: sled)
        for z in [Float(-0.3), 0, 0.3] {
            Make.part(Make.box(0.44, 0.012, 0.05, r: 0.004), Colors.barkLine, at: [0, 0.157, z], in: sled)
        }
        for x in [Float(0.17), -0.17] {
            Make.part(Make.box(0.04, 0.04, 0.96, r: 0.015), Colors.ink, at: [x, 0.02, 0], in: sled)
            let curl = Make.part(Make.box(0.04, 0.04, 0.2, r: 0.015), Colors.ink, at: [x, 0.09, 0.52], in: sled)
            curl.orientation = rotX(-0.9)
            Make.part(Make.box(0.03, 0.1, 0.03), Colors.ink, at: [x, 0.07, -0.3], in: sled)
            Make.part(Make.box(0.03, 0.1, 0.03), Colors.ink, at: [x, 0.07, 0.25], in: sled)
        }
        let rope = Make.part(Make.box(0.36, 0.025, 0.025), Colors.turquoise, at: [0, 0.18, 0.6], in: sled)
        rope.orientation = rotX(0.2)
        return sled
    }

    /// En lykt som lyser gult. Lyset er sterkest om natta.
    static func lantern() -> Entity {
        let lantern = Entity()
        Make.part(Make.box(0.24, 0.05, 0.24, r: 0.015), Colors.ink, at: [0, 0.025, 0], in: lantern)
        let glass = ModelEntity(mesh: Make.box(0.18, 0.24, 0.18, r: 0.02), materials: [UnlitMaterial(color: UIColor(hex: 0xFFE08A))])
        glass.position = [0, 0.17, 0]
        lantern.addChild(glass)
        for (x, z) in [(Float(0.095), Float(0.095)), (-0.095, 0.095), (0.095, -0.095), (-0.095, -0.095)] {
            Make.part(Make.box(0.025, 0.26, 0.025), Colors.ink, at: [x, 0.17, z], in: lantern)
        }
        let flame = ModelEntity(mesh: Make.cone(0.1, 0.035), materials: [UnlitMaterial(color: Colors.flame)])
        flame.position = [0, 0.13, 0]
        lantern.addChild(flame)
        Make.part(Make.cone(0.1, 0.15), Colors.ink, at: [0, 0.3, 0], in: lantern)
        let handle = Make.part(Make.cylinder(0.02, 0.06), Colors.turquoise, at: [0, 0.4, 0], in: lantern)
        handle.orientation = rotX(.pi / 2)
        return lantern
    }

    /// En fuglekasse på en stolpe, med turkist tak og en liten fugl på pinnen.
    static func birdhouse() -> Entity {
        let house = Entity()
        Make.part(Make.cylinder(1.0, 0.045), Colors.bark, at: [0, 0.5, 0], in: house)
        Make.part(Make.box(0.36, 0.32, 0.32, r: 0.02), Colors.barkLight, at: [0, 1.15, 0], in: house)
        for side in [Float(1), -1] {
            let roof = Make.part(Make.box(0.27, 0.035, 0.4, r: 0.01), Colors.turquoise, at: [side * 0.1, 1.39, 0], in: house)
            roof.orientation = rotZ(side * -0.65)
        }
        let hole = Make.part(Make.cylinder(0.01, 0.06), Colors.ink, at: [0, 1.18, 0.161], in: house)
        hole.orientation = rotX(.pi / 2)
        let perch = Make.part(Make.cylinder(0.12, 0.012), Colors.bark, at: [0, 1.06, 0.2], in: house)
        perch.orientation = rotX(.pi / 2)

        let bird = Entity()
        bird.name = "bird"
        bird.position = [0, 1.36, 0.22]
        house.addChild(bird)
        let red = UIColor(hex: 0xE2553B)
        let body = Make.part(Make.sphere(0.06), UIColor(hex: 0x7A6A5C), at: [0, 0.05, 0], in: bird)
        body.scale = [0.9, 0.9, 1.2]
        Make.part(Make.sphere(0.045), red, at: [0, 0.05, 0.035], in: bird)
        Make.part(Make.sphere(0.04), UIColor(hex: 0x7A6A5C), at: [0, 0.11, 0.04], in: bird)
        let beak = Make.part(Make.cone(0.03, 0.012), Colors.sun, at: [0, 0.11, 0.085], in: bird)
        beak.orientation = rotX(.pi / 2)
        for x in [Float(0.018), -0.018] {
            Make.part(Make.sphere(0.008), Colors.ink, at: [x, 0.12, 0.072], in: bird)
        }
        let tail = Make.part(Make.box(0.04, 0.012, 0.07), UIColor(hex: 0x5E5046), at: [0, 0.06, -0.08], in: bird)
        tail.orientation = rotX(-0.4)
        return house
    }
}

extension Make {
    /// En grå stein i snøen, med en mindre stein inntil.
    static func stone() -> Entity {
        let stone = Entity()
        let big = part(sphere(0.14), Colors.stone, at: [0, 0.07, 0], in: stone)
        big.scale = [1.2, 0.65, 1]
        let small = part(sphere(0.07), UIColor(hex: 0x8794A0), at: [0.13, 0.035, 0.06], in: stone)
        small.scale = [1, 0.7, 1]
        part(sphere(0.06), Colors.snow, at: [-0.03, 0.12, -0.01], in: stone).scale = [1.3, 0.35, 1]
        return stone
    }
}

// MARK: Bilder

/// Små tegninger til ryggsekken og knappene. Alt tegnes i en rute på 100 x 100 og skaleres.
@MainActor
enum Icons {
    private static func canvas(_ size: CGFloat, _ draw: (CALayer) -> Void) -> CALayer {
        let layer = CALayer()
        layer.frame = CGRect(x: 0, y: 0, width: size, height: size)
        let g = CALayer()
        g.bounds = CGRect(x: 0, y: 0, width: 100, height: 100)
        g.position = CGPoint(x: size / 2, y: size / 2)
        g.setAffineTransform(CGAffineTransform(scaleX: size / 100, y: size / 100))
        draw(g)
        layer.addSublayer(g)
        return layer
    }

    private static func shape(_ path: UIBezierPath, _ fill: UIColor?, stroke: UIColor? = Colors.ink,
                              width: CGFloat = 5, in g: CALayer) {
        let s = CAShapeLayer()
        s.path = path.cgPath
        s.fillColor = fill?.cgColor
        s.strokeColor = stroke?.cgColor
        s.lineWidth = width
        s.lineJoin = .round
        s.lineCap = .round
        g.addSublayer(s)
    }

    static func resource(_ r: Resource, size: CGFloat) -> CALayer {
        switch r {
        case .wood: return wood(size)
        case .cone: return cone(size)
        case .stone: return stone(size)
        }
    }

    static func thing(_ t: Thing, size: CGFloat) -> CALayer {
        switch t {
        case .sled: return sled(size)
        case .lantern: return lantern(size)
        case .birdhouse: return birdhouse(size)
        }
    }

    static func wood(_ size: CGFloat) -> CALayer {
        canvas(size) { g in
            shape(UIBezierPath(roundedRect: CGRect(x: 8, y: 30, width: 84, height: 40), cornerRadius: 20), Colors.bark, in: g)
            shape(UIBezierPath(ovalIn: CGRect(x: 60, y: 34, width: 28, height: 32)), Colors.wood, in: g)
            shape(UIBezierPath(ovalIn: CGRect(x: 69, y: 45, width: 10, height: 10)), nil, stroke: Colors.barkLine, width: 3, in: g)
        }
    }

    static func cone(_ size: CGFloat) -> CALayer {
        let layer = CALayer()
        layer.frame = CGRect(x: 0, y: 0, width: size, height: size)
        let cone = ControlsView.pineconeLayer(found: true)
        let scale = size / 42
        cone.position = CGPoint(x: size / 2, y: size / 2)
        cone.setAffineTransform(CGAffineTransform(scaleX: scale, y: scale))
        layer.addSublayer(cone)
        return layer
    }

    static func stone(_ size: CGFloat) -> CALayer {
        canvas(size) { g in
            shape(UIBezierPath(ovalIn: CGRect(x: 10, y: 34, width: 66, height: 44)), Colors.stone, in: g)
            shape(UIBezierPath(ovalIn: CGRect(x: 58, y: 54, width: 32, height: 26)), UIColor(hex: 0x8794A0), in: g)
            shape(UIBezierPath(ovalIn: CGRect(x: 24, y: 42, width: 22, height: 9)), UIColor(white: 1, alpha: 0.7), stroke: nil, in: g)
        }
    }

    static func sled(_ size: CGFloat) -> CALayer {
        canvas(size) { g in
            let runner = UIBezierPath()
            runner.move(to: CGPoint(x: 8, y: 72))
            runner.addLine(to: CGPoint(x: 78, y: 72))
            runner.addQuadCurve(to: CGPoint(x: 90, y: 52), controlPoint: CGPoint(x: 96, y: 72))
            shape(runner, nil, width: 7, in: g)
            for x in [CGFloat(22), 64] {
                let leg = UIBezierPath()
                leg.move(to: CGPoint(x: x, y: 58))
                leg.addLine(to: CGPoint(x: x, y: 72))
                shape(leg, nil, width: 6, in: g)
            }
            shape(UIBezierPath(roundedRect: CGRect(x: 8, y: 44, width: 78, height: 16), cornerRadius: 6), Colors.wood, in: g)
            let rope = UIBezierPath()
            rope.move(to: CGPoint(x: 86, y: 50))
            rope.addQuadCurve(to: CGPoint(x: 96, y: 30), controlPoint: CGPoint(x: 100, y: 44))
            shape(rope, nil, stroke: Colors.turquoise, width: 5, in: g)
        }
    }

    static func lantern(_ size: CGFloat) -> CALayer {
        canvas(size) { g in
            shape(UIBezierPath(ovalIn: CGRect(x: 18, y: 22, width: 64, height: 64)), UIColor(hex: 0xFFE08A).withAlphaComponent(0.45), stroke: nil, in: g)
            let handle = UIBezierPath(arcCenter: CGPoint(x: 50, y: 20), radius: 10, startAngle: .pi, endAngle: 0, clockwise: true)
            shape(handle, nil, stroke: Colors.turquoise, width: 5, in: g)
            let cap = UIBezierPath()
            cap.move(to: CGPoint(x: 30, y: 34))
            cap.addLine(to: CGPoint(x: 50, y: 20))
            cap.addLine(to: CGPoint(x: 70, y: 34))
            cap.close()
            shape(cap, Colors.ink, in: g)
            shape(UIBezierPath(roundedRect: CGRect(x: 33, y: 34, width: 34, height: 42), cornerRadius: 5), UIColor(hex: 0xFFE08A), in: g)
            let flame = UIBezierPath()
            flame.move(to: CGPoint(x: 50, y: 44))
            flame.addQuadCurve(to: CGPoint(x: 50, y: 68), controlPoint: CGPoint(x: 62, y: 62))
            flame.addQuadCurve(to: CGPoint(x: 50, y: 44), controlPoint: CGPoint(x: 38, y: 62))
            shape(flame, Colors.flame, stroke: nil, in: g)
            shape(UIBezierPath(roundedRect: CGRect(x: 28, y: 76, width: 44, height: 9), cornerRadius: 3), Colors.ink, in: g)
        }
    }

    static func birdhouse(_ size: CGFloat) -> CALayer {
        canvas(size) { g in
            shape(UIBezierPath(rect: CGRect(x: 45, y: 72, width: 10, height: 24)), Colors.bark, in: g)
            shape(UIBezierPath(rect: CGRect(x: 26, y: 38, width: 48, height: 36)), Colors.barkLight, in: g)
            let roof = UIBezierPath()
            roof.move(to: CGPoint(x: 16, y: 42))
            roof.addLine(to: CGPoint(x: 50, y: 12))
            roof.addLine(to: CGPoint(x: 84, y: 42))
            roof.close()
            shape(roof, Colors.turquoise, in: g)
            shape(UIBezierPath(ovalIn: CGRect(x: 42, y: 46, width: 16, height: 16)), Colors.ink, stroke: nil, in: g)
            let perch = UIBezierPath()
            perch.move(to: CGPoint(x: 50, y: 67))
            perch.addLine(to: CGPoint(x: 64, y: 67))
            shape(perch, nil, width: 4, in: g)
        }
    }

    static func backpack(_ size: CGFloat) -> CALayer {
        canvas(size) { g in
            let strap = UIBezierPath(arcCenter: CGPoint(x: 50, y: 24), radius: 13, startAngle: .pi, endAngle: 0, clockwise: true)
            shape(strap, nil, width: 6, in: g)
            shape(UIBezierPath(roundedRect: CGRect(x: 20, y: 24, width: 60, height: 66), cornerRadius: 16), Colors.turquoise, in: g)
            let flap = UIBezierPath(roundedRect: CGRect(x: 20, y: 24, width: 60, height: 28),
                                    byRoundingCorners: [.topLeft, .topRight], cornerRadii: CGSize(width: 16, height: 16))
            shape(flap, UIColor(hex: 0x179A9A), in: g)
            shape(UIBezierPath(roundedRect: CGRect(x: 32, y: 60, width: 36, height: 20), cornerRadius: 6), UIColor(hex: 0x179A9A), in: g)
            shape(UIBezierPath(ovalIn: CGRect(x: 45, y: 45, width: 10, height: 10)), Colors.sun, width: 3, in: g)
        }
    }

    static func close(_ size: CGFloat) -> CALayer {
        canvas(size) { g in
            let x = UIBezierPath()
            x.move(to: CGPoint(x: 30, y: 30))
            x.addLine(to: CGPoint(x: 70, y: 70))
            x.move(to: CGPoint(x: 70, y: 30))
            x.addLine(to: CGPoint(x: 30, y: 70))
            shape(x, nil, width: 11, in: g)
        }
    }
}

// MARK: Ryggsekken på skjermen

/// Ryggsekken åpnet: øverst det Lowe har samlet, i midten det han kan lage, og nederst tingene han har laget.
/// Bare bilder og tall. Et trykk på en oppskrift lager tingen, et trykk på en ting setter den ut i skogen.
final class BackpackView: UIView {
    var onMake: ((Thing) -> Void)?
    var onUse: ((Thing) -> Void)?
    var onClose: (() -> Void)?

    private let panel = UIView()
    private let closeButton = UIButton(type: .custom)
    private var resourceViews: [(Resource, UIView, UILabel)] = []
    private var recipeCards: [(Thing, UIButton)] = []
    private var thingSlots: [(Thing, UIButton, UILabel)] = []

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = UIColor(white: 0, alpha: 0.45)
        autoresizingMask = [.flexibleWidth, .flexibleHeight]

        panel.backgroundColor = UIColor(hex: 0xFFF7EE)
        panel.layer.cornerRadius = 28
        panel.layer.borderColor = Colors.ink.cgColor
        panel.layer.borderWidth = 5
        addSubview(panel)

        closeButton.frame.size = CGSize(width: 50, height: 50)
        closeButton.layer.cornerRadius = 25
        closeButton.backgroundColor = .white
        closeButton.layer.borderColor = Colors.ink.cgColor
        closeButton.layer.borderWidth = 4
        let x = Icons.close(50)
        closeButton.layer.addSublayer(x)
        closeButton.addTarget(self, action: #selector(closeTapped), for: .touchUpInside)
        panel.addSubview(closeButton)

        for r in Resource.allCases {
            let holder = UIView(frame: CGRect(x: 0, y: 0, width: 110, height: 50))
            holder.isUserInteractionEnabled = false
            let icon = Icons.resource(r, size: 46)
            icon.frame.origin = CGPoint(x: 0, y: 2)
            holder.layer.addSublayer(icon)
            let label = Self.numberLabel(size: 28)
            label.frame = CGRect(x: 52, y: 0, width: 58, height: 50)
            holder.addSubview(label)
            panel.addSubview(holder)
            resourceViews.append((r, holder, label))
        }

        for t in Thing.allCases {
            let card = UIButton(type: .custom)
            card.backgroundColor = .white
            card.layer.cornerRadius = 20
            card.layer.borderColor = Colors.ink.cgColor
            card.layer.borderWidth = 4
            card.tag = t.rawValue
            card.addTarget(self, action: #selector(recipeTapped(_:)), for: .touchUpInside)
            panel.addSubview(card)
            recipeCards.append((t, card))
        }

        for t in Thing.allCases {
            let slot = UIButton(type: .custom)
            slot.frame.size = CGSize(width: 66, height: 66)
            slot.backgroundColor = UIColor(hex: 0xEDE3D6)
            slot.layer.cornerRadius = 16
            slot.layer.borderColor = Colors.ink.cgColor
            slot.layer.borderWidth = 3
            slot.tag = t.rawValue
            let icon = Icons.thing(t, size: 58)
            icon.frame.origin = CGPoint(x: 4, y: 4)
            slot.layer.addSublayer(icon)
            let badge = Self.numberLabel(size: 18)
            badge.backgroundColor = Colors.turquoise
            badge.layer.cornerRadius = 13
            badge.layer.masksToBounds = true
            badge.layer.borderColor = Colors.ink.cgColor
            badge.layer.borderWidth = 2.5
            badge.frame = CGRect(x: 44, y: -8, width: 30, height: 26)
            badge.shadowColor = nil
            slot.addSubview(badge)
            slot.addTarget(self, action: #selector(thingTapped(_:)), for: .touchUpInside)
            panel.addSubview(slot)
            thingSlots.append((t, slot, badge))
        }

        addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(backgroundTapped(_:))))
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) is not used") }

    private static func numberLabel(size: CGFloat) -> UILabel {
        let label = UILabel()
        label.font = UIFont.systemFont(ofSize: size, weight: .black)
        label.textColor = Colors.ink
        label.textAlignment = .center
        label.isUserInteractionEnabled = false
        return label
    }

    /// Fyller inn tallene og gjør oppskriftene Lowe ikke har nok til, bleke.
    func refresh(have: (Resource) -> Int, things: (Thing) -> Int) {
        for (r, _, label) in resourceViews {
            label.text = "\(have(r))"
            label.textAlignment = .left
        }
        for (t, card) in recipeCards {
            let affordable = t.recipe.allSatisfy { have($0.0) >= $0.1 }
            card.alpha = affordable ? 1 : 0.45
            card.layer.borderColor = (affordable ? Colors.turquoise : Colors.ink).cgColor
            card.layer.borderWidth = affordable ? 6 : 4
        }
        for (t, slot, badge) in thingSlots {
            let n = things(t)
            badge.text = "\(n)"
            badge.isHidden = n == 0
            slot.alpha = n > 0 ? 1 : 0.35
        }
    }

    /// Kortet hopper litt når tingen blir laget, eller rister når det ikke er nok.
    func bounce(_ thing: Thing, made: Bool) {
        guard let card = recipeCards.first(where: { $0.0 == thing })?.1 else { return }
        if made {
            card.transform = CGAffineTransform(scaleX: 1.15, y: 1.15)
            UIView.animate(withDuration: 0.35, delay: 0, usingSpringWithDamping: 0.5, initialSpringVelocity: 3) {
                card.transform = .identity
            }
        } else {
            let shake = CAKeyframeAnimation(keyPath: "transform.translation.x")
            shake.values = [0, -10, 10, -6, 6, 0]
            shake.duration = 0.35
            card.layer.add(shake, forKey: "shake")
        }
        if made, let slot = thingSlots.first(where: { $0.0 == thing })?.1 {
            slot.transform = CGAffineTransform(scaleX: 1.4, y: 1.4)
            UIView.animate(withDuration: 0.4, delay: 0.1, usingSpringWithDamping: 0.45, initialSpringVelocity: 3) {
                slot.transform = .identity
            }
        }
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        let inset = safeAreaInsets
        let w = min(bounds.width - inset.left - inset.right - 40, 640)
        let h = min(bounds.height - inset.top - inset.bottom - 24, 340)
        panel.frame = CGRect(x: bounds.midX - w / 2, y: bounds.midY - h / 2, width: w, height: h)
        closeButton.center = CGPoint(x: w - 42, y: 42)

        // Øverst: det Lowe har samlet.
        let gap = (w - 60 - 60) / CGFloat(resourceViews.count)
        for (i, (_, holder, _)) in resourceViews.enumerated() {
            holder.frame.origin = CGPoint(x: 30 + CGFloat(i) * gap + (gap - 110) / 2, y: 14)
        }

        // I midten: det Lowe kan lage.
        let cardTop: CGFloat = 76
        let bottomRow: CGFloat = 86
        let cardH = h - cardTop - bottomRow - 10
        let cardW = (w - 4 * 18) / CGFloat(recipeCards.count)
        for (i, (t, card)) in recipeCards.enumerated() {
            card.frame = CGRect(x: 18 + CGFloat(i) * (cardW + 18), y: cardTop, width: cardW, height: cardH)
            card.subviews.forEach { $0.removeFromSuperview() }
            card.layer.sublayers?.filter { $0.name == "art" }.forEach { $0.removeFromSuperlayer() }
            let picture = min(cardH - 46, cardW - 20)
            let art = Icons.thing(t, size: picture)
            art.name = "art"
            art.frame.origin = CGPoint(x: (cardW - picture) / 2, y: 4)
            card.layer.addSublayer(art)
            let cost = UIView()
            cost.isUserInteractionEnabled = false
            var x: CGFloat = 0
            for (r, n) in t.recipe {
                let icon = Icons.resource(r, size: 30)
                icon.frame.origin = CGPoint(x: x, y: 0)
                cost.layer.addSublayer(icon)
                let label = Self.numberLabel(size: 20)
                label.text = "\(n)"
                label.textAlignment = .left
                label.frame = CGRect(x: x + 30, y: 0, width: 22, height: 30)
                cost.addSubview(label)
                x += 58
            }
            cost.frame = CGRect(x: (cardW - x + 6) / 2, y: cardH - 40, width: x, height: 30)
            card.addSubview(cost)
        }

        // Nederst: tingene Lowe har laget.
        let slotGap: CGFloat = 92
        let startX = w / 2 - CGFloat(thingSlots.count - 1) * slotGap / 2
        for (i, (_, slot, _)) in thingSlots.enumerated() {
            slot.center = CGPoint(x: startX + CGFloat(i) * slotGap, y: h - bottomRow / 2 - 4)
        }
    }

    @objc private func closeTapped() { onClose?() }

    @objc private func recipeTapped(_ sender: UIButton) {
        if let t = Thing(rawValue: sender.tag) { onMake?(t) }
    }

    @objc private func thingTapped(_ sender: UIButton) {
        if let t = Thing(rawValue: sender.tag) { onUse?(t) }
    }

    @objc private func backgroundTapped(_ recognizer: UITapGestureRecognizer) {
        if !panel.frame.contains(recognizer.location(in: self)) { onClose?() }
    }
}
