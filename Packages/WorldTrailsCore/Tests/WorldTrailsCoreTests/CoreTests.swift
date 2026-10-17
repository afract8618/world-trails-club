import XCTest
@testable import WorldTrailsCore

final class ContentTests: XCTestCase {
    func testBundledContentLoadsAndValidates() throws {
        let pack = try ContentLoader.loadBundled()
        XCTAssertGreaterThanOrEqual(pack.countries.count, 6)
        XCTAssertGreaterThanOrEqual(pack.destinations.count, 18)
        XCTAssertTrue(ContentValidator.validate(pack).isEmpty)
        // The guess pool must be much larger than the answer pool.
        XCTAssertGreaterThan(pack.guessPool.count, pack.destinations.count * 4)
    }

    func testValidatorCatchesAnswerLeak() {
        let leaky = Destination(id: "x-rome", name: "Rome", countryID: "x", latitude: 0, longitude: 0, difficulty: 1,
                                clues: (1...5).map { Clue(kind: .history, text: $0 == 3 ? "Rome's founders were twins" : "clue \($0)") },
                                fact: "fact")
        let pack = ContentPack(version: 1, countries: [Country(id: "x", name: "X", region: .europe, latitude: 0, longitude: 0)],
                               destinations: [leaky])
        XCTAssertTrue(ContentValidator.validate(pack).contains { $0.message.contains("leaks") })
    }

    func testValidatorAllowsWordsThatOnlyContainTheName() {
        XCTAssertFalse(ContentValidator.containsWord("romeo and juliet", "rome"))
        XCTAssertTrue(ContentValidator.containsWord("in rome's forum", "rome"))
    }

    func testValidatorCatchesUnlockCycle() {
        let a = Country(id: "a", name: "A", region: .europe, latitude: 0, longitude: 0, unlockAfter: ["b"])
        let b = Country(id: "b", name: "B", region: .europe, latitude: 0, longitude: 0, unlockAfter: ["a"])
        XCTAssertTrue(ContentValidator.hasUnlockCycle([a, b]))
    }
}

final class GeoTests: XCTestCase {
    func testDistanceParisToRomeIsAbout1100km() {
        let km = Geo.distanceKm(GeoPoint(latitude: 48.86, longitude: 2.35), GeoPoint(latitude: 41.90, longitude: 12.50))
        XCTAssertEqual(km, 1106, accuracy: 15)
    }

    func testBearingParisToRomeIsSoutheast() {
        let b = Geo.bearing(from: GeoPoint(latitude: 48.86, longitude: 2.35), to: GeoPoint(latitude: 41.90, longitude: 12.50))
        XCTAssertEqual(CompassDirection(bearing: b), .se)
    }

    func testCompassWrapsAround() {
        XCTAssertEqual(CompassDirection(bearing: 359), .n)
        XCTAssertEqual(CompassDirection(bearing: -90), .w)
    }
}

final class MysteryRoundTests: XCTestCase {
    var pack: ContentPack!
    override func setUpWithError() throws { pack = try ContentLoader.loadBundled() }

    private func place(_ id: String) -> Place { pack.guessPool.first { $0.id == id }! }

    func testFirstClueSolveIsGold1000() throws {
        var round = MysteryRound(target: pack.destination("it-rome")!)
        let g = try round.guess(place("it-rome"))
        XCTAssertTrue(g.isCorrect)
        XCTAssertEqual(round.status, .solved(points: 1000, tier: .gold))
    }

    func testWrongGuessRevealsClueAndGivesDirection() throws {
        var round = MysteryRound(target: pack.destination("it-rome")!)
        let g = try round.guess(place("fr-paris"))
        XCTAssertFalse(g.isCorrect)
        XCTAssertEqual(g.direction, .se)
        XCTAssertEqual(round.revealedClueCount, 2)
        XCTAssertEqual(round.pointsAvailable, 800)
    }

