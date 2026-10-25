import Foundation
#if canImport(UIKit)
import UIKit
public typealias AdPresentingController = UIViewController
#else
public typealias AdPresentingController = AnyObject
#endif

public struct AdPresentationResult: Sendable {
    public var didShow: Bool
    public var reward: AdReward?
    public var error: Error?

    public init(didShow: Bool, reward: AdReward? = nil, error: Error? = nil) {
        self.didShow = didShow
        self.reward = reward
        self.error = error
    }
}

@MainActor
public protocol FullScreenAd: AnyObject {
    var format: AdFormat { get }
    var adUnitID: String { get }
    var revenueHandler: ((AdRevenue) -> Void)? { get set }
    var clickHandler: (() -> Void)? { get set }
    func present(from controller: AdPresentingController) async -> AdPresentationResult
}

#if canImport(UIKit)
@MainActor
public protocol BannerAd: AnyObject {
    var view: UIView { get }
    var rootViewController: UIViewController? { get set }
    var revenueHandler: ((AdRevenue) -> Void)? { get set }
    var clickHandler: (() -> Void)? { get set }
    func load(width: CGFloat) async throws -> CGSize
}

/// A native ad laid out as a card. `load()` fills `view`; the host sizes it from `fittingHeight(for:)`.
@MainActor
public protocol NativeCardAd: AnyObject {
    var view: UIView { get }
    var rootViewController: UIViewController? { get set }
    var revenueHandler: ((AdRevenue) -> Void)? { get set }
    var clickHandler: (() -> Void)? { get set }
    var impressionHandler: (() -> Void)? { get set }
    func load() async throws
    func fittingHeight(for width: CGFloat) -> CGFloat
}

/// Colors and shape for a native ad card, so it matches the app around it.
public struct NativeAdStyle {
    public var background: UIColor
    public var primaryText: UIColor
    public var secondaryText: UIColor
    public var accent: UIColor
    public var accentText: UIColor
    public var cornerRadius: CGFloat
    public var showsMedia: Bool

    public init(
        background: UIColor = .secondarySystemGroupedBackground,
        primaryText: UIColor = .label,
        secondaryText: UIColor = .secondaryLabel,
        accent: UIColor = .tintColor,
        accentText: UIColor = .white,
        cornerRadius: CGFloat = 20,
        showsMedia: Bool = true
    ) {
        self.background = background
        self.primaryText = primaryText
        self.secondaryText = secondaryText
        self.accent = accent
        self.accentText = accentText
        self.cornerRadius = cornerRadius
        self.showsMedia = showsMedia
    }
}
#endif

@MainActor
public protocol AdNetwork: AnyObject {
    var name: String { get }
    func start(audience: AdAudience, testDeviceIDs: [String]) async
    func loadFullScreenAd(_ format: AdFormat, adUnitID: String) async throws -> FullScreenAd
    #if canImport(UIKit)
    func makeBannerAd(adUnitID: String) -> BannerAd
    /// `nil` when the network has no native ads.
    func makeNativeAd(adUnitID: String, style: NativeAdStyle) -> NativeCardAd?
    #endif
    /// Called after the user changes their choices in the privacy options form.
    func privacyChoicesDidChange()
}

public extension AdNetwork {
    func privacyChoicesDidChange() {}
    #if canImport(UIKit)
    func makeNativeAd(adUnitID: String, style: NativeAdStyle) -> NativeCardAd? { nil }
    #endif
}

public enum ConsentStatus: String, Sendable {
    case unknown
    case notRequired
    case required
    case obtained
}

@MainActor
public protocol ConsentProvider: AnyObject {
    var canRequestAds: Bool { get }
    var isPrivacyOptionsRequired: Bool { get }
    func gatherConsent(audience: AdAudience, from controller: AdPresentingController?) async throws -> ConsentStatus
    func presentPrivacyOptions(from controller: AdPresentingController) async throws
    /// Whether the last `gatherConsent` call showed a consent form. A cold start app open ad is skipped right after one.
    var didPresentFormInLastGather: Bool { get }
}

public extension ConsentProvider {
    var didPresentFormInLastGather: Bool { false }
}

@MainActor
public final class NoConsentProvider: ConsentProvider {
    public init() {}
    public var canRequestAds: Bool { true }
    public var isPrivacyOptionsRequired: Bool { false }
    public func gatherConsent(audience: AdAudience, from controller: AdPresentingController?) async throws -> ConsentStatus { .notRequired }
    public func presentPrivacyOptions(from controller: AdPresentingController) async throws {}
}
