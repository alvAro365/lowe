import SpriteKit
import UIKit

/// Lyd og vibrasjon. iPad har ikke vibrasjon, der blir det bare lyd.
@MainActor
final class Feedback {
    enum Sound: String, CaseIterable {
        case chop, split, stack, land, whoosh, cheer, squeak, pop
    }

    private let actions: [Sound: SKAction]
    private let medium = UIImpactFeedbackGenerator(style: .medium)
    private let heavy = UIImpactFeedbackGenerator(style: .heavy)
    private let light = UIImpactFeedbackGenerator(style: .light)
    private let notify = UINotificationFeedbackGenerator()
    weak var scene: SKScene?
    /// Lyden kan slås av i foreldremenyen. Vibrasjon er fortsatt på.
    var muted = false

    init() {
        var map: [Sound: SKAction] = [:]
        for sound in Sound.allCases {
            map[sound] = SKAction.playSoundFileNamed("\(sound.rawValue).wav", waitForCompletion: false)
        }
        actions = map
        medium.prepare()
        heavy.prepare()
    }

    func play(_ sound: Sound) {
        guard !muted, let action = actions[sound] else { return }
        scene?.run(action)
    }

    func chop() {
        play(.chop)
        medium.impactOccurred()
        medium.prepare()
    }

    func split() {
        play(.split)
        heavy.impactOccurred(intensity: 1)
        heavy.prepare()
    }

    func stack() {
        play(.stack)
        light.impactOccurred(intensity: 0.6)
    }

    func land() {
        play(.land)
        light.impactOccurred(intensity: 0.4)
    }

    func celebrate() {
        play(.cheer)
        notify.notificationOccurred(.success)
    }
}