    func testDuplicateGuessRejected() throws {
        var round = MysteryRound(target: pack.destination("it-rome")!)
        try round.guess(place("fr-paris"))
        XCTAssertThrowsError(try round.guess(place("fr-paris"))) { XCTAssertEqual($0 as? MysteryRound.GuessError, .alreadyGuessed) }
    }

    func testFiveWrongGuessesFails() throws {
        var round = MysteryRound(target: pack.destination("it-rome")!)
        for id in ["fr-paris", "jp-tokyo", "eg-cairo", "br-rio", "us-new-york"] { try round.guess(place(id)) }
        XCTAssertEqual(round.status, .failed)
        XCTAssertThrowsError(try round.guess(place("it-rome")))
        XCTAssertEqual(round.result?.solved, false)
    }

    func testFreeClueDoesNotCostPoints() throws {
        var round = MysteryRound(target: pack.destination("it-rome")!)
        XCTAssertTrue(round.revealFreeClue())
        XCTAssertFalse(round.revealFreeClue()) // one per round
        XCTAssertEqual(round.revealedClueCount, 2)
        try round.guess(place("it-rome"))
        XCTAssertEqual(round.status, .solved(points: 1000, tier: .gold))
    }

    func testStampTiers() {
        XCTAssertEqual(StampTier(solvedOnClue: 1), .gold)
        XCTAssertEqual(StampTier(solvedOnClue: 3), .silver)
        XCTAssertEqual(StampTier(solvedOnClue: 5), .bronze)
    }

    func testSearchIsAccentAndCaseInsensitive() {
        let results = GuessSearch.matches("SAO", in: pack.guessPool)
        XCTAssertTrue(results.contains { $0.name == "Sao Paulo" })
        XCTAssertTrue(GuessSearch.matches("firenze", in: pack.guessPool).contains { $0.id == "it-florence" })
    }
}

final class ProgressionTests: XCTestCase {
    var pack: ContentPack!
    override func setUpWithError() throws { pack = try ContentLoader.loadBundled() }

    private func solve(_ id: String, clue: Int, _ p: inout PlayerProgress) -> RewardSummary {
        let d = pack.destination(id)!
        let r = RoundResult(destinationID: id, countryID: d.countryID, solved: true,
                            points: MysteryRound.cluePoints[clue - 1], tier: StampTier(solvedOnClue: clue),
                            cluesUsed: clue, wrongGuesses: clue - 1)
        return ProgressionEngine.apply(r, to: &p, pack: pack)
    }

    func testNewStampAwardsXP() {
        var p = PlayerProgress()
        let s = solve("it-rome", clue: 1, &p)
        XCTAssertEqual(s.newStamp, .gold)
        XCTAssertEqual(s.xpGained, 100 + ProgressionEngine.xpPerNewStamp)
        XCTAssertEqual(p.xp, s.xpGained)
    }

    func testStampOnlyUpgrades() {
        var p = PlayerProgress()
        _ = solve("it-rome", clue: 4, &p)
        let up = solve("it-rome", clue: 1, &p)
        XCTAssertEqual(up.upgradedStamp?.to, .gold)
        _ = solve("it-rome", clue: 5, &p)
        XCTAssertEqual(p.stamps["it-rome"], .gold)
    }

    func testCompletingItalyUnlocksFrance() {
        var p = PlayerProgress()
        let france = pack.country("fr")!
        XCTAssertFalse(p.isUnlocked(france))
        _ = solve("it-rome", clue: 2, &p)
        _ = solve("it-venice", clue: 2, &p)
        let last = solve("it-florence", clue: 2, &p)
        XCTAssertEqual(last.completedCountry, "it")
        XCTAssertEqual(last.unlockedCountries, ["fr"])
        XCTAssertTrue(p.isUnlocked(france))
    }

