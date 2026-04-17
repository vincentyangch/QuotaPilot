import XCTest
@testable import QuotaPilotCore

final class SwitchActionModeStorageTests: XCTestCase {
    func testLoadsDefaultModeWhenNothingStored() {
        let suiteName = "SwitchActionModeStorageTests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)

        let storage = SwitchActionModeStorage(userDefaults: defaults)

        XCTAssertEqual(storage.load(), .recommendOnly)
    }

    func testPersistsModeRoundTrip() {
        let suiteName = "SwitchActionModeStorageTests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)

        let storage = SwitchActionModeStorage(userDefaults: defaults)

        storage.save(.autoActivateLocalProfiles)

        XCTAssertEqual(storage.load(), .autoActivateLocalProfiles)
    }
}
