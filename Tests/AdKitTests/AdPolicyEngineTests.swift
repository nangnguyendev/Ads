import XCTest
@testable import AdKit

final class AdPolicyEngineTests: XCTestCase {
    private let engine = AdPolicyEngine(policy: .balanced)
    private let start = Date(timeIntervalSince1970: 1_000_000)
    private let placement = AdPlacement.interstitial("level_complete")

    private func history(sessions: Int = 3, triggers: Int = 1, impressions: [AdHistory.Impression] = []) -> AdHistory {
        AdHistory(firstLaunch: start, sessionCount: sessions, impressions: impressions, pendingTriggers: [placement.id: triggers])
    }

    private func context(after seconds: TimeInterval, adFree: Bool = false) -> AdContext {
        AdContext(now: start.addingTimeInterval(seconds), sessionStart: start, isAdFree: adFree)
    }

    func testAllowsInterstitialAfterGracePeriods() {
        XCTAssertEqual(engine.evaluateInterstitial(placement, history: history(), context: context(after: 61)), .allowed)
    }

    func testBlocksNewUsers() {
        XCTAssertEqual(engine.evaluateInterstitial(placement, history: history(sessions: 1), context: context(after: 600)), .blocked(.newUserGrace))
    }

    func testBlocksRightAfterSessionStart() {
        let decision = engine.evaluateInterstitial(placement, history: history(), context: context(after: 10))
        XCTAssertEqual(decision, .blocked(.sessionStartDelay(remaining: 50)))
    }

    func testBlocksAdFreeUsers() {
        XCTAssertEqual(engine.evaluateInterstitial(placement, history: history(), context: context(after: 600, adFree: true)), .blocked(.adFree))
    }

    func testRewardedAllowedForAdFreeUsersByDefault() {
        XCTAssertEqual(engine.evaluateRewarded(context: context(after: 0, adFree: true)), .allowed)
    }

    func testRespectsTriggerInterval() {
        let everyThird = AdPlacement.interstitial("level_complete", every: 3)
        XCTAssertEqual(engine.evaluateInterstitial(everyThird, history: history(triggers: 2), context: context(after: 600)), .blocked(.triggerInterval(current: 2, required: 3)))
        XCTAssertEqual(engine.evaluateInterstitial(everyThird, history: history(triggers: 3), context: context(after: 600)), .allowed)
    }

    func testEnforcesMinimumIntervalBetweenFullScreenAds() {
        let last = AdHistory.Impression(format: .interstitial, placement: placement.id, date: start.addingTimeInterval(100))
        let decision = engine.evaluateInterstitial(placement, history: history(impressions: [last]), context: context(after: 130))
        XCTAssertEqual(decision, .blocked(.tooSoon(remaining: 60)))
    }

    func testCooldownAfterRewarded() {
        let last = AdHistory.Impression(format: .rewarded, placement: "coins", date: start.addingTimeInterval(100))
        let decision = engine.evaluateInterstitial(placement, history: history(impressions: [last]), context: context(after: 130))
        XCTAssertEqual(decision, .blocked(.cooldownAfterRewarded(remaining: 30)))
    }

    func testHourlyCap() {
        let impressions = (0..<4).map {
            AdHistory.Impression(format: .interstitial, placement: placement.id, date: start.addingTimeInterval(Double($0) * 100))
        }
        let decision = engine.evaluateInterstitial(placement, history: history(impressions: impressions), context: context(after: 1000))
        XCTAssertEqual(decision, .blocked(.hourlyCap))
    }

    func testDailyCapAcrossSessions() {
        var policy = AdPolicy.balanced
        policy.interstitial.maxPerDay = 2
        let engine = AdPolicyEngine(policy: policy)
        let impressions = [
            AdHistory.Impression(format: .interstitial, placement: placement.id, date: start.addingTimeInterval(-7200)),
            AdHistory.Impression(format: .interstitial, placement: placement.id, date: start.addingTimeInterval(-5000))
        ]
        let decision = engine.evaluateInterstitial(placement, history: history(impressions: impressions), context: context(after: 600))
        XCTAssertEqual(decision, .blocked(.dailyCap))
    }

    func testAppOpenRequiresReturningUser() {
        XCTAssertEqual(engine.evaluateAppOpen(.coldStart, history: history(sessions: 1), context: context(after: 0)), .blocked(.notEnoughSessions))
        XCTAssertEqual(engine.evaluateAppOpen(.coldStart, history: history(sessions: 3), context: context(after: 0)), .allowed)
    }

    func testAppOpenIgnoresQuickAppSwitches() {
        let decision = engine.evaluateAppOpen(.resume(backgroundDuration: 5), history: history(), context: context(after: 600))
        XCTAssertEqual(decision, .blocked(.backgroundTooShort))
    }

    func testAppOpenNotRightAfterInterstitial() {
        let last = AdHistory.Impression(format: .interstitial, placement: placement.id, date: start.addingTimeInterval(500))
        let decision = engine.evaluateAppOpen(.resume(backgroundDuration: 60), history: history(impressions: [last]), context: context(after: 560))
        XCTAssertEqual(decision, .blocked(.tooSoon(remaining: 60)))
    }

    func testConsentGateBlocksEverything() {
        var ctx = context(after: 600)
        ctx.canRequestAds = false
        XCTAssertEqual(engine.evaluateRewarded(context: ctx), .blocked(.consentRequired))
        XCTAssertEqual(engine.evaluateInterstitial(placement, history: history(), context: ctx), .blocked(.consentRequired))
    }

    func testHistoryPrunesOldImpressionsAndResetsTriggers() {
        var history = history(triggers: 5, impressions: [
            AdHistory.Impression(format: .interstitial, placement: placement.id, date: start.addingTimeInterval(-90_000))
        ])
        history.record(.interstitial, placement: placement.id, at: start)
        XCTAssertEqual(history.impressions.count, 1)
        XCTAssertEqual(history.pendingTriggers[placement.id], 0)
    }
}
