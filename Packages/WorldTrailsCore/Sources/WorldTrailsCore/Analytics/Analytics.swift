import Foundation

/// Every event the game emits. Names are snake_case and stable: dashboards depend on them.
/// Changing a name or a parameter's meaning requires bumping `AnalyticsEvent.schemaVersion`.
public enum AnalyticsEvent: Equatable, Sendable {
    case firstLaunch
    case sessionStart(sessionNumber: Int, daysSinceInstall: Int)
    case sessionEnd(durationSeconds: Int, roundsCompleted: Int)
    case onboardingStarted
    case onboardingCompleted(durationSeconds: Int)
    case challengeStarted(mode: String, destinationID: String, countryID: String, difficulty: Int, isFirstEver: Bool, source: String)
    case challengeCompleted(mode: String, destinationID: String, solved: Bool, points: Int, cluesUsed: Int,
                            wrongGuesses: Int, durationSeconds: Int, isFirstEver: Bool)
    case challengeAbandoned(mode: String, destinationID: String, cluesRevealed: Int, durationSeconds: Int)
    case clueRevealed(destinationID: String, clueNumber: Int, trigger: String)
    case destinationUnlocked(countryID: String)
    case trailCompleted(countryID: String)
    case stampCollected(destinationID: String, tier: String, isUpgrade: Bool)
    case rankUp(rank: String)
    case dailyStarted(dayKey: String)
    case dailyCompleted(dayKey: String, totalPoints: Int, streak: Int)
    case streakUpdated(current: Int, outcome: String)
    case rewardedAdOffered(placement: String)
    case rewardedAdStarted(placement: String)
    case rewardedAdCompleted(placement: String, reward: String)
    case rewardedAdFailed(placement: String, reason: String)
    case interstitialShown(placement: String)
    case interstitialSkipped(placement: String, reason: String)
    case adRevenue(network: String, format: String, valueMicros: Int, currency: String)
    case paywallViewed(source: String)
    case purchaseStarted(productID: String)
    case purchaseCompleted(productID: String, isTrial: Bool)
    case purchaseFailed(productID: String, reason: String)
    case purchaseRestored(productID: String)
    case subscriptionStatusChanged(productID: String, status: String)
    case shareTapped(context: String)

    public static let schemaVersion = 1

    public var name: String {
        switch self {
        case .firstLaunch: return "first_launch"
        case .sessionStart: return "session_start"
        case .sessionEnd: return "session_end"
        case .onboardingStarted: return "onboarding_started"
        case .onboardingCompleted: return "onboarding_completed"
        case .challengeStarted: return "challenge_started"
        case .challengeCompleted: return "challenge_completed"
        case .challengeAbandoned: return "challenge_abandoned"
        case .clueRevealed: return "clue_revealed"
        case .destinationUnlocked: return "destination_unlocked"
        case .trailCompleted: return "trail_completed"
        case .stampCollected: return "stamp_collected"
        case .rankUp: return "rank_up"
        case .dailyStarted: return "daily_started"
        case .dailyCompleted: return "daily_completed"
        case .streakUpdated: return "streak_updated"
        case .rewardedAdOffered: return "rewarded_ad_offered"
        case .rewardedAdStarted: return "rewarded_ad_started"
        case .rewardedAdCompleted: return "rewarded_ad_completed"
        case .rewardedAdFailed: return "rewarded_ad_failed"
        case .interstitialShown: return "interstitial_shown"
        case .interstitialSkipped: return "interstitial_skipped"
        case .adRevenue: return "ad_revenue"
        case .paywallViewed: return "paywall_viewed"
        case .purchaseStarted: return "purchase_started"
        case .purchaseCompleted: return "purchase_completed"
        case .purchaseFailed: return "purchase_failed"
        case .purchaseRestored: return "purchase_restored"
        case .subscriptionStatusChanged: return "subscription_status_changed"
        case .shareTapped: return "share_tapped"
        }
    }

