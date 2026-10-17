import Foundation

/// Remotely tunable monetization settings. Defaults are deliberately conservative;
/// the app overlays a remote JSON on top of these so experiments don't need an app update.
public struct MonetizationConfig: Codable, Equatable, Sendable {
    public var interstitialsEnabled = true
    public var rewardedEnabled = true
    /// No interstitials until the player has finished this many rounds in total (protects D1).
    public var minLifetimeRoundsBeforeInterstitials = 15
    public var minRoundsBetweenInterstitials = 4
    public var minSecondsBetweenInterstitials: Double = 240
    public var maxInterstitialsPerSession = 2
    public var maxRewardedPerDay = 6
    /// Hide the paywall entry from the results screen until the player has seen the core loop.
    public var minRoundsBeforeSoftPaywall = 8
    public var experimentGroup = "control"

    public init() {}

    /// Overlays only the keys present in `json`.
    public func merged(withJSON data: Data) -> MonetizationConfig {
        guard let overrides = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let baseData = try? JSONEncoder().encode(self),
              var base = try? JSONSerialization.jsonObject(with: baseData) as? [String: Any] else { return self }
        for (k, v) in overrides where base[k] != nil { base[k] = v }
        guard let mergedData = try? JSONSerialization.data(withJSONObject: base),
              let result = try? JSONDecoder().decode(MonetizationConfig.self, from: mergedData) else { return self }
        return result
    }
}

public enum AdPlacement: String, Codable, Sendable {
    case appLaunch, inChallenge, roundResults, betweenRounds, dailyComplete
}

public struct AdSessionState: Equatable, Sendable {
    public var lifetimeRoundsCompleted = 0
    public var roundsSinceLastInterstitial = 0
    public var interstitialsThisSession = 0
    public var lastInterstitialAt: Date?
    public var rewardedToday = 0
    public init() {}
}

public enum AdDecision: Equatable, Sendable {
    case show
    case skip(reason: String)
}

/// Single source of truth for "may an ad appear here?". Pure and unit-tested.
public struct AdPolicy: Sendable {
    public let config: MonetizationConfig
    public init(config: MonetizationConfig) { self.config = config }

    public func interstitial(at placement: AdPlacement, isPlus: Bool, state: AdSessionState, now: Date = Date()) -> AdDecision {
        if isPlus { return .skip(reason: "plus") }
        if !config.interstitialsEnabled { return .skip(reason: "disabled") }
        switch placement {
        case .appLaunch, .inChallenge, .roundResults:
            // Never at launch, never mid-challenge, never over the reward moment.
            return .skip(reason: "placement_forbidden")
        case .betweenRounds, .dailyComplete:
            break
        }
        if state.lifetimeRoundsCompleted < config.minLifetimeRoundsBeforeInterstitials { return .skip(reason: "new_player") }
        if state.interstitialsThisSession >= config.maxInterstitialsPerSession { return .skip(reason: "session_cap") }
        if state.roundsSinceLastInterstitial < config.minRoundsBetweenInterstitials { return .skip(reason: "round_gap") }
        if let last = state.lastInterstitialAt, now.timeIntervalSince(last) < config.minSecondsBetweenInterstitials {
            return .skip(reason: "time_gap")
        }
        return .show
    }

    public func canOfferRewarded(isPlus: Bool, state: AdSessionState) -> Bool {
        // Plus members get the reward directly; no ad required.
        !isPlus && config.rewardedEnabled && state.rewardedToday < config.maxRewardedPerDay
    }
}
