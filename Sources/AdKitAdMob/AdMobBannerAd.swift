#if canImport(GoogleMobileAds) && canImport(UIKit)
import AdKit
import GoogleMobileAds
import UIKit

@MainActor
final class AdMobBannerAd: NSObject, BannerAd {
    var revenueHandler: ((AdRevenue) -> Void)?
    var clickHandler: (() -> Void)?

    var view: UIView { bannerView }

    var rootViewController: UIViewController? {
        get { bannerView.rootViewController }
        set { bannerView.rootViewController = newValue }
    }

    private let bannerView: BannerView
    private var continuation: CheckedContinuation<CGSize, Error>?

    init(adUnitID: String) {
        bannerView = BannerView()
        super.init()
        bannerView.adUnitID = adUnitID
        bannerView.delegate = self
        bannerView.paidEventHandler = { [weak self] value in
            Task { @MainActor in
                guard let self else { return }
                self.revenueHandler?(AdRevenue(value, format: .banner, adUnitID: adUnitID, responseInfo: self.bannerView.responseInfo))
            }
        }
    }

    func load(width: CGFloat) async throws -> CGSize {
        continuation?.resume(throwing: CancellationError())
        let size = largeAnchoredAdaptiveBanner(width: width)
        bannerView.adSize = size
        return try await withCheckedThrowingContinuation { continuation in
            self.continuation = continuation
            bannerView.load(Request())
        }
    }
}

extension AdMobBannerAd: BannerViewDelegate {
    func bannerViewDidReceiveAd(_ bannerView: BannerView) {
        continuation?.resume(returning: bannerView.adSize.size)
        continuation = nil
    }

    func bannerView(_ bannerView: BannerView, didFailToReceiveAdWithError error: Error) {
        continuation?.resume(throwing: error)
        continuation = nil
    }

    func bannerViewDidRecordClick(_ bannerView: BannerView) {
        clickHandler?()
    }
}
#endif
