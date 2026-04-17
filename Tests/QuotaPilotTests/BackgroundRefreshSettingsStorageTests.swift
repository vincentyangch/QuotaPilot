import XCTest
@testable import QuotaPilotCore

final class BackgroundRefreshSettingsStorageTests: XCTestCase {
    func testLoadsDefaultSettingsWhenNothingStored() {
        let suiteName = "BackgroundRefreshSettingsStorageTests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)

        let storage = BackgroundRefreshSettingsStorage(userDefaults: defaults)

        XCTAssertEqual(storage.load(), .default)
    }

    func testPersistsSettingsRoundTrip() {
        let suiteName = "BackgroundRefreshSettingsStorageTests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)

        let storage = BackgroundRefreshSettingsStorage(userDefaults: defaults)
        let expected = BackgroundRefreshSettings(isEnabled: true, intervalMinutes: 10)

        storage.save(expected)

        XCTAssertEqual(storage.load(), expected)
    }
}
