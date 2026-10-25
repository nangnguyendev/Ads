# AdKit

![Swift](https://img.shields.io/badge/Swift-5.9+-orange.svg)
![Platforms](https://img.shields.io/badge/platforms-iOS%2015+-blue.svg)
![SPM](https://img.shields.io/badge/SPM-compatible-brightgreen.svg)
![License](https://img.shields.io/badge/license-MIT-lightgrey.svg)

A Swift Package for adding ads to iOS apps. It follows US market rules by default: App Store Review Guidelines, App Tracking Transparency, COPPA, US state privacy laws, Google AdMob policies, and the Better Ads Standards. The goal is **solid revenue without spamming users, in a few lines of code**.

- **`AdKit`**: the dependency-free core.
  - A policy engine for frequency capping, grace periods and cooldowns.
  - Preloading with ad expiry and exponential-backoff retries.
  - A consent → ATT flow.
  - Impression-level revenue reporting.
  - SwiftUI helpers.
- **`AdKitAdMob`**: an adapter for Google Mobile Ads SDK 13.x and the User Messaging Platform (UMP) 3.x, including the US state regulations consent message.
- **`AdKitAdMobMediation`** (optional): AdMob bidding adapters for AppLovin, Unity Ads, Liftoff Monetize, Meta Audience Network, Mintegral, InMobi and Moloco, with the US state "Do Not Sell" choice passed to each SDK.
- **Formats**: adaptive banner, interstitial, rewarded and app open.

See [Docs/US-Ad-Compliance.md](Docs/US-Ad-Compliance.md) for each rule and how AdKit handles it.

## Installation

**Xcode:** File ▸ Add Package Dependencies… ▸ paste `https://github.com/nangnguyendev/Ads.git` ▸ Dependency Rule: *Up to Next Major Version* `1.0.0` ▸ add the `AdKit` and `AdKitAdMob` products.

**Package.swift:**

```swift
dependencies: [
    .package(url: "https://github.com/nangnguyendev/Ads.git", from: "1.0.0")
],
targets: [
    .target(name: "MyApp", dependencies: [
        .product(name: "AdKit", package: "Ads"),
        .product(name: "AdKitAdMob", package: "Ads")
    ])
]
```

## Info.plist (required)

```xml
<key>GADApplicationIdentifier</key>
<string>ca-app-pub-XXXXXXXXXXXXXXXX~YYYYYYYYYY</string>

<key>NSUserTrackingUsageDescription</key>
<string>Your data will be used to show you more relevant ads and keep this app free.</string>

<key>SKAdNetworkItems</key>
<array>
    <dict><key>SKAdNetworkIdentifier</key><string>cstr6suwn9.skadnetwork</string></dict>
    <!-- Paste the full, current list from AdMob and from every mediation network -->
</array>
```

Your app also needs its own `PrivacyInfo.xcprivacy`. The example app includes one you can start from.

## Usage

### 1. Start at launch

```swift
import SwiftUI
import AdKit
import AdKitAdMob
import IAP

enum Placements {
    static let levelComplete = AdPlacement.interstitial("level_complete", every: 2)
    static let doubleCoins = AdPlacement.rewarded("double_coins")
}

@main
struct MyApp: App {
    @StateObject private var iap = IAPManager(productIDs: ["com.myapp.removeads"])
    @StateObject private var ads = AdManager(
        configuration: AdConfiguration(
            adUnitIDs: {
                #if DEBUG
                .googleTestIDs
                #else
                AdUnitIDs(
                    banner: "ca-app-pub-xxx/111",
                    interstitial: "ca-app-pub-xxx/222",
                    rewarded: "ca-app-pub-xxx/333",
                    appOpen: "ca-app-pub-xxx/444"
                )
                #endif
            }(),
            policy: .balanced,
            audience: .general
        ),
        network: AdMobNetwork(),
        consent: UMPConsentProvider()
    )

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(ads)
                .environmentObject(iap)
                .task {
                    await iap.start()
                    ads.isAdFree = iap.isPremium
                    await ads.start()
                }
                .onChange(of: iap.isPremium) { ads.isAdFree = $0 }
        }
    }
}
```

`start()` runs these steps in order:

1. Show the UMP consent form, but only where the law requires it.
2. Show the ATT prompt.
3. Initialize the ad SDK.
4. Preload ads.

No ad request is sent until the user's choices allow it. `IAP` is [nangnguyendev/IAP](https://github.com/nangnguyendev/IAP); any source of truth for "has removed ads" works.

### 2. Banner: hides itself when there is no fill and never covers content

```swift
ContentView()
    .adBanner(ads)
```

### 3. Interstitial: call it at natural breaks

```swift
func levelDidFinish() async {
    await ads.showInterstitial(at: Placements.levelComplete)
    showResultScreen()
}
```

Call it at every natural break. AdKit decides whether an ad actually shows, based on `AdPolicy`:

- new-user grace period;
- time since the last full-screen ad;
- cooldowns;
- hourly, daily and per-session caps;
- the placement's `every:` setting.

It returns `false` when no ad is shown, so your flow is never blocked.

### 4. Rewarded: always opt-in

```swift
RewardedAdButton(manager: ads, placement: Placements.doubleCoins) { reward in
    wallet.add(Int(truncating: reward.amount as NSNumber))
} label: {
    Label("Watch an ad to double your coins", systemImage: "play.rectangle")
}
```

The button only appears when an ad is ready, so users never tap a button that does nothing.

### 5. Privacy Choices (required in US states with privacy laws)

```swift
Section("Privacy") {
    PrivacyOptionsButton(manager: ads)
}
```

### 6. Pause full-screen ads during sensitive flows

```swift
await ads.withFullScreenAdsSuppressed {
    try await iap.purchase(productID: "com.myapp.removeads")
}
```

Use it for checkout, onboarding, recording, calls and form entry.

### 7. Mediation (higher eCPM)

Add the `AdKitAdMobMediation` product and build the network with it:

```swift
import AdKitAdMobMediation

network: AdMobMediation.network(startsMuted: true)
```

Then, in AdMob:

1. Mediation ▸ create a mediation group per format and add each network as a **bidding** ad source.
2. Privacy & messaging ▸ US states ▸ add the networks to the partner list.
3. Add every network's SKAdNetwork IDs to `SKAdNetworkItems`. Each network publishes its list, for example AppLovin's at `https://skadnetwork-ids.applovin.com/v1/skadnetworkids.json`.

GDPR consent and the child-directed and under-age settings reach the adapters through UMP and the Google Mobile Ads request configuration. Google doesn't forward the US state opt-out, so `AdMobMediation` reads it from the IAB GPP string UMP stores and sets it on every SDK before ads start and after the user changes their Privacy Choices. Minors are always treated as opted out.

Use `MobileAds.shared.presentAdInspector(from:)` to check that each network loads.

### 8. Impression-level revenue

```swift
ads.revenueHandler = { revenue in
    Analytics.logEvent("ad_impression", parameters: [
        "value": NSDecimalNumber(decimal: revenue.value).doubleValue,
        "currency": revenue.currencyCode,
        "ad_format": revenue.format.rawValue,
        "ad_placement": revenue.placement,
        "ad_source": revenue.adSourceName ?? "unknown"
    ])
}
ads.eventHandler = { event in print(event) }
```

## Policy presets

| Preset | Gap between interstitials | Hour / Day / Session caps | App open ads | Best for |
|---|---|---|---|---|
| `.conservative` | 180s | 2 / 10 / 3 | off | utilities, paid apps, early launch |
| `.balanced` (default) | 90s | 4 / 20 / 6 | from 3rd session, max 4/day | most apps |
| `.revenueFocused` | 60s | 6 / 30 / 10 | from 2nd session, max 6/day | casual games with long sessions |
| `.kids` | 300s | 2 / 6 / 2 | off | kids apps (with `audience: .childDirected`) |

Every preset also applies these rules:

- No interstitials in a user's first session, or in the first 60 seconds of any session.
- Cooldowns after rewarded and app open ads.
- App open ads are skipped:
  - after quick app switches (under 30 seconds);
  - right after the user taps an ad;
  - on any launch that showed a consent or ATT prompt.

To tweak individual values:

```swift
var policy = AdPolicy.balanced
policy.interstitial.minimumInterval = 120
policy.appOpen.isEnabled = false
```

Tip: A/B test frequency with Remote Config instead of guessing. Track ARPDAU together with D1/D7 retention.

## Example app

`Examples/AdKitExample` is a small game, "Tap Quest", that uses every feature:

| Feature | File |
|---|---|
| Ad units, policy, consent | `AdsSetup.swift` |
| Startup, `isAdFree` binding, revenue tracking | `AdKitExampleApp.swift` |
| Banner anchored below the TabView | `ContentView.swift` |
| Interstitial at a natural break (every 2 levels), rewarded to double coins | `LevelView.swift` |
| Remove Ads, Privacy Choices, ad status, debug actions | `SettingsView.swift` |
| Event log showing which ads were blocked and why, plus revenue | `AdEventLog.swift` |
| `GADApplicationIdentifier`, SKAdNetwork, ATT string, privacy manifest | `Info.plist`, `AdKitExample/PrivacyInfo.xcprivacy` |

Open `Examples/AdKitExample/AdKitExample.xcodeproj` and run the `AdKitExample` scheme. The Debug build:

- uses Google's test app ID and test ad units;
- simulates a user in a regulated US state;
- relaxes the policy so ads are easy to see.

Open the **Ad Log** tab to watch the rules work, e.g. `Blocked interstitial @ level_complete: trigger 1/2`.

## Testing

```bash
swift test
```

If `swift test` can't find XCTest, your active developer directory is the Command Line Tools. Prefix the command with `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer`.

- Debug builds use `AdUnitIDs.googleTestIDs`. Never tap live ads in your own app.
- To simulate a user in a regulated US state: `UMPConsentProvider(debugGeography: .regulatedUSState, testDeviceIDs: ["<hashed id>"])`.
- Use `MobileAds.shared.presentAdInspector(from:)` to debug mediation.

## Architecture

```
AdManager (ObservableObject, @MainActor)
 ├─ ConsentProvider     → UMPConsentProvider / NoConsentProvider
 ├─ TrackingAuthorizing → AppTrackingAuthorizer (ATT)
 ├─ AdPolicyEngine      → pure, unit-tested decision logic
 ├─ AdHistoryStore      → UserDefaults / InMemory
 └─ AdNetwork           → AdMobNetwork (swap in AppLovin MAX, ironSource, …)
```

To support another ad network, implement `AdNetwork`, `FullScreenAd` and `BannerAd`.

## License

MIT. See [LICENSE](LICENSE).
