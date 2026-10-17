import Foundation

/// Deterministic, platform-independent RNG so every player gets the same Daily
/// Expedition on the same day (required for fair daily leaderboards and sharing).
public struct SplitMix64: RandomNumberGenerator, Sendable {
    private var state: UInt64
    public init(seed: UInt64) { state = seed }
    public mutating func next() -> UInt64 {
        state &+= 0x9E3779B97F4A7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58476D1CE4E5B9
        z = (z ^ (z >> 27)) &* 0x94D049BB133111EB
        return z ^ (z >> 31)
    }

    /// FNV-1a: stable across launches (unlike Swift's randomized `hashValue`).
    public static func seed(from string: String) -> UInt64 {
        var hash: UInt64 = 0xcbf29ce484222325
        for byte in string.utf8 {
            hash ^= UInt64(byte)
            hash = hash &* 0x100000001b3
        }
        return hash
    }
}

public enum DailyExpedition {
    public static let roundCount = 3

    /// Same three destinations worldwide for a given day key, ordered easy → hard.
    /// Drawn from the full free catalog (not just unlocked trails) so it doubles as a preview of what's ahead.
    public static func destinations(for dayKey: String, pack: ContentPack, salt: String = "wtc-daily-v1") -> [Destination] {
        let freeCountries = Set(pack.countries.filter { !$0.isPlusCollection }.map(\.id))
        let pool = pack.destinations.filter { freeCountries.contains($0.countryID) }.sorted { $0.id < $1.id }
        var rng = SplitMix64(seed: SplitMix64.seed(from: salt + dayKey))
        var picked: [Destination] = []
        var usedCountries = Set<String>()
        for d in pool.shuffled(using: &rng) where picked.count < roundCount {
            // Prefer three different countries; relax if the catalog is small.
            if usedCountries.contains(d.countryID) && usedCountries.count < Set(pool.map(\.countryID)).count { continue }
            picked.append(d)
            usedCountries.insert(d.countryID)
        }
        if picked.count < roundCount {
            for d in pool where picked.count < roundCount && !picked.contains(d) { picked.append(d) }
        }
        return picked.sorted { ($0.difficulty, $0.id) < ($1.difficulty, $1.id) }
    }
}

/// Picks the next trail destination for a player. Targets a difficulty band from
/// recent performance, prefers unstamped places, and never repeats the last one.
public struct DifficultySelector {
    public init() {}

    public func targetDifficulty(for recent: [Double]) -> Int {
        guard recent.count >= 3 else { return 1 } // new players start easy
        let avg = recent.reduce(0, +) / Double(recent.count)
        switch avg {
        case ..<0.45: return 1
        case ..<0.70: return 2
        default: return 3
        }
    }

    public func nextDestination<G: RandomNumberGenerator>(
        in countryID: String, progress: PlayerProgress, pack: ContentPack,
        excluding lastID: String? = nil, using rng: inout G
    ) -> Destination? {
        let candidates = pack.destinations(in: countryID).filter { $0.id != lastID }
        guard !candidates.isEmpty else { return pack.destinations(in: countryID).first }
        let target = targetDifficulty(for: progress.recentPerformance)

        // Unstamped first, then stamps that can still be upgraded, then anything.
        let unstamped = candidates.filter { progress.stamps[$0.id] == nil }
        let upgradable = candidates.filter { (progress.stamps[$0.id] ?? .gold) < .gold }
        let tierPool = !unstamped.isEmpty ? unstamped : (!upgradable.isEmpty ? upgradable : candidates)

        let bestDistance = tierPool.map { abs($0.difficulty - target) }.min() ?? 0
        let closest = tierPool.filter { abs($0.difficulty - target) == bestDistance }
        return closest.randomElement(using: &rng)
    }

    public func nextDestination(in countryID: String, progress: PlayerProgress, pack: ContentPack, excluding lastID: String? = nil) -> Destination? {
        var rng = SystemRandomNumberGenerator()
        return nextDestination(in: countryID, progress: progress, pack: pack, excluding: lastID, using: &rng)
    }

    /// "Recommended next trail": an unlocked, incomplete country, preferring the one closest to done.
    public func recommendedCountry(progress: PlayerProgress, pack: ContentPack, isPlus: Bool) -> Country? {
        pack.countries
            .filter { progress.isUnlocked($0) && !progress.completedCountries.contains($0.id) && (isPlus || !$0.isPlusCollection) }
            .max { a, b in
                let ra = Double(progress.stampCount(in: a.id, pack: pack)) / Double(max(1, pack.destinations(in: a.id).count))
                let rb = Double(progress.stampCount(in: b.id, pack: pack)) / Double(max(1, pack.destinations(in: b.id).count))
                return ra != rb ? ra < rb : a.id > b.id
            }
    }
}
