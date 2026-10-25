#if canImport(GoogleMobileAds) && canImport(UIKit)
import AdKit
import GoogleMobileAds
import UIKit

@MainActor
public final class AdMobNetwork: AdNetwork {
    public let name = "AdMob"
    public var startsMuted: Bool
    /// Runs before the SDK starts and again after the user changes their privacy choices, to pass
    /// privacy signals to mediated networks that Google doesn't forward. See `AdKitAdMobMediation`.
    public var applyPrivacy: (@MainActor (AdAudience) -> Void)?

    private var audience = AdAudience.general

    public init(startsMuted: Bool = false, applyPrivacy: (@MainActor (AdAudience) -> Void)? = nil) {
        self.startsMuted = startsMuted
        self.applyPrivacy = applyPrivacy
    }

    public func privacyChoicesDidChange() {
        applyPrivacy?(audience)
    }

    public func start(audience: AdAudience, testDeviceIDs: [String]) async {
        self.audience = audience
        applyPrivacy?(audience)
        let requestConfiguration = MobileAds.shared.requestConfiguration
        requestConfiguration.testDeviceIdentifiers = testDeviceIDs
        requestConfiguration.maxAdContentRating = Self.rating(audience.maxContentRating)
        if audience.isChildDirected {
            requestConfiguration.ageRestrictedTreatment = .child
        } else if audience.isUnderAgeOfConsent {
            requestConfiguration.ageRestrictedTreatment = .teen
        } else {
            requestConfiguration.ageRestrictedTreatment = .unspecified
        }
        MobileAds.shared.isApplicationMuted = startsMuted
        _ = await MobileAds.shared.start()
    }

    public func loadFullScreenAd(_ format: AdKit.AdFormat, adUnitID: String) async throws -> FullScreenAd {
        switch format {
        case .interstitial:
            let ad = try await InterstitialAd.load(with: adUnitID, request: Request())
            return AdMobFullScreenAd(interstitial: ad)
        case .rewarded:
            let ad = try await RewardedAd.load(with: adUnitID, request: Request())
            return AdMobFullScreenAd(rewarded: ad)
        case .appOpen:
            let ad = try await AppOpenAd.load(with: adUnitID, request: Request())
            return AdMobFullScreenAd(appOpen: ad)
        case .banner, .native:
            throw AdMobAdapterError.unsupportedFormat(format)
        }
    }

    public func makeBannerAd(adUnitID: String) -> BannerAd {
        AdMobBannerAd(adUnitID: adUnitID)
    }

    public func makeNativeAd(adUnitID: String, style: NativeAdStyle) -> NativeCardAd? {
        AdMobNativeAd(adUnitID: adUnitID, style: style)
    }

    private static func rating(_ rating: AdContentRating) -> GADMaxAdContentRating {
        switch rating {
        case .general: return .general
        case .parentalGuidance: return .parentalGuidance
        case .teen: return .teen
        case .matureAudience: return .matureAudience
        }
    }
}

public enum AdMobAdapterError: LocalizedError {
    case unsupportedFormat(AdKit.AdFormat)
    case cannotPresent

    public var errorDescription: String? {
        switch self {
        case .unsupportedFormat(let format): return "AdMob adapter does not load \(format.rawValue) as a full-screen ad"
        case .cannotPresent: return "The ad cannot be presented from this view controller"
        }
    }
}

extension AdRevenue {
    init(_ value: AdValue, format: AdKit.AdFormat, adUnitID: String, responseInfo: ResponseInfo?) {
        self.init(
            value: value.value.decimalValue,
            currencyCode: value.currencyCode,
            precision: Self.precision(value.precision),
            format: format,
            placement: "",
            adUnitID: adUnitID,
            adSourceName: responseInfo?.loadedAdNetworkResponseInfo?.adSourceName
        )
    }

    private static func precision(_ precision: AdValuePrecision) -> Precision {
        switch precision {
        case .estimated: return .estimated
        case .publisherProvided: return .publisherProvided
        case .precise: return .precise
        default: return .unknown
        }
    }
}
#endif
