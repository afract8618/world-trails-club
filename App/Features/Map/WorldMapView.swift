import SwiftUI
import MapKit
import WorldTrailsCore

/// The world map: unlocked trails glow, locked ones show what unlocks them.
struct WorldMapView: View {
    @Environment(AppModel.self) private var model
    @State private var selected: Country?
    @State private var camera: MapCameraPosition = .region(MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 25, longitude: 10),
        span: MKCoordinateSpan(latitudeDelta: 120, longitudeDelta: 160)))

    var body: some View {
        NavigationStack {
            Map(position: $camera) {
                ForEach(model.pack.countries) { country in
                    Annotation(country.name, coordinate: CLLocationCoordinate2D(latitude: country.latitude, longitude: country.longitude)) {
                        CountryPin(country: country, state: pinState(country))
                            .onTapGesture { selected = country }
                    }
                }
            }
            .mapStyle(.standard(elevation: .flat, pointsOfInterest: .excludingAll, showsTraffic: false))
            .navigationTitle("World Map")
            .navigationBarTitleDisplayMode(.inline)
            .sheet(item: $selected) { country in
                CountryDetailView(country: country)
                    .presentationDetents([.medium, .large])
                    .environment(model)
            }
            .safeAreaInset(edge: .bottom) { legend }
        }
    }

    private func pinState(_ c: Country) -> CountryPin.PinState {
        if model.progress.completedCountries.contains(c.id) { return .complete }
        return model.progress.isUnlocked(c) ? .open : .locked
    }

    private var legend: some View {
        HStack(spacing: 16) {
            LegendDot(color: Theme.success, label: "Complete")
            LegendDot(color: Theme.terracotta, label: "Open")
            LegendDot(color: Theme.inkMuted, label: "Locked")
        }
        .font(Theme.caption)
        .padding(.horizontal, 14).padding(.vertical, 8)
        .background(.regularMaterial, in: Capsule())
        .padding(.bottom, 8)
    }
}

struct CountryPin: View {
    enum PinState { case open, locked, complete }
    let country: Country
    let state: PinState

    var body: some View {
        let color: Color = state == .complete ? Theme.success : state == .open ? Theme.terracotta : Theme.inkMuted
        ZStack {
            Circle().fill(color).frame(width: 34, height: 34)
            Image(systemName: state == .locked ? "lock.fill" : state == .complete ? "checkmark" : "seal.fill")
                .font(.caption.weight(.bold)).foregroundStyle(.white)
        }
        .overlay(Circle().strokeBorder(.white, lineWidth: 2))
        .shadow(color: .black.opacity(0.2), radius: 3, y: 2)
        .frame(width: 44, height: 44)
        .contentShape(Circle())
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(country.name), \(state == .locked ? "locked" : state == .complete ? "complete" : "open")")
        .accessibilityAddTraits(.isButton)
    }
}

private struct LegendDot: View {
    let color: Color
    let label: String
    var body: some View {
        HStack(spacing: 6) { Circle().fill(color).frame(width: 10, height: 10); Text(label) }
    }
}

struct CountryDetailView: View {
    let country: Country
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss

    private var destinations: [Destination] { model.pack.destinations(in: country.id) }
    private var unlocked: Bool { model.progress.isUnlocked(country) }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Overline(text: country.region.displayName, color: Theme.terracotta)
                Text(country.name).font(Theme.display).foregroundStyle(Theme.ink)
                if unlocked {
                    Text("\(model.progress.stampCount(in: country.id, pack: model.pack)) of \(destinations.count) stamps collected")
                        .font(Theme.body).foregroundStyle(Theme.inkMuted)
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 96))], spacing: 16) {
                        ForEach(destinations) { d in
                            let tier = model.progress.stamps[d.id]
                            Button {
                                startAfterDismiss { model.play(d) }
                            } label: {
                                VStack(spacing: 6) {
                                    StampView(title: d.name, subtitle: country.name, tier: tier, size: 88)
                                    Text(tier == nil ? "Mystery" : d.name).font(Theme.caption).foregroundStyle(Theme.ink)
                                }
                            }
                            .buttonStyle(.plain)
                            .accessibilityHint(tier == nil ? "Play this mystery destination" : "Replay to upgrade your stamp")
                        }
                    }
                    Button("Play next mystery") {
                        startAfterDismiss { model.playTrail(in: country) }
                    }
                    .buttonStyle(PrimaryButtonStyle())
                } else {
                    let names = country.unlockAfter.compactMap { model.pack.country($0)?.name }
                    EmptyStateView(symbol: "lock",
                                   title: "Trail locked",
                                   message: "Complete the \(ListFormatter.localizedString(byJoining: names)) trail to unlock \(country.name).")
                }
            }
            .padding(Theme.gutter)
        }
        .background(Theme.paper)
    }

    /// Let the sheet finish dismissing before the full-screen round is presented.
    private func startAfterDismiss(_ start: @escaping @MainActor () -> Void) {
        dismiss()
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(350))
            start()
        }
    }
}

extension Region {
    var displayName: String {
        switch self {
        case .eastAsia: return "East Asia"
        case .europe: return "Europe"
        case .northAmerica: return "North America"
        case .southAmerica: return "South America"
        case .africa: return "Africa"
        case .middleEast: return "Middle East"
        case .oceania: return "Oceania"
        case .southAsia: return "South Asia"
        }
    }
}
