import XCTest
@testable import QuotaPilotCore

final class TrackedProfileInventoryBuilderTests: XCTestCase {
    func testIncludesTrackedProfilesEvenWithoutLiveUsage() {
        let discoveredProfiles = [
            DiscoveredLocalProfile(
                provider: .codex,
                label: "Codex Work",
                email: "work@example.com",
                plan: "pro",
                profileRootURL: URL(fileURLWithPath: "/Users/tester/.quotapilot/codex-work", isDirectory: true),
                credentialsURL: URL(fileURLWithPath: "/Users/tester/.quotapilot/codex-work/auth.json"),
                sourceDescription: "Stored profile source"
            ),
            DiscoveredLocalProfile(
                provider: .claude,
                label: "Claude Free",
                email: nil,
                plan: "free",
                profileRootURL: URL(fileURLWithPath: "/Users/tester/.claude", isDirectory: true),
                credentialsURL: URL(fileURLWithPath: "/Users/tester/.claude/.credentials.json"),
                sourceDescription: "macOS Keychain"
            ),
        ]

        let items = TrackedProfileInventoryBuilder.makeItems(
            discoveredProfiles: discoveredProfiles,
            liveAccounts: [],
            failures: [],
            currentProfileRootPaths: [.claude: "/Users/tester/.claude"]
        )

        XCTAssertEqual(items.count, 2)
        XCTAssertEqual(items[0].label, "Codex Work")
        XCTAssertFalse(items[0].hasLiveUsage)
        XCTAssertEqual(items[0].statusSummary, "Awaiting live refresh")
        XCTAssertEqual(items[0].capabilitySummary, "Usage, Recommend, Auto-Switch, Desktop Handoff")
        XCTAssertNil(items[0].lastRefreshSummary)
        XCTAssertNil(items[0].lastErrorDetail)

        XCTAssertEqual(items[1].label, "Claude Free")
        XCTAssertTrue(items[1].isCurrentSelection)
        XCTAssertFalse(items[1].hasLiveUsage)
    }

    func testMergesLiveUsageIntoTrackedProfiles() {
        let discoveredProfiles = [
            DiscoveredLocalProfile(
                provider: .codex,
                label: "Codex Work",
                email: "work@example.com",
                plan: "pro",
                profileRootURL: URL(fileURLWithPath: "/Users/tester/.quotapilot/codex-work", isDirectory: true),
                credentialsURL: URL(fileURLWithPath: "/Users/tester/.quotapilot/codex-work/auth.json"),
                sourceDescription: "Stored profile source"
            )
        ]

        let liveAccounts = [
            QuotaAccount(
                id: UUID(),
                provider: .codex,
                label: "Codex Work",
                priority: 80,
                isCurrent: true,
                profileRootPath: "/Users/tester/.quotapilot/codex-work",
                sourceDescription: "Stored profile source",
                email: "work@example.com",
                plan: "pro",
                workspaceLabel: "Personal Workspace",
                lastSuccessfulRefreshAt: Date(timeIntervalSince1970: 1_800_000_000),
                windows: [
                    UsageWindow(
                        id: "session",
                        title: "Session",
                        remainingPercent: 63,
                        resetsAt: Date(timeIntervalSince1970: 1_900_000_000)
                    )
                ]
            )
        ]

        let items = TrackedProfileInventoryBuilder.makeItems(
            discoveredProfiles: discoveredProfiles,
            liveAccounts: liveAccounts,
            failures: [
                AmbientUsageRefreshFailure(
                    provider: .codex,
                    profileLabel: "Codex Work",
                    profileRootPath: "/Users/tester/.quotapilot/codex-work",
                    detail: "Codex usage request failed with HTTP 401.",
                    kind: .requestFailed(statusCode: 401)
                )
            ],
            now: Date(timeIntervalSince1970: 1_800_000_060),
            currentProfileRootPaths: [.codex: "/Users/tester/.quotapilot/codex-work"]
        )

        let item = try? XCTUnwrap(items.first)
        XCTAssertEqual(item?.label, "Codex Work")
        XCTAssertTrue(item?.hasLiveUsage == true)
        XCTAssertEqual(item?.liveRemainingPercent, 63)
        XCTAssertEqual(item?.statusSummary, "63% remaining")
        XCTAssertEqual(item?.capabilitySummary, "Usage, Recommend, Auto-Switch, Desktop Handoff")
        XCTAssertEqual(item?.lastRefreshSummary, "Updated 1 min ago")
        XCTAssertEqual(item?.lastErrorDetail, "Codex usage request failed with HTTP 401.")
    }
}
