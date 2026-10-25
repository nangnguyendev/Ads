#if canImport(GoogleMobileAds) && canImport(UIKit)
import AdKit
import GoogleMobileAds
import UIKit

/// A native ad card: icon, headline, "Ad" badge, advertiser, body, optional media and a call-to-action.
/// Every asset is registered with `NativeAdView` so the SDK handles clicks, impressions and AdChoices.
@MainActor
final class AdMobNativeAd: NSObject, NativeCardAd {
    var revenueHandler: ((AdRevenue) -> Void)?
    var clickHandler: (() -> Void)?
    var impressionHandler: (() -> Void)?
    var rootViewController: UIViewController?

    var view: UIView { adView }

    private let adUnitID: String
    private let style: NativeAdStyle
    private let adView = NativeAdView()
    private let iconView = UIImageView()
    private let headlineLabel = UILabel()
    private let badgeLabel = PaddedLabel()
    private let advertiserLabel = UILabel()
    private let bodyLabel = UILabel()
    private let mediaView = MediaView()
    private let callToActionButton = UIButton(type: .system)
    private var mediaAspect: NSLayoutConstraint?
    private var loader: AdLoader?
    private var nativeAd: NativeAd?
    private var continuation: CheckedContinuation<Void, Error>?

    init(adUnitID: String, style: NativeAdStyle) {
        self.adUnitID = adUnitID
        self.style = style
        super.init()
        buildLayout()
    }

    func load() async throws {
        continuation?.resume(throwing: CancellationError())
        let loader = AdLoader(adUnitID: adUnitID, rootViewController: rootViewController, adTypes: [.native], options: nil)
        loader.delegate = self
        self.loader = loader
        try await withCheckedThrowingContinuation { continuation in
            self.continuation = continuation
            loader.load(Request())
        }
    }

    func fittingHeight(for width: CGFloat) -> CGFloat {
        adView.bounds.size.width = width
        adView.layoutIfNeeded()
        return adView.systemLayoutSizeFitting(
            CGSize(width: width, height: UIView.layoutFittingCompressedSize.height),
            withHorizontalFittingPriority: .required,
            verticalFittingPriority: .fittingSizeLevel
        ).height
    }

