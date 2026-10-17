import Foundation
import Observation
import WorldTrailsCore

/// A batch of rounds to play in one sitting (one trail round, or the 3-round Daily Expedition).
struct RoundRequest: Identifiable, Equatable {
    enum Source: String { case onboarding, trail, daily }
    let id = UUID()
    let destinations: [Destination]
    let source: Source
    var dayKey: String?

    static func == (a: RoundRequest, b: RoundRequest) -> Bool { a.id == b.id }
}

/// App-wide state and the only place that mutates player progress.
@MainActor
@Observable
final class AppModel {
    let pack: ContentPack
    let guessPool: [Place]
    private(set) var progress: PlayerProgress
    var activeRequest: RoundRequest?
    var saveError: String?
    var showPaywall = false

    @ObservationIgnored let analytics: Analytics
    @ObservationIgnored let ads: AdService
    let purchases: PurchaseManager
    private(set) var config: MonetizationConfig
    @ObservationIgnored private(set) var adState = AdSessionState()
    @ObservationIgnored private let store: ProgressStore?
    @ObservationIgnored private let clock = DayClock()
    @ObservationIgnored private var sessionStart = Date()
    @ObservationIgnored private var sessionRounds = 0
    @ObservationIgnored private var onboardingStart = Date()
    @ObservationIgnored private let selector = DifficultySelector()

    var isPlus: Bool { purchases.isPlus }
    var todayKey: String { clock.dayKey(for: Date()) }
    var today: Int { clock.dayNumber(for: Date()) }
    var dailyDoneToday: Bool { progress.completedDailies.contains(todayKey) }
    var streakToday: Int { progress.streak.displayValue(today: today) }

    init(pack: ContentPack, store: ProgressStore?, ads: AdService, purchases: PurchaseManager, sinks: [AnalyticsSink]) {
        self.pack = pack
        self.guessPool = pack.guessPool
        self.store = store
        self.ads = ads
        self.purchases = purchases
        let config = MonetizationConfig()
        self.config = config
        var loaded = store?.load() ?? PlayerProgress()

        let defaults = UserDefaults.standard
        let installID = defaults.string(forKey: "installID") ?? UUID().uuidString
        let isFirstLaunch = defaults.string(forKey: "installID") == nil
        defaults.set(installID, forKey: "installID")
        if loaded.firstLaunchDate == nil { loaded.firstLaunchDate = Date() }
        self.progress = loaded

        let clock = DayClock()
        analytics = Analytics(
            context: AnalyticsContext(
                installID: installID,
                installDayKey: clock.dayKey(for: loaded.firstLaunchDate ?? Date()),
                sessionID: UUID().uuidString,
                appVersion: Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "dev",
                isPlus: false,
                experimentGroup: config.experimentGroup),
            sinks: sinks)

        adState.lifetimeRoundsCompleted = loaded.roundsPlayed
        if isFirstLaunch { analytics.track(.firstLaunch) }

        purchases.onEvent = { [weak self] event in
            guard let self else { return }
            switch event {
            case .started(let id): self.analytics.track(.purchaseStarted(productID: id))
            case .completed(let id, let trial): self.analytics.track(.purchaseCompleted(productID: id, isTrial: trial))
            case .failed(let id, let reason): self.analytics.track(.purchaseFailed(productID: id, reason: reason))
            case .restored(let id): self.analytics.track(.purchaseRestored(productID: id))
            case .statusChanged(let id, let status): self.analytics.track(.subscriptionStatusChanged(productID: id, status: status))
            }
            self.analytics.context.isPlus = self.purchases.isPlus
        }
    }

    // MARK: Session

