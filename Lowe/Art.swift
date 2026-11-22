import SpriteKit

// Alle figurer tegnes i "designkoordinater": samme tall som i designtavlene
// (1180 × 820, y peker nedover). Verdens-noden i GameScene snur y-aksen,
// så stiene kan kopieres rett fra designet.

extension SKColor {
    convenience init(hex: UInt32, alpha: CGFloat = 1) {
        self.init(red: CGFloat((hex >> 16) & 0xFF) / 255,
                  green: CGFloat((hex >> 8) & 0xFF) / 255,
                  blue: CGFloat(hex & 0xFF) / 255,
                  alpha: alpha)
    }
}

enum Palette {
    static let ink = SKColor(hex: 0x1D1F24)
    static let inkSoft = SKColor(hex: 0x2B2E35)
    static let turquoise = SKColor(hex: 0x1FC2C2)
    static let turquoiseDeep = SKColor(hex: 0x0E9C9F)
    static let sky = SKColor(hex: 0xCDEBEF)
    static let farHill = SKColor(hex: 0xB5DCE2)
    static let snow = SKColor(hex: 0xF6F8F9)
    static let snowMid = SKColor(hex: 0xE4EEF1)
    static let snowShade = SKColor(hex: 0xDCE7EC)
    static let spruce = SKColor(hex: 0x2E5E55)
    static let spruceMid = SKColor(hex: 0x3F7A6E)
    static let spruceFar = SKColor(hex: 0x8DBDB2)
    static let spruceFar2 = SKColor(hex: 0x7FB2A6)
    static let trunk = SKColor(hex: 0x5A3A24)
    static let bark = SKColor(hex: 0x7A4A2B)
    static let barkLight = SKColor(hex: 0x8A5A36)
    static let barkLine = SKColor(hex: 0x6B4227)
    static let barkDeep = SKColor(hex: 0x5E3820)
    static let wood = SKColor(hex: 0xF0CE94)
    static let ring = SKColor(hex: 0xC99A62)
    static let crack = SKColor(hex: 0x3B2416)
    static let skin = SKColor(hex: 0xF4CBA6)
    static let cheek = SKColor(hex: 0xF2A08F)
    static let steel = SKColor(hex: 0xBFC8CF)
    static let sun = SKColor(hex: 0xFFD66B)
    static let sunGlow = SKColor(hex: 0xFFE9A8)
    static let spark = SKColor(hex: 0xFFF6C8)
    static let hogSpikes = SKColor(hex: 0x6B4A33)
    static let hogFace = SKColor(hex: 0xF0D5B0)
    static let hogFeet = SKColor(hex: 0x4A3324)
    static let white = SKColor.white
}

// MARK: - Stier

enum SVGPath {
    /// Leser de enkle SVG-stiene fra designet: M, L, Q og Z med absolutte tall.
    static func make(_ d: String) -> CGPath {
        var tokens: [String] = []
        var current = ""
        func flush() {
            if !current.isEmpty { tokens.append(current); current = "" }
        }
        for ch in d {
            if ch.isLetter {
                flush()
                tokens.append(String(ch))
            } else if ch == " " || ch == "," || ch == "\n" {
                flush()
            } else if ch == "-" {
                flush()
                current = "-"
            } else {
                current.append(ch)
            }
        }
        flush()

        let path = CGMutablePath()
        var i = 0
        var command: Character = "M"
        func number() -> CGFloat {
            let value = i < tokens.count ? Double(tokens[i]) ?? 0 : 0
            i += 1
            return CGFloat(value)
        }
        while i < tokens.count {
            if let first = tokens[i].first, first.isLetter {
                command = first
                i += 1
                if command == "Z" || command == "z" {
                    path.closeSubpath()
                    continue
                }
            }
            switch command {
            case "M":
                let x = number(); let y = number()
                path.move(to: CGPoint(x: x, y: y))
                command = "L"
            case "L":
                let x = number(); let y = number()
                path.addLine(to: CGPoint(x: x, y: y))
            case "Q":
                let cx = number(); let cy = number()
                let x = number(); let y = number()
                path.addQuadCurve(to: CGPoint(x: x, y: y), control: CGPoint(x: cx, y: cy))
            default:
                i += 1
            }
        }
        return path
    }
}

@MainActor
enum Shape {
    static func node(_ path: CGPath, fill: SKColor? = nil, stroke: SKColor? = nil, width: CGFloat = 4) -> SKShapeNode {
        let n = SKShapeNode(path: path)
        n.fillColor = fill ?? .clear
        n.strokeColor = stroke ?? .clear
        n.lineWidth = stroke == nil ? 0 : width
        n.lineJoin = .round
        n.lineCap = .round
        return n
    }

    static func svg(_ d: String, fill: SKColor? = nil, stroke: SKColor? = Palette.ink, width: CGFloat = 4) -> SKShapeNode {
        node(SVGPath.make(d), fill: fill, stroke: stroke, width: width)
    }

