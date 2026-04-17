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
                addedAt: Date(timeIntervalSince1970: 100),
                sourceKind: .stored,
                ownershipMode: .externalLocal
            ),
            StoredProfileSource(
                id: UUID(uuidString: "E8A47B0D-4FEE-43E7-8F63-0673EAB82A02") ?? UUID(),
                provider: .claude,
                label: "Claude Alt",
                profileRootPath: "/tmp/claude-alt",
                isEnabled: false,
                addedAt: Date(timeIntervalSince1970: 200),
                sourceKind: .stored,
                ownershipMode: .externalLocal
            ),
        ]

        try store.saveSources(expected)

        XCTAssertEqual(try store.loadSources(), expected)
    }

    func testLoadsLegacySourcesWithoutOwnershipFields() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        let fileURL = root.appendingPathComponent("profile-sources.json")
        let store = FileStoredProfileSourceStore(fileURL: fileURL)

        let legacyJSON = """
        {
          "version" : 1,
          "sources" : [
            {
              "addedAt" : "1970-01-01T00:01:40Z",
              "id" : "E8A47B0D-4FEE-43E7-8F63-0673EAB82A03",
              "isEnabled" : true,
              "label" : "Legacy Codex",
              "profileRootPath" : "/tmp/legacy-codex",
              "provider" : "codex"
            }
          ]
        }
        """
        try legacyJSON.write(to: fileURL, atomically: true, encoding: .utf8)

        let sources = try store.loadSources()
        XCTAssertEqual(sources.count, 1)
        XCTAssertEqual(sources.first?.sourceKind, .stored)
        XCTAssertEqual(sources.first?.ownershipMode, .externalLocal)
    }
}