    func sessionDidBegin() {
        sessionStart = Date()
        sessionRounds = 0
        adState.interstitialsThisSession = 0
        analytics.context.sessionID = UUID().uuidString
        analytics.context.isPlus = isPlus
        let installDay = clock.dayNumber(for: progress.firstLaunchDate ?? Date())
        let sessions = UserDefaults.standard.integer(forKey: "sessionCount") + 1
        UserDefaults.standard.set(sessions, forKey: "sessionCount")
        analytics.track(.sessionStart(sessionNumber: sessions, daysSinceInstall: today - installDay))
        if progress.lastActiveDay != today {
            progress.lastActiveDay = today
            adState.rewardedToday = 0
            persist()
        }
        Task { await refreshRemoteConfig() }
    }

    func sessionDidEnd() {
        analytics.track(.sessionEnd(durationSeconds: Int(Date().timeIntervalSince(sessionStart)), roundsCompleted: sessionRounds))
    }

    /// Overlays remote monetization config. Hook up your config endpoint (README → "Remote config").
    private func refreshRemoteConfig() async {
        guard let urlString = Bundle.main.object(forInfoDictionaryKey: "RemoteConfigURL") as? String,
              let url = URL(string: urlString), !urlString.isEmpty else { return }
        if let response = try? await URLSession.shared.data(from: url) {
            config = MonetizationConfig().merged(withJSON: response.0)
            analytics.context.experimentGroup = config.experimentGroup
        }
    }

    // MARK: Onboarding

    func beginOnboarding() {
        onboardingStart = Date()
        analytics.track(.onboardingStarted)
        // First trail is always a famous, solvable place so the first win happens in seconds.
        let first = pack.destination("it-rome") ?? pack.destinations.first(where: { $0.difficulty == 1 }) ?? pack.destinations[0]
        activeRequest = RoundRequest(destinations: [first], source: .onboarding)
    }

    func completeOnboarding() {
        progress.hasCompletedOnboarding = true
        analytics.track(.onboardingCompleted(durationSeconds: Int(Date().timeIntervalSince(onboardingStart))))
        persist()
    }

    // MARK: Starting rounds

    func countries(unlocked: Bool) -> [Country] {
        pack.countries.filter { progress.isUnlocked($0) == unlocked }
    }

    var recommendedCountry: Country? {
        selector.recommendedCountry(progress: progress, pack: pack, isPlus: isPlus)
    }

    func playTrail(in country: Country) {
        guard progress.isUnlocked(country) else { return }
        if country.isPlusCollection && !isPlus { presentPaywall(source: "plus_collection"); return }
        guard let d = selector.nextDestination(in: country.id, progress: progress, pack: pack) else { return }
        activeRequest = RoundRequest(destinations: [d], source: .trail)
    }

    func play(_ destination: Destination) {
        activeRequest = RoundRequest(destinations: [destination], source: .trail)
    }

    func playDaily() {
        let key = todayKey
        analytics.track(.dailyStarted(dayKey: key))
        activeRequest = RoundRequest(destinations: DailyExpedition.destinations(for: key, pack: pack), source: .daily, dayKey: key)
    }

    // MARK: Round lifecycle (called by the round screen)

    func roundStarted(_ destination: Destination, source: RoundRequest.Source) {
        analytics.track(.challengeStarted(mode: "mystery_destination", destinationID: destination.id, countryID: destination.countryID,
                                          difficulty: destination.difficulty, isFirstEver: progress.roundsPlayed == 0,
                                          source: source.rawValue))
    }

    func clueRevealed(_ destination: Destination, clueNumber: Int, byGuess: Bool) {
        analytics.track(.clueRevealed(destinationID: destination.id, clueNumber: clueNumber, trigger: byGuess ? "wrong_guess" : "manual"))
    }

    func roundAbandoned(_ round: MysteryRound) {
        analytics.track(.challengeAbandoned(mode: "mystery_destination", destinationID: round.target.id,
                                            cluesRevealed: round.revealedClueCount,
                                            durationSeconds: Int(Date().timeIntervalSince(round.startedAt))))
    }

