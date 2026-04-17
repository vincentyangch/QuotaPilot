import XCTest
@testable import QuotaPilotCore

final class CurrentProfileSelectionStoreTests: XCTestCase {
    func testLoadsEmptySelectionWhenFileIsMissing() throws {
        let fileURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathComponent("current-profile-selection.json")

        let store = FileCurrentProfileSelectionStore(fileURL: fileURL)
        XCTAssertEqual(try store.loadSelections(), [:])
    }

    func testPersistsSelectionsRoundTrip() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        let fileURL = root.appendingPathComponent("current-profile-selection.json")

        let store = FileCurrentProfileSelectionStore(fileURL: fileURL)
        let expected: [QuotaProvider: String] = [
            .codex: "/Users/tester/.quotapilot/codex-work",
            .claude: "/Users/tester/.quotapilot/claude-free",
        ]

        try store.saveSelections(expected)

        XCTAssertEqual(try store.loadSelections(), expected)
    }
}