    private func buildLayout() {
        adView.backgroundColor = style.background
        adView.layer.cornerRadius = style.cornerRadius
        adView.layer.cornerCurve = .continuous
        adView.clipsToBounds = true

        iconView.contentMode = .scaleAspectFill
        iconView.layer.cornerRadius = 10
        iconView.layer.cornerCurve = .continuous
        iconView.clipsToBounds = true
        iconView.widthAnchor.constraint(equalToConstant: 44).isActive = true
        iconView.heightAnchor.constraint(equalToConstant: 44).isActive = true

        headlineLabel.font = .preferredFont(forTextStyle: .headline)
        headlineLabel.adjustsFontForContentSizeCategory = true
        headlineLabel.textColor = style.primaryText
        headlineLabel.numberOfLines = 2

        badgeLabel.text = "Ad"
        badgeLabel.font = .systemFont(ofSize: 11, weight: .bold)
        badgeLabel.textColor = style.accentText
        badgeLabel.backgroundColor = style.accent
        badgeLabel.layer.cornerRadius = 4
        badgeLabel.clipsToBounds = true
        badgeLabel.setContentHuggingPriority(.required, for: .horizontal)
        badgeLabel.setContentCompressionResistancePriority(.required, for: .horizontal)
        badgeLabel.isAccessibilityElement = true
        badgeLabel.accessibilityLabel = "Advertisement"

        advertiserLabel.font = .preferredFont(forTextStyle: .caption1)
        advertiserLabel.adjustsFontForContentSizeCategory = true
        advertiserLabel.textColor = style.secondaryText

        bodyLabel.font = .preferredFont(forTextStyle: .subheadline)
        bodyLabel.adjustsFontForContentSizeCategory = true
        bodyLabel.textColor = style.secondaryText
        bodyLabel.numberOfLines = 3

        mediaView.layer.cornerRadius = 12
        mediaView.clipsToBounds = true

        var configuration = UIButton.Configuration.filled()
        configuration.baseBackgroundColor = style.accent
        configuration.baseForegroundColor = style.accentText
        configuration.cornerStyle = .capsule
        callToActionButton.configuration = configuration
        callToActionButton.heightAnchor.constraint(greaterThanOrEqualToConstant: 44).isActive = true
        // The SDK handles the tap through NativeAdView; the button only draws.
        callToActionButton.isUserInteractionEnabled = false

        let titleRow = UIStackView(arrangedSubviews: [badgeLabel, headlineLabel])
        titleRow.spacing = 6
        titleRow.alignment = .firstBaseline
        let titleColumn = UIStackView(arrangedSubviews: [titleRow, advertiserLabel])
        titleColumn.axis = .vertical
        titleColumn.spacing = 2
        let header = UIStackView(arrangedSubviews: [iconView, titleColumn])
        header.spacing = 12
        header.alignment = .center

        let stack = UIStackView(arrangedSubviews: [header, bodyLabel, mediaView, callToActionButton])
        stack.axis = .vertical
        stack.spacing = 12
        stack.translatesAutoresizingMaskIntoConstraints = false
        adView.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: adView.topAnchor, constant: 16),
            stack.leadingAnchor.constraint(equalTo: adView.leadingAnchor, constant: 16),
            stack.trailingAnchor.constraint(equalTo: adView.trailingAnchor, constant: -16),
            stack.bottomAnchor.constraint(equalTo: adView.bottomAnchor, constant: -16),
        ])

        adView.iconView = iconView
        adView.headlineView = headlineLabel
        adView.advertiserView = advertiserLabel
        adView.bodyView = bodyLabel
        adView.mediaView = mediaView
        adView.callToActionView = callToActionButton
    }

    private func populate(_ ad: NativeAd) {
        headlineLabel.text = ad.headline
        bodyLabel.text = ad.body
        bodyLabel.isHidden = ad.body?.isEmpty ?? true
        advertiserLabel.text = ad.advertiser
        advertiserLabel.isHidden = ad.advertiser?.isEmpty ?? true
        iconView.image = ad.icon?.image
        iconView.isHidden = ad.icon == nil
        callToActionButton.configuration?.title = ad.callToAction
        callToActionButton.isHidden = ad.callToAction == nil

        let aspect = ad.mediaContent.aspectRatio > 0 ? ad.mediaContent.aspectRatio : 16.0 / 9.0
        mediaAspect?.isActive = false
        mediaAspect = mediaView.heightAnchor.constraint(equalTo: mediaView.widthAnchor, multiplier: 1 / aspect)
        mediaAspect?.isActive = true
        mediaView.mediaContent = ad.mediaContent
        mediaView.isHidden = !style.showsMedia

        ad.delegate = self
        ad.paidEventHandler = { [weak self] value in
            Task { @MainActor in
                guard let self else { return }
                self.revenueHandler?(AdRevenue(value, format: .native, adUnitID: self.adUnitID, responseInfo: ad.responseInfo))
            }
        }
        adView.nativeAd = ad
        nativeAd = ad
    }
}

extension AdMobNativeAd: NativeAdLoaderDelegate {
    func adLoader(_ adLoader: AdLoader, didReceive nativeAd: NativeAd) {
        populate(nativeAd)
        continuation?.resume()
        continuation = nil
    }

    func adLoader(_ adLoader: AdLoader, didFailToReceiveAdWithError error: Error) {
        continuation?.resume(throwing: error)
        continuation = nil
    }
}

extension AdMobNativeAd: NativeAdDelegate {
    func nativeAdDidRecordImpression(_ nativeAd: NativeAd) {
        impressionHandler?()
    }

    func nativeAdDidRecordClick(_ nativeAd: NativeAd) {
        clickHandler?()
    }
}

private final class PaddedLabel: UILabel {
    private let insets = UIEdgeInsets(top: 2, left: 5, bottom: 2, right: 5)

    override func drawText(in rect: CGRect) {
        super.drawText(in: rect.inset(by: insets))
    }

    override var intrinsicContentSize: CGSize {
        let size = super.intrinsicContentSize
        return CGSize(width: size.width + insets.left + insets.right, height: size.height + insets.top + insets.bottom)
    }
}
#endif
