import Foundation

public enum Rank: Int, CaseIterable, Codable, Comparable, Sendable {
    case explorer, pathfinder, adventurer, globetrotter, worldLegend

    public static func < (a: Rank, b: Rank) -> Bool { a.rawValue < b.rawValue }

    public var title: String {
        switch self {
        case .explorer: return "Explorer"
        case .pathfinder: return "Pathfinder"
        case .adventurer: return "Adventurer"
        case .globetrotter: return "Globetrotter"
        case .worldLegend: return "World Legend"
        }
    }

    /// XP needed to reach this rank. Tuned so Pathfinder lands inside the first
    /// session (~6 rounds) and World Legend is a multi-month goal. Hypothesis, to be tuned with data.
    public var xpRequired: Int {
        switch self {
        case .explorer: return 0
        case .pathfinder: return 500
        case .adventurer: return 2_000
        case .globetrotter: return 6_000
        case .worldLegend: return 15_000
        }
    }

    public static func forXP(_ xp: Int) -> Rank {
        allCases.last { xp >= $0.xpRequired } ?? .explorer
    }

    public var next: Rank? { Rank(rawValue: rawValue + 1) }
}

/// Everything about the player that must survive app restarts.
public struct PlayerProgress: Codable, Equatable, Sendable {
    public var schemaVersion = 1
    public var xp = 0
    /// destinationID → best stamp earned
    public var stamps: [String: StampTier] = [:]
    /// destinationID → date first stamped
    public var stampDates: [String: Date] = [:]
    public var completedCountries: Set<String> = []
    public var roundsPlayed = 0
    public var roundsSolved = 0
    /// Last 10 normalized scores (0...1) for adaptive difficulty.
    public var recentPerformance: [Double] = []
    public var streak = Streak()
    /// Day keys ("2026-10-17") of completed Daily Expeditions.
    public var completedDailies: Set<String> = []
    public var hasCompletedOnboarding = false
    public var firstLaunchDate: Date?
    public var lastActiveDay: Int?

    public init() {}

    public var rank: Rank { Rank.forXP(xp) }

    /// 0...1 progress to the next rank.
    public var rankProgress: Double {
        guard let next = rank.next else { return 1 }
        let span = Double(next.xpRequired - rank.xpRequired)
        return min(1, Double(xp - rank.xpRequired) / span)
    }

    public func isUnlocked(_ country: Country) -> Bool {
        country.unlockAfter.allSatisfy { completedCountries.contains($0) }
    }

    public func stampCount(in countryID: String, pack: ContentPack) -> Int {
        pack.destinations(in: countryID).filter { stamps[$0.id] != nil }.count
    }
}

// Tolerant decoding: any key missing from an older save falls back to its default,
// so adding a field in a future version never wipes a player's progress.
extension PlayerProgress {
    enum CodingKeys: String, CodingKey {
        case schemaVersion, xp, stamps, stampDates, completedCountries, roundsPlayed, roundsSolved,
             recentPerformance, streak, completedDailies, hasCompletedOnboarding, firstLaunchDate, lastActiveDay
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.init()
        schemaVersion = try c.decodeIfPresent(Int.self, forKey: .schemaVersion) ?? schemaVersion
        xp = try c.decodeIfPresent(Int.self, forKey: .xp) ?? 0
        stamps = try c.decodeIfPresent([String: StampTier].self, forKey: .stamps) ?? [:]
        stampDates = try c.decodeIfPresent([String: Date].self, forKey: .stampDates) ?? [:]
        completedCountries = try c.decodeIfPresent(Set<String>.self, forKey: .completedCountries) ?? []
        roundsPlayed = try c.decodeIfPresent(Int.self, forKey: .roundsPlayed) ?? 0
        roundsSolved = try c.decodeIfPresent(Int.self, forKey: .roundsSolved) ?? 0
        recentPerformance = try c.decodeIfPresent([Double].self, forKey: .recentPerformance) ?? []
        streak = try c.decodeIfPresent(Streak.self, forKey: .streak) ?? Streak()
        completedDailies = try c.decodeIfPresent(Set<String>.self, forKey: .completedDailies) ?? []
        hasCompletedOnboarding = try c.decodeIfPresent(Bool.self, forKey: .hasCompletedOnboarding) ?? false
        firstLaunchDate = try c.decodeIfPresent(Date.self, forKey: .firstLaunchDate)
        lastActiveDay = try c.decodeIfPresent(Int.self, forKey: .lastActiveDay)
    }
}

/// What the results screen celebrates.
public struct RewardSummary: Equatable, Sendable {
    public var xpGained = 0
    public var newStamp: StampTier?
    public var upgradedStamp: (from: StampTier, to: StampTier)?
    public var rankUp: Rank?
    public var completedCountry: String?
    public var unlockedCountries: [String] = []

    public init() {}

    public static func == (a: RewardSummary, b: RewardSummary) -> Bool {
        a.xpGained == b.xpGained && a.newStamp == b.newStamp &&
        a.upgradedStamp?.from == b.upgradedStamp?.from && a.upgradedStamp?.to == b.upgradedStamp?.to &&
        a.rankUp == b.rankUp && a.completedCountry == b.completedCountry && a.unlockedCountries == b.unlockedCountries
    }
}

public enum ProgressionEngine {
    public static let xpPerNewStamp = 50
    public static let xpPerStampUpgrade = 25
    public static let xpPerTrailCompletion = 200
    public static let xpForAttempt = 10   // failed rounds still move you forward

    /// Applies a finished round to the player's progress and reports what changed.
    public static func apply(_ result: RoundResult, to progress: inout PlayerProgress,
                             pack: ContentPack, now: Date = Date()) -> RewardSummary {
        var summary = RewardSummary()
        let rankBefore = progress.rank

        progress.roundsPlayed += 1
        progress.recentPerformance.append(Double(result.points) / Double(MysteryRound.cluePoints[0]))
        if progress.recentPerformance.count > 10 { progress.recentPerformance.removeFirst() }

        if result.solved, let tier = result.tier {
            progress.roundsSolved += 1
            summary.xpGained += result.points / 10
            if let existing = progress.stamps[result.destinationID] {
                if tier > existing {
                    progress.stamps[result.destinationID] = tier
                    summary.upgradedStamp = (existing, tier)
                    summary.xpGained += xpPerStampUpgrade
                }
            } else {
                progress.stamps[result.destinationID] = tier
                progress.stampDates[result.destinationID] = now
                summary.newStamp = tier
                summary.xpGained += xpPerNewStamp
            }

            // Trail completion → unlock the next countries.
            // Stamps from the Daily can land in still-locked countries; the trail only
            // completes once the country itself is unlocked.
            let countryID = result.countryID
            if let country = pack.country(countryID), progress.isUnlocked(country),
               !progress.completedCountries.contains(countryID),
               progress.stampCount(in: countryID, pack: pack) == pack.destinations(in: countryID).count {
                let lockedBefore = Set(pack.countries.filter { !progress.isUnlocked($0) }.map(\.id))
                progress.completedCountries.insert(countryID)
                summary.completedCountry = countryID
                summary.xpGained += xpPerTrailCompletion
                summary.unlockedCountries = pack.countries
                    .filter { lockedBefore.contains($0.id) && progress.isUnlocked($0) }
                    .map(\.id)
            }
        } else {
            summary.xpGained += xpForAttempt
        }

        progress.xp += summary.xpGained
        if progress.rank > rankBefore { summary.rankUp = progress.rank }
        return summary
    }
}
