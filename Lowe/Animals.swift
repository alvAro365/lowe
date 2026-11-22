import SpriteKit

/// Skogsvennene som kommer på besøk, i rekkefølgen de kommer.
enum Animal: Int, CaseIterable {
    case hedgehog, fox, moose, bear, owl

    /// Hvor stort dyret står ved vedstabelen.
    var visitorScale: CGFloat { self == .moose ? 0.6 : 0.55 }

    /// Fargen på hytta dyret får i landsbyen.
    var cabinColor: SKColor {
        switch self {
        case .hedgehog: return SKColor(hex: 0x8A5A36)
        case .fox: return SKColor(hex: 0xB4693F)
        case .moose: return SKColor(hex: 0xC8553D)
        case .bear: return SKColor(hex: 0x7A5236)
        case .owl: return SKColor(hex: 0x8C7A6B)
        }
    }

    /// Hvor hytta står i landsbyen (nederste venstre hjørne) og hvor stor den er.
    var homeSlot: (position: CGPoint, scale: CGFloat) {
        switch self {
        case .hedgehog: return (CGPoint(x: 110, y: 680), 1)
        case .fox: return (CGPoint(x: 300, y: 585), 0.8)
        case .moose: return (CGPoint(x: 760, y: 590), 1.05)
        case .bear: return (CGPoint(x: 930, y: 690), 1)
        case .owl: return (CGPoint(x: 1000, y: 560), 0.7)
        }
    }

    /// Dyret med føttene i (0, 0), vendt mot høyre. Øynene heter "eye" så de kan blunke.
    @MainActor
    func build() -> SKNode {
        let n = SKNode()
        let body = SKNode()
        n.addChild(body)
        switch self {
        case .hedgehog: AnimalArt.hedgehog(body)
        case .fox: AnimalArt.fox(body)
        case .moose: AnimalArt.moose(body)
        case .bear: AnimalArt.bear(body)
        case .owl: AnimalArt.owl(body)
        }
        return n
    }
}

/// Tegningene fra designtavla «Skogsvennene» (0–200 i hver retning).
@MainActor
enum AnimalArt {
    private static let ink = Palette.ink

    private static func eye(_ body: SKNode, _ x: CGFloat, _ y: CGFloat, rx: CGFloat = 5, ry: CGFloat = 6) {
        let e = SKNode()
        e.name = "eye"
        e.position = CGPoint(x: x, y: y)
        e.addChild(Shape.node(Shape.ellipse(0, 0, rx, ry), fill: ink))
        e.addChild(Shape.node(Shape.circle(1.5, -2, 1.8), fill: Palette.white))
        body.addChild(e)
    }

    private static func ellipse(_ body: SKNode, _ cx: CGFloat, _ cy: CGFloat, _ rx: CGFloat, _ ry: CGFloat,
                                _ fill: SKColor, stroke: Bool = true) {
        body.addChild(Shape.node(Shape.ellipse(cx, cy, rx, ry), fill: fill, stroke: stroke ? ink : nil))
    }

    static func hedgehog(_ body: SKNode) {
        body.position = CGPoint(x: -106, y: -172)
        ellipse(body, 72, 166, 14, 7, Palette.hogFeet)
        ellipse(body, 140, 166, 14, 7, Palette.hogFeet)
        body.addChild(Shape.svg("M24 160 L30 124 L44 132 L46 96 L64 110 L72 74 L90 96 L104 66 L116 94 L134 76 L140 106 L158 100 L156 128 L150 160 Z", fill: Palette.hogSpikes))
        body.addChild(Shape.svg("M118 160 Q112 112 150 108 Q182 112 192 140 Q186 160 150 162 Z", fill: Palette.hogFace))
        ellipse(body, 192, 140, 7, 7, ink)
        eye(body, 156, 128)
        ellipse(body, 150, 146, 7, 7, Palette.cheek, stroke: false)
        body.addChild(Shape.svg("M164 150 Q172 156 180 150", width: 3))
    }

    static func fox(_ body: SKNode) {
        let orange = SKColor(hex: 0xE8803A)
        let cream = SKColor(hex: 0xFFF7EE)
        body.position = CGPoint(x: -100, y: -191)
        body.addChild(Shape.svg("M126 176 Q196 170 184 96 Q174 140 128 150 Z", fill: orange))
        body.addChild(Shape.svg("M184 96 Q192 120 180 138 Q170 124 184 96 Z", fill: cream))
        ellipse(body, 100, 146, 38, 40, orange)
        ellipse(body, 100, 156, 19, 26, cream)
        ellipse(body, 82, 184, 12, 7, ink)
        ellipse(body, 118, 184, 12, 7, ink)
        body.addChild(Shape.svg("M64 66 L70 22 L96 52 Z", fill: orange))
        body.addChild(Shape.svg("M136 66 L130 22 L104 52 Z", fill: orange))
        body.addChild(Shape.svg("M71 52 L73 34 L84 48 Z M129 52 L127 34 L116 48 Z", fill: ink, width: 2))
        ellipse(body, 100, 80, 42, 33, orange)
        body.addChild(Shape.svg("M74 86 Q100 122 126 86 Q100 98 74 86 Z", fill: cream))
        ellipse(body, 100, 104, 6, 6, ink)
        eye(body, 85, 76)
        eye(body, 115, 76)
    }

