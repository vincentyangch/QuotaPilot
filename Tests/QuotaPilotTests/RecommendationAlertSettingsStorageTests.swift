import XCTest
@testable import QuotaPilotCore

final class RecommendationAlertSettingsStorageTests: XCTestCase {
    func testLoadsDefaultSettingsWhenNothingStored() {
        let suiteName = "RecommendationAlertSettingsStorageTests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)

        let storage = RecommendationAlertSettingsStorage(userDefaults: defaults)

        XCTAssertEqual(storage.load(), .default)
    }

    func testPersistsSettingsRoundTrip() {
        let suiteName = "RecommendationAlertSettingsStorageTests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)

        let storage = RecommendationAlertSettingsStorage(userDefaults: defaults)
        let expected = RecommendationAlertSettings(isEnabled: true)

        storage.save(expected)

        XCTAssertEqual(storage.load(), expected)
    }
}
