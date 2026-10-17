import SwiftUI
import WorldTrailsCore

/// The core game screen: clue cards on top, guesses with distance + direction below,
/// a search field pinned to the bottom.
struct MysteryRoundView: View {
    let destination: Destination
    let source: RoundRequest.Source
    var progressLabel: String?
    let onFinish: (MysteryRound) -> Void
    let onClose: () -> Void

    @Environment(AppModel.self) private var model
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var round: MysteryRound
    @State private var query = ""
    @State private var shake = 0
    @State private var loadingRewarded = false
    @State private var confirmGiveUp = false
    @FocusState private var searchFocused: Bool

    init(destination: Destination, source: RoundRequest.Source, progressLabel: String? = nil,
         onFinish: @escaping (MysteryRound) -> Void, onClose: @escaping () -> Void) {
        self.destination = destination
        self.source = source
        self.progressLabel = progressLabel
        self.onFinish = onFinish
        self.onClose = onClose
        _round = State(initialValue: MysteryRound(target: destination))
    }

    private var suggestions: [Place] {
        GuessSearch.matches(query, in: model.guessPool, excluding: Set(round.guesses.map(\.destinationID)))
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(alignment: .leading, spacing: 12) {
                        if source == .onboarding && round.guesses.isEmpty {
                            onboardingTip
                        }
                        ForEach(Array(round.revealedClues.enumerated()), id: \.offset) { i, clue in
                            ClueCard(number: i + 1, clue: clue, isNewest: i == round.revealedClueCount - 1)
                                .id("clue\(i)")
                                .transition(reduceMotion ? .opacity : .move(edge: .trailing).combined(with: .opacity))
                        }
                        if !round.guesses.isEmpty {
                            Overline(text: "Your guesses").padding(.top, 8)
                            ForEach(round.guesses.reversed()) { GuessRow(guess: $0) }
                        }
                        clueActions
                    }
                    .padding(Theme.gutter)
                    .animation(reduceMotion ? nil : .spring(response: 0.45, dampingFraction: 0.8), value: round.revealedClueCount)
                }
                .scrollDismissesKeyboard(.interactively)
                .onChange(of: round.revealedClueCount) { _, n in
                    withAnimation { proxy.scrollTo("clue\(n - 1)", anchor: .center) }
                }
            }
            guessBar
        }
        .background(Theme.paper)
        .onAppear { model.roundStarted(destination, source: source) }
        .confirmationDialog("Reveal the answer?", isPresented: $confirmGiveUp, titleVisibility: .visible) {
            Button("Reveal answer", role: .destructive) {
                round.giveUp()
                onFinish(round)
            }
        } message: {
            Text("You'll still earn a little XP, and you can come back for this stamp later.")
        }
    }

    // MARK: Pieces

    private var header: some View {
        HStack {
            Button {
                model.roundAbandoned(round)
                onClose()
            } label: {
                Image(systemName: "xmark").font(.headline).frame(width: 44, height: 44)
            }
            .accessibilityLabel("Leave trail")
            .accessibilityIdentifier("closeRound")
            Spacer()
            VStack(spacing: 2) {
                Overline(text: progressLabel ?? "Mystery destination")
                Text("Clue \(round.revealedClueCount) of \(destination.clues.count)")
                    .font(Theme.headline).foregroundStyle(Theme.ink)
            }
            .accessibilityElement(children: .combine)
            Spacer()
            Text("\(round.pointsAvailable)")
                .font(Theme.headline.monospacedDigit())
                .foregroundStyle(Theme.ochre)
                .contentTransition(.numericText(value: Double(round.pointsAvailable)))
                .frame(minWidth: 44)
                .accessibilityLabel("\(round.pointsAvailable) points available")
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .overlay(alignment: .bottom) { Divider() }
    }

    private var onboardingTip: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "lightbulb").foregroundStyle(Theme.ochre)
            Text("Name the place these clues describe. Fewer clues means more points — and a shinier stamp. Wrong guesses reveal the next clue and point you in the right direction.")
                .font(Theme.caption).foregroundStyle(Theme.inkMuted)
        }
        .card()
    }

    @ViewBuilder private var clueActions: some View {
        if round.canRevealMore {
            HStack(spacing: 10) {
                Button {
                    round.revealNextClue()
                    model.clueRevealed(destination, clueNumber: round.revealedClueCount, byGuess: false)
                    Haptics.tap()
                } label: {
                    Text("Next clue · \(nextCluePoints) pts")
                }
                .buttonStyle(SecondaryButtonStyle())
                .accessibilityIdentifier("revealClue")

                if round.canUseFreeClue && model.canOfferRewardedHint && source != .onboarding {
                    Button {
                        Task {
                            loadingRewarded = true
                            if await model.requestRewardedHint() {
                                round.revealFreeClue()
                                model.clueRevealed(destination, clueNumber: round.revealedClueCount, byGuess: false)
                            }
                            loadingRewarded = false
                        }
                    } label: {
                        if loadingRewarded { ProgressView() } else {
                            Label(model.isPlus ? "Free clue" : "Free clue (ad)", systemImage: model.isPlus ? "sparkles" : "play.rectangle")
                        }
                    }
                    .buttonStyle(SecondaryButtonStyle())
                    .disabled(loadingRewarded)
                }
            }
            .padding(.top, 8)
        } else if !round.isOver {
            Button("I'm stuck — reveal the answer") { confirmGiveUp = true }
                .font(Theme.caption)
                .foregroundStyle(Theme.inkMuted)
                .frame(maxWidth: .infinity)
                .padding(.top, 8)
        }
    }

    private var nextCluePoints: Int {
        MysteryRound.cluePoints[min(round.scoringClueNumber, MysteryRound.cluePoints.count - 1)]
    }

    private var guessBar: some View {
        VStack(spacing: 0) {
            if searchFocused && !suggestions.isEmpty {
                ScrollView {
                    VStack(spacing: 0) {
                        ForEach(suggestions) { place in
                            Button { submit(place) } label: {
                                HStack {
                                    Text(place.name).foregroundStyle(Theme.ink)
                                    Spacer()
                                    Text(place.countryName).font(Theme.caption).foregroundStyle(Theme.inkMuted)
                                }
                                .padding(.horizontal, 16).padding(.vertical, 12)
                                .contentShape(Rectangle())
                            }
                            .accessibilityLabel("\(place.name), \(place.countryName)")
                            Divider().padding(.leading, 16)
                        }
                    }
                }
                .frame(maxHeight: 220)
                .background(Theme.card)
            } else if searchFocused && !query.isEmpty {
                Text("No matching places — try a city or landmark name.")
                    .font(Theme.caption).foregroundStyle(Theme.inkMuted).padding(12)
            }
            HStack(spacing: 10) {
                Image(systemName: "magnifyingglass").foregroundStyle(Theme.inkMuted)
                TextField("Where in the world?", text: $query)
                    .focused($searchFocused)
                    .textInputAutocapitalization(.words)
                    .autocorrectionDisabled()
                    .submitLabel(.go)
                    .onSubmit { if let first = suggestions.first { submit(first) } }
                    .accessibilityIdentifier("guessField")
                Text("\(round.guessesRemaining) left")
                    .font(Theme.caption.monospacedDigit())
                    .foregroundStyle(round.guessesRemaining <= 2 ? Theme.danger : Theme.inkMuted)
            }
            .padding(.horizontal, 16)
            .frame(height: 54)
            .background(Theme.card, in: RoundedRectangle(cornerRadius: Theme.smallRadius, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: Theme.smallRadius, style: .continuous).strokeBorder(Theme.rule))
            .modifier(ShakeEffect(shakes: CGFloat(shake)))
            .padding(.horizontal, Theme.gutter)
            .padding(.vertical, 10)
        }
        .background(Theme.paper)
        .disabled(round.isOver)
    }

    private func submit(_ place: Place) {
        guard let guess = try? round.guess(place) else { return }
        query = ""
        if guess.isCorrect {
            Haptics.success()
            searchFocused = false
            finishSoon()
        } else {
            Haptics.warning()
            if !reduceMotion { withAnimation(.default) { shake += 1 } }
            if round.isOver {
                searchFocused = false
                finishSoon()
            } else {
                model.clueRevealed(destination, clueNumber: round.revealedClueCount, byGuess: true)
            }
        }
    }

    /// Brief beat so the player sees the final guess land before results slide in.
    private func finishSoon() {
        let r = round
        Task {
            try? await Task.sleep(for: .milliseconds(reduceMotion ? 150 : 650))
            onFinish(r)
        }
    }
}