    func roundFinished(_ round: MysteryRound) -> RewardSummary {
        guard let result = round.result else { return RewardSummary() }
        let wasFirst = progress.roundsPlayed == 0
        let summary = ProgressionEngine.apply(result, to: &progress, pack: pack)
        sessionRounds += 1
        adState.lifetimeRoundsCompleted += 1
        adState.roundsSinceLastInterstitial += 1

        analytics.track(.challengeCompleted(mode: "mystery_destination", destinationID: result.destinationID, solved: result.solved,
                                            points: result.points, cluesUsed: result.cluesUsed, wrongGuesses: result.wrongGuesses,
                                            durationSeconds: Int(Date().timeIntervalSince(round.startedAt)), isFirstEver: wasFirst))
        if let tier = summary.newStamp {
            analytics.track(.stampCollected(destinationID: result.destinationID, tier: tier.displayName.lowercased(), isUpgrade: false))
        }
        if let up = summary.upgradedStamp {
            analytics.track(.stampCollected(destinationID: result.destinationID, tier: up.to.displayName.lowercased(), isUpgrade: true))
        }
        if let c = summary.completedCountry { analytics.track(.trailCompleted(countryID: c)) }
        summary.unlockedCountries.forEach { analytics.track(.destinationUnlocked(countryID: $0)) }
        if let r = summary.rankUp { analytics.track(.rankUp(rank: r.title)) }
        persist()
        return summary
    }

    /// Returns the streak outcome so the summary screen can explain it.
    func dailyFinished(dayKey: String, totalPoints: Int) -> Streak.Outcome {
        progress.completedDailies.insert(dayKey)
        let outcome = progress.streak.record(day: today)
        analytics.track(.dailyCompleted(dayKey: dayKey, totalPoints: totalPoints, streak: progress.streak.current))
        analytics.track(.streakUpdated(current: progress.streak.current, outcome: String(describing: outcome)))
        persist()
        return outcome
    }

    // MARK: Monetization

    /// Call between rounds (after the player leaves a results screen). Never during play.
    func maybeShowInterstitial(placement: AdPlacement) async {
        let decision = AdPolicy(config: config).interstitial(at: placement, isPlus: isPlus, state: adState)
        switch decision {
        case .show:
            await ads.showInterstitial(placement: placement.rawValue)
            adState.interstitialsThisSession += 1
            adState.roundsSinceLastInterstitial = 0
            adState.lastInterstitialAt = Date()
            analytics.track(.interstitialShown(placement: placement.rawValue))
        case .skip(let reason):
            analytics.track(.interstitialSkipped(placement: placement.rawValue, reason: reason))
        }
    }

    var canOfferRewardedHint: Bool {
        isPlus || AdPolicy(config: config).canOfferRewarded(isPlus: isPlus, state: adState)
    }

    /// Optional rewarded ad for a free extra clue. Plus members get it without an ad.
    func requestRewardedHint() async -> Bool {
        if isPlus { return true }
        let placement = "extra_clue"
        analytics.track(.rewardedAdOffered(placement: placement))
        guard AdPolicy(config: config).canOfferRewarded(isPlus: false, state: adState) else { return false }
        analytics.track(.rewardedAdStarted(placement: placement))
        let rewarded = await ads.showRewarded(placement: placement)
        if rewarded {
            adState.rewardedToday += 1
            analytics.track(.rewardedAdCompleted(placement: placement, reward: "free_clue"))
        } else {
            analytics.track(.rewardedAdFailed(placement: placement, reason: "not_completed"))
        }
        return rewarded
    }

    var shouldShowSoftPaywallPrompt: Bool {
        !isPlus && progress.roundsPlayed >= config.minRoundsBeforeSoftPaywall
    }

    func presentPaywall(source: String) {
        analytics.track(.paywallViewed(source: source))
        showPaywall = true
    }

    // MARK: Persistence

    func resetProgress() {
        progress = PlayerProgress()
        progress.firstLaunchDate = Date()
        persist()
    }

    private func persist() {
        do {
            try store?.save(progress)
            saveError = nil
        } catch {
            saveError = "Your progress couldn't be saved. Free up some storage and it will retry automatically."
        }
    }
}
