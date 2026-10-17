# World Trails Club — Game Design Document (v0.1, Milestone 1)

*Explore the world. One trail at a time.*

Status legend used throughout: **[Built]** exists in this repo · **[Planned]** designed, not built · **[Hypothesis]** a number or claim to be tested with real data, not a promise.

---

## A. Product vision

**The pitch:** a daily geography mystery you solve with *reasoning*, not recall — and every answer becomes a stamp in a passport you're proud of.

Most geography apps are either (a) multiple-choice quizzes that test memory and feel like homework, or (b) GeoGuessr-style street-view games that need expensive licensed imagery and a big time commitment. World Trails Club sits between them:

- **Deduction over trivia.** Clues go from obscure to obvious. Every wrong guess tells you *how far* and *which way* the answer is, so a guess is never wasted — you triangulate. That "warmer/colder" loop is what makes it a game rather than a quiz.
- **A collection that means something.** Stamp quality reflects *how* you solved it (Gold = first clue). Players replay to upgrade, not to grind.
- **A shared daily ritual.** Everyone in the world gets the same 3-stop Daily Expedition and can share a spoiler-free result grid.
- **Cheap to make well.** Content is text + coordinates, so we can ship dozens of polished destinations without licensing photography, and validate every clue automatically.

**USP:** *"Wordle's daily ritual + Worldle's distance-and-direction deduction + a collectible travel passport."* No single competitor combines all three, and the passport gives long-term progression that pure daily-puzzle games lack.

## B. Core loop — first session, minute by minute

| Time | What the player does | Why |
|---|---|---|
| 0:00 | Welcome screen: one sentence, one button, "takes about 30 seconds". No sign-up, no permission prompts. **[Built]** | Every pre-play screen costs players. |
| 0:05 | First mystery opens on a famous place in a starter country (Rome) with an inline tip. Clue 1 shows. **[Built]** | Guarantees an early win. |
| 0:10–0:30 | Player types a guess. Wrong → distance + compass arrow + next clue. Right → stamp slams onto the results card with haptic, +XP, a fact. **[Built]** | First win inside 30 s (UI test asserts it). |
| 0:30–1:00 | "This is your passport": the stamp + two empty slots, four lines explaining tiers, trails, daily, ranks. **[Built]** | Establishes the long-term goal before they get bored. |
| 1:00–3:00 | Home: Daily Expedition card (3 stops) or continue a trail. Distance/direction mechanic shows its depth on harder places. **[Built]** | Strongest feature demonstrated by minute 3. |
| 3:00–10:00 | ~5–8 rounds total. Rank up to Pathfinder (500 XP) lands around round 5–6. Completing a 3-stop country unlocks the next country on the map. **[Built]** | Progression system is visible and felt within 10 minutes. |

A single round is 20–60 s; a Daily Expedition is ~2–3 min; a trail session can go as long as the player likes.

## C. Five differentiating features

1. **Distance + direction feedback on every wrong guess** [Built]. Turns guessing into triangulation. A decoy gazetteer of 100+ world places means you can't solve by elimination.
2. **Skill-earned stamp tiers** [Built]. Gold/Silver/Bronze by clue number. No random drops, no gacha — rarity means "I was good at this."
3. **Same-for-everyone Daily Expedition with a spoiler-free share grid** [Built]. Deterministic seeding (FNV-1a + SplitMix64) so it's identical worldwide.
4. **Trails that unlock the map** [Built]. Countries open by completing neighbors; the map *is* the progress bar.
5. **Forgiving streaks** [Built]. Missing a day spends an earned "Rest Day" token instead of wiping the streak. Tokens are earned (1 per 7 days, max 2) and **never sold**.

## Challenge-mode evaluation (why only one mode ships first)

| Mode | Fun | Build cost | Content cost | Replay | Verdict |
|---|---|---|---|---|---|
| **Mystery Destination** | High (deduction) | Low | Low (text) | High | **Ship in MVP** — core mode |
| GeoGuess (visual clues) | High | Med | **High** (licensed images) | High | Later; photo licensing is the blocker |
| Landmark Hunt | Med | Med | High (images) | Med | Fold into Mystery as clue type later |
| Route Builder | Med–High | High (map interaction, solver) | Med | Med | Phase 5 candidate if data supports |
| Culture Quest | Low–Med | Low | Med | Low | Feels like a quiz; merge into clues instead |
| Flag Sprint | Med | Low | Low | Med | Cheap bonus mode — strong Phase 3 candidate |
| Daily Expedition | High | Low (reuses Mystery) | None | High | **Ship in MVP** |
| Travel Puzzle | Unknown | High | Med | Med | Needs paper prototype first |

Founder call: the brief lists eight modes; shipping eight mediocre modes would be the biggest risk to this product. One excellent mode + a daily wrapper is enough to test retention.

## D. Retention strategy

Principles: return because it's fun, not because you're scared to lose something. Max one notification per day, opt-in only, never before the player has finished a Daily.