    func testLockedCountryDoesNotCompleteFromDailyStamps() {
        var p = PlayerProgress()
        for id in pack.destinations(in: "eg").map(\.id) { _ = solve(id, clue: 1, &p) }
        XCTAssertFalse(p.completedCountries.contains("eg"))
        XCTAssertEqual(p.stampCount(in: "eg", pack: pack), 3)
    }

    func testRankThresholds() {
        XCTAssertEqual(Rank.forXP(0), .explorer)
        XCTAssertEqual(Rank.forXP(500), .pathfinder)
        XCTAssertEqual(Rank.forXP(20_000), .worldLegend)
    }

    func testOldSaveMissingNewFieldsStillDecodes() throws {
        let json = #"{"xp": 750, "stamps": {"it-rome": 3}}"#.data(using: .utf8)!
        let p = try JSONDecoder().decode(PlayerProgress.self, from: json)
        XCTAssertEqual(p.xp, 750)
        XCTAssertEqual(p.stamps["it-rome"], .gold)
        XCTAssertEqual(p.streak, Streak())
    }
}

final class StreakTests: XCTestCase {
    func testConsecutiveDaysExtend() {
        var s = Streak()
        XCTAssertEqual(s.record(day: 10), .started)
        XCTAssertEqual(s.record(day: 10), .alreadyCountedToday)
        XCTAssertEqual(s.record(day: 11), .extended)
        XCTAssertEqual(s.current, 2)
    }

    func testMissedDayUsesRestToken() {
        var s = Streak()
        s.record(day: 1); s.record(day: 2)
        XCTAssertEqual(s.record(day: 4), .savedByRestTokens(1))
        XCTAssertEqual(s.current, 3)
        XCTAssertEqual(s.restTokens, 0)
    }

    func testLongGapRestartsButKeepsBest() {
        var s = Streak()
        for d in 1...5 { s.record(day: d) }
        XCTAssertEqual(s.record(day: 20), .restarted(previous: 5))
        XCTAssertEqual(s.current, 1)
        XCTAssertEqual(s.best, 5)
    }

    func testEarnsTokenEverySevenDaysCapped() {
        var s = Streak()
        for d in 1...21 { s.record(day: d) }
        XCTAssertEqual(s.restTokens, Streak.maxRestTokens)
    }

    func testDayNumbersAreConsecutiveAcrossDST() {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "America/New_York")!
        let clock = DayClock(calendar: cal)
        let f = ISO8601DateFormatter()
        let before = clock.dayNumber(for: f.date(from: "2026-11-01T03:00:00Z")!) // Oct 31 local
        let after = clock.dayNumber(for: f.date(from: "2026-11-02T03:00:00Z")!)  // Nov 1 local (DST ends)
        XCTAssertEqual(after - before, 1)
        XCTAssertEqual(clock.dayNumber(for: f.date(from: "2000-01-01T12:00:00Z")!), 0)
    }
}

final class SelectionTests: XCTestCase {
    var pack: ContentPack!
    override func setUpWithError() throws { pack = try ContentLoader.loadBundled() }

    func testDailyIsDeterministicAndVaried() {
        let a = DailyExpedition.destinations(for: "2026-10-17", pack: pack)
        let b = DailyExpedition.destinations(for: "2026-10-17", pack: pack)
        XCTAssertEqual(a.map(\.id), b.map(\.id))
        XCTAssertEqual(a.count, 3)
        XCTAssertEqual(Set(a.map(\.countryID)).count, 3)
        let days = (1...28).map { DailyExpedition.destinations(for: String(format: "2026-02-%02d", $0), pack: pack).map(\.id) }
        XCTAssertGreaterThan(Set(days).count, 15)
    }

    func testNewPlayersGetEasyDestinations() {
        let selector = DifficultySelector()
        XCTAssertEqual(selector.targetDifficulty(for: []), 1)
        XCTAssertEqual(selector.targetDifficulty(for: [1, 1, 0.8]), 3)
        var rng = SplitMix64(seed: 1)
        let d = selector.nextDestination(in: "jp", progress: PlayerProgress(), pack: pack, using: &rng)
        XCTAssertEqual(d?.difficulty, 1)
    }

