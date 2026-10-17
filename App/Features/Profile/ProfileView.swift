import SwiftUI
import WorldTrailsCore

struct ProfileView: View {
    @Environment(AppModel.self) private var model
    @AppStorage("haptics") private var haptics = true
    @State private var confirmReset = false

    var body: some View {
        NavigationStack {
            List {
                Section {
                    RankProgressView(progress: model.progress)
                        .padding(.vertical, 6)
                    LabeledContent("Rounds played", value: "\(model.progress.roundsPlayed)")
                    LabeledContent("Solve rate", value: solveRate)
                    LabeledContent("Current streak", value: "\(model.streakToday) days")
                    LabeledContent("Best streak", value: "\(model.progress.streak.best) days")
                    LabeledContent("Rest days banked", value: "\(model.progress.streak.restTokens)")
                }

                Section("Ranks") {
                    ForEach(Rank.allCases, id: \.self) { rank in
                        HStack {
                            Label(rank.title, systemImage: rank.symbol)
                                .foregroundStyle(model.progress.rank >= rank ? Theme.ink : Theme.inkMuted)
                            Spacer()
                            Text("\(rank.xpRequired.formatted()) XP").font(Theme.caption.monospacedDigit()).foregroundStyle(Theme.inkMuted)
                            if model.progress.rank >= rank { Image(systemName: "checkmark").foregroundStyle(Theme.success) }
                        }
                    }
                }

                Section("Membership") {
                    if model.isPlus {
                        Label("World Trails Club Plus — active", systemImage: "sparkles").foregroundStyle(Theme.ochre)
                    } else {
                        Button { model.presentPaywall(source: "profile") } label: {
                            Label("Join World Trails Club Plus", systemImage: "sparkles")
                        }
                    }
                    Button("Restore purchases") { Task { await model.purchases.restore() } }
                }

                Section("Settings") {
                    Toggle("Haptics", isOn: $haptics)
                    LabeledContent("Reduce motion", value: "Follows iOS setting")
                    LabeledContent("Text size", value: "Follows iOS setting")
                }

                Section {
                    Button("Reset all progress", role: .destructive) { confirmReset = true }
                } footer: {
                    Text("World Trails Club stores your progress on this device. Analytics use a random install ID and are never linked to your identity.")
                }
            }
            .navigationTitle("Profile")
            .confirmationDialog("Reset all progress?", isPresented: $confirmReset, titleVisibility: .visible) {
                Button("Reset everything", role: .destructive) { model.resetProgress() }
            } message: {
                Text("Stamps, XP and streaks will be erased. Purchases are not affected.")
            }
        }
    }

    private var solveRate: String {
        guard model.progress.roundsPlayed > 0 else { return "—" }
        return (Double(model.progress.roundsSolved) / Double(model.progress.roundsPlayed)).formatted(.percent.precision(.fractionLength(0)))
    }
}
