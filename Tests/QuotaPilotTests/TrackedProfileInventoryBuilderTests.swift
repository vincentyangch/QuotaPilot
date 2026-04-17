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
                sourceDescription: "Stored profile source",
                sourceKind: .stored,
                ownershipMode: .externalLocal
            ),
            DiscoveredLocalProfile(
                provider: .claude,
                label: "Claude Free",
                email: nil,
                plan: "free",
                profileRootURL: URL(fileURLWithPath: "/Users/tester/.claude", isDirectory: true),
                credentialsURL: URL(fileURLWithPath: "/Users/tester/.claude/.credentials.json"),
                sourceDescription: "macOS Keychain",
                sourceKind: .ambient,
                ownershipMode: .externalLocal
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
        XCTAssertEqual(items[0].lifecycleTitle, "Awaiting Refresh")
        XCTAssertEqual(items[0].capabilitySummary, "Auto-Switch, Desktop Handoff")
        XCTAssertEqual(items[0].sourceSummary, "Stored • External")
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
                sourceDescription: "Stored profile source",
                sourceKind: .backup,
                ownershipMode: .quotaPilotManaged
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
                sourceKind: .backup,
                ownershipMode: .quotaPilotManaged,
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
        XCTAssertEqual(item?.lifecycleTitle, "Ready")
        XCTAssertEqual(item?.capabilitySummary, "Usage, Recommend, Auto-Switch, Desktop Handoff")
        XCTAssertEqual(item?.sourceSummary, "Backup • Managed")
        XCTAssertEqual(item?.lastRefreshSummary, "Updated 1 min ago")
        XCTAssertEqual(item?.lastErrorDetail, "Codex usage request failed with HTTP 401.")
    }

    func testDowngradesCapabilitiesWhenAuthIsExpired() {
        let discoveredProfiles = [
            DiscoveredLocalProfile(
                provider: .claude,
                label: "Claude Team",
                email: nil,
                plan: "team",
                profileRootURL: URL(fileURLWithPath: "/Users/tester/.quotapilot/claude-team", isDirectory: true),
                credentialsURL: URL(fileURLWithPath: "/Users/tester/.quotapilot/claude-team/.credentials.json"),
                sourceDescription: "Stored profile source",
                sourceKind: .stored,
                ownershipMode: .externalLocal
            )
        ]

        let items = TrackedProfileInventoryBuilder.makeItems(
            discoveredProfiles: discoveredProfiles,
            liveAccounts: [],
            failures: [
                AmbientUsageRefreshFailure(
                    provider: .claude,
                    profileLabel: "Claude Team",
                    profileRootPath: "/Users/tester/.quotapilot/claude-team",
                    detail: "Claude usage request failed with HTTP 401.",
                    kind: .requestFailed(statusCode: 401)
                )
            ],
            currentProfileRootPaths: [:]
        )

        let item = try? XCTUnwrap(items.first)
        XCTAssertEqual(item?.lifecycleTitle, "Auth Expired")
        XCTAssertEqual(item?.capabilitySummary, "Desktop Handoff")
    }

    func testSuggestsManagedBackupRestoreForBrokenCurrentProfile() {
        let discoveredProfiles = [
            DiscoveredLocalProfile(
                provider: .codex,
                label: "Codex Current",
                email: nil,
                plan: "pro",
                profileRootURL: URL(fileURLWithPath: "/Users/tester/.codex", isDirectory: true),
                credentialsURL: URL(fileURLWithPath: "/Users/tester/.codex/auth.json"),
                sourceDescription: "Ambient profile",
                sourceKind: .ambient,
                ownershipMode: .externalLocal
            ),
            DiscoveredLocalProfile(
                provider: .codex,
                label: "Codex Ambient Backup",
                email: nil,
                plan: "pro",
                profileRootURL: URL(fileURLWithPath: "/Users/tester/Library/Application Support/QuotaPilot/profile-backups/codex/ambient-backup", isDirectory: true),
                credentialsURL: URL(fileURLWithPath: "/Users/tester/Library/Application Support/QuotaPilot/profile-backups/codex/ambient-backup/auth.json"),
                sourceDescription: "QuotaPilot backup profile",
                sourceKind: .backup,
                ownershipMode: .quotaPilotManaged
            ),
        ]

        let items = TrackedProfileInventoryBuilder.makeItems(
            discoveredProfiles: discoveredProfiles,
            liveAccounts: [],
            failures: [
                AmbientUsageRefreshFailure(
                    provider: .codex,
                    profileLabel: "Codex Current",
                    profileRootPath: "/Users/tester/.codex",
                    detail: "Codex usage request failed with HTTP 401.",
                    kind: .requestFailed(statusCode: 401)
                )
            ],
            currentProfileRootPaths: [.codex: "/Users/tester/.codex"]
        )

        let currentItem = items.first(where: { $0.profileRootPath == "/Users/tester/.codex" })
        XCTAssertEqual(currentItem?.recoveryActionKind, .restoreManagedBackup)
        XCTAssertEqual(currentItem?.recoveryActionTitle, "Restore Codex Ambient Backup")
        XCTAssertEqual(
            currentItem?.recoveryActionTargetProfileRootPath,
            "/Users/tester/Library/Application Support/QuotaPilot/profile-backups/codex/ambient-backup"
        )
    }
}
