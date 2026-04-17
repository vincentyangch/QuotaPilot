import XCTest
@testable import QuotaPilotCore

final class QuotaPilotWidgetSnapshotStoreTests: XCTestCase {
    func testLoadsNilWhenSnapshotFileIsMissing() throws {
        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathComponent("widget-snapshot.json")
        let store = QuotaPilotWidgetSnapshotStore(fileURL: tempURL)

        XCTAssertNil(try store.load())
    }

    func testPersistsSnapshotRoundTrip() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        let fileURL = root.appendingPathComponent("widget-snapshot.json")
        let store = QuotaPilotWidgetSnapshotStore(fileURL: fileURL)

        let snapshot = QuotaPilotWidgetSnapshot(
            generatedAt: Date(timeIntervalSince1970: 123),
            accounts: [
                QuotaAccount(
                    id: UUID(uuidString: "00000000-0000-0000-0000-000000000001") ?? UUID(),
                    provider: .codex,
                    label: "Codex Work",
                    priority: 80,
                    isCurrent: true,
                    profileRootPath: "/tmp/codex-work",
                    sourceDescription: "Test",
                    windows: [
                        UsageWindow(
                            id: "session",
                            title: "Session",
                            remainingPercent: 64,
                            resetsAt: Date(timeIntervalSince1970: 10_000)
                        ),
                        UsageWindow(
                            id: "weekly",
                            title: "Weekly",
                            remainingPercent: 54,
                            resetsAt: Date(timeIntervalSince1970: 20_000)
                        ),
                    ]
                ),
                QuotaAccount(
                    id: UUID(uuidString: "00000000-0000-0000-0000-000000000002") ?? UUID(),
                    provider: .claude,
                    label: "Claude Free",
                    priority: 40,
                    isCurrent: true,
                    profileRootPath: "/tmp/claude-free",
                    sourceDescription: "Test",
                    windows: [
                        UsageWindow(
                            id: "weekly",
                            title: "Weekly",
                            remainingPercent: 18,
                            resetsAt: Date(timeIntervalSince1970: 30_000)
                        ),
                    ]
                ),
            ],
            rules: GlobalRules.default,
            lastUsageRefreshSummary: "Loaded live usage for 2 local profile(s)."
        )

        try store.save(snapshot)

        XCTAssertEqual(try store.load(), snapshot)
    }
}