    func testSelectorPrefersUnstamped() {
        var p = PlayerProgress()
        p.stamps = ["it-rome": .gold, "it-venice": .gold]
        var rng = SplitMix64(seed: 7)
        XCTAssertEqual(DifficultySelector().nextDestination(in: "it", progress: p, pack: pack, using: &rng)?.id, "it-florence")
    }
}

final class AdPolicyTests: XCTestCase {
    let policy = AdPolicy(config: MonetizationConfig())

    private func veteranState() -> AdSessionState {
        var s = AdSessionState()
        s.lifetimeRoundsCompleted = 100
        s.roundsSinceLastInterstitial = 10
        return s
    }

    func testNeverDuringChallengeOrLaunchOrResults() {
        for p in [AdPlacement.inChallenge, .appLaunch, .roundResults] {
            XCTAssertEqual(policy.interstitial(at: p, isPlus: false, state: veteranState()), .skip(reason: "placement_forbidden"))
        }
    }

    func testNewPlayersSeeNoInterstitials() {
        XCTAssertEqual(policy.interstitial(at: .betweenRounds, isPlus: false, state: AdSessionState()), .skip(reason: "new_player"))
    }

    func testPlusNeverSeesAds() {
        XCTAssertEqual(policy.interstitial(at: .betweenRounds, isPlus: true, state: veteranState()), .skip(reason: "plus"))
        XCTAssertFalse(policy.canOfferRewarded(isPlus: true, state: veteranState()))
    }

    func testCapsAndGaps() {
        var s = veteranState()
        XCTAssertEqual(policy.interstitial(at: .betweenRounds, isPlus: false, state: s), .show)
        s.lastInterstitialAt = Date()
        XCTAssertEqual(policy.interstitial(at: .betweenRounds, isPlus: false, state: s), .skip(reason: "time_gap"))
        s.interstitialsThisSession = 2
        XCTAssertEqual(policy.interstitial(at: .betweenRounds, isPlus: false, state: s), .skip(reason: "session_cap"))
    }

    func testRemoteConfigOverlay() {
        let json = #"{"maxInterstitialsPerSession": 0, "unknownKey": true}"#.data(using: .utf8)!
        let merged = MonetizationConfig().merged(withJSON: json)
        XCTAssertEqual(merged.maxInterstitialsPerSession, 0)
        XCTAssertEqual(merged.minRoundsBetweenInterstitials, MonetizationConfig().minRoundsBetweenInterstitials)
    }
}

final class PersistenceAndAnalyticsTests: XCTestCase {
    func testSaveLoadRoundTripAndBackupRecovery() throws {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".json")
        let store = ProgressStore(fileURL: url)
        var p = PlayerProgress()
        p.xp = 42
        try store.save(p)
        p.xp = 43
        try store.save(p)                       // first save becomes the backup
        try Data("garbage".utf8).write(to: url) // corrupt main file
        XCTAssertEqual(store.load().xp, 42)     // recovered from backup
        store.reset()
    }

    func testAnalyticsRecordsCarryContext() {
        let sink = InMemoryAnalyticsSink()
        let ctx = AnalyticsContext(installID: "i", installDayKey: "2026-10-17", sessionID: "s", appVersion: "1.0", isPlus: false, experimentGroup: "control")
        let analytics = Analytics(context: ctx, sinks: [sink])
        analytics.track(.stampCollected(destinationID: "it-rome", tier: "gold", isUpgrade: false))
        XCTAssertEqual(sink.records.first?.name, "stamp_collected")
        XCTAssertEqual(sink.records.first?.parameters["tier"], .string("gold"))
        XCTAssertEqual(sink.records.first?.context.installDayKey, "2026-10-17")
    }
}