    static func ellipse(_ cx: CGFloat, _ cy: CGFloat, _ rx: CGFloat, _ ry: CGFloat) -> CGPath {
        CGPath(ellipseIn: CGRect(x: cx - rx, y: cy - ry, width: rx * 2, height: ry * 2), transform: nil)
    }

    static func circle(_ cx: CGFloat, _ cy: CGFloat, _ r: CGFloat) -> CGPath {
        ellipse(cx, cy, r, r)
    }

    static func rect(_ x: CGFloat, _ y: CGFloat, _ w: CGFloat, _ h: CGFloat, r: CGFloat = 0) -> CGPath {
        let radius = max(0, min(r, w / 2 - 0.01, h / 2 - 0.01))
        let frame = CGRect(x: x, y: y, width: w, height: h)
        if radius <= 0 { return CGPath(rect: frame, transform: nil) }
        return CGPath(roundedRect: frame, cornerWidth: radius, cornerHeight: radius, transform: nil)
    }

    static func line(_ a: CGPoint, _ b: CGPoint) -> CGPath {
        let p = CGMutablePath()
        p.move(to: a)
        p.addLine(to: b)
        return p
    }
}

func deg(_ d: CGFloat) -> CGFloat { d * .pi / 180 }

// MARK: - Bakgrunn

@MainActor
enum Scenery {
    static func spruce(color: SKColor, snow: SKColor = Palette.white, trunk: SKColor = Palette.trunk) -> SKNode {
        let n = SKNode()
        n.addChild(Shape.node(Shape.rect(-7, -20, 14, 22), fill: trunk))
        n.addChild(Shape.svg("M0 -160 L34 -110 L18 -110 L48 -66 L28 -66 L60 -18 L-60 -18 L-28 -66 L-48 -66 L-18 -110 L-34 -110 Z", fill: color, stroke: nil))
        n.addChild(Shape.svg("M0 -160 L17 -135 L7 -130 L0 -138 L-7 -130 L-17 -135 Z", fill: snow, stroke: nil))
        n.addChild(Shape.svg("M-48 -66 L-38 -60 L-28 -66 Z M48 -66 L38 -60 L28 -66 Z", fill: snow, stroke: nil))
        return n
    }

    /// Himmel, sol, skyer, åser, trær og snø. Alt som står stille.
    static func build() -> SKNode {
        let root = SKNode()
        func add(_ n: SKNode, _ x: CGFloat = 0, _ y: CGFloat = 0, scale: CGFloat = 1) {
            n.position = CGPoint(x: x, y: y)
            n.setScale(scale)
            root.addChild(n)
        }
        add(Shape.node(Shape.rect(-600, -600, 2380, 2020), fill: Palette.sky))
        add(Shape.node(Shape.circle(960, 140, 58), fill: Palette.sunGlow))
        add(Shape.node(Shape.circle(960, 140, 40), fill: Palette.sun))

        let clouds = SKNode()
        for (cx, cy, rx, ry) in [(250, 146, 74, 24), (292, 124, 44, 30), (210, 132, 38, 22),
                                  (700, 96, 60, 18), (732, 80, 34, 22)] as [(CGFloat, CGFloat, CGFloat, CGFloat)] {
            clouds.addChild(Shape.node(Shape.ellipse(cx, cy, rx, ry), fill: Palette.white))
        }
        add(clouds)
        clouds.run(.repeatForever(.sequence([
            .moveBy(x: 40, y: 0, duration: 9), .moveBy(x: -40, y: 0, duration: 9)
        ])))

        add(Shape.svg("M-600 520 Q200 420 420 480 Q640 400 860 470 Q1040 420 1780 470 L1780 1420 L-600 1420 Z", fill: Palette.farHill, stroke: nil))
        let far: [(CGFloat, CGFloat, CGFloat, SKColor)] = [
            (40, 500, 0.6, Palette.spruceFar), (130, 480, 0.75, Palette.spruceFar2),
            (330, 470, 0.55, Palette.spruceFar), (470, 460, 0.7, Palette.spruceFar2),
            (700, 450, 0.6, Palette.spruceFar), (800, 470, 0.75, Palette.spruceFar2),
            (1100, 460, 0.65, Palette.spruceFar), (-80, 490, 0.7, Palette.spruceFar2),
            (1240, 470, 0.7, Palette.spruceFar2)
        ]
        for (x, y, s, c) in far { add(spruce(color: c), x, y, scale: s) }

        add(Shape.svg("M-600 600 Q300 560 600 590 Q900 620 1780 580 L1780 1420 L-600 1420 Z", fill: Palette.snowMid, stroke: nil))
        add(spruce(color: Palette.spruce), 70, 655, scale: 1.5)
        add(spruce(color: Palette.spruceMid), 990, 610, scale: 1.2)
        add(spruce(color: Palette.spruce), -90, 660, scale: 1.3)
        add(Shape.svg("M-600 640 Q590 618 1780 645 L1780 1420 L-600 1420 Z", fill: Palette.snow, stroke: nil))

        for (cx, cy, rx, ry) in [(575, 654, 122, 14), (355, 654, 74, 10), (990, 656, 170, 12), (775, 654, 52, 8)] as [(CGFloat, CGFloat, CGFloat, CGFloat)] {
            add(Shape.node(Shape.ellipse(cx, cy, rx, ry), fill: Palette.snowShade))
        }

        // Stolper til vedstabelen
        add(Shape.node(Shape.rect(826, 508, 16, 146, r: 5), fill: Palette.bark, stroke: Palette.ink, width: 3))
        add(Shape.node(Shape.rect(1138, 508, 16, 146, r: 5), fill: Palette.bark, stroke: Palette.ink, width: 3))
        return root
    }

