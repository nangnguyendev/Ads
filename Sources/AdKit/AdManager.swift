import Foundation
import os
#if canImport(UIKit)
import UIKit
#endif

@MainActor
public final class AdManager: ObservableObject {
    public enum State: Equatable, Sendable {
        case idle
        case gatheringConsent
        case ready
        case disabled
    }

    @Published public private(set) var state: State = .idle
    @Published public private(set) var canRequestAds = false
    @Published public private(set) var isPrivacyOptionsRequired = false
    @Published public private(set) var trackingStatus: TrackingStatus = .notDetermined
    @Published public private(set) var isPresentingFullScreenAd = false
    @Published public private(set) var readyFormats: Set<AdFormat> = []
    @Published public var isAdFree = false {
        didSet { if oldValue != isAdFree { adFreeDidChange() } }
    }

    public let configuration: AdConfiguration
    public let network: AdNetwork

    public var eventHandler: ((AdEvent) -> Void)?
    public var revenueHandler: ((AdRevenue) -> Void)?

    private struct CachedAd {
        let ad: FullScreenAd
        let loadedAt: Date
    }

    private let consent: ConsentProvider
    private let tracking: TrackingAuthorizing
    private let store: AdHistoryStore
    private let clock: AdClock
    private let engine: AdPolicyEngine
    private let logger = Logger(subsystem: "AdKit", category: "AdManager")

    private var history: AdHistory
    private var sessionStart: Date
    private var cache: [AdFormat: CachedAd] = [:]
    private var loading: Set<AdFormat> = []
    private var retryAttempts: [AdFormat: Int] = [:]
    private var suppressionCount = 0
    private var backgroundedAt: Date?
    private var skipNextAppOpen = false
    private var didPromptThisLaunch = false
    private var lifecycleTasks: [Task<Void, Never>] = []

    public init(
        configuration: AdConfiguration,
        network: AdNetwork,
        consent: ConsentProvider? = nil,
        tracking: TrackingAuthorizing? = nil,
        store: AdHistoryStore = UserDefaultsAdHistoryStore(),
        clock: AdClock = SystemAdClock()
    ) {
        self.configuration = configuration
        self.network = network
        self.consent = consent ?? NoConsentProvider()
        self.tracking = tracking ?? AppTrackingAuthorizer()
        self.store = store
        self.clock = clock
        self.engine = AdPolicyEngine(policy: configuration.policy)
        self.history = store.load()
        self.sessionStart = clock.now
        beginSession()
    }

    public var shouldShowBanners: Bool {
        state == .ready && canRequestAds && !isAdFree && configuration.adUnitIDs.banner != nil
    }

    public var shouldShowNativeAds: Bool {
        state == .ready && canRequestAds && !isAdFree && configuration.adUnitIDs.native != nil
    }

    public var isRewardedAdAvailable: Bool {
        readyFormats.contains(.rewarded) && engine.evaluateRewarded(context: context()).isAllowed
    }

    public var isSuppressingFullScreenAds: Bool { suppressionCount > 0 }

    public func start(from controller: AdPresentingController? = nil) async {
        guard state == .idle else { return }
        state = .gatheringConsent

        do {
            let status = try await consent.gatherConsent(audience: configuration.audience, from: controller)
            emit(.consentGathered(status))
        } catch {
            log("consent error: \(error.localizedDescription)")
        }
        canRequestAds = consent.canRequestAds
        isPrivacyOptionsRequired = consent.isPrivacyOptionsRequired
        // Not `canRequestAds` before and after: UMP reports false at every cold start until its update finishes.
        if consent.didPresentFormInLastGather { didPromptThisLaunch = true }

        trackingStatus = tracking.status
        if configuration.requestsTrackingAuthorization, configuration.audience.allowsTracking, trackingStatus == .notDetermined {
            trackingStatus = await tracking.requestAuthorization()
            didPromptThisLaunch = true
            emit(.trackingAuthorization(trackingStatus))
        }

        guard canRequestAds else {
            state = .disabled
            return
        }
        await startNetwork()

        if !didPromptThisLaunch {
            await presentAppOpen(.coldStart, from: controller, waitUpTo: configuration.policy.appOpen.coldStartLoadTimeout)
        }
    }