| Return point | Reason to come back | Status |
|---|---|---|
| **D1** | New Daily Expedition (3 fresh places). Streak = 1 → 2. Incomplete first trail shows "1 of 3 stamps". | Built |
| **D3** | First trail likely completed → new country unlocked. Silver stamps visibly upgradable to Gold. | Built |
| **D7** | 7-day streak earns a Rest Day token (shown in Profile). Weekly goal ("stamp 5 new places") | Token built; weekly goals Planned |
| **D30** | Adventurer rank (2,000 XP) territory; new destination pack (live ops); monthly passport recap card to share. | Ranks built; packs & recap Planned |
| Lapsed | Returning player sees streak saved by tokens where possible; "Welcome back" bonus XP. | Saving built; bonus Planned |

Notifications [Planned]: one daily reminder at the player's usual play time, only if they opted in after their 3rd session; auto-pause after 3 ignored.

## E. Monetization

**Free players get the whole game.** Every country, the daily, all ranks and stamps.

### Ads (rules enforced in `AdPolicy`, unit-tested) [Built as policy; SDK Planned]
- **Rewarded (opt-in only):** "Free clue (ad)" — reveals a clue *without* the point penalty, max 1 per round, 6 per day.
- **Interstitials:** only at `betweenRounds` (after leaving a results screen) or after the Daily is done.
  Never at launch, never during a round, never over the results/reward moment.
  None until the player has finished **15 rounds lifetime**; then ≥4 rounds and ≥4 minutes apart, max 2 per session. All values are remote-configurable.
- Test plan: holdout group with interstitials off. If D7 retention for the ads group drops more than the ad revenue gained (compare ARPDAU × retained days), dial them down. **Do not assume more ads = more revenue.**

### World Trails Club Plus [Built: StoreKit 2 flow, restore; Products need App Store Connect]
- No ads · free clue every round without an ad · exclusive passport covers & stamp inks [Planned] · Plus collections (special themed packs, never core countries) [Built as content flag] · detailed stats [Planned].
- Products: `club.plus.monthly`, `club.plus.annual`, `club.plus.lifetime`.
- **Pricing [Hypothesis — not yet researched against live competitors]:** start at $2.99/mo, $19.99/yr (with 7-day trial), $39.99 lifetime. Before launch, verify against current App Store prices of comparable daily-puzzle subscriptions and test with an A/B on the annual price. No conversion rate is assumed in this document.
- Paywall rules: never shown before round 8 except when the player taps it; close button always visible; renewal terms and Restore on screen.

## F. Visual direction

"Modern travel magazine meets vintage passport." [Built: tokens in `App/Design/Theme.swift`]

- **Color:** warm paper `#F6F1E7` / ink `#1D2433` (dark: `#12151C` / `#EDE6D8`); terracotta `#C4553A` for actions; sea `#2A7F8E` for map/info; ochre `#C98A1B` for XP/rewards; stamp tiers gold/silver/bronze. Every color has a dark-mode pair.
- **Type:** New York (system serif) for headlines and stamps — editorial; SF Pro for UI; SF Mono small caps for "overline" section labels like a magazine. All text uses Dynamic Type styles.
- **Motion:** stamp "slam" (scale 2.2→1 spring + rotation), clue cards slide in, compass arrow swings to bearing, guess bar shakes on a miss. All gated on Reduce Motion.
- **Layout:** one primary action per screen, cards on paper, generous 20 pt gutters, nothing scrolls horizontally.
- **Iconography:** SF Symbols only for v1 (consistent, accessible, free). Custom illustrated destination art is the main Phase 3 art investment — commissioned or licensed, never scraped.

## G. MVP scope

**In (this milestone):** Mystery Destination mode · 6 countries × 3 destinations · 109-place decoy gazetteer · world map with unlock graph · passport · XP + 5 ranks · Daily Expedition + forgiving streak · adaptive difficulty · analytics event schema + debug sink · ad policy + simulated ad service · StoreKit 2 Plus flow · local persistence with backup recovery · unit tests (core) and UI tests (first session).

**Next milestone (still MVP):** real ad SDK + consent; analytics vendor adapter; Game Center leaderboard for the Daily; App icon & destination illustrations; 6→10 countries; notifications opt-in; weekly goals.

**Postponed until data says so:** friend challenges, weekly competitions, multiplayer, Route Builder, Travel Puzzle, image-based modes, iPad layout (code is size-class-ready but untuned).

## H. Architecture & implementation order

