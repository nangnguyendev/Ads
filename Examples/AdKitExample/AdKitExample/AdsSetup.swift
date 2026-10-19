import AdKit
import AdKitAdMob

enum Placements {
    static let levelComplete = AdPlacement.interstitial("level_complete", every: 2)
    static let doubleCoins = AdPlacement.rewarded("double_coins")
    static let freeHint = AdPlacement.rewarded("free_hint")
}

enum AdsSetup {
    static let adUnitIDs: AdUnitIDs = {
        #if DEBUG
        return .googleTestIDs
        #else
        return AdUnitIDs(
            banner: "ca-app-pub-XXXXXXXXXXXXXXXX/1111111111",
            interstitial: "ca-app-pub-XXXXXXXXXXXXXXXX/2222222222",
            rewarded: "ca-app-pub-XXXXXXXXXXXXXXXX/3333333333",
            appOpen: "ca-app-pub-XXXXXXXXXXXXXXXX/4444444444"
        )
        #endif
    }()

    static let policy: AdPolicy = {
        #if DEBUG
        var policy = AdPolicy.balanced
        policy.interstitial.newUserGraceSessions = 0
        policy.interstitial.sessionStartDelay = 10
        policy.interstitial.minimumInterval = 30
        policy.appOpen.minimumSessions = 1
        policy.appOpen.minimumInterval = 60
        return policy
        #else
        return .balanced
        #endif
    }()

    @MainActor
    static func makeManager() -> AdManager {
        #if DEBUG
        let consent = UMPConsentProvider(debugGeography: .regulatedUSState)
        #else
        let consent = UMPConsentProvider()
        #endif
        return AdManager(
            configuration: AdConfiguration(
                adUnitIDs: adUnitIDs,
                policy: policy,
                audience: .general,
                isLoggingEnabled: true
            ),
            network: AdMobNetwork(),
            consent: consent
        )
    }
}