    @discardableResult
    public func showInterstitial(at placement: AdPlacement, from controller: AdPresentingController? = nil) async -> Bool {
        precondition(placement.format == .interstitial, "AdKit: \(placement.id) is not an interstitial placement")
        history.pendingTriggers[placement.id, default: 0] += 1
        store.save(history)

        let decision = engine.evaluateInterstitial(placement, history: history, context: context())
        guard decision == .allowed else {
            if case .blocked(let reason) = decision { emit(.blocked(.interstitial, placement: placement.id, reason: reason)) }
            return false
        }
        return await present(.interstitial, placement: placement.id, from: controller)?.didShow ?? false
    }

    public func showRewarded(at placement: AdPlacement, from controller: AdPresentingController? = nil) async -> AdReward? {
        precondition(placement.format == .rewarded, "AdKit: \(placement.id) is not a rewarded placement")
        let decision = engine.evaluateRewarded(context: context())
        guard decision == .allowed else {
            if case .blocked(let reason) = decision { emit(.blocked(.rewarded, placement: placement.id, reason: reason)) }
            return nil
        }
        let reward = await present(.rewarded, placement: placement.id, from: controller)?.reward
        if let reward { emit(.rewarded(reward, placement: placement.id)) }
        return reward
    }

    @discardableResult
    public func showAppOpenAdIfEligible(from controller: AdPresentingController? = nil) async -> Bool {
        await presentAppOpen(.resume(backgroundDuration: .infinity), from: controller, waitUpTo: 0)
    }

    public func presentPrivacyOptions(from controller: AdPresentingController? = nil) async {
        guard let presenter = resolve(controller) else { return }
        do {
            try await consent.presentPrivacyOptions(from: presenter)
        } catch {
            log("privacy options error: \(error.localizedDescription)")
        }
        canRequestAds = consent.canRequestAds
        isPrivacyOptionsRequired = consent.isPrivacyOptionsRequired
        network.privacyChoicesDidChange()
        if canRequestAds, state == .disabled {
            await startNetwork()
        } else if !canRequestAds {
            cache.removeAll()
            updateReadiness()
            state = .disabled
        }
    }

    public func beginSuppressingFullScreenAds() {
        suppressionCount += 1
    }

    public func endSuppressingFullScreenAds() {
        suppressionCount = max(0, suppressionCount - 1)
    }

    public func withFullScreenAdsSuppressed<T>(_ operation: () async throws -> T) async rethrows -> T {
        beginSuppressingFullScreenAds()
        defer { endSuppressingFullScreenAds() }
        return try await operation()
    }

    public func preload(_ format: AdFormat) {
        load(format)
    }

    public func resetHistory() {
        history = AdHistory()
        beginSession()
    }

    #if canImport(UIKit)
    public func makeBannerAd(placement: AdPlacement = .banner) -> BannerAd? {
        guard shouldShowBanners, let unitID = configuration.adUnitIDs.banner else { return nil }
        let banner = network.makeBannerAd(adUnitID: unitID)
        banner.revenueHandler = { [weak self] revenue in
            self?.emit(.revenue(revenue.with(placement: placement.id)))
        }
        banner.clickHandler = { [weak self] in
            self?.skipNextAppOpen = true
            self?.emit(.clicked(.banner, placement: placement.id))
        }
        return banner
    }

