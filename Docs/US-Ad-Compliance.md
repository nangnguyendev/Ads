# In-app advertising rules for the US market

Current as of October 2026. This is not legal advice. Check the official sources before every major release.

Legend: ✅ handled by AdKit · 🔧 you need to configure or do something.

## 1. Apple App Store Review Guidelines

| Guideline | Requirement | AdKit |
|---|---|---|
| 2.5.18 | Ads only in the main app binary: not in extensions, widgets, notifications, keyboards or watchOS apps. Ads must match the app's age rating. Interstitials must be closable or skippable. Ads must not trick users into tapping. | ✅ Only usable in the main app. `maxContentRating` defaults to PG. 🔧 Set `maxContentRating` to match your age rating. |
| 2.5.18 | Users must be able to see the information used to target them. | ✅ AdChoices and "Why this ad" are rendered by the SDK. |
| 3.2.2 | No artificially inflating impressions or clicks, and no rewarding clicks. | ✅ Rewarded ads only grant rewards on completion (`userDidEarnReward`), never on clicks. |
| 3.1.1 | Unlocking digital features or content for money requires IAP. Rewarding users for watching ads (coins, lives…) is allowed. | 🔧 Don't make rewarded ads the only way to get something that should be sold through IAP. |
| 1.3 (Kids Category) | No behavioral advertising. Contextual ads must come from an Apple-approved network, be human-reviewed, and sit behind a parental gate. No ATT and no IDFA. | ✅ `audience: .childDirected` skips ATT and applies child treatment in AdMob and UMP. 🔧 Use `policy: .kids`, and think hard before putting ads in the Kids Category. |
| 5.1.1 / 5.1.2 | A privacy policy and complete App Privacy details (nutrition label) are required. Apps must not require tracking consent to function. | ✅ The app keeps working when ATT is denied. 🔧 Declare in the nutrition label: Identifiers (Device ID), Usage Data, Diagnostics, Coarse Location. Mark them "Used for tracking" if IDFA is used. |
| Age ratings (2025+) | New ratings: 4+, 9+, 13+, 16+, 18+. Advertising is one of the questions in the age-rating questionnaire. | 🔧 Answer "Advertising" accurately in App Store Connect. |

## 2. App Tracking Transparency (ATT) & SKAdNetwork

- **Authorization:** you must have ATT authorization before accessing the IDFA or tracking across apps. ✅ `AppTrackingAuthorizer`.
- **Active state:** the prompt only appears while the app is active. Otherwise iOS silently returns `notDetermined`. ✅ AdKit waits for `didBecomeActive` before asking.
- **Pre-prompt screens:** an explainer screen before ATT is allowed. It must not imitate the system alert, must not reward tapping Allow, and must not block features when the user declines. 🔧 Applies if you add your own explainer.
- **Order:** Google recommends UMP consent first, then ATT. ✅
- **Usage string:** `NSUserTrackingUsageDescription` is required. ✅ Debug builds assert when it is missing.
- **SKAdNetwork:** `SKAdNetworkItems` must include Google's list and every mediation network's list. Missing IDs lose revenue from users who declined ATT. 🔧
- **Privacy manifests:** GoogleMobileAds and UMP ship their own `PrivacyInfo.xcprivacy`. 🔧 Your app still needs its own, declaring required-reason APIs such as `UserDefaults` (e.g. `CA92.1`).

## 3. COPPA (FTC): apps directed to children under 13

- **Timeline:** the amended COPPA Rule took effect on June 23, 2025. The **compliance deadline was April 22, 2026**, and the FTC is now enforcing it.
- **What changed:** you need **separate verifiable parental consent** before disclosing children's data to third parties, including for targeted advertising. You also need a written data-retention policy and a security program.
- **Penalties:** civil penalties exceed $50,000 per violation.
- **Kids apps:** use `audience: .childDirected` ✅. This applies AdMob `ageRestrictedTreatment = .child`, G-rated content, no IDFA and no ATT.
- **Mixed-audience apps:** use a neutral age gate, and create the `AdManager` with `.childDirected` for users under 13. 🔧
- **AdMob setting:** 🔧 enable "Tag for child-directed treatment" at the app level in AdMob if your app targets children.

## 4. US state privacy laws (CCPA/CPRA and ~20 other states)

- **Opt-out:** personalized ads count as a "sale/share" of personal data, so users must be able to **opt out** ("Do Not Sell or Share My Personal Information").
- **Minors:** data from users under 16 requires opt-in in California. Some states, such as Maryland (MODPA), ban selling data of users under 18.
- **GPC:** the Global Privacy Control signal must be honored where required.
- **What AdKit does:**
  - ✅ `UMPConsentProvider` shows Google's "US states regulations" message and produces an IAB GPP string for ad partners.
  - ✅ `PrivacyOptionsButton` only appears when the law requires it. 🔧 Put it in your Settings screen.
- **AdMob setup:** 🔧 In AdMob ▸ Privacy & messaging ▸ US states:
  - create and publish the message;
  - enable Restricted Data Processing (RDP) for users who opt out;
  - add your mediation networks to the partner list.

## 5. App store age-verification laws (2026)

- **Texas SB 2420 (App Store Accountability Act)** has had a changing status:
  - Dec 23, 2025: a district court blocked it.
  - June 2026: the Fifth Circuit stayed that injunction, so the law can take effect while the appeal is pending.
  - Litigation is ongoing and may reach the Supreme Court, so the status can change again.
