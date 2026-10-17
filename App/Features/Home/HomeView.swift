import SwiftUI
import WorldTrailsCore

struct HomeView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    header
                    dailyCard
                    continueCard
                    RankProgressView(progress: model.progress).card()
                    statsRow
                    if model.shouldShowSoftPaywallPrompt {
                        plusTeaser
                    }
                }
                .padding(Theme.gutter)
            }
            .background(Theme.paper)
            .toolbar(.hidden, for: .navigationBar)
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            Overline(text: Date().formatted(.dateTime.weekday(.wide).month().day()), color: Theme.terracotta)
            Text(greeting).font(Theme.display).foregroundStyle(Theme.ink)
        }
        .padding(.top, 8)
    }

    private var greeting: String {
        let stamps = model.progress.stamps.count
        return stamps == 0 ? "Where to first?" : "\(stamps) stamp\(stamps == 1 ? "" : "s") and counting."
    }

    private var dailyCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Overline(text: "Daily expedition", color: Theme.terracotta)
                Spacer()
                Label("\(model.streakToday)", systemImage: "flame.fill")
                    .font(Theme.caption.monospacedDigit())
                    .foregroundStyle(model.streakToday > 0 ? Theme.terracotta : Theme.inkMuted)
                    .accessibilityLabel("\(model.streakToday) day streak")
            }
            if model.dailyDoneToday {
                Text("Today's expedition is complete.").font(Theme.title).foregroundStyle(Theme.ink)
                Text("Three new mystery places arrive at midnight.").font(Theme.body).foregroundStyle(Theme.inkMuted)
            } else {
                Text("Three mystery places. Same for every explorer today.")
                    .font(Theme.title).foregroundStyle(Theme.ink)
                Button("Begin today's expedition") { model.playDaily() }
                    .buttonStyle(PrimaryButtonStyle())
                    .accessibilityIdentifier("playDaily")
            }
        }
        .card()
    }

    @ViewBuilder private var continueCard: some View {
        if let country = model.recommendedCountry {
            let total = model.pack.destinations(in: country.id).count
            let done = model.progress.stampCount(in: country.id, pack: model.pack)
            VStack(alignment: .leading, spacing: 12) {
                Overline(text: done == 0 ? "Start a trail" : "Continue your trail")
                Text(country.name).font(Theme.title).foregroundStyle(Theme.ink)
                ProgressView(value: Double(done), total: Double(max(total, 1))).tint(Theme.sea)
                Text("\(done) of \(total) stamps").font(Theme.caption).foregroundStyle(Theme.inkMuted)
                Button("Play \(country.name)") { model.playTrail(in: country) }
                    .buttonStyle(SecondaryButtonStyle())
                    .accessibilityIdentifier("continueTrail")
            }
            .card()
        } else {
            EmptyStateView(symbol: "globe.americas", title: "Every trail complete",
                           message: "You've stamped every destination we have. New countries are on the way — replay trails to upgrade stamps to Gold.")
                .card()
        }
    }

    private var statsRow: some View {
        HStack(spacing: 12) {
            StatTile(value: "\(model.progress.completedCountries.count)", label: "Countries")
            StatTile(value: "\(model.progress.stamps.count)", label: "Stamps")
            StatTile(value: "\(model.progress.stamps.values.filter { $0 == .gold }.count)", label: "Gold")
        }
    }

    private var plusTeaser: some View {
        Button { model.presentPaywall(source: "home_teaser") } label: {
            HStack {
                Image(systemName: "sparkles").foregroundStyle(Theme.ochre)
                VStack(alignment: .leading, spacing: 2) {
                    Text("World Trails Club Plus").font(Theme.headline).foregroundStyle(Theme.ink)
                    Text("No ads, a free clue every round, exclusive passport covers.").font(Theme.caption).foregroundStyle(Theme.inkMuted)
                }
                Spacer()
                Image(systemName: "chevron.right").foregroundStyle(Theme.inkMuted)
            }
            .card()
        }
        .buttonStyle(.plain)
    }
}

struct StatTile: View {
    let value: String
    let label: String
    var body: some View {
        VStack(spacing: 4) {
            Text(value).font(Theme.score).foregroundStyle(Theme.ink)
            Text(label).font(Theme.caption).foregroundStyle(Theme.inkMuted)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .background(Theme.card, in: RoundedRectangle(cornerRadius: Theme.smallRadius, style: .continuous))
        .accessibilityElement(children: .combine)
    }
}
