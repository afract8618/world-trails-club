import Foundation

/// Stamp quality is earned by skill, never by chance (no loot boxes).
public enum StampTier: Int, Codable, Comparable, CaseIterable, Sendable {
    case bronze = 1, silver = 2, gold = 3

    public static func < (a: StampTier, b: StampTier) -> Bool { a.rawValue < b.rawValue }

    public var displayName: String {
        switch self {
        case .bronze: return "Bronze"
        case .silver: return "Silver"
        case .gold: return "Gold"
        }
    }

    /// Clue number (1-based) the player solved on.
    public init(solvedOnClue clue: Int) {
        switch clue {
        case ...1: self = .gold
        case 2...3: self = .silver
        default: self = .bronze
        }
    }
}

/// One Mystery Destination round: clues reveal one at a time; every wrong guess
/// reveals the next clue and returns a distance + compass direction to the answer.
public struct MysteryRound: Sendable {
    public enum Status: Equatable, Sendable {
        case playing
        case solved(points: Int, tier: StampTier)
        case failed
    }

    public struct Guess: Equatable, Sendable, Identifiable {
        public var id: String { destinationID }
        public let destinationID: String
        public let name: String
        public let isCorrect: Bool
        public let distanceKm: Int
        public let direction: CompassDirection?
        public let proximity: Int
    }

    public enum GuessError: Error, Equatable {
        case roundOver
        case alreadyGuessed
    }

    /// Points for solving on clue 1...5.
    public static let cluePoints = [1000, 800, 600, 450, 300]
    public static let maxWrongGuesses = 5

    public let target: Destination
    public private(set) var revealedClueCount = 1
    public private(set) var guesses: [Guess] = []
    public private(set) var status: Status = .playing
    /// Clues revealed for free (rewarded ad / Plus perk). They don't reduce points.
    public private(set) var freeClueCount = 0
    public let startedAt: Date

    public init(target: Destination, startedAt: Date = Date()) {
        precondition(!target.clues.isEmpty, "A destination needs at least one clue")
        self.target = target
        self.startedAt = startedAt
    }

    public var revealedClues: ArraySlice<Clue> { target.clues.prefix(revealedClueCount) }
    public var canRevealMore: Bool { status == .playing && revealedClueCount < target.clues.count }
    public var wrongGuessCount: Int { guesses.filter { !$0.isCorrect }.count }
    public var guessesRemaining: Int { max(0, Self.maxWrongGuesses - wrongGuessCount) }
    public var isOver: Bool { status != .playing }

    /// Clue number used for scoring: revealed clues minus free ones.
    public var scoringClueNumber: Int { max(1, revealedClueCount - freeClueCount) }

    /// Points the player would earn by guessing correctly right now.
    public var pointsAvailable: Int {
        Self.cluePoints[min(scoringClueNumber, Self.cluePoints.count) - 1]
    }

    /// Reveal the next clue without lowering the score. One per round.
    @discardableResult
    public mutating func revealFreeClue() -> Bool {
        guard canRevealMore, freeClueCount == 0 else { return false }
        revealedClueCount += 1
        freeClueCount += 1
        return true
    }

    public var canUseFreeClue: Bool { canRevealMore && freeClueCount == 0 }

    /// Voluntarily reveal the next clue (costs points, not a guess).
    @discardableResult
    public mutating func revealNextClue() -> Bool {
        guard canRevealMore else { return false }
        revealedClueCount += 1
        return true
    }

    @discardableResult
    public mutating func guess(_ destination: Place) throws -> Guess {
        guard status == .playing else { throw GuessError.roundOver }
        guard !guesses.contains(where: { $0.destinationID == destination.id }) else { throw GuessError.alreadyGuessed }

        let isCorrect = destination.id == target.id
        let km = isCorrect ? 0 : Geo.distanceKm(destination.coordinate, target.coordinate)
        let result = Guess(
            destinationID: destination.id,
            name: destination.name,
            isCorrect: isCorrect,
            distanceKm: Int(km.rounded()),
            direction: isCorrect ? nil : CompassDirection(bearing: Geo.bearing(from: destination.coordinate, to: target.coordinate)),
            proximity: isCorrect ? 100 : Geo.proximityPercent(distanceKm: km)
        )
        guesses.append(result)

        if isCorrect {
            status = .solved(points: pointsAvailable, tier: StampTier(solvedOnClue: scoringClueNumber))
        } else if wrongGuessCount >= Self.maxWrongGuesses {
            status = .failed
        } else {
            revealNextClue()
        }
        return result
    }

    /// Ends the round as failed (player tapped "Reveal answer").
    public mutating func giveUp() {
        guard status == .playing else { return }
        status = .failed
    }

    public var result: RoundResult? {
        switch status {
        case .playing: return nil
        case .solved(let points, let tier):
            return RoundResult(destinationID: target.id, countryID: target.countryID, solved: true,
                               points: points, tier: tier, cluesUsed: revealedClueCount,
                               wrongGuesses: wrongGuessCount)
        case .failed:
            return RoundResult(destinationID: target.id, countryID: target.countryID, solved: false,
                               points: 0, tier: nil, cluesUsed: revealedClueCount,
                               wrongGuesses: wrongGuessCount)
        }
    }
}

public struct RoundResult: Equatable, Codable, Sendable {
    public let destinationID: String
    public let countryID: String
    public let solved: Bool
    public let points: Int
    public let tier: StampTier?
    public let cluesUsed: Int
    public let wrongGuesses: Int

    public init(destinationID: String, countryID: String, solved: Bool, points: Int,
                tier: StampTier?, cluesUsed: Int, wrongGuesses: Int) {
        self.destinationID = destinationID
        self.countryID = countryID
        self.solved = solved
        self.points = points
        self.tier = tier
        self.cluesUsed = cluesUsed
        self.wrongGuesses = wrongGuesses
    }
}

/// Fuzzy search over the guess pool for the answer field.
public enum GuessSearch {
    public static func matches(_ query: String, in pool: [Place], excluding guessedIDs: Set<String> = [], limit: Int = 8) -> [Place] {
        let q = ContentValidator.normalize(query)
        guard !q.isEmpty else { return [] }
        func rank(_ p: Place) -> Int? {
            let names = ([p.name] + p.aliases).map(ContentValidator.normalize)
            if names.contains(where: { $0.hasPrefix(q) }) { return 0 }
            if names.contains(where: { $0.contains(q) }) { return 1 }
            if ContentValidator.normalize(p.countryName).hasPrefix(q) { return 2 }
            return nil
        }
        var ranked: [(place: Place, rank: Int)] = []
        for p in pool where !guessedIDs.contains(p.id) {
            if let r = rank(p) { ranked.append((place: p, rank: r)) }
        }
        ranked.sort { a, b in
            if a.rank != b.rank { return a.rank < b.rank }
            return a.place.name < b.place.name
        }
        return ranked.prefix(limit).map { $0.place }
    }
}
