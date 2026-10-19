#if canImport(UserMessagingPlatform) && canImport(UIKit)
import AdKit
import UIKit
import UserMessagingPlatform

@MainActor
public final class UMPConsentProvider: ConsentProvider {
    public enum DebugGeography {
        case regulatedUSState
        case eea
        case other
    }

    private let debugGeography: DebugGeography?
    private let testDeviceIDs: [String]

    public init(debugGeography: DebugGeography? = nil, testDeviceIDs: [String] = []) {
        self.debugGeography = debugGeography
        self.testDeviceIDs = testDeviceIDs
    }

    public var canRequestAds: Bool {
        ConsentInformation.shared.canRequestAds
    }

    public var isPrivacyOptionsRequired: Bool {
        ConsentInformation.shared.privacyOptionsRequirementStatus == .required
    }

    public func gatherConsent(audience: AdAudience, from controller: UIViewController?) async throws -> AdKit.ConsentStatus {
        let parameters = RequestParameters()
        parameters.isTaggedForUnderAgeOfConsent = audience.isUnderAgeOfConsent || audience.isChildDirected
        if let debugGeography {
            let settings = DebugSettings()
            settings.testDeviceIdentifiers = testDeviceIDs
            switch debugGeography {
            case .regulatedUSState: settings.geography = .regulatedUSState
            case .eea: settings.geography = .EEA
            case .other: settings.geography = .other
            }
            parameters.debugSettings = settings
        }

        try await ConsentInformation.shared.requestConsentInfoUpdate(with: parameters)
        try await ConsentForm.loadAndPresentIfRequired(from: controller)
        return Self.map(ConsentInformation.shared.consentStatus)
    }

    public func presentPrivacyOptions(from controller: UIViewController) async throws {
        try await ConsentForm.presentPrivacyOptionsForm(from: controller)
    }

    public func reset() {
        ConsentInformation.shared.reset()
    }

    private static func map(_ status: UserMessagingPlatform.ConsentStatus) -> AdKit.ConsentStatus {
        switch status {
        case .notRequired: return .notRequired
        case .required: return .required
        case .obtained: return .obtained
        default: return .unknown
        }
    }
}
#endif
