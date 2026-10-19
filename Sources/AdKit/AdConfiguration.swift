import Foundation

public struct AdConfiguration: Sendable {
    public var adUnitIDs: AdUnitIDs
    public var policy: AdPolicy
    public var audience: AdAudience
    public var requestsTrackingAuthorization: Bool
    public var preloadedFormats: Set<AdFormat>
    public var testDeviceIDs: [String]
    public var maxRetryDelay: TimeInterval
    public var isLoggingEnabled: Bool

    public init(
        adUnitIDs: AdUnitIDs,
        policy: AdPolicy = .balanced,
        audience: AdAudience = .general,
        requestsTrackingAuthorization: Bool = true,
        preloadedFormats: Set<AdFormat> = [.interstitial, .rewarded, .appOpen],
        testDeviceIDs: [String] = [],
        maxRetryDelay: TimeInterval = 64,
        isLoggingEnabled: Bool = false
    ) {
        self.adUnitIDs = adUnitIDs
        self.policy = policy
        self.audience = audience
        self.requestsTrackingAuthorization = requestsTrackingAuthorization
        self.preloadedFormats = preloadedFormats
        self.testDeviceIDs = testDeviceIDs
        self.maxRetryDelay = maxRetryDelay
        self.isLoggingEnabled = isLoggingEnabled
    }
}

public enum AdEvent: Sendable {
    case consentGathered(ConsentStatus)
    case trackingAuthorization(TrackingStatus)
    case started
    case loaded(AdFormat)
    case loadFailed(AdFormat, String)
    case shown(AdFormat, placement: String)
    case dismissed(AdFormat, placement: String)
    case clicked(AdFormat, placement: String)
    case rewarded(AdReward, placement: String)
    case blocked(AdFormat, placement: String, reason: AdBlockReason)
    case revenue(AdRevenue)
}

public protocol AdClock: Sendable {
    var now: Date { get }
}

public struct SystemAdClock: AdClock {
    public init() {}
    public var now: Date { Date() }
}
