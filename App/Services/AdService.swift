import Foundation
import WorldTrailsCore

/// Seam for the ad network SDK. The shipping implementation will wrap Google Mobile Ads
/// (or AppLovin MAX) behind this protocol; until credentials exist the game runs on
/// `SimulatedAdService`, which never shows a real ad.
///
/// Integration requirements (see README → "Advertising"):
/// - Ad unit IDs from the network, read from a non-committed xcconfig, never hardcoded.
/// - Google UMP consent form (GDPR/US state privacy) before any ad request.
/// - App Tracking Transparency prompt only if personalized ads are enabled; default is non-personalized.
/// - SKAdNetwork IDs in Info.plist, and the network's privacy manifest.
@MainActor
protocol AdService: AnyObject {
    var isRewardedReady: Bool { get }
    /// Returns true if the user watched to completion and should be rewarded.
    func showRewarded(placement: String) async -> Bool
    func showInterstitial(placement: String) async
    func preload()
}

@MainActor
final class SimulatedAdService: AdService {
    var isRewardedReady: Bool { true }
    func preload() {}
    func showRewarded(placement: String) async -> Bool {
        try? await Task.sleep(for: .milliseconds(600)) // stand-in for a real ad
        return true
    }
    func showInterstitial(placement: String) async {}
}
