import XCTest
@testable import QuotaPilotCore

final class RecommendationAlertStateStoreTests: XCTestCase {
    func testLoadsEmptyStateWhenFileIsMissing() throws {
        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathComponent("alert-state.json")
        let store = RecommendationAlertStateStore(fileURL: tempURL)
        let expected: [QuotaProvider: String] = [:]

        XCTAssertEqual(try store.loadState(), expected)
    }

    func testPersistsStateRoundTrip() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        let store = RecommendationAlertStateStore(fileURL: root.appendingPathComponent("alert-state.json"))
        let expected: [QuotaProvider: String] = [
            .codex: "codex:one:two",
            .claude: "claude:three:four",
        ]

        try store.saveState(expected)

        XCTAssertEqual(try store.loadState(), expected)
    }
}