    static func choppingBlock() -> SKNode {
        let n = SKNode()
        n.addChild(Shape.svg("M480 590 L480 645 Q575 672 670 645 L670 590 Z", fill: Palette.bark, width: 3.5))
        n.addChild(Shape.svg("M510 610 L510 650 M560 614 L560 660 M620 612 L620 657", stroke: Palette.barkDeep, width: 3))
        n.addChild(Shape.node(Shape.ellipse(575, 590, 95, 26), fill: Palette.wood, stroke: Palette.ink, width: 3.5))
        n.addChild(Shape.node(Shape.ellipse(575, 590, 66, 17), stroke: Palette.ring, width: 2.5))
        n.addChild(Shape.node(Shape.ellipse(575, 590, 36, 9), stroke: Palette.ring, width: 2.5))
        return n
    }

    /// Enden av et vedstykke i stabelen, sentrert i (0, 0).
    static func logEnd() -> SKNode {
        let n = SKNode()
        n.addChild(Shape.node(Shape.circle(0, 0, 33), fill: Palette.bark, stroke: Palette.ink, width: 3))
        n.addChild(Shape.node(Shape.circle(0, 0, 26), fill: Palette.wood))
        n.addChild(Shape.node(Shape.circle(0, 0, 17), stroke: Palette.ring, width: 2.5))
        n.addChild(Shape.node(Shape.circle(0, 0, 8), stroke: Palette.ring, width: 2.5))
        n.addChild(Shape.node(Shape.circle(0, 0, 2.5), fill: Palette.ring))
        return n
    }

    /// Stjerneglimt der øksa treffer.
    static func impactStar() -> SKShapeNode {
        let star = Shape.svg("M0 -48 L12 -18 L44 -26 L22 -2 L50 16 L16 18 L14 50 L-2 24 L-30 40 L-18 10 L-44 -6 L-12 -12 Z",
                             fill: Palette.spark, stroke: Palette.sun, width: 3)
        return star
    }

    /// Stor gul stjerne som popper opp når stabelen er full.
    static func bigStar() -> SKShapeNode {
        Shape.svg("M0 -48 L14 -14 L50 -11 L22 12 L32 48 L0 28 L-32 48 L-22 12 L-50 -11 L-14 -14 Z",
                  fill: Palette.sun, stroke: Palette.ink, width: 4)
    }

    /// Ekorn som hopper ut av kubben. Føttene i (0, 0), vendt mot høyre.
    static func squirrel() -> SKNode {
        let fur = SKColor(hex: 0xC0682F)
        let n = SKNode()
        n.addChild(Shape.svg("M-6 0 Q-50 -6 -46 -50 Q-40 -82 -12 -72 Q-32 -58 -26 -36 Q-20 -16 2 -10 Z", fill: fur))
        n.addChild(Shape.node(Shape.ellipse(8, -18, 18, 16), fill: fur, stroke: Palette.ink))
        n.addChild(Shape.node(Shape.ellipse(15, -14, 9, 10), fill: SKColor(hex: 0xF3D9B5)))
        n.addChild(Shape.svg("M18 -48 L21 -62 L30 -48 Z", fill: fur))
        n.addChild(Shape.node(Shape.circle(25, -38, 13), fill: fur, stroke: Palette.ink))
        n.addChild(Shape.node(Shape.circle(29, -41, 2.8), fill: Palette.ink))
        n.addChild(Shape.node(Shape.circle(38, -35, 2.4), fill: Palette.ink))
        n.addChild(Shape.node(Shape.ellipse(14, 0, 8, 3.5), fill: SKColor(hex: 0x8A4A22), stroke: Palette.ink, width: 2.5))
        return n
    }

    /// Kongle som spretter av kubben, sentrert i (0, 0).
    static func pinecone() -> SKNode {
        let n = SKNode()
        n.addChild(Shape.node(Shape.ellipse(0, 0, 10, 14), fill: Palette.barkLight, stroke: Palette.ink, width: 3))
        n.addChild(Shape.svg("M-6 -6 L6 -6 M-8 1 L8 1 M-6 8 L6 8", stroke: Palette.barkDeep, width: 2))
        return n
    }

    /// Lite glimt-stjerne til feiringer, sentrert i (0, 0).
    static func sparkle(color: SKColor) -> SKShapeNode {
        Shape.svg("M0 -14 L4 -4 L14 0 L4 4 L0 14 L-4 4 L-14 0 L-4 -4 Z", fill: color, stroke: Palette.ink, width: 2)
    }
}
