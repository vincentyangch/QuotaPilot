import XCTest
@testable import QuotaPilotCore

final class StoredProfileSourceStoreTests: XCTestCase {
    func testLoadsEmptyWhenFileIsMissing() throws {
        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathComponent("profile-sources.json")
        let store = FileStoredProfileSourceStore(fileURL: tempURL)

        XCTAssertEqual(try store.loadSources(), [])
    }

    func testPersistsSourcesRoundTrip() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        let fileURL = root.appendingPathComponent("profile-sources.json")
        let store = FileStoredProfileSourceStore(fileURL: fileURL)

        let expected = [
            StoredProfileSource(
                id: UUID(uuidString: "E8A47B0D-4FEE-43E7-8F63-0673EAB82A01") ?? UUID(),
                provider: .codex,
                label: "Codex Work",
                profileRootPath: "/tmp/codex-work",
                isEnabled: true,
                addedAt: Date(timeIntervalSince1970: 100)
            ),
            StoredProfileSource(
                id: UUID(uuidString: "E8A47B0D-4FEE-43E7-8F63-0673EAB82A02") ?? UUID(),
                provider: .claude,
                label: "Claude Alt",
                profileRootPath: "/tmp/claude-alt",
                isEnabled: false,
                addedAt: Date(timeIntervalSince1970: 200)
            ),
        ]

        try store.saveSources(expected)

        XCTAssertEqual(try store.loadSources(), expected)
    }
}