```
WorldTrailsClub/
├── project.yml                      XcodeGen spec (generates the .xcodeproj)
├── App/                             iOS app target (SwiftUI, iOS 17+)
│   ├── WorldTrailsClubApp.swift     launch, content load, scene phase → sessions
│   ├── AppModel.swift               @Observable app state; the only writer of progress
│   ├── Design/                      Theme tokens + reusable components
│   ├── Features/                    Onboarding, Home, Map, Trail (round/results/daily), Passport, Profile, Plus
│   └── Services/                    PurchaseManager (StoreKit 2), AdService seam, analytics sink
├── Packages/WorldTrailsCore/        Pure Swift package — no UIKit/SwiftUI, fully unit-tested
│   ├── Models/        Country, Destination, Place, Geo math
│   ├── Content/       loader + validator (answer-leak, duplicates, unlock-graph cycles)
│   ├── Game/          MysteryRound state machine, search, daily seeding, adaptive difficulty
│   ├── Progression/   XP, ranks, stamps, trail unlocks, streaks
│   ├── Monetization/  MonetizationConfig (remote overlay) + AdPolicy
│   ├── Analytics/     typed event schema, context envelope, sinks
│   └── Persistence/   atomic JSON save + rolling backup, tolerant decoding
├── Tools/build_content.py           generates + validates destinations.json
└── UITests/                         first-session funnel tests
```

Key decisions:
- **Game rules live in a platform-free package.** Testable in seconds, reusable for iPad/macOS/widgets, and a server could share the same rules later.
- **Progress persistence is a single atomic JSON snapshot + backup**, not SwiftData. It's one small document that must never be half-written; tolerant decoding means new fields never wipe old saves. SwiftData is reserved for large queryable data (e.g. round history) if we need it.
- **Content is data.** New countries = new JSON entries; validator blocks bad content at load. A downloadable content pack can layer on later.
- **SpriteKit not used** in v1: nothing in the core mode needs a game loop; SwiftUI animations are enough and cheaper to maintain.

Implementation order: core rules + tests → content pipeline → round screen → results/onboarding → home/map/passport → daily → monetization seams → **(next)** SDKs, art, Game Center, notifications.

---

## Analytics: metric definitions

All events carry `install_id` (random UUID, not IDFA), `install_day_key` (cohort), `session_id`, `app_version`, `is_plus`, `experiment_group`, local `day_key`. Schema in `Analytics.swift`.

| Metric | Definition |
|---|---|
| DAU / MAU | Distinct `install_id` with ≥1 `session_start` on a local day / in trailing 28 days |
| D*n* retention | Of installs in cohort day C, share with ≥1 `session_start` on day C+*n* (exact day, not "within") |
| Session frequency | `session_start` count per DAU per day |
| Median session duration | Median of `session_end.duration_s` (sessions with no end event excluded and counted separately) |
| Challenge completion rate | `challenge_completed` ÷ `challenge_started` (same mode) |
| Solve rate | `challenge_completed` where `solved=true` ÷ `challenge_completed` |
| Onboarding funnel | `first_launch` → `onboarding_started` → first `challenge_completed(is_first_ever)` → `onboarding_completed` |
| Rewarded opt-in rate | `rewarded_ad_started` ÷ `rewarded_ad_offered` |
| Ad completion rate | `rewarded_ad_completed` ÷ `rewarded_ad_started` |
| Ad impressions / DAU | (`interstitial_shown` + `rewarded_ad_completed`) ÷ DAU |
| Ad ARPDAU | Σ `ad_revenue.value_micros`/1e6 ÷ DAU |
| Subscription conversion | Installs with `purchase_completed` ÷ installs, per cohort, at D7/D30 |
| Trial conversion | Trials (`is_trial=true`) that reach a paid renewal (from App Store Server Notifications) ÷ trials |
| ARPU / ARPDAU | (IAP revenue + ad revenue) ÷ users / ÷ DAU |
| LTV | Cumulative revenue per install by cohort day N (observed, not projected, until 90 days of data) |

**Benchmark hypotheses** (to test, not promises): D1 ≥ 35%, D7 ≥ 12%, D30 ≥ 5%, first-challenge completion ≥ 85%, onboarding completion ≥ 75%. Kill/pivot signal: D1 < 20% after onboarding iterations.

## Competitive notes [Hypothesis — from general knowledge, not yet verified with review mining]

- **Worldle / daily web geography puzzles:** proved distance+direction deduction is fun and shareable; weak long-term progression, one puzzle a day caps engagement.
- **GeoGuessr:** deep and beloved, but needs licensed imagery and long sessions; subscription-heavy.
- **Seterra-style map quizzes:** great for learning, feel like study tools.
- **Duolingo:** benchmark for streak mechanics — and for streak-anxiety complaints we avoid with earned rest days.

Before Phase 2 ends: mine App Store reviews of 5–8 competitors for top complaints (ads, paywalls, repetition), record findings with sources in `RESEARCH.md`.

## Roadmap

1. **Spec, prototype, design system** — *this milestone (done, pending first device build).*
2. **Vertical slice** — art, app icon, onboarding polish, Game Center daily leaderboard, notifications opt-in.
3. **Content & monetization** — 10+ countries, Flag Sprint bonus mode, ad SDK + consent, analytics vendor, Plus cosmetics.
4. **TestFlight** — 50–200 testers, measure D1/D7, iterate onboarding, App Store submission.
5. **Live ops** — monthly destination packs, themed Plus collections, monetization experiments.
