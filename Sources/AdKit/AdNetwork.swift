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
#endif

@MainActor
public protocol AdNetwork: AnyObject {
    var name: String { get }
    func start(audience: AdAudience, testDeviceIDs: [String]) async
    func loadFullScreenAd(_ format: AdFormat, adUnitID: String) async throws -> FullScreenAd
    #if canImport(UIKit)
    func makeBannerAd(adUnitID: String) -> BannerAd
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
}

@MainActor
public final class NoConsentProvider: ConsentProvider {
    public init() {}
    public var canRequestAds: Bool { true }
    public var isPrivacyOptionsRequired: Bool { false }
    public func gatherConsent(audience: AdAudience, from controller: AdPresentingController?) async throws -> ConsentStatus { .notRequired }
    public func presentPrivacyOptions(from controller: AdPresentingController) async throws {}
}
