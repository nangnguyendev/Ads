#if canImport(GoogleMobileAds) && canImport(UIKit)
import AdKit
import AdKitAdMob
import AppLovinSDK
import AppTrackingTransparency
import FBAudienceNetwork
import Foundation
import MolocoSDK
import MTGSDK
import UnityAds
import VungleAdsSDK

/// AdMob bidding with AppLovin, Unity Ads, Liftoff Monetize, Meta Audience Network, Mintegral,
/// InMobi and Moloco. Linking this module adds their adapters; turn each network on in
/// AdMob ▸ Mediation and add every network's SKAdNetwork IDs to Info.plist.
///
/// GDPR consent and child-directed settings reach the adapters through UMP and the Google Mobile
/// Ads request configuration. The US state "Do Not Sell" choice does not, so `applyPrivacy` sets it
/// on each SDK before ads start and whenever the user changes it.
public enum AdMobMediation {
    @MainActor
    public static func network(startsMuted: Bool = false, defaults: UserDefaults = .standard) -> AdMobNetwork {
        AdMobNetwork(startsMuted: startsMuted) { audience in
            applyPrivacy(audience: audience, defaults: defaults)
        }
    }

    @MainActor
    public static func applyPrivacy(audience: AdAudience, defaults: UserDefaults = .standard) {
        // Minors are never opted in to sale, and AppLovin turns itself off for them.
        let doNotSell = !audience.allowsTracking || (USPrivacy.current(defaults: defaults)?.doNotSell ?? false)

        ALPrivacySettings.setDoNotSell(doNotSell)

        let unity = UADSMetaData()
        unity.set("privacy.consent", value: !doNotSell)
        unity.commit()

        VunglePrivacySettings.setCCPAStatus(!doNotSell)

        if doNotSell {
            FBAdSettings.setDataProcessingOptions(["LDU"], country: 1, state: 1000)
        } else {
            FBAdSettings.setDataProcessingOptions([])
        }
        FBAdSettings.setAdvertiserTrackingEnabled(audience.allowsTracking && ATTrackingManager.trackingAuthorizationStatus == .authorized)

        MTGSDK.sharedInstance().doNotTrackStatus = doNotSell

        MolocoPrivacySettings.isDoNotSell = doNotSell

        // InMobi reads the IAB CCPA string. Only write it when this module decided the value.
        if defaults.string(forKey: "IABUSPrivacy_String") == nil || defaults.bool(forKey: writtenUSPrivacyKey) {
            defaults.set(USPrivacy(doNotSell: doNotSell).usPrivacyString, forKey: "IABUSPrivacy_String")
            defaults.set(true, forKey: writtenUSPrivacyKey)
        }
    }

    private static let writtenUSPrivacyKey = "AdKitWroteIABUSPrivacy"
}
#endif
