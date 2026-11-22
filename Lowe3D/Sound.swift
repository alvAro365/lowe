import AVFoundation
import UIKit

/// Lydene fra 2D-spillet, pluss vibrasjon. Følger lydløsbryteren.
@MainActor
final class Sound {
    enum Name: String, CaseIterable {
        case chop, split, stack, land, whoosh, cheer
    }

    private var players: [Name: [AVAudioPlayer]] = [:]
    private var next: [Name: Int] = [:]
    private let tap = UIImpactFeedbackGenerator(style: .medium)
    private let thud = UIImpactFeedbackGenerator(style: .heavy)

    init() {
        try? AVAudioSession.sharedInstance().setCategory(.ambient)
        for name in Name.allCases {
            guard let url = Bundle.main.url(forResource: name.rawValue, withExtension: "wav") else { continue }
            let list = (0..<3).compactMap { _ in try? AVAudioPlayer(contentsOf: url) }
            list.forEach { $0.prepareToPlay() }
            players[name] = list
        }
    }

    func play(_ name: Name, volume: Float = 1) {
        guard let list = players[name], !list.isEmpty else { return }
        let i = next[name, default: 0] % list.count
        next[name] = i + 1
        let player = list[i]
        player.volume = volume
        player.currentTime = 0
        player.play()
    }

    func buzz(strong: Bool = false) {
        if strong { thud.impactOccurred() } else { tap.impactOccurred() }
    }
}
