import SwiftUI
import WorldTrailsCore

/// First screen. One tap and the player is inside their first mystery — no account, no tutorial wall.
struct WelcomeView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var appeared = false

    var body: some View {
        ZStack {
            Theme.paper.ignoresSafeArea()
            VStack(alignment: .leading, spacing: 0) {
                Overline(text: "World Trails Club · Est. 2026", color: Theme.terracotta)
                    .padding(.top, 24)
                Spacer()
                StampView(title: "Your first stamp", subtitle: "awaits", tier: .gold, size: 140)
                    .opacity(appeared ? 1 : 0)
                    .scaleEffect(appeared || reduceMotion ? 1 : 1.4)
                    .frame(maxWidth: .infinity)
                    .accessibilityHidden(true)
                Spacer()
                Text("Explore the world.\nOne trail at a time.")
                    .font(Theme.display)
                    .foregroundStyle(Theme.ink)
                    .fixedSize(horizontal: false, vertical: true)
                Text("Read the clues. Name the place. Fill your passport with stamps from every corner of the map.")
                    .font(Theme.body)
                    .foregroundStyle(Theme.inkMuted)
                    .padding(.top, 12)
                Button {
                    Haptics.tap()
                    model.beginOnboarding()
                } label: {
                    Label("Start your first trail", systemImage: "arrow.right")
                        .labelStyle(.titleAndIcon)
                }
                .buttonStyle(PrimaryButtonStyle())
                .padding(.top, 28)
                .accessibilityIdentifier("startFirstTrail")
                Text("Takes about 30 seconds")
                    .font(Theme.caption)
                    .foregroundStyle(Theme.inkMuted)
                    .frame(maxWidth: .infinity)
                    .padding(.top, 10)
                    .padding(.bottom, 16)
            }
            .padding(.horizontal, Theme.gutter)
        }
        .onAppear {
            withAnimation(reduceMotion ? nil : .spring(response: 0.7, dampingFraction: 0.6).delay(0.2)) { appeared = true }
        }
    }
}
