import XCTest
@testable import AdKit

@MainActor
final class MockFullScreenAd: FullScreenAd {
    let format: AdFormat
    let adUnitID: String
    var revenueHandler: ((AdRevenue) -> Void)?
    var clickHandler: (() -> Void)?
    var reward: AdReward?
    weak var network: MockNetwork?

    init(format: AdFormat, adUnitID: String, reward: AdReward? = nil) {
        self.format = format
        self.adUnitID = adUnitID
        self.reward = reward
    }

    func present(from controller: AdPresentingController) async -> AdPresentationResult {
        if network?.clicksOnPresent == true { clickHandler?() }
        revenueHandler?(AdRevenue(value: 0.012, currencyCode: "USD", precision: .precise, format: format, placement: "", adUnitID: adUnitID, adSourceName: "Mock"))
        return AdPresentationResult(didShow: true, reward: reward)
    }
}

@MainActor
final class MockNetwork: AdNetwork {
    let name = "Mock"
    var loadCount: [AdFormat: Int] = [:]
    var failLoads = false
    var clicksOnPresent = false
    var loadDelay: UInt64 = 0

    func start(audience: AdAudience, testDeviceIDs: [String]) async {}

    func loadFullScreenAd(_ format: AdFormat, adUnitID: String) async throws -> FullScreenAd {
        loadCount[format, default: 0] += 1
        if loadDelay > 0 { try? await Task.sleep(nanoseconds: loadDelay) }
        if failLoads { throw URLError(.notConnectedToInternet) }
        let ad = MockFullScreenAd(format: format, adUnitID: adUnitID, reward: format == .rewarded ? AdReward(type: "coins", amount: 10) : nil)
        ad.network = self
        return ad
    }
}

@MainActor
final class MockTracking: TrackingAuthorizing {
    var status: TrackingStatus = .notDetermined
    var requestCount = 0

    func requestAuthorization() async -> TrackingStatus {
        requestCount += 1
        status = .denied
        return status
    }
}

@MainActor
final class MockConsent: ConsentProvider {
    var canRequestAds = true
    var isPrivacyOptionsRequired = true

    func gatherConsent(audience: AdAudience, from controller: AdPresentingController?) async throws -> ConsentStatus { .obtained }
    func presentPrivacyOptions(from controller: AdPresentingController) async throws {}
}

final class MutableClock: AdClock, @unchecked Sendable {
    var now: Date
    init(_ now: Date) { self.now = now }
}

@MainActor
final class AdManagerTests: XCTestCase {
    private let presenter = NSObject()
    private var clock: MutableClock!
    private var network: MockNetwork!
    private var tracking: MockTracking!
    private var consent: MockConsent!
    private var store: InMemoryAdHistoryStore!

    override func setUp() async throws {
        clock = MutableClock(Date(timeIntervalSince1970: 2_000_000))
        network = MockNetwork()
        tracking = MockTracking()
        consent = MockConsent()
        store = InMemoryAdHistoryStore(history: AdHistory(sessionCount: 5))
    }

    private func makeManager(audience: AdAudience = .general) -> AdManager {
        AdManager(
            configuration: AdConfiguration(adUnitIDs: .googleTestIDs, audience: audience),
            network: network,
            consent: consent,
            tracking: tracking,
            store: store,
            clock: clock
        )
    }

    private func waitForLoads() async {
        for _ in 0..<20 { await Task.yield() }
    }

    func testStartRequestsTrackingAndPreloads() async {
        let manager = makeManager()
        await manager.start(from: presenter)
        await waitForLoads()
        XCTAssertEqual(manager.state, .ready)
        XCTAssertEqual(tracking.requestCount, 1)
        XCTAssertEqual(manager.readyFormats, [.interstitial, .rewarded, .appOpen])
        XCTAssertTrue(manager.isPrivacyOptionsRequired)
    }

    func testAppOpenSkippedWhenSuppressedWhileLoading() async {
        tracking.status = .authorized
        network.loadDelay = 300_000_000
        var events: [AdEvent] = []
        let manager = makeManager()
        manager.eventHandler = { events.append($0) }
        let start = Task { await manager.start(from: presenter) }
        // The alarm starts ringing while the cold start app open ad is still loading.
        try? await Task.sleep(nanoseconds: 100_000_000)
        manager.beginSuppressingFullScreenAds()
        await start.value
        XCTAssertNil(store.load().lastImpression(of: [.appOpen]))
        XCTAssertTrue(events.contains { if case .blocked(.appOpen, _, .suppressed) = $0 { return true }; return false })
    }

    func testNativeAdsNeedANetworkThatSupportsThem() async {
        let manager = makeManager()
        await manager.start(from: presenter)
        XCTAssertTrue(manager.shouldShowNativeAds)
        manager.isAdFree = true
        XCTAssertFalse(manager.shouldShowNativeAds)
    }

