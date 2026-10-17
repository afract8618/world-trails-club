import SwiftUI
import WorldTrailsCore

/// Post-round celebration: the stamp lands, XP counts up, the fact rewards curiosity.
struct ResultsView: View {
    let round: MysteryRound
    let summary: RewardSummary
    let pack: ContentPack
    let primaryTitle: String
    let onPrimary: () -> Void
    let onClose: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var stamped = false

    private var result: RoundResult? { round.result }
    private var solved: Bool { result?.solved == true }
    private var countryName: String { pack.country(round.target.countryID)?.name ?? "" }

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                HStack {
                    Spacer()
                    Button(action: onClose) { Image(systemName: "xmark").font(.headline).frame(width: 44, height: 44) }
                        .accessibilityLabel("Close")
                }
                Overline(text: solved ? "Destination found" : "The answer was", color: solved ? Theme.success : Theme.inkMuted)
                Text(round.target.name)
                    .font(Theme.display).foregroundStyle(Theme.ink)
                    .multilineTextAlignment(.center)
                    .accessibilityIdentifier("resultsTitle")
                Text(countryName).font(Theme.headline).foregroundStyle(Theme.inkMuted)

                StampView(title: round.target.name, subtitle: countryName, tier: result?.tier, size: 150)
                    .scaleEffect(stamped || reduceMotion ? 1 : 2.2)
                    .opacity(stamped || reduceMotion ? 1 : 0)
                    .padding(.vertical, 8)

                rewardLines

                VStack(alignment: .leading, spacing: 6) {
                    Overline(text: "Field notes")
                    Text(round.target.fact).font(Theme.body).foregroundStyle(Theme.ink)
                }
                .card()

                Button(primaryTitle, action: onPrimary)
                    .buttonStyle(PrimaryButtonStyle())
                    .accessibilityIdentifier("resultsPrimary")
            }
            .padding(Theme.gutter)
        }
        .background(Theme.paper)
        .onAppear {
            guard !reduceMotion else { stamped = true; return }
            withAnimation(.spring(response: 0.35, dampingFraction: 0.55).delay(0.25)) { stamped = true }
        }
        .sensoryFeedback(.success, trigger: stamped) { _, new in new && solved && Haptics.enabled }
    }

    @ViewBuilder private var rewardLines: some View {
        VStack(spacing: 10) {
            if let r = result, r.solved {
                RewardLine(symbol: "star.fill", text: "\(r.points) points · solved on clue \(r.cluesUsed)", color: Theme.ochre)
            }
            RewardLine(symbol: "plus.circle.fill", text: "+\(summary.xpGained) XP", color: Theme.ochre)
            if let tier = summary.newStamp {
                RewardLine(symbol: "seal.fill", text: "New \(tier.displayName) stamp for your passport", color: Theme.tierColor(tier))
            }
            if let up = summary.upgradedStamp {
                RewardLine(symbol: "arrow.up.circle.fill", text: "Stamp upgraded: \(up.from.displayName) → \(up.to.displayName)", color: Theme.tierColor(up.to))
            }
            if let c = summary.completedCountry, let name = pack.country(c)?.name {
                RewardLine(symbol: "flag.checkered", text: "\(name) trail complete!", color: Theme.success)
            }
            ForEach(summary.unlockedCountries, id: \.self) { id in
                RewardLine(symbol: "lock.open.fill", text: "New trail unlocked: \(pack.country(id)?.name ?? id)", color: Theme.sea)
            }
            if let rank = summary.rankUp {
                RewardLine(symbol: rank.symbol, text: "Rank up — you're now a \(rank.title)", color: Theme.terracotta)
            }
            if result?.solved == false {
                Text("Every trail can be replayed. Come back for this stamp anytime.")
                    .font(Theme.caption).foregroundStyle(Theme.inkMuted)
            }
        }
        .frame(maxWidth: .infinity)
    }
}

struct RewardLine: View {
    let symbol: String
    let text: String
    let color: Color
    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: symbol).foregroundStyle(color)
            Text(text).font(Theme.headline).foregroundStyle(Theme.ink)
            Spacer()
        }
        .padding(.horizontal, 14).padding(.vertical, 10)
        .background(color.opacity(0.10), in: RoundedRectangle(cornerRadius: Theme.smallRadius, style: .continuous))
        .accessibilityElement(children: .combine)
    }
}

