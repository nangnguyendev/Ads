# Changelog

## [1.2.0] - 2026-10-25

### Added
- Native ads: `AdFormat.native`, `AdUnitIDs.native` (Google's test ID included), `AdManager.makeNativeAd(placement:style:)`, `shouldShowNativeAds` and the SwiftUI `NativeAdCardView`. `AdKitAdMob` lays the ad out as a card: icon, headline, an "Ad" badge, advertiser, body, optional media and a call-to-action, with AdChoices added by the SDK. `NativeAdStyle` sets its colors and corner radius.
- `AdNetwork.makeNativeAd(adUnitID:style:)`, with a default that returns `nil`.

### Fixed
- A cold-start app open ad could appear over a sensitive flow, such as a ringing alarm, if the flow began while the ad was still loading. Full-screen ads now re-check suppression right before they present.

### Note
- `AdFormat` has a new case. Code that switches over `AdFormat` exhaustively needs a `.native` branch. AnalyticsKit needs 1.1.0 or later.

## [1.1.0] - 2026-10-25

### Added
- `AdKitAdMobMediation`: AdMob bidding adapters for AppLovin, Unity Ads, Liftoff Monetize, Meta Audience Network, Mintegral, InMobi and Moloco. `AdMobMediation.network()` passes the US state "Do Not Sell" choice to each SDK before ads start and after the user changes their Privacy Choices.
- `USPrivacy`: reads the US state opt-out from the IAB GPP US National section (or `IABUSPrivacy_String`).
- `AdMobNetwork.applyPrivacy` hook and `AdNetwork.privacyChoicesDidChange()` (with a default no-op implementation).

## [1.0.0] - 2026-10-19

### Added
- `AdManager`: consent → ATT → SDK start flow, preloading with expiry (1h, app open 4h), exponential-backoff retries, ad-free mode, full-screen ad suppression, impression-level revenue and event reporting.
- `AdPolicyEngine` with presets `.conservative`, `.balanced`, `.revenueFocused`, `.kids`: new-user grace, session start delay, minimum interval, cooldowns, hourly/daily/session caps, per-placement trigger intervals, app open rules.
- `AdAudience` for COPPA / age-restricted treatment and max ad content rating.
- `AppTrackingAuthorizer` that waits for the app to be active before showing the ATT prompt.
- SwiftUI: `BannerAdView`, `.adBanner()`, `RewardedAdButton`, `PrivacyOptionsButton`.
- `AdKitAdMob`: `AdMobNetwork` (Google Mobile Ads SDK 13.x) and `UMPConsentProvider` (UMP 3.x, US state regulations).
- US ad compliance guide in `Docs/US-Ad-Compliance.md`.
- Example app `Examples/AdKitExample`.
