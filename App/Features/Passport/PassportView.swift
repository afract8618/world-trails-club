import SwiftUI
import WorldTrailsCore

/// The collection: one "page" per country, stamps in their tier colors, empty slots as dashed rings.
struct PassportView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    passportCover
                    ForEach(model.pack.countries) { country in
                        PassportPage(country: country)
                    }
                }
                .padding(Theme.gutter)
            }
            .background(Theme.paper)
            .navigationTitle("Passport")
        }
    }

    private var passportCover: some View {
        let p = model.progress
        return VStack(alignment: .leading, spacing: 10) {
            Overline(text: "World Trails Club · Passport", color: Theme.ochre)
            Text(p.rank.title).font(Theme.display).foregroundStyle(.white)
            HStack(spacing: 18) {
                coverStat("\(p.stamps.count)/\(model.pack.destinations.count)", "stamps")
                coverStat("\(p.completedCountries.count)", "trails")
                coverStat("\(p.streak.best)", "best streak")
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(light: 0x1B2A4A, dark: 0x1B2A4A), in: RoundedRectangle(cornerRadius: Theme.radius, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: Theme.radius, style: .continuous).strokeBorder(Theme.ochre.opacity(0.5), lineWidth: 1).padding(6))
        .accessibilityElement(children: .combine)
    }

    private func coverStat(_ value: String, _ label: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(value).font(Theme.score).foregroundStyle(.white)
            Text(label.uppercased()).font(Theme.overline).foregroundStyle(.white.opacity(0.7))
        }
    }
}

struct PassportPage: View {
    let country: Country
    @Environment(AppModel.self) private var model

    var body: some View {
        let unlocked = model.progress.isUnlocked(country)
        let destinations = model.pack.destinations(in: country.id)
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(country.name).font(Theme.title).foregroundStyle(unlocked ? Theme.ink : Theme.inkMuted)
                Spacer()
                if model.progress.completedCountries.contains(country.id) {
                    Label("Complete", systemImage: "checkmark.seal.fill").font(Theme.caption).foregroundStyle(Theme.success)
                } else if !unlocked {
                    Label("Locked", systemImage: "lock.fill").font(Theme.caption).foregroundStyle(Theme.inkMuted)
                }
            }
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 90), spacing: 12)], spacing: 12) {
                ForEach(destinations) { d in
                    let tier = model.progress.stamps[d.id]
                    VStack(spacing: 4) {
                        StampView(title: d.name, subtitle: country.name, tier: tier, size: 84)
                        if let tier, let date = model.progress.stampDates[d.id] {
                            Text("\(tier.displayName) · \(date.formatted(.dateTime.month(.abbreviated).day()))")
                                .font(Theme.caption).foregroundStyle(Theme.inkMuted)
                        } else {
                            Text(" ").font(Theme.caption)
                        }
                    }
                }
            }
        }
        .card()
        .opacity(unlocked ? 1 : 0.6)
    }
}