- **Other states:** Utah and Louisiana have similar laws.
- **Apple's tooling:** Apple provides the **Declared Age Range API** for apps to receive an age signal.
- 🔧 Recommendation: get the user's age range from Declared Age Range, then:
  - under 13 → `AdAudience.childDirected`;
  - 13–17 → `AdAudience(isUnderAgeOfConsent: true, maxContentRating: .teen)`. AdKit maps this to `ageRestrictedTreatment = .teen`.

## 6. Google AdMob policies

| Policy | AdKit |
|---|---|
| No interstitials on app launch, on exit, or interrupting the user mid-task. Only show them at natural breaks. | ✅ `sessionStartDelay`, `minimumInterval`, and an API designed to be called at natural breaks. |
| No repeated interstitials, or one after every action. | ✅ `every:`, plus hourly, daily and per-session caps. |
| No stacked full-screen ads. | ✅ `isPresentingFullScreenAd` and cross-format cooldowns. |
| Banners must not overlap content or controls, or sit close enough to cause accidental clicks. | ✅ `.adBanner()` uses `safeAreaInset`, so content is pushed up instead of covered. |
| No ads on empty screens or loading screens. | ✅ The banner collapses to zero height when there is no fill. |
| App open ads: only on launch or return to the app. Cold starts need a loading screen. Ads expire after 4 hours. | ✅ Cold start waits at most 3 seconds. The cache expires after 4 hours. |
| Show interstitial and rewarded ads within 1 hour of loading. | ✅ Expired after 1 hour and reloaded. |
| Rewarded ads must be opt-in and clearly state the reward. | ✅ `RewardedAdButton` only appears when an ad is ready. 🔧 State the reward in the button label. |
| No hammering ad requests after failures. | ✅ Exponential backoff: 2s, 4s, … up to 64s. |
| Never click your own ads or ask users to click ads. | 🔧 |
| Native ads need an "Ad"/"Sponsored" label and AdChoices. | ⏳ AdKit doesn't support native ads yet. If you build your own, follow this rule. |

## 7. Better Ads Standards (Coalition for Better Ads), mobile

These are the ad experiences users dislike most:

| Experience | AdKit |
|---|---|
| Full-screen pop-ups on entry | ✅ No interstitials at the start of a session |
| Ad density over 30% of the screen | ✅ The adaptive banner is capped at 20% of screen height |
| Flashing ads, auto-playing video with sound | 🔧 You can use `AdMobNetwork(startsMuted: true)`. Trade-off: fewer video ads, so eCPM may drop |
| Prestitials and postitials with a countdown | ✅ App open ads are frequency-capped, never in the first session, never on exit |
| Large sticky ads | ✅ |

## 8. FTC: ads must be identifiable

- Under FTC Act Section 5 (deceptive practices), ads must be clearly distinguishable from app content. No fake close buttons, and nothing that makes users believe an ad is part of the app.
- No dark patterns to push users into consenting to tracking or buying ad removal.

## 9. Maximizing revenue without annoying users

1. **Mediation and bidding**: enable AdMob bidding with AppLovin, Meta Audience Network, Unity, Liftoff, Mintegral, InMobi and others. This usually lifts US eCPM significantly.
2. **Rewarded ads are the best format** for both revenue and UX: high eCPM, and the user chooses to watch. Design your in-app economy with room for rewards.
3. **Sell a Remove Ads IAP** (`ads.isAdFree = iap.isPremium`). Users who hate ads pay instead of uninstalling. Rewarded ads stay available to premium users by default.
4. **Track impression-level revenue** through `revenueHandler` and send it to Firebase, AppsFlyer or Adjust to compute LTV and ROAS for user acquisition.
5. **A/B test frequency** with Remote Config. Watch ARPDAU together with D1/D7 retention and session length, not just eCPM.
6. **ATT opt-in rates** in the US are typically 25–40%. An honest explainer screen before the prompt usually raises them.
7. **Complete SKAdNetwork IDs**, so you don't lose revenue from users who decline ATT.
8. Add **eCPM floors** or multiple ad unit tiers only once you have enough data. Otherwise fill rate drops.

## Pre-submission checklist

- [ ] `GADApplicationIdentifier`, `NSUserTrackingUsageDescription` and `SKAdNetworkItems` are in Info.plist
- [ ] The app has its own `PrivacyInfo.xcprivacy`
- [ ] App Privacy (nutrition label) covers all data the ad SDKs collect
- [ ] The privacy policy covers advertising, partners and how to opt out
- [ ] The "US states" message is published in AdMob Privacy & messaging
- [ ] A "Privacy Choices" button is in Settings
- [ ] The age rating and `maxContentRating` match
- [ ] Release builds use live ad units; debug builds use test IDs or test devices
- [ ] `app-ads.txt` is hosted on the developer domain listed in the App Store
- [ ] Remove Ads works and turns off both app open and interstitial ads

## Sources

- Apple App Store Review Guidelines: https://developer.apple.com/app-store/review/guidelines/
- Apple User Privacy & Data Use: https://developer.apple.com/app-store/user-privacy-and-data-use/
- FTC COPPA Rule (Federal Register, Apr 22, 2025): https://www.federalregister.gov/documents/2025/04/22/2025-05904/childrens-online-privacy-protection-rule
- Texas SB 2420 litigation: https://ccianet.org/litigation/ccia-v-paxton/ and https://www.pearlcohen.com/fifth-circuit-stays-injunctions-against-texas-app-store-accountability-act/
- AdMob program policies: https://support.google.com/admob/answer/6128543
- AdMob disallowed interstitial implementations: https://support.google.com/admob/answer/6201362
- Google Mobile Ads iOS release notes: https://developers.google.com/admob/ios/rel-notes
- Better Ads Standards: https://www.betterads.org/standards/
