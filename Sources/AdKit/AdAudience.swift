import Foundation

public enum AdContentRating: String, Sendable, Codable {
    case general
    case parentalGuidance
    case teen
    case matureAudience
}

public struct AdAudience: Sendable, Equatable {
    public var isChildDirected: Bool
    public var isUnderAgeOfConsent: Bool
    public var maxContentRating: AdContentRating

    public init(isChildDirected: Bool = false, isUnderAgeOfConsent: Bool = false, maxContentRating: AdContentRating = .parentalGuidance) {
        self.isChildDirected = isChildDirected
        self.isUnderAgeOfConsent = isUnderAgeOfConsent
        self.maxContentRating = maxContentRating
    }

    public var allowsTracking: Bool { !isChildDirected && !isUnderAgeOfConsent }

    public static let general = AdAudience()

    public static let childDirected = AdAudience(isChildDirected: true, isUnderAgeOfConsent: true, maxContentRating: .general)

    public static let mixed13Plus = AdAudience(maxContentRating: .teen)
}
