import SwiftUI
import WorldTrailsCore

/// Runs a RoundRequest: one or more Mystery Destination rounds, then results
/// (and, for the Daily Expedition, a shareable summary).
struct RoundFlowView: View {
    let request: RoundRequest
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss

    private enum Phase {
        case playing
        case results(MysteryRound, RewardSummary)
        case dailySummary(Streak.Outcome)
        case onboardingPassport(MysteryRound, RewardSummary)
    }

    @State private var index = 0
    @State private var phase: Phase = .playing
    @State private var finishedRounds: [MysteryRound] = []

    var body: some View {
        ZStack {
            Theme.paper.ignoresSafeArea()
            switch phase {
            case .playing:
                MysteryRoundView(
                    destination: request.destinations[index],
                    source: request.source,
                    progressLabel: request.destinations.count > 1 ? "Stop \(index + 1) of \(request.destinations.count)" : nil,
                    onFinish: finish,
                    onClose: { dismiss() }
                )
                .id(index) // fresh state per round
                .transition(.opacity)
            case .results(let round, let summary):
                ResultsView(round: round, summary: summary, pack: model.pack,
                            primaryTitle: primaryTitle, onPrimary: advance, onClose: close)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            case .onboardingPassport(let round, let summary):
                OnboardingPassportView(round: round, summary: summary) {
                    model.completeOnboarding()
                    dismiss()
                }
                .transition(.opacity)
            case .dailySummary(let outcome):
                DailySummaryView(rounds: finishedRounds, dayKey: request.dayKey ?? model.todayKey,
                                 streak: model.progress.streak.current, outcome: outcome, onDone: close)
                    .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.3), value: phaseKey)
    }

    private var phaseKey: String {
        switch phase {
        case .playing: return "play\(index)"
        case .results: return "results\(index)"
        case .dailySummary: return "daily"
        case .onboardingPassport: return "passport"
        }
    }

    private var isLastRound: Bool { index == request.destinations.count - 1 }

    private var primaryTitle: String {
        switch request.source {
        case .onboarding: return "Open my passport"
        case .daily: return isLastRound ? "See today's expedition" : "Next stop"
        case .trail: return "Keep exploring"
        }
    }

    private func finish(_ round: MysteryRound) {
        let summary = model.roundFinished(round)
        finishedRounds.append(round)
        phase = .results(round, summary)
    }

    private func advance() {
        guard case .results(let round, let summary) = phase else { return }
        switch request.source {
        case .onboarding:
            phase = .onboardingPassport(round, summary)
        case .daily:
            if isLastRound {
                let total = finishedRounds.compactMap(\.result).reduce(0) { $0 + $1.points }
                phase = .dailySummary(model.dailyFinished(dayKey: request.dayKey ?? model.todayKey, totalPoints: total))
            } else {
                index += 1
                phase = .playing
            }
        case .trail:
            // Natural break: the only place an interstitial may appear in a trail.
            Task {
                await model.maybeShowInterstitial(placement: .betweenRounds)
                if let country = model.pack.country(round.target.countryID), !model.progress.completedCountries.contains(country.id),
                   let next = DifficultySelector().nextDestination(in: country.id, progress: model.progress, pack: model.pack, excluding: round.target.id) {
                    model.play(next) // replaces activeRequest → new flow
                } else {
                    dismiss()
                }
            }
        }
    }

    private func close() {
        if case .dailySummary = phase {
            Task { await model.maybeShowInterstitial(placement: .dailyComplete) }
        }
        dismiss()
    }
}