/// Onboarding beat 3: show where the stamp went and why to come back.
struct OnboardingPassportView: View {
    let round: MysteryRound
    let summary: RewardSummary
    let onDone: () -> Void
    @Environment(AppModel.self) private var model

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Spacer()
            Overline(text: "Your passport", color: Theme.terracotta)
            Text("This is where every trail ends up.")
                .font(Theme.display).foregroundStyle(Theme.ink)
            HStack(spacing: 14) {
                StampView(title: round.target.name, subtitle: "first", tier: round.result?.tier, size: 88)
                StampView(title: "", subtitle: "", tier: nil, size: 88)
                StampView(title: "", subtitle: "", tier: nil, size: 88)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
            VStack(alignment: .leading, spacing: 10) {
                OnboardingPoint(symbol: "seal", text: "Solve on fewer clues for Gold stamps. Replay anytime to upgrade.")
                OnboardingPoint(symbol: "map", text: "Complete a country's trail to unlock new countries on the map.")
                OnboardingPoint(symbol: "sun.horizon", text: "A new 3-stop Daily Expedition opens every day — the same one for everyone.")
                OnboardingPoint(symbol: model.progress.rank.symbol, text: "Earn XP to rise from Explorer to World Legend.")
            }
            Spacer()
            Button("Start exploring", action: onDone)
                .buttonStyle(PrimaryButtonStyle())
                .accessibilityIdentifier("finishOnboarding")
        }
        .padding(Theme.gutter)
        .background(Theme.paper)
    }
}

private struct OnboardingPoint: View {
    let symbol: String
    let text: String
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: symbol).foregroundStyle(Theme.sea).frame(width: 24)
            Text(text).font(Theme.body).foregroundStyle(Theme.ink)
        }
    }
}

/// End of the Daily Expedition: score, streak, and a spoiler-free share card.
struct DailySummaryView: View {
    let rounds: [MysteryRound]
    let dayKey: String
    let streak: Int
    let outcome: Streak.Outcome
    let onDone: () -> Void
    @Environment(AppModel.self) private var model

    private var total: Int { rounds.compactMap(\.result).reduce(0) { $0 + $1.points } }

    /// Wordle-style grid: one row per stop, one square per clue used. No answers revealed.
    private var shareText: String {
        let rows = rounds.map { r -> String in
            guard let res = r.result else { return "" }
            let used = String(repeating: res.solved ? "🟨" : "⬛️", count: max(0, res.cluesUsed - 1))
            return used + (res.solved ? "🟩" : "⬛️") + String(repeating: "⬜️", count: max(0, 5 - res.cluesUsed))
        }
        return "World Trails Club · Daily \(dayKey)\n\(rows.joined(separator: "\n"))\n\(total) pts · 🔥\(streak)"
    }

    private var streakMessage: String {
        switch outcome {
        case .started: return "Streak started. See you tomorrow."
        case .extended: return "\(streak)-day streak. Nicely done."
        case .savedByRestTokens(let n): return "Welcome back! \(n == 1 ? "A rest day" : "\(n) rest days") kept your \(streak)-day streak alive."
        case .restarted(let prev): return "New streak started. Your best is \(max(prev, model.progress.streak.best)) days."
        case .alreadyCountedToday: return "Today's expedition is already in the book."
        }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                Overline(text: "Daily expedition · \(dayKey)", color: Theme.terracotta).padding(.top, 32)
                Text("\(total)").font(.system(size: 64, weight: .bold, design: .serif).monospacedDigit()).foregroundStyle(Theme.ink)
                Text("points today").font(Theme.headline).foregroundStyle(Theme.inkMuted)
                HStack(spacing: 12) {
                    ForEach(Array(rounds.enumerated()), id: \.offset) { _, r in
                        StampView(title: r.target.name, subtitle: model.pack.country(r.target.countryID)?.name ?? "", tier: r.result?.tier, size: 96)
                    }
                }
                Label(streakMessage, systemImage: "flame.fill")
                    .font(Theme.headline).foregroundStyle(Theme.ink)
                    .card()
                Text("Tomorrow's expedition opens at midnight. Three new places, same for every explorer.")
                    .font(Theme.caption).foregroundStyle(Theme.inkMuted).multilineTextAlignment(.center)
                ShareLink(item: shareText) {
                    Label("Share result", systemImage: "square.and.arrow.up")
                }
                .buttonStyle(SecondaryButtonStyle())
                .simultaneousGesture(TapGesture().onEnded { model.analytics.track(.shareTapped(context: "daily")) })
                Button("Done", action: onDone).buttonStyle(PrimaryButtonStyle())
            }
            .padding(Theme.gutter)
        }
        .background(Theme.paper)
    }
}