    /// Flat, JSON-safe parameters (String / Int / Bool only).
    public var parameters: [String: AnalyticsValue] {
        switch self {
        case .firstLaunch, .onboardingStarted: return [:]
        case let .sessionStart(n, days): return ["session_number": .int(n), "days_since_install": .int(days)]
        case let .sessionEnd(s, r): return ["duration_s": .int(s), "rounds_completed": .int(r)]
        case let .onboardingCompleted(s): return ["duration_s": .int(s)]
        case let .challengeStarted(mode, d, c, diff, first, source):
            return ["mode": .string(mode), "destination_id": .string(d), "country_id": .string(c),
                    "difficulty": .int(diff), "is_first_ever": .bool(first), "source": .string(source)]
        case let .challengeCompleted(mode, d, solved, pts, clues, wrong, dur, first):
            return ["mode": .string(mode), "destination_id": .string(d), "solved": .bool(solved), "points": .int(pts),
                    "clues_used": .int(clues), "wrong_guesses": .int(wrong), "duration_s": .int(dur), "is_first_ever": .bool(first)]
        case let .challengeAbandoned(mode, d, clues, dur):
            return ["mode": .string(mode), "destination_id": .string(d), "clues_revealed": .int(clues), "duration_s": .int(dur)]
        case let .clueRevealed(d, n, trigger):
            return ["destination_id": .string(d), "clue_number": .int(n), "trigger": .string(trigger)]
        case let .destinationUnlocked(c): return ["country_id": .string(c)]
        case let .trailCompleted(c): return ["country_id": .string(c)]
        case let .stampCollected(d, tier, up): return ["destination_id": .string(d), "tier": .string(tier), "is_upgrade": .bool(up)]
        case let .rankUp(r): return ["rank": .string(r)]
        case let .dailyStarted(k): return ["day_key": .string(k)]
        case let .dailyCompleted(k, pts, s): return ["day_key": .string(k), "total_points": .int(pts), "streak": .int(s)]
        case let .streakUpdated(c, o): return ["current": .int(c), "outcome": .string(o)]
        case let .rewardedAdOffered(p), let .rewardedAdStarted(p): return ["placement": .string(p)]
        case let .rewardedAdCompleted(p, r): return ["placement": .string(p), "reward": .string(r)]
        case let .rewardedAdFailed(p, r): return ["placement": .string(p), "reason": .string(r)]
        case let .interstitialShown(p): return ["placement": .string(p)]
        case let .interstitialSkipped(p, r): return ["placement": .string(p), "reason": .string(r)]
        case let .adRevenue(n, f, v, c): return ["network": .string(n), "format": .string(f), "value_micros": .int(v), "currency": .string(c)]
        case let .paywallViewed(s): return ["source": .string(s)]
        case let .purchaseStarted(p), let .purchaseRestored(p): return ["product_id": .string(p)]
        case let .purchaseCompleted(p, t): return ["product_id": .string(p), "is_trial": .bool(t)]
        case let .purchaseFailed(p, r): return ["product_id": .string(p), "reason": .string(r)]
        case let .subscriptionStatusChanged(p, s): return ["product_id": .string(p), "status": .string(s)]
        case let .shareTapped(c): return ["context": .string(c)]
        }
    }
}

public enum AnalyticsValue: Equatable, Codable, Sendable {
    case string(String), int(Int), bool(Bool)

    public func encode(to encoder: Encoder) throws {
        var c = encoder.singleValueContainer()
        switch self {
        case .string(let s): try c.encode(s)
        case .int(let i): try c.encode(i)
        case .bool(let b): try c.encode(b)
        }
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.singleValueContainer()
        if let b = try? c.decode(Bool.self) { self = .bool(b) }
        else if let i = try? c.decode(Int.self) { self = .int(i) }
        else { self = .string(try c.decode(String.self)) }
    }
}

/// Envelope attached to every event: what cohort and retention queries group by.
public struct AnalyticsContext: Codable, Equatable, Sendable {
    public var installID: String          // random UUID, not linked to identity (no IDFA)
    public var installDayKey: String      // acquisition cohort
    public var sessionID: String
    public var appVersion: String
    public var isPlus: Bool
    public var experimentGroup: String
    public init(installID: String, installDayKey: String, sessionID: String, appVersion: String, isPlus: Bool, experimentGroup: String) {
        self.installID = installID; self.installDayKey = installDayKey; self.sessionID = sessionID
        self.appVersion = appVersion; self.isPlus = isPlus; self.experimentGroup = experimentGroup
    }
}

public struct AnalyticsRecord: Codable, Equatable, Sendable {
    public let name: String
    public let timestamp: Date
    public let dayKey: String
    public let schemaVersion: Int
    public let context: AnalyticsContext
    public let parameters: [String: AnalyticsValue]
}

/// Where events go: a vendor SDK adapter, a debug console, or a test spy.
public protocol AnalyticsSink: AnyObject {
    func send(_ record: AnalyticsRecord)
}

public final class Analytics {
    public private(set) var sinks: [AnalyticsSink]
    public var context: AnalyticsContext
    private let clock: DayClock
    private let now: () -> Date

    public init(context: AnalyticsContext, sinks: [AnalyticsSink], clock: DayClock = DayClock(), now: @escaping () -> Date = Date.init) {
        self.context = context
        self.sinks = sinks
        self.clock = clock
        self.now = now
    }

    public func track(_ event: AnalyticsEvent) {
        let date = now()
        let record = AnalyticsRecord(name: event.name, timestamp: date, dayKey: clock.dayKey(for: date),
                                     schemaVersion: AnalyticsEvent.schemaVersion, context: context,
                                     parameters: event.parameters)
        sinks.forEach { $0.send(record) }
    }
}

/// Test / debug sink that keeps everything in memory.
public final class InMemoryAnalyticsSink: AnalyticsSink {
    public private(set) var records: [AnalyticsRecord] = []
    public init() {}
    public func send(_ record: AnalyticsRecord) { records.append(record) }
}
