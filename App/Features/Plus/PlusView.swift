import SwiftUI
import StoreKit
import WorldTrailsCore

/// World Trails Club Plus paywall. Honest by design: clear prices, clear renewal terms,
/// easy close, restore button, no fake countdowns.
struct PlusView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    Overline(text: "Membership", color: Theme.ochre)
                    Text("World Trails Club Plus").font(Theme.display).foregroundStyle(Theme.ink)
                    Text("Everything in the game stays free to play. Plus is for explorers who want to go further and support the club.")
                        .font(Theme.body).foregroundStyle(Theme.inkMuted)

                    VStack(alignment: .leading, spacing: 12) {
                        Benefit(symbol: "nosign", text: "No ads, ever")
                        Benefit(symbol: "lightbulb", text: "A free clue every round — no ad required")
                        Benefit(symbol: "book.closed", text: "Exclusive passport covers and stamp inks")
                        Benefit(symbol: "map", text: "Special collections (e.g. Wonders of the World) as they release")
                        Benefit(symbol: "chart.bar", text: "Detailed travel stats")
                    }
                    .card()

                    products

                    Button("Restore purchases") { Task { await model.purchases.restore() } }
                        .frame(maxWidth: .infinity)
                    Text("Subscriptions renew automatically unless cancelled at least 24 hours before the end of the period. Manage or cancel anytime in your Apple ID settings.")
                        .font(Theme.caption).foregroundStyle(Theme.inkMuted)
                    HStack {
                        Link("Terms of Use", destination: URL(string: "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/")!)
                        Spacer()
                        Link("Privacy Policy", destination: URL(string: "https://example.com/privacy")!) // TODO: your privacy policy URL
                    }
                    .font(Theme.caption)
                }
                .padding(Theme.gutter)
            }
            .background(Theme.paper)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Not now") { dismiss() }
                }
            }
            .task { await model.purchases.loadProducts() }
            .onChange(of: model.isPlus) { _, isPlus in if isPlus { dismiss() } }
        }
    }

    @ViewBuilder private var products: some View {
        switch model.purchases.loadState {
        case .idle, .loading:
            ProgressView("Loading options…").frame(maxWidth: .infinity).padding()
        case .failed(let message):
            ErrorStateView(message: message) { Task { await model.purchases.loadProducts() } }
        case .loaded:
            VStack(spacing: 10) {
                ForEach(model.purchases.products, id: \.id) { product in
                    Button {
                        Task { await model.purchases.purchase(product) }
                    } label: {
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(product.displayName).font(Theme.headline)
                                Text(product.description).font(Theme.caption).foregroundStyle(Theme.inkMuted)
                            }
                            Spacer()
                            Text(priceLabel(product)).font(Theme.headline.monospacedDigit())
                        }
                        .foregroundStyle(Theme.ink)
                        .card()
                    }
                    .buttonStyle(.plain)
                    .disabled(model.purchases.isPurchasing)
                }
            }
        }
    }

    private func priceLabel(_ product: Product) -> String {
        guard let period = product.subscription?.subscriptionPeriod else { return product.displayPrice }
        switch period.unit {
        case .month: return "\(product.displayPrice)/mo"
        case .year: return "\(product.displayPrice)/yr"
        default: return product.displayPrice
        }
    }
}

private struct Benefit: View {
    let symbol: String
    let text: String
    var body: some View {
        Label { Text(text).foregroundStyle(Theme.ink) } icon: { Image(systemName: symbol).foregroundStyle(Theme.ochre) }
    }
}
