import Foundation
#if canImport(AppTrackingTransparency)
import AppTrackingTransparency
#endif
#if canImport(UIKit)
import UIKit
#endif

public enum TrackingStatus: String, Sendable {
    case notDetermined
    case restricted
    case denied
    case authorized
    case unavailable
}

@MainActor
public protocol TrackingAuthorizing: AnyObject {
    var status: TrackingStatus { get }
    func requestAuthorization() async -> TrackingStatus
}

@MainActor
public final class AppTrackingAuthorizer: TrackingAuthorizing {
    public init() {}

    public var status: TrackingStatus {
        #if canImport(AppTrackingTransparency)
        return Self.map(ATTrackingManager.trackingAuthorizationStatus)
        #else
        return .unavailable
        #endif
    }

    public func requestAuthorization() async -> TrackingStatus {
        #if canImport(AppTrackingTransparency) && canImport(UIKit)
        guard status == .notDetermined else { return status }
        guard Bundle.main.object(forInfoDictionaryKey: "NSUserTrackingUsageDescription") != nil else {
            assertionFailure("AdKit: add NSUserTrackingUsageDescription to Info.plist before requesting tracking authorization")
            return status
        }
        await waitUntilActive()
        let result = await ATTrackingManager.requestTrackingAuthorization()
        return Self.map(result)
        #else
        return status
        #endif
    }

    #if canImport(UIKit)
    private func waitUntilActive() async {
        guard UIApplication.shared.applicationState != .active else { return }
        for await _ in NotificationCenter.default.notifications(named: UIApplication.didBecomeActiveNotification) {
            return
        }
    }
    #endif

    #if canImport(AppTrackingTransparency)
    private static func map(_ status: ATTrackingManager.AuthorizationStatus) -> TrackingStatus {
        switch status {
        case .notDetermined: return .notDetermined
        case .restricted: return .restricted
        case .denied: return .denied
        case .authorized: return .authorized
        @unknown default: return .unavailable
        }
    }
    #endif
}
