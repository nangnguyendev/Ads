import Foundation

public struct AdPolicy: Sendable, Equatable {
    public struct Interstitial: Sendable, Equatable {
        public var minimumInterval: TimeInterval
        public var maxPerHour: Int
        public var maxPerDay: Int
        public var maxPerSession: Int
        public var sessionStartDelay: TimeInterval
        public var newUserGraceSessions: Int
        public var cooldownAfterRewarded: TimeInterval
        public var cooldownAfterAppOpen: TimeInterval

        public init(
            minimumInterval: TimeInterval = 90,
            maxPerHour: Int = 4,
            maxPerDay: Int = 20,
            maxPerSession: Int = 6,
            sessionStartDelay: TimeInterval = 60,
            newUserGraceSessions: Int = 1,
            cooldownAfterRewarded: TimeInterval = 60,
            cooldownAfterAppOpen: TimeInterval = 60
        ) {
            self.minimumInterval = minimumInterval
            self.maxPerHour = maxPerHour
            self.maxPerDay = maxPerDay
            self.maxPerSession = maxPerSession
            self.sessionStartDelay = sessionStartDelay
            self.newUserGraceSessions = newUserGraceSessions
            self.cooldownAfterRewarded = cooldownAfterRewarded
            self.cooldownAfterAppOpen = cooldownAfterAppOpen
        }
    }

    public struct AppOpen: Sendable, Equatable {
        public var isEnabled: Bool
        public var showOnColdStart: Bool
        public var coldStartLoadTimeout: TimeInterval
        public var minimumSessions: Int
        public var minimumBackgroundDuration: TimeInterval
        public var minimumInterval: TimeInterval
        public var maxPerDay: Int
        public var cooldownAfterFullScreenAd: TimeInterval

        public init(
            isEnabled: Bool = true,
            showOnColdStart: Bool = true,
            coldStartLoadTimeout: TimeInterval = 3,
            minimumSessions: Int = 3,
            minimumBackgroundDuration: TimeInterval = 30,
            minimumInterval: TimeInterval = 30 * 60,
            maxPerDay: Int = 4,
            cooldownAfterFullScreenAd: TimeInterval = 120
        ) {
            self.isEnabled = isEnabled
            self.showOnColdStart = showOnColdStart
            self.coldStartLoadTimeout = coldStartLoadTimeout
            self.minimumSessions = minimumSessions
            self.minimumBackgroundDuration = minimumBackgroundDuration
            self.minimumInterval = minimumInterval
            self.maxPerDay = maxPerDay
            self.cooldownAfterFullScreenAd = cooldownAfterFullScreenAd
        }
    }

    public var interstitial: Interstitial
    public var appOpen: AppOpen
    public var rewardedAvailableToAdFreeUsers: Bool
    public var sessionTimeout: TimeInterval

    public init(
        interstitial: Interstitial = Interstitial(),
        appOpen: AppOpen = AppOpen(),
        rewardedAvailableToAdFreeUsers: Bool = true,
        sessionTimeout: TimeInterval = 30 * 60
    ) {
        self.interstitial = interstitial
        self.appOpen = appOpen
        self.rewardedAvailableToAdFreeUsers = rewardedAvailableToAdFreeUsers
        self.sessionTimeout = sessionTimeout
    }

    public static let balanced = AdPolicy()

    public static let conservative = AdPolicy(
        interstitial: Interstitial(
            minimumInterval: 180,
            maxPerHour: 2,
            maxPerDay: 10,
            maxPerSession: 3,
            sessionStartDelay: 120,
            newUserGraceSessions: 2
        ),
        appOpen: AppOpen(isEnabled: false)
    )

    public static let revenueFocused = AdPolicy(
        interstitial: Interstitial(
            minimumInterval: 60,
            maxPerHour: 6,
            maxPerDay: 30,
            maxPerSession: 10,
            sessionStartDelay: 45,
            newUserGraceSessions: 1
        ),
        appOpen: AppOpen(minimumSessions: 2, minimumInterval: 15 * 60, maxPerDay: 6)
    )

    public static let kids = AdPolicy(
        interstitial: Interstitial(
            minimumInterval: 300,
            maxPerHour: 2,
            maxPerDay: 6,
            maxPerSession: 2,
            sessionStartDelay: 180,
            newUserGraceSessions: 2
        ),
        appOpen: AppOpen(isEnabled: false)
    )
}