    func testNativeIsNotFullScreen() {
        XCTAssertFalse(AdFormat.native.isFullScreen)
        XCTAssertFalse(AdFormat.banner.isFullScreen)
        XCTAssertTrue(AdFormat.appOpen.isFullScreen)
        XCTAssertEqual(AdUnitIDs.googleTestIDs[.native], "ca-app-pub-3940256099942544/3986624511")
    }

    func testChildDirectedAudienceNeverRequestsTracking() async {
        let manager = makeManager(audience: .childDirected)
        await manager.start(from: presenter)
        XCTAssertEqual(tracking.requestCount, 0)
    }

    func testDisabledWithoutConsent() async {
        consent.canRequestAds = false
        let manager = makeManager()
        await manager.start(from: presenter)
        XCTAssertEqual(manager.state, .disabled)
        XCTAssertNil(network.loadCount[.interstitial])
        XCTAssertFalse(manager.shouldShowBanners)
    }

    func testInterstitialShowsThenRespectsFrequencyCap() async {
        let manager = makeManager()
        var revenue: [AdRevenue] = []
        manager.revenueHandler = { revenue.append($0) }
        await manager.start(from: presenter)
        await waitForLoads()

        clock.now = clock.now.addingTimeInterval(120)
        let first = await manager.showInterstitial(at: .interstitial("level_complete"), from: presenter)
        XCTAssertTrue(first)
        XCTAssertEqual(revenue.first?.placement, "level_complete")
        await waitForLoads()

        clock.now = clock.now.addingTimeInterval(30)
        let second = await manager.showInterstitial(at: .interstitial("level_complete"), from: presenter)
        XCTAssertFalse(second)

        clock.now = clock.now.addingTimeInterval(90)
        let third = await manager.showInterstitial(at: .interstitial("level_complete"), from: presenter)
        XCTAssertTrue(third)
    }

    func testAdFreeDropsInterstitialsButKeepsRewarded() async {
        let manager = makeManager()
        await manager.start(from: presenter)
        await waitForLoads()

        manager.isAdFree = true
        XCTAssertEqual(manager.readyFormats, [.rewarded])
        XCTAssertTrue(manager.isRewardedAdAvailable)

        clock.now = clock.now.addingTimeInterval(600)
        let shown = await manager.showInterstitial(at: .interstitial("level_complete"), from: presenter)
        XCTAssertFalse(shown)

        let reward = await manager.showRewarded(at: .rewarded("double_coins"), from: presenter)
        XCTAssertEqual(reward, AdReward(type: "coins", amount: 10))
    }

    func testExpiredAdsAreNotShown() async {
        let manager = makeManager()
        await manager.start(from: presenter)
        await waitForLoads()

        clock.now = clock.now.addingTimeInterval(3601)
        let reward = await manager.showRewarded(at: .rewarded("double_coins"), from: presenter)
        XCTAssertNil(reward)
        await waitForLoads()
        XCTAssertEqual(network.loadCount[.rewarded], 2)
    }

    func testSuppressionBlocksFullScreenAds() async {
        let manager = makeManager()
        await manager.start(from: presenter)
        await waitForLoads()
        clock.now = clock.now.addingTimeInterval(600)

        let shown = await manager.withFullScreenAdsSuppressed {
            await manager.showInterstitial(at: .interstitial("checkout"), from: presenter)
        }
        XCTAssertFalse(shown)
    }

    func testAppOpenOnResumeButNotOnQuickSwitch() async {
        let manager = makeManager()
        var shownFormats: [AdFormat] = []
        manager.eventHandler = { if case .shown(let format, _) = $0 { shownFormats.append(format) } }
        await manager.start(from: presenter)
        await waitForLoads()

        clock.now = clock.now.addingTimeInterval(600)
        manager.handleDidEnterBackground()
        clock.now = clock.now.addingTimeInterval(5)
        await manager.handleDidBecomeActive(from: presenter)
        XCTAssertEqual(shownFormats, [])

        manager.handleDidEnterBackground()
        clock.now = clock.now.addingTimeInterval(120)
        await manager.handleDidBecomeActive(from: presenter)
        XCTAssertEqual(shownFormats, [.appOpen])
    }

    func testAppOpenSkippedAfterAdClick() async {
        let manager = makeManager()
        var shownFormats: [AdFormat] = []
        manager.eventHandler = { if case .shown(let format, _) = $0 { shownFormats.append(format) } }
        await manager.start(from: presenter)
        await waitForLoads()

        clock.now = clock.now.addingTimeInterval(600)
        network.clicksOnPresent = true
        _ = await manager.showRewarded(at: .rewarded("double_coins"), from: presenter)
        manager.handleDidEnterBackground()
        clock.now = clock.now.addingTimeInterval(300)
        await manager.handleDidBecomeActive(from: presenter)
        XCTAssertEqual(shownFormats, [.rewarded])
    }
}
