import Foundation

/// Det som huskes mellom gangene Lowe spiller. Lagres lokalt på enheten.
struct SavedGame: Codable, Equatable {
    /// Hvor mange fulle vedstabler som er levert til sammen.
    var deliveries = 0
    /// Hvor mange vedstykker som ligger i stabelen nå.
    var pileCount = 0
    var muted = false
    /// Store stjerner samlet i stjernekrukka til sammen.
    var stars = 0

    var homesBuilt: Int { min(deliveries, Animal.allCases.count) }
    var visitor: Animal { Animal.allCases[deliveries % Animal.allCases.count] }

    init() {}

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        deliveries = try c.decodeIfPresent(Int.self, forKey: .deliveries) ?? 0
        pileCount = try c.decodeIfPresent(Int.self, forKey: .pileCount) ?? 0
        muted = try c.decodeIfPresent(Bool.self, forKey: .muted) ?? false
        stars = try c.decodeIfPresent(Int.self, forKey: .stars) ?? 0
    }

    private static let key = "lowe.savedGame.v1"

    static func load() -> SavedGame {
        guard let data = UserDefaults.standard.data(forKey: key),
              let game = try? JSONDecoder().decode(SavedGame.self, from: data) else {
            return SavedGame()
        }
        return game
    }

    func save() {
        guard let data = try? JSONEncoder().encode(self) else { return }
        UserDefaults.standard.set(data, forKey: SavedGame.key)
    }
}
