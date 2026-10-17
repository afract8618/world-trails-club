# World Trails Club — iOS

Milestone 1: playable core (Mystery Destination), progression, passport, map, Daily Expedition, monetization seams, analytics schema. See `DESIGN.md` for the full design.

> **Build status:** this code was written without access to a Mac, so it has **not yet been compiled or run**. The content JSON was generated and validated by `Tools/build_content.py`. Expect to fix a handful of compiler errors on the first Xcode build — report them back and the next milestone starts there.

## Requirements
- macOS with **Xcode 15.4+** (iOS 17 SDK) — Xcode 16 recommended
- [XcodeGen](https://github.com/yonaskolb/XcodeGen): `brew install xcodegen`

## Build & run
```bash
cd WorldTrailsClub
xcodegen generate            # creates WorldTrailsClub.xcodeproj from project.yml
open WorldTrailsClub.xcodeproj
```
Select an iPhone simulator → Run (⌘R).

Core logic tests (no simulator needed):
```bash
cd Packages/WorldTrailsCore && swift test
```
UI tests: in Xcode, ⌘U on the `WorldTrailsClub` scheme. The `-uitest` launch argument gives each test a fresh save.

Regenerate content after editing destinations:
```bash
python3 Tools/build_content.py   # fails loudly on answer leaks, duplicates, bad countries
```

## What needs your setup

| Item | Where | Notes |
|---|---|---|
| Bundle ID & Team | `project.yml` (`bundleIdPrefix`, `PRODUCT_BUNDLE_IDENTIFIER`, `DEVELOPMENT_TEAM`) | Required for device builds |
| App icon | `App/Assets.xcassets/AppIcon.appiconset` | 1024×1024 PNG |
| **Purchases** | App Store Connect: subscription group "Club Plus" with `club.plus.monthly`, `club.plus.annual`; non-consumable `club.plus.lifetime` | For simulator testing: Xcode → File → New → StoreKit Configuration File (sync with App Store Connect or add the 3 IDs manually), then Edit Scheme → Run → Options → StoreKit Configuration |
| Privacy policy URL | `PlusView.swift` (`TODO`) | Required by App Review for subscriptions |
| **Advertising** | Implement `AdService` with Google Mobile Ads or AppLovin MAX | Needs: ad unit IDs in a git-ignored `.xcconfig`, `GADApplicationIdentifier` + `SKAdNetworkItems` in Info.plist, Google UMP consent before first request, ATT prompt only if serving personalized ads. Currently `SimulatedAdService` (never shows ads) |
| **Analytics vendor** | Add a sink conforming to `AnalyticsSink` | Currently logs to Console (`LogAnalyticsSink`). Event schema is vendor-neutral |
| **Remote config** | Add `RemoteConfigURL` to Info.plist pointing at a JSON with any `MonetizationConfig` keys | Unknown keys are ignored; missing keys keep defaults |
| Game Center | Not yet integrated | Next milestone (Daily leaderboard) |

No API secrets are in the repo.

## TestFlight checklist
- [ ] First build compiles with zero warnings in Core; app runs on iPhone SE (3rd gen) and Pro Max sizes
- [ ] First-session UI test passes; manual: first stamp in < 30 s with a new tester
- [ ] Light/dark mode on every screen; Dynamic Type at XXL; VoiceOver can complete a full round; Reduce Motion disables stamp/clue animations
- [ ] Kill app mid-round, relaunch → progress intact; airplane mode → whole game playable
- [ ] Daily Expedition identical on two devices on the same day; streak behaves across midnight and DST
- [ ] Sandbox purchase, cancel, restore, refund → Plus state correct; Ask to Buy pending handled
- [ ] Analytics events visible for the full first-session funnel
- [ ] Testers briefed on what to report: confusing clues, wrong facts, "too hard/easy" places

## App Store launch checklist
- [ ] App Privacy "nutrition label" matches actual SDKs (analytics + ads); privacy manifest (`PrivacyInfo.xcprivacy`) for app and every SDK
- [ ] Age rating questionnaire; ads content filters set to the rating
- [ ] Subscription metadata: display names, descriptions, review screenshot of paywall; Terms (EULA) + privacy links on paywall and in description
- [ ] Restore Purchases visible; paywall closable; no misleading pricing
- [ ] Screenshots (6.9" and 6.5"), app preview video of a round, subtitle + keywords
- [ ] All destination facts double-checked; art assets licensed with records kept
- [ ] Phased release on; remote config kill-switch for interstitials tested
