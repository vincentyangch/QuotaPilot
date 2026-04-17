import XCTest
@testable import QuotaPilotCore

final class ActivityLogStoreTests: XCTestCase {
    func testLoadsEmptyWhenFileIsMissing() throws {
        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathComponent("activity-log.json")
        let store = ActivityLogStore(fileURL: tempURL)

        XCTAssertEqual(try store.loadEntries(), [])
    }

    func testPersistsEntriesRoundTrip() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        let fileURL = root.appendingPathComponent("activity-log.json")
        let store = ActivityLogStore(fileURL: fileURL)

        let expected = [
            ActivityLogEntry(
                id: UUID(uuidString: "00000000-0000-0000-0000-000000000001") ?? UUID(),
                timestamp: Date(timeIntervalSince1970: 100),
                kind: .refreshSucceeded,
                provider: .codex,
                title: "Refresh succeeded",
                detail: "Loaded live usage for 2 local profile(s)."
            ),
            ActivityLogEntry(
                id: UUID(uuidString: "00000000-0000-0000-0000-000000000002") ?? UUID(),
                timestamp: Date(timeIntervalSince1970: 200),
                kind: .activationSucceeded,
                provider: .claude,
                title: "Activated profile",
                detail: "Activated Claude Max."
            ),
        ]

        try store.saveEntries(expected)

        XCTAssertEqual(try store.loadEntries(), expected)
    }

    func testTrimsToMostRecentEntries() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        let fileURL = root.appendingPathComponent("activity-log.json")
        let store = ActivityLogStore(fileURL: fileURL)

        let entries = (0..<5).map { index in
            ActivityLogEntry(
                id: UUID(),
                timestamp: Date(timeIntervalSince1970: Double(index)),
                kind: .refreshSucceeded,
                provider: .codex,
                title: "Entry \(index)",
                detail: "Detail \(index)"
            )
        }

        try store.saveEntries(entries, maxEntries: 3)
        let loaded = try store.loadEntries()

        XCTAssertEqual(loaded.count, 3)
        XCTAssertEqual(loaded.map(\.title), ["Entry 2", "Entry 3", "Entry 4"])
    }
}
