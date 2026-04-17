import XCTest
@testable import QuotaPilotCore

final class GlobalRulesStorageTests: XCTestCase {
    func testLoadsDefaultRulesWhenNothingIsStored() {
        let suiteName = "GlobalRulesStorageTests.default"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)

        let storage = GlobalRulesStorage(userDefaults: defaults)

        XCTAssertEqual(storage.load(), .default)
    }

    func testPersistsRulesRoundTrip() {
        let suiteName = "GlobalRulesStorageTests.roundtrip"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)

        let expected = GlobalRules(
            switchThresholdPercent: 35,
            minimumScoreAdvantage: 22,
            remainingWeight: 2,
            resetWeight: 4,
            priorityWeight: 1,
            providerWeights: [.codex: 50, .claude: 50]
        )

        let storage = GlobalRulesStorage(userDefaults: defaults)
        storage.save(expected)

        XCTAssertEqual(storage.load(), expected)
    }
}
