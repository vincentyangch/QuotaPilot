import XCTest
@testable import QuotaPilotCore

final class QuotaPilotWidgetProjectionTests: XCTestCase {
    func testBuildsGlobalRecommendationPanelAcrossProviders() throws {
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
                            remainingPercent: 18,
                            resetsAt: now.addingTimeInterval(3600)
                        )
                    ]
                ),
                QuotaAccount(
                    id: UUID(uuidString: "00000000-0000-0000-0000-000000000010") ?? UUID(),
                    provider: .claude,
                    label: "Claude Active",
                    priority: 10,
                    isCurrent: true,
                    profileRootPath: "/tmp/claude-current",
                    sourceDescription: "Test",
                    windows: [
                        UsageWindow(
                            id: "weekly",
                            title: "Weekly",
                            remainingPercent: 30,
                            resetsAt: now.addingTimeInterval(7200)
                        )
                    ]
                ),
                QuotaAccount(
                    id: UUID(uuidString: "00000000-0000-0000-0000-000000000002") ?? UUID(),
                    provider: .claude,
                    label: "Claude Better",
                    priority: 90,
                    isCurrent: false,
                    profileRootPath: "/tmp/claude-better",
                    sourceDescription: "Test",
                    windows: [
                        UsageWindow(
                            id: "weekly",
                            title: "Weekly",
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
        let panel = try XCTUnwrap(projection.globalRecommendationPanel)

        XCTAssertEqual(panel.currentLabel, "Codex Current")
        XCTAssertEqual(panel.currentProvider, .codex)
        XCTAssertEqual(panel.currentRemainingPercent, 18)
        XCTAssertEqual(panel.recommendedLabel, "Claude Better")
        XCTAssertEqual(panel.recommendedProvider, .claude)
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
        let panel = try XCTUnwrap(projection.globalRecommendationPanel)

        XCTAssertEqual(panel.currentLabel, "Claude Team")
        XCTAssertEqual(panel.currentProvider, .claude)
        XCTAssertEqual(panel.recommendedLabel, "Claude Team")
        XCTAssertEqual(panel.recommendedProvider, .claude)
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

        XCTAssertNil(projection.globalRecommendationPanel)
        XCTAssertEqual(
            projection.emptyStateText,
            "No local profiles found yet. Add a Codex or Claude profile in Settings."
        )
        XCTAssertEqual(projection.lastRefreshText, "Updated 1 min ago")
    }
}
