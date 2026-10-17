import SwiftUI
import WorldTrailsCore

// MARK: - Buttons

struct PrimaryButtonStyle: ButtonStyle {
    var tint: Color = Theme.terracotta
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(Theme.headline)
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity, minHeight: 52)
            .background(tint.opacity(isEnabled ? 1 : 0.4), in: RoundedRectangle(cornerRadius: Theme.smallRadius, style: .continuous))
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(.snappy(duration: 0.15), value: configuration.isPressed)
    }
}

struct SecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(Theme.headline)
            .foregroundStyle(Theme.ink)
            .frame(maxWidth: .infinity, minHeight: 48)
            .background(Theme.card, in: RoundedRectangle(cornerRadius: Theme.smallRadius, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: Theme.smallRadius, style: .continuous).strokeBorder(Theme.rule))
            .opacity(configuration.isPressed ? 0.7 : 1)
    }
}

// MARK: - Surfaces

struct CardModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Theme.card, in: RoundedRectangle(cornerRadius: Theme.radius, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: Theme.radius, style: .continuous).strokeBorder(Theme.rule.opacity(0.7)))
    }
}

extension View {
    func card() -> some View { modifier(CardModifier()) }
}

/// Small uppercase label used like a magazine section marker.
struct Overline: View {
    let text: String
    var color: Color = Theme.inkMuted
    var body: some View {
        Text(text.uppercased())
            .font(Theme.overline)
            .tracking(1.5)
            .foregroundStyle(color)
    }
}

// MARK: - Passport stamp

/// A circular rubber-stamp style badge. Tier color + ring count communicate quality.
struct StampView: View {
    let title: String
    let subtitle: String
    let tier: StampTier?
    var size: CGFloat = 96

    var body: some View {
        let color = tier.map(Theme.tierColor) ?? Theme.rule
        ZStack {
            Circle().strokeBorder(color, style: StrokeStyle(lineWidth: 3, dash: tier == nil ? [4, 4] : []))
            Circle().strokeBorder(color.opacity(0.6), lineWidth: 1).padding(6)
            if tier == .gold {
                Circle().strokeBorder(color.opacity(0.4), lineWidth: 1).padding(11)
            }
            VStack(spacing: 2) {
                if tier == nil {
                    Image(systemName: "questionmark").font(.system(size: size * 0.25, weight: .semibold))
                } else {
                    Text(title.uppercased())
                        .font(.system(size: size * 0.12, weight: .heavy, design: .serif))
                        .multilineTextAlignment(.center)
                        .lineLimit(2)
                        .minimumScaleFactor(0.6)
                    Text(subtitle.uppercased())
                        .font(.system(size: size * 0.08, weight: .semibold, design: .monospaced))
                }
            }
            .foregroundStyle(color)
            .padding(size * 0.16)
        }
        .frame(width: size, height: size)
        .rotationEffect(.degrees(tier == nil ? 0 : -8))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(tier.map { "\(title), \($0.displayName) stamp" } ?? "Undiscovered stamp")
    }
}

// MARK: - Progress

struct RankProgressView: View {
    let progress: PlayerProgress

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Label(progress.rank.title, systemImage: progress.rank.symbol)
                    .font(Theme.headline)
                    .foregroundStyle(Theme.ink)
                Spacer()
                Text("\(progress.xp) XP")
                    .font(Theme.caption.monospacedDigit())
                    .foregroundStyle(Theme.ochre)
            }
            ProgressView(value: progress.rankProgress)
                .tint(Theme.ochre)
            if let next = progress.rank.next {
                Text("\(next.xpRequired - progress.xp) XP to \(next.title)")
                    .font(Theme.caption)
                    .foregroundStyle(Theme.inkMuted)
            }
        }
        .accessibilityElement(children: .combine)
    }
}

/// Arrow that points toward the answer after a wrong guess.
struct CompassArrow: View {
    let direction: CompassDirection
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var settled = false

    var body: some View {
        Image(systemName: "location.north.fill")
            .rotationEffect(.degrees(settled || reduceMotion ? direction.degrees : direction.degrees - 60))
            .animation(reduceMotion ? nil : .spring(response: 0.5, dampingFraction: 0.55), value: settled)
            .onAppear { settled = true }
            .accessibilityLabel("Head \(direction.spokenName)")
    }
}

extension CompassDirection {
    var spokenName: String {
        switch self {
        case .n: return "north"
        case .ne: return "northeast"
        case .e: return "east"
        case .se: return "southeast"
        case .s: return "south"
        case .sw: return "southwest"
        case .w: return "west"
        case .nw: return "northwest"
        }
    }
}

// MARK: - States

struct EmptyStateView: View {
    let symbol: String
    let title: String
    let message: String
    var body: some View {
        VStack(spacing: 10) {
            Image(systemName: symbol).font(.largeTitle).foregroundStyle(Theme.inkMuted)
            Text(title).font(Theme.title).foregroundStyle(Theme.ink)
            Text(message).font(Theme.body).foregroundStyle(Theme.inkMuted).multilineTextAlignment(.center)
        }
        .padding(32)
        .frame(maxWidth: .infinity)
    }
}

struct ErrorStateView: View {
    let message: String
    var retry: (() -> Void)?
    var body: some View {
        VStack(spacing: 16) {
            EmptyStateView(symbol: "exclamationmark.triangle", title: "Something went off-trail", message: message)
            if let retry {
                Button("Try again", action: retry).buttonStyle(PrimaryButtonStyle()).padding(.horizontal, 40)
            }
        }
    }
}

// MARK: - Haptics

enum Haptics {
    static var enabled: Bool { UserDefaults.standard.object(forKey: "haptics") as? Bool ?? true }
    static func success() { guard enabled else { return }; UINotificationFeedbackGenerator().notificationOccurred(.success) }
    static func warning() { guard enabled else { return }; UINotificationFeedbackGenerator().notificationOccurred(.warning) }
    static func tap() { guard enabled else { return }; UIImpactFeedbackGenerator(style: .light).impactOccurred() }
}