    public func makeNativeAd(placement: AdPlacement = .native, style: NativeAdStyle = NativeAdStyle()) -> NativeCardAd? {
        guard shouldShowNativeAds, let unitID = configuration.adUnitIDs.native,
              let ad = network.makeNativeAd(adUnitID: unitID, style: style) else { return nil }
        ad.revenueHandler = { [weak self] revenue in
            self?.emit(.revenue(revenue.with(placement: placement.id)))
        }
        ad.clickHandler = { [weak self] in
            self?.skipNextAppOpen = true
            self?.emit(.clicked(.native, placement: placement.id))
        }
        ad.impressionHandler = { [weak self] in
            self?.emit(.shown(.native, placement: placement.id))
        }
        return ad
    }
    #endif

    private func startNetwork() async {
        await network.start(audience: configuration.audience, testDeviceIDs: configuration.testDeviceIDs)
        state = .ready
        emit(.started)
        observeLifecycle()
        preloadAll()
    }

    private func beginSession() {
        let now = clock.now
        if history.firstLaunch == nil { history.firstLaunch = now }
        history.sessionCount += 1
        history.prune(now: now)
        sessionStart = now
        store.save(history)
    }

    private func context() -> AdContext {
        AdContext(
            now: clock.now,
            sessionStart: sessionStart,
            isAdFree: isAdFree,
            canRequestAds: canRequestAds && state == .ready,
            isSuppressed: suppressionCount > 0,
            isPresenting: isPresentingFullScreenAd
        )
    }

    @discardableResult
    private func presentAppOpen(_ trigger: AppOpenTrigger, from controller: AdPresentingController?, waitUpTo timeout: TimeInterval) async -> Bool {
        let placement = AdPlacement.appOpen.id
        let decision = engine.evaluateAppOpen(trigger, history: history, context: context())
        guard decision == .allowed else {
            if case .blocked(let reason) = decision { emit(.blocked(.appOpen, placement: placement, reason: reason)) }
            return false
        }
        if timeout > 0, validAd(.appOpen) == nil {
            load(.appOpen)
            await waitForAd(.appOpen, timeout: timeout)
        }
        return await present(.appOpen, placement: placement, from: controller)?.didShow ?? false
    }

    private func present(_ format: AdFormat, placement: String, from controller: AdPresentingController?) async -> AdPresentationResult? {
        guard let ad = validAd(format) else {
            emit(.blocked(format, placement: placement, reason: configuration.adUnitIDs[format] == nil ? .noAdUnit : .notLoaded))
            load(format)
            return nil
        }
        guard let presenter = resolve(controller) else { return nil }
        // A sensitive flow (such as an alarm ringing) may have started while an app open ad was loading.
        if suppressionCount > 0 && format != .rewarded {
            emit(.blocked(format, placement: placement, reason: .suppressed))
            return nil
        }

        cache[format] = nil
        updateReadiness()
        ad.revenueHandler = { [weak self] revenue in
            self?.emit(.revenue(revenue.with(placement: placement)))
        }
        ad.clickHandler = { [weak self] in
            self?.skipNextAppOpen = true
            self?.emit(.clicked(format, placement: placement))
        }

        isPresentingFullScreenAd = true
        let result = await ad.present(from: presenter)
        isPresentingFullScreenAd = false

        if result.didShow {
            history.record(format, placement: placement, at: clock.now)
            store.save(history)
            emit(.shown(format, placement: placement))
            emit(.dismissed(format, placement: placement))
        } else if let error = result.error {
            log("present \(format.rawValue) failed: \(error.localizedDescription)")
        }
        load(format)
        return result
    }

    private func shouldKeepLoaded(_ format: AdFormat) -> Bool {
        guard state == .ready, canRequestAds, configuration.adUnitIDs[format] != nil else { return false }
        switch format {
        case .banner, .native: return false
        case .rewarded: return !isAdFree || configuration.policy.rewardedAvailableToAdFreeUsers
        case .appOpen: return !isAdFree && configuration.policy.appOpen.isEnabled
        case .interstitial: return !isAdFree
        }
    }

    private func preloadAll() {
        configuration.preloadedFormats.forEach(load)
    }