// MARK: - Subviews

struct ClueCard: View {
    let number: Int
    let clue: Clue
    let isNewest: Bool

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            ZStack {
                Circle().fill(isNewest ? Theme.terracotta : Theme.rule)
                Image(systemName: clue.kind.symbol)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(isNewest ? .white : Theme.inkMuted)
            }
            .frame(width: 36, height: 36)
            VStack(alignment: .leading, spacing: 4) {
                Overline(text: "Clue \(number) · \(clue.kind.label)")
                Text(clue.text)
                    .font(isNewest ? Theme.title : Theme.body)
                    .foregroundStyle(Theme.ink)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .card()
        .accessibilityElement(children: .combine)
    }
}

struct GuessRow: View {
    let guess: MysteryRound.Guess

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: guess.isCorrect ? "checkmark.circle.fill" : "xmark.circle")
                .foregroundStyle(guess.isCorrect ? Theme.success : Theme.danger)
            Text(guess.name).font(Theme.headline).foregroundStyle(Theme.ink)
            Spacer()
            if !guess.isCorrect {
                Text(guess.distanceKm.formatted() + " km")
                    .font(Theme.caption.monospacedDigit())
                    .foregroundStyle(Theme.inkMuted)
                if let dir = guess.direction {
                    CompassArrow(direction: dir).foregroundStyle(Theme.sea)
                }
                Text("\(guess.proximity)%")
                    .font(Theme.caption.monospacedDigit())
                    .foregroundStyle(proximityColor)
                    .frame(width: 40, alignment: .trailing)
            }
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 14)
        .background(Theme.card, in: RoundedRectangle(cornerRadius: Theme.smallRadius, style: .continuous))
        .accessibilityElement(children: .combine)
        .accessibilityLabel(guess.isCorrect ? "\(guess.name), correct"
                            : "\(guess.name), \(guess.distanceKm) kilometres away, head \(guess.direction?.spokenName ?? "")")
    }

    private var proximityColor: Color {
        switch guess.proximity {
        case 95...: return Theme.success
        case 80..<95: return Theme.ochre
        default: return Theme.inkMuted
        }
    }
}

struct ShakeEffect: GeometryEffect {
    var shakes: CGFloat
    var animatableData: CGFloat {
        get { shakes }
        set { shakes = newValue }
    }
    func effectValue(size: CGSize) -> ProjectionTransform {
        ProjectionTransform(CGAffineTransform(translationX: 8 * sin(shakes * .pi * 4), y: 0))
    }
}
