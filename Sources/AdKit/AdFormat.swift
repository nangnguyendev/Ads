import Foundation

public enum AdFormat: String, CaseIterable, Codable, Sendable {
    case banner
    case interstitial
    case rewarded
    case appOpen

    public var isFullScreen: Bool { self != .banner }

    public var cacheLifetime: TimeInterval {
        switch self {
        case .appOpen: return 4 * 3600
        case .banner: return .infinity
        case .interstitial, .rewarded: return 3600
        }
    }
}

public struct AdPlacement: Hashable, Codable, Sendable {
    public let id: String
    public let format: AdFormat
    public let triggerInterval: Int

    public init(_ id: String, format: AdFormat, every triggerInterval: Int = 1) {
        self.id = id
        self.format = format
        self.triggerInterval = max(1, triggerInterval)
    }

    public static func interstitial(_ id: String, every triggerInterval: Int = 1) -> AdPlacement {
        AdPlacement(id, format: .interstitial, every: triggerInterval)
    }

    public static func rewarded(_ id: String) -> AdPlacement {
        AdPlacement(id, format: .rewarded)
    }

    public static let appOpen = AdPlacement("app_open", format: .appOpen)
    public static let banner = AdPlacement("banner", format: .banner)
}

public struct AdUnitIDs: Sendable, Equatable {
    public var banner: String?
    public var interstitial: String?
    public var rewarded: String?
    public var appOpen: String?

    public init(banner: String? = nil, interstitial: String? = nil, rewarded: String? = nil, appOpen: String? = nil) {
        self.banner = banner
        self.interstitial = interstitial
        self.rewarded = rewarded
        self.appOpen = appOpen
    }

    public subscript(format: AdFormat) -> String? {
        switch format {
        case .banner: return banner
        case .interstitial: return interstitial
        case .rewarded: return rewarded
        case .appOpen: return appOpen
        }
    }

    public static let googleTestIDs = AdUnitIDs(
        banner: "ca-app-pub-3940256099942544/2435281174",
        interstitial: "ca-app-pub-3940256099942544/4411468910",
        rewarded: "ca-app-pub-3940256099942544/1712485313",
        appOpen: "ca-app-pub-3940256099942544/5575463023"
    )
}

public struct AdReward: Equatable, Sendable {
    public let type: String
    public let amount: Decimal

    public init(type: String, amount: Decimal) {
        self.type = type
        self.amount = amount
    }
}

public struct AdRevenue: Sendable {
    public enum Precision: String, Sendable {
        case unknown, estimated, publisherProvided, precise
    }

    public let value: Decimal
    public let currencyCode: String
    public let precision: Precision
    public let format: AdFormat
    public let placement: String
    public let adUnitID: String
    public let adSourceName: String?

    public init(value: Decimal, currencyCode: String, precision: Precision, format: AdFormat, placement: String, adUnitID: String, adSourceName: String?) {
        self.value = value
        self.currencyCode = currencyCode
        self.precision = precision
        self.format = format
        self.placement = placement
        self.adUnitID = adUnitID
        self.adSourceName = adSourceName
    }

    public func with(placement: String) -> AdRevenue {
        AdRevenue(value: value, currencyCode: currencyCode, precision: precision, format: format, placement: placement, adUnitID: adUnitID, adSourceName: adSourceName)
    }
}
