import XCTest
@testable import AdKit

final class USPrivacyTests: XCTestCase {
    private var defaults: UserDefaults!

    override func setUp() {
        super.setUp()
        defaults = UserDefaults(suiteName: "USPrivacyTests")
        defaults.removePersistentDomain(forName: "USPrivacyTests")
    }

    // Version 1, every notice given, then SaleOptOut, SharingOptOut and TargetedAdvertisingOptOut.
    // "BVVq": all three "did not opt out" (2). "BVVa": sale opted out (1).

    func testUsnatWithoutOptOut() {
        XCTAssertEqual(USPrivacy.optedOut(usnat: "BVVqAAEABA"), false)
    }

    func testUsnatSaleOptOut() {
        XCTAssertEqual(USPrivacy.optedOut(usnat: "BVVaAAEABA"), true)
    }

    func testUsnatIgnoresSubsections() {
        XCTAssertEqual(USPrivacy.optedOut(usnat: "BVVa.QA"), true)
    }

    func testRejectsMalformedUsnat() {
        XCTAssertNil(USPrivacy.optedOut(usnat: "BV"))
        XCTAssertNil(USPrivacy.optedOut(usnat: "B*Vq"))
    }

    func testReadsSectionKey() {
        defaults.set("BVVaAAEABA", forKey: "IABGPP_7_String")
        XCTAssertEqual(USPrivacy.current(defaults: defaults), USPrivacy(doNotSell: true))
    }

    func testReadsFullGPPString() {
        defaults.set("DBABLA~BVVqAAEABA", forKey: "IABGPP_HDR_GppString")
        defaults.set("7", forKey: "IABGPP_GppSID")
        XCTAssertEqual(USPrivacy.current(defaults: defaults), USPrivacy(doNotSell: false))
    }

    func testFallsBackToUSPrivacyString() {
        defaults.set("1YYN", forKey: "IABUSPrivacy_String")
        XCTAssertEqual(USPrivacy.current(defaults: defaults), USPrivacy(doNotSell: true))
    }

    func testNoSignalOutsideRegulatedStates() {
        XCTAssertNil(USPrivacy.current(defaults: defaults))
    }

    func testUSPrivacyString() {
        XCTAssertEqual(USPrivacy(doNotSell: true).usPrivacyString, "1YYN")
        XCTAssertEqual(USPrivacy(doNotSell: false).usPrivacyString, "1YNN")
    }
}