    private func load(_ format: AdFormat) {
        guard shouldKeepLoaded(format), !loading.contains(format), validAd(format) == nil,
              let unitID = configuration.adUnitIDs[format] else { return }
        loading.insert(format)
        Task {
            defer { loading.remove(format) }
            do {
                let ad = try await network.loadFullScreenAd(format, adUnitID: unitID)
                guard shouldKeepLoaded(format) else { return }
                cache[format] = CachedAd(ad: ad, loadedAt: clock.now)
                retryAttempts[format] = 0
                updateReadiness()
                emit(.loaded(format))
            } catch {
                emit(.loadFailed(format, error.localizedDescription))
                scheduleRetry(format)
            }
        }
    }

    private func scheduleRetry(_ format: AdFormat) {
        let attempt = retryAttempts[format, default: 0] + 1
        retryAttempts[format] = attempt
        let delay = min(pow(2, Double(attempt)), configuration.maxRetryDelay)
        Task { [weak self] in
            try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
            self?.load(format)
        }
    }

    private func validAd(_ format: AdFormat) -> FullScreenAd? {
        guard let cached = cache[format] else { return nil }
        guard clock.now.timeIntervalSince(cached.loadedAt) < format.cacheLifetime else {
            cache[format] = nil
            updateReadiness()
            return nil
        }
        return cached.ad
    }

    private func waitForAd(_ format: AdFormat, timeout: TimeInterval) async {
        let deadline = Date().addingTimeInterval(timeout)
        while validAd(format) == nil, loading.contains(format), Date() < deadline {
            try? await Task.sleep(nanoseconds: 100_000_000)
        }
    }

    private func updateReadiness() {
        let ready = Set(cache.keys)
        if ready != readyFormats { readyFormats = ready }
    }

    private func adFreeDidChange() {
        for format in Array(cache.keys) where !shouldKeepLoaded(format) {
            cache[format] = nil
        }
        updateReadiness()
        if !isAdFree { preloadAll() }
    }

    private func dropExpiredAndReload() {
        for format in Array(cache.keys) { _ = validAd(format) }
        preloadAll()
    }

    private func resolve(_ controller: AdPresentingController?) -> AdPresentingController? {
        if let controller { return controller }
        #if canImport(UIKit)
        return UIApplication.shared.adKitTopViewController
        #else
        return nil
        #endif
    }

    private func emit(_ event: AdEvent) {
        if configuration.isLoggingEnabled { log("\(event)") }
        if case .revenue(let revenue) = event { revenueHandler?(revenue) }
        eventHandler?(event)
    }

    private func log(_ message: String) {
        guard configuration.isLoggingEnabled else { return }
        logger.debug("\(message, privacy: .public)")
    }

    func handleDidEnterBackground() {
        backgroundedAt = clock.now
    }

    func handleDidBecomeActive(from controller: AdPresentingController? = nil) async {
        guard let backgroundedAt else { return }
        self.backgroundedAt = nil
        let duration = clock.now.timeIntervalSince(backgroundedAt)
        if duration >= configuration.policy.sessionTimeout { beginSession() }
        dropExpiredAndReload()

        if skipNextAppOpen {
            skipNextAppOpen = false
            return
        }
        await presentAppOpen(.resume(backgroundDuration: duration), from: controller, waitUpTo: 0)
    }

    private func observeLifecycle() {
        #if canImport(UIKit)
        guard lifecycleTasks.isEmpty else { return }
        let center = NotificationCenter.default
        lifecycleTasks.append(Task { [weak self] in
            for await _ in center.notifications(named: UIApplication.didEnterBackgroundNotification) {
                self?.handleDidEnterBackground()
            }
        })
        lifecycleTasks.append(Task { [weak self] in
            for await _ in center.notifications(named: UIApplication.didBecomeActiveNotification) {
                await self?.handleDidBecomeActive()
            }
        })
        #endif
    }
}
