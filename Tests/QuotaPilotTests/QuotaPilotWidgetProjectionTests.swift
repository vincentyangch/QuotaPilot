import XCTest
@testable import QuotaPilotCore

final class QuotaPilotWidgetProjectionTests: XCTestCase {
    func testBuildsProviderPanelsWithCurrentAndRecommendedAccounts() throws {
        let now = Date(timeIntervalSince1970: 2_000)
        let snapshot = QuotaPilotWidgetSnapshot(
            generatedAt: Date(timeIntervalSince1970: 1_700),
            accounts: [
                QuotaAccount(
                    id: UUID(uuidString: "00000000-0000-0000-0000-000000000001") ?? UUID(),
                    provider: .codex,
                    label: "Codex Current",
                    priority: 50,
                    isCurrent: true,
                    profileRootPath: "/tmp/codex-current",
                    sourceDescription: "Test",
                    windows: [
                        UsageWindow(
                            id: "session",
                            title: "Session",
                            remainingPercent: 10,
                            resetsAt: now.addingTimeInterval(3600)
                        )
                    ]
                ),
                QuotaAccount(
                    id: UUID(uuidString: "00000000-0000-0000-0000-000000000002") ?? UUID(),
                    provider: .codex,
                    label: "Codex Better",
                    priority: 90,
                    isCurrent: false,
                    profileRootPath: "/tmp/codex-better",
                    sourceDescription: "Test",
                    windows: [
                        UsageWindow(
                            id: "session",
                            title: "Session",
                            remainingPercent: 80,
                            resetsAt: now.addingTimeInterval(1800)
                        )
                    ]
                ),
            ],
            rules: .default,
            lastUsageRefreshSummary: "Loaded live usage for 2 local profile(s)."
        )

        let projection = QuotaPilotWidgetProjection.make(snapshot: snapshot, now: now)
        let panel = try XCTUnwrap(projection.providerPanels.first(where: { $0.provider == .codex }))

        XCTAssertEqual(panel.currentLabel, "Codex Current")
        XCTAssertEqual(panel.currentRemainingPercent, 10)
        XCTAssertEqual(panel.recommendedLabel, "Codex Better")
        XCTAssertEqual(panel.recommendedRemainingPercent, 80)
        XCTAssertTrue(panel.showsWarning)
        XCTAssertEqual(panel.statusText, "Switch suggested")
        XCTAssertEqual(projection.lastRefreshText, "Updated 5 min ago")
    }

    func testKeepsStayCurrentPanelWhenCurrentStillBest() throws {
        let now = Date(timeIntervalSince1970: 4_000)
        let snapshot = QuotaPilotWidgetSnapshot(
            generatedAt: Date(timeIntervalSince1970: 3_940),
            accounts: [
                QuotaAccount(
                    id: UUID(uuidString: "00000000-0000-0000-0000-000000000003") ?? UUID(),
                    provider: .claude,
                    label: "Claude Team",
                    priority: 85,
                    isCurrent: true,
                    profileRootPath: "/tmp/claude-team",
                    sourceDescription: "Test",
                    windows: [
                        UsageWindow(
                            id: "weekly",
                            title: "Weekly",
                            remainingPercent: 70,
                            resetsAt: now.addingTimeInterval(7200)
                        )
                    ]
                )
            ],
            rules: .default,
            lastUsageRefreshSummary: "Loaded live usage for 1 local profile(s)."
        )

        let projection = QuotaPilotWidgetProjection.make(snapshot: snapshot, now: now)
        let panel = try XCTUnwrap(projection.providerPanels.first(where: { $0.provider == .claude }))

        XCTAssertEqual(panel.currentLabel, "Claude Team")
        XCTAssertEqual(panel.recommendedLabel, "Claude Team")
        XCTAssertFalse(panel.showsWarning)
        XCTAssertEqual(panel.statusText, "Current stays best")
        XCTAssertEqual(projection.lastRefreshText, "Updated 1 min ago")
    }

    func testCarriesEmptyStateTextWhenNoAccountsArePresent() {
        let now = Date(timeIntervalSince1970: 5_000)
        let snapshot = QuotaPilotWidgetSnapshot(
            generatedAt: Date(timeIntervalSince1970: 4_940),
            accounts: [],
            rules: .default,
            lastUsageRefreshSummary: "No local profiles found yet. Add a Codex or Claude profile in Settings."
        )

        let projection = QuotaPilotWidgetProjection.make(snapshot: snapshot, now: now)

        XCTAssertTrue(projection.providerPanels.isEmpty)
        XCTAssertEqual(
            projection.emptyStateText,
            "No local profiles found yet. Add a Codex or Claude profile in Settings."
        )
        XCTAssertEqual(projection.lastRefreshText, "Updated 1 min ago")
    }
}