    static func moose(_ body: SKNode) {
        let fur = SKColor(hex: 0x7A5236)
        let leg = SKColor(hex: 0x6A452C)
        let antler = SKColor(hex: 0xE9D3A8)
        body.position = CGPoint(x: -100, y: -240)
        for x in [CGFloat(62), 84, 106, 128] {
            body.addChild(Shape.node(Shape.rect(x, 200, 12, 40, r: 5), fill: leg, stroke: ink))
        }
        ellipse(body, 100, 196, 54, 26, fur)
        body.addChild(Shape.svg("M72 66 Q30 70 18 36 Q34 46 38 30 Q46 48 54 28 Q60 50 70 34 Q80 54 80 70 Z", fill: antler))
        body.addChild(Shape.svg("M128 66 Q170 70 182 36 Q166 46 162 30 Q154 48 146 28 Q140 50 130 34 Q120 54 120 70 Z", fill: antler))
        body.addChild(Shape.svg("M70 86 Q44 80 40 94 Q56 102 72 98 Z", fill: fur))
        body.addChild(Shape.svg("M130 86 Q156 80 160 94 Q144 102 128 98 Z", fill: fur))
        ellipse(body, 100, 104, 32, 44, fur)
        ellipse(body, 100, 140, 30, 22, SKColor(hex: 0x9C6E4C))
        ellipse(body, 90, 140, 4, 6, ink, stroke: false)
        ellipse(body, 110, 140, 4, 6, ink, stroke: false)
        body.addChild(Shape.svg("M92 152 Q100 158 108 152", width: 3))
        eye(body, 87, 96)
        eye(body, 113, 96)
    }

    static func bear(_ body: SKNode) {
        let fur = SKColor(hex: 0x6E4B33)
        let muzzle = SKColor(hex: 0xC9A27A)
        body.position = CGPoint(x: -100, y: -199)
        ellipse(body, 100, 152, 54, 42, fur)
        ellipse(body, 100, 162, 30, 26, SKColor(hex: 0xA07A56))
        ellipse(body, 74, 190, 16, 9, SKColor(hex: 0x5A3C28))
        ellipse(body, 126, 190, 16, 9, SKColor(hex: 0x5A3C28))
        ellipse(body, 64, 52, 15, 15, fur)
        ellipse(body, 136, 52, 15, 15, fur)
        ellipse(body, 64, 52, 7, 7, muzzle, stroke: false)
        ellipse(body, 136, 52, 7, 7, muzzle, stroke: false)
        ellipse(body, 100, 86, 42, 42, fur)
        ellipse(body, 100, 102, 21, 16, muzzle)
        ellipse(body, 100, 95, 8, 6, ink)
        body.addChild(Shape.svg("M92 108 Q100 114 108 108", width: 3))
        eye(body, 84, 78)
        eye(body, 116, 78)
    }

    static func owl(_ body: SKNode) {
        let feather = SKColor(hex: 0x8C7A6B)
        let beak = SKColor(hex: 0xF2A23A)
        body.position = CGPoint(x: -100, y: -187)
        body.addChild(Shape.svg("M84 176 L84 184 M92 176 L92 184 M108 176 L108 184 M116 176 L116 184", stroke: beak, width: 5))
        body.addChild(Shape.svg("M58 52 L52 22 L80 44 Z M142 52 L148 22 L120 44 Z", fill: feather))
        body.addChild(Shape.svg("M100 38 Q156 42 156 116 Q152 178 100 178 Q48 178 44 116 Q44 42 100 38 Z", fill: feather))
        body.addChild(Shape.svg("M46 110 Q30 140 52 164 Q60 136 56 112 Z M154 110 Q170 140 148 164 Q140 136 144 112 Z", fill: SKColor(hex: 0x6F5F52)))
        ellipse(body, 100, 146, 30, 26, SKColor(hex: 0xD9C7AE))
        body.addChild(Shape.svg("M86 140 L90 146 L94 140 M106 140 L110 146 L114 140 M96 154 L100 160 L104 154", stroke: feather, width: 3))
        ellipse(body, 78, 90, 24, 24, SKColor(hex: 0xF3E7D3))
        ellipse(body, 122, 90, 24, 24, SKColor(hex: 0xF3E7D3))
        for x in [CGFloat(80), 120] {
            let e = SKNode()
            e.name = "eye"
            e.position = CGPoint(x: x, y: 92)
            e.addChild(Shape.node(Shape.circle(0, 0, 10), fill: ink))
            e.addChild(Shape.node(Shape.circle(3, -4, 3), fill: Palette.white))
            body.addChild(e)
        }
        body.addChild(Shape.svg("M93 108 L107 108 L100 122 Z", fill: beak, width: 3))
    }
}
