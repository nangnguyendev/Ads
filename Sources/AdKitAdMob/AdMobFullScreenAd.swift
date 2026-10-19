#if canImport(GoogleMobileAds) && canImport(UIKit)
import AdKit
import GoogleMobileAds
import UIKit

@MainActor
final class AdMobFullScreenAd: NSObject, FullScreenAd {
    private enum Kind {
        case interstitial(InterstitialAd)
        case rewarded(RewardedAd)
        case appOpen(AppOpenAd)
    }

    let format: AdKit.AdFormat
    let adUnitID: String
    var revenueHandler: ((AdRevenue) -> Void)?
    var clickHandler: (() -> Void)?

    private let kind: Kind
    private var continuation: CheckedContinuation<AdPresentationResult, Never>?
    private var didRecordImpression = false
    private var earnedReward: AdKit.AdReward?

    init(interstitial: InterstitialAd) {
        kind = .interstitial(interstitial)
        format = .interstitial
        adUnitID = interstitial.adUnitID
        super.init()
        interstitial.fullScreenContentDelegate = self
        interstitial.paidEventHandler = { [weak self] value in
            Task { @MainActor in self?.reportRevenue(value, responseInfo: interstitial.responseInfo) }
        }
    }

    init(rewarded: RewardedAd) {
        kind = .rewarded(rewarded)
        format = .rewarded
        adUnitID = rewarded.adUnitID
        super.init()
        rewarded.fullScreenContentDelegate = self
        rewarded.paidEventHandler = { [weak self] value in
            Task { @MainActor in self?.reportRevenue(value, responseInfo: rewarded.responseInfo) }
        }
    }

    init(appOpen: AppOpenAd) {
        kind = .appOpen(appOpen)
        format = .appOpen
        adUnitID = appOpen.adUnitID
        super.init()
        appOpen.fullScreenContentDelegate = self
        appOpen.paidEventHandler = { [weak self] value in
            Task { @MainActor in self?.reportRevenue(value, responseInfo: appOpen.responseInfo) }
        }
    }

    func present(from controller: UIViewController) async -> AdPresentationResult {
        await withCheckedContinuation { continuation in
            self.continuation = continuation
            switch kind {
            case .interstitial(let ad):
                guard (try? ad.canPresent(from: controller)) != nil else { return finish(error: AdMobAdapterError.cannotPresent) }
                ad.present(from: controller)
            case .appOpen(let ad):
                guard (try? ad.canPresent(from: controller)) != nil else { return finish(error: AdMobAdapterError.cannotPresent) }
                ad.present(from: controller)
            case .rewarded(let ad):
                guard (try? ad.canPresent(from: controller)) != nil else { return finish(error: AdMobAdapterError.cannotPresent) }
                ad.present(from: controller) { [weak self, weak ad] in
                    guard let reward = ad?.adReward else { return }
                    self?.earnedReward = AdKit.AdReward(type: reward.type, amount: reward.amount.decimalValue)
                }
            }
        }
    }

    private func reportRevenue(_ value: AdValue, responseInfo: ResponseInfo) {
        revenueHandler?(AdRevenue(value, format: format, adUnitID: adUnitID, responseInfo: responseInfo))
    }

    private func finish(error: Error? = nil) {
        let result = AdPresentationResult(didShow: didRecordImpression || error == nil, reward: earnedReward, error: error)
        continuation?.resume(returning: result)
        continuation = nil
    }
}

extension AdMobFullScreenAd: FullScreenContentDelegate {
    func adDidRecordImpression(_ ad: FullScreenPresentingAd) {
        didRecordImpression = true
    }

    func adDidRecordClick(_ ad: FullScreenPresentingAd) {
        clickHandler?()
    }

    func ad(_ ad: FullScreenPresentingAd, didFailToPresentFullScreenContentWithError error: Error) {
        finish(error: error)
    }

    func adDidDismissFullScreenContent(_ ad: FullScreenPresentingAd) {
        finish()
    }
}
#endif
