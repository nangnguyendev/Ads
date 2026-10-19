import Foundation

public enum AdBlockReason: Equatable, Sendable, CustomStringConvertible {
    case adFree
    case consentRequired
    case noAdUnit
    case notLoaded
    case alreadyPresenting
    case suppressed
    case newUserGrace
    case sessionStartDelay(remaining: TimeInterval)
    case tooSoon(remaining: TimeInterval)
    case cooldownAfterRewarded(remaining: TimeInterval)
    case cooldownAfterAppOpen(remaining: TimeInterval)
    case triggerInterval(current: Int, required: Int)
    case sessionCap
    case hourlyCap
    case dailyCap
    case appOpenDisabled
    case coldStartDisabled
    case notEnoughSessions
    case backgroundTooShort

    public var description: String {
        switch self {
        case .adFree: return "user is ad-free"
        case .consentRequired: return "consent not gathered"
        case .noAdUnit: return "no ad unit configured"
        case .notLoaded: return "ad not loaded"
        case .alreadyPresenting: return "another full-screen ad is on screen"
        case .suppressed: return "ads suppressed during sensitive flow"
        case .newUserGrace: return "new user grace period"
        case .sessionStartDelay(let r): return "session just started (\(Int(r))s left)"
        case .tooSoon(let r): return "too soon after last full-screen ad (\(Int(r))s left)"
        case .cooldownAfterRewarded(let r): return "cooldown after rewarded ad (\(Int(r))s left)"
        case .cooldownAfterAppOpen(let r): return "cooldown after app open ad (\(Int(r))s left)"
        case .triggerInterval(let c, let r): return "trigger \(c)/\(r)"
        case .sessionCap: return "session cap reached"
        case .hourlyCap: return "hourly cap reached"
        case .dailyCap: return "daily cap reached"
        case .appOpenDisabled: return "app open ads disabled"
        case .coldStartDisabled: return "app open on cold start disabled"
        case .notEnoughSessions: return "not enough sessions for app open ads"
        case .backgroundTooShort: return "app was in background too briefly"
        }
    }
}

public enum AdDecision: Equatable, Sendable {
    case allowed
    case blocked(AdBlockReason)

    public var isAllowed: Bool { self == .allowed }
}

public struct AdContext: Sendable {
    public var now: Date
    public var sessionStart: Date
    public var isAdFree: Bool
    public var canRequestAds: Bool
    public var isSuppressed: Bool
    public var isPresenting: Bool

    public init(now: Date, sessionStart: Date, isAdFree: Bool = false, canRequestAds: Bool = true, isSuppressed: Bool = false, isPresenting: Bool = false) {
        self.now = now
        self.sessionStart = sessionStart
        self.isAdFree = isAdFree
        self.canRequestAds = canRequestAds
        self.isSuppressed = isSuppressed
        self.isPresenting = isPresenting
    }
}

public enum AppOpenTrigger: Equatable, Sendable {
    case coldStart
    case resume(backgroundDuration: TimeInterval)
}

public struct AdPolicyEngine: Sendable {
    public var policy: AdPolicy

    public init(policy: AdPolicy) {
        self.policy = policy
    }

    public func evaluateInterstitial(_ placement: AdPlacement, history: AdHistory, context: AdContext) -> AdDecision {
        if let reason = commonBlock(context, ignoresAdFree: false) { return .blocked(reason) }
        let rules = policy.interstitial
        let now = context.now

        if history.sessionCount <= rules.newUserGraceSessions { return .blocked(.newUserGrace) }

        let sinceSessionStart = now.timeIntervalSince(context.sessionStart)
        if sinceSessionStart < rules.sessionStartDelay {
            return .blocked(.sessionStartDelay(remaining: rules.sessionStartDelay - sinceSessionStart))
        }

        let triggers = history.pendingTriggers[placement.id, default: 0]
        if triggers < placement.triggerInterval {
            return .blocked(.triggerInterval(current: triggers, required: placement.triggerInterval))
        }

        if let reason = remaining(rules.minimumInterval, since: history.lastImpression(of: [.interstitial, .appOpen]), now: now) {
            return .blocked(.tooSoon(remaining: reason))
        }
        if let reason = remaining(rules.cooldownAfterRewarded, since: history.lastImpression(of: [.rewarded]), now: now) {
            return .blocked(.cooldownAfterRewarded(remaining: reason))
        }
        if let reason = remaining(rules.cooldownAfterAppOpen, since: history.lastImpression(of: [.appOpen]), now: now) {
            return .blocked(.cooldownAfterAppOpen(remaining: reason))
        }

        if history.count(of: .interstitial, since: context.sessionStart) >= rules.maxPerSession { return .blocked(.sessionCap) }
        if history.count(of: .interstitial, since: now.addingTimeInterval(-3600)) >= rules.maxPerHour { return .blocked(.hourlyCap) }
        if history.count(of: .interstitial, since: now.addingTimeInterval(-24 * 3600)) >= rules.maxPerDay { return .blocked(.dailyCap) }

        return .allowed
    }

    public func evaluateRewarded(context: AdContext) -> AdDecision {
        if let reason = commonBlock(context, ignoresAdFree: policy.rewardedAvailableToAdFreeUsers) { return .blocked(reason) }
        return .allowed
    }

    public func evaluateAppOpen(_ trigger: AppOpenTrigger, history: AdHistory, context: AdContext) -> AdDecision {
        if let reason = commonBlock(context, ignoresAdFree: false) { return .blocked(reason) }
        let rules = policy.appOpen
        let now = context.now

        guard rules.isEnabled else { return .blocked(.appOpenDisabled) }
        if history.sessionCount < rules.minimumSessions { return .blocked(.notEnoughSessions) }

        switch trigger {
        case .coldStart:
            guard rules.showOnColdStart else { return .blocked(.coldStartDisabled) }
        case .resume(let duration):
            if duration < rules.minimumBackgroundDuration { return .blocked(.backgroundTooShort) }
        }

        if let reason = remaining(rules.minimumInterval, since: history.lastImpression(of: [.appOpen]), now: now) {
            return .blocked(.tooSoon(remaining: reason))
        }
        if let reason = remaining(rules.cooldownAfterFullScreenAd, since: history.lastImpression(of: [.interstitial, .rewarded]), now: now) {
            return .blocked(.tooSoon(remaining: reason))
        }
        if history.count(of: .appOpen, since: now.addingTimeInterval(-24 * 3600)) >= rules.maxPerDay { return .blocked(.dailyCap) }

        return .allowed
    }

    private func commonBlock(_ context: AdContext, ignoresAdFree: Bool) -> AdBlockReason? {
        if !context.canRequestAds { return .consentRequired }
        if context.isAdFree && !ignoresAdFree { return .adFree }
        if context.isPresenting { return .alreadyPresenting }
        if context.isSuppressed { return .suppressed }
        return nil
    }

    private func remaining(_ interval: TimeInterval, since date: Date?, now: Date) -> TimeInterval? {
        guard let date else { return nil }
        let elapsed = now.timeIntervalSince(date)
        return elapsed < interval ? interval - elapsed : nil
    }
}
