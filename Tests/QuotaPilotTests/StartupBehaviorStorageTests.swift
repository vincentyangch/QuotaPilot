import XCTest
@testable import QuotaPilotCore

final class StartupBehaviorStorageTests: XCTestCase {
    func testLoadsDefaultBehaviorWhenNothingStored() {
        let suiteName = "StartupBehaviorStorageTests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)

        let storage = StartupBehaviorStorage(userDefaults: defaults)

        XCTAssertEqual(storage.load(), .default)
    }

    func testPersistsBehaviorRoundTrip() {
        let suiteName = "StartupBehaviorStorageTests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)

        let storage = StartupBehaviorStorage(userDefaults: defaults)
        let expected = StartupBehavior(opensDashboardOnLaunch: false)

        storage.save(expected)

        XCTAssertEqual(storage.load(), expected)
    }
}
