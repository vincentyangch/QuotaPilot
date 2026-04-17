import XCTest
@testable import QuotaPilotCore

final class ProfileActionLabelTests: XCTestCase {
    func testManagedBackupUsesRecoveryActionLabels() {
        let storedSource = StoredProfileSource(
            id: UUID(),
            provider: .codex,
            label: "Codex Ambient Backup",
            profileRootPath: "/tmp/codex-backup",
            isEnabled: true,
            addedAt: .now,
            sourceKind: .backup,
            ownershipMode: .quotaPilotManaged
        )

        let discovered = DiscoveredLocalProfile(
            provider: .codex,
            label: "Codex Ambient Backup",
            email: nil,
            plan: nil,
            profileRootURL: URL(fileURLWithPath: "/tmp/codex-backup", isDirectory: true),
            credentialsURL: URL(fileURLWithPath: "/tmp/codex-backup/auth.json"),
            sourceDescription: "QuotaPilot backup profile",
            sourceKind: .backup,
            ownershipMode: .quotaPilotManaged
        )

        let item = TrackedProfileInventoryItem(
            provider: .codex,
            label: "Codex Ambient Backup",
            email: nil,
            plan: nil,
            identitySummary: nil,
            profileRootPath: "/tmp/codex-backup",
            sourceDescription: "QuotaPilot backup profile",
            sourceKind: .backup,
            ownershipMode: .quotaPilotManaged,
            sourceSummary: "Backup • Managed",
            isCurrentSelection: false,
            hasLiveUsage: false,
            liveRemainingPercent: nil,
            lifecycleState: .awaitingRefresh,
            lifecycleTitle: "Awaiting Refresh",
            lifecycleDetail: nil,
            lifecycleNextAction: "Run Refresh Live Usage to evaluate this profile.",
            capabilitySummary: "Usage, Recommend, Auto-Switch, Desktop Handoff",
            lastRefreshSummary: nil,
            lastErrorDetail: nil,
            statusSummary: "Awaiting live refresh"
        )

        XCTAssertEqual(storedSource.removalActionTitle, "Delete Backup")
        XCTAssertEqual(storedSource.removalConfirmationTitle, "Delete managed backup?")
        XCTAssertEqual(
            storedSource.removalConfirmationDetail,
            "QuotaPilot will permanently delete Codex Ambient Backup from its managed backup storage."
        )
        XCTAssertEqual(discovered.activationActionTitle, "Restore Backup")
        XCTAssertEqual(item.activationActionTitle, "Restore Backup")
        XCTAssertEqual(item.deletionConfirmationTitle, "Delete managed backup?")
        XCTAssertEqual(
            item.deletionConfirmationDetail,
            "QuotaPilot will permanently delete Codex Ambient Backup from its managed backup storage."
        )
    }

    func testExternalProfilesKeepStandardActionLabels() {
        let storedSource = StoredProfileSource(
            id: UUID(),
            provider: .claude,
            label: "Claude Work",
            profileRootPath: "/tmp/claude-work",
            isEnabled: true,
            addedAt: .now,
            sourceKind: .stored,
            ownershipMode: .externalLocal
        )

        let discovered = DiscoveredLocalProfile(
            provider: .claude,
            label: "Claude Work",
            email: nil,
            plan: "max",
            profileRootURL: URL(fileURLWithPath: "/tmp/claude-work", isDirectory: true),
            credentialsURL: URL(fileURLWithPath: "/tmp/claude-work/.credentials.json"),
            sourceDescription: "Stored profile source",
            sourceKind: .stored,
            ownershipMode: .externalLocal
        )

        let item = TrackedProfileInventoryItem(
            provider: .claude,
            label: "Claude Work",
            email: nil,
            plan: "max",
            identitySummary: "MAX",
            profileRootPath: "/tmp/claude-work",
            sourceDescription: "Stored profile source",
            sourceKind: .stored,
            ownershipMode: .externalLocal,
            sourceSummary: "Stored • External",
            isCurrentSelection: false,
            hasLiveUsage: true,
            liveRemainingPercent: 80,
            lifecycleState: .ready,
            lifecycleTitle: "Ready",
            lifecycleDetail: "Live usage is available for this profile.",
            lifecycleNextAction: "QuotaPilot will keep refreshing this profile automatically.",
            capabilitySummary: "Usage, Recommend, Auto-Switch, Desktop Handoff",
            lastRefreshSummary: "Updated just now",
            lastErrorDetail: nil,
            statusSummary: "80% remaining"
        )

        XCTAssertEqual(storedSource.removalActionTitle, "Remove")
        XCTAssertEqual(storedSource.removalConfirmationTitle, "Remove stored profile source?")
        XCTAssertEqual(
            storedSource.removalConfirmationDetail,
            "QuotaPilot will stop tracking Claude Work, but it will not modify the provider credentials at that path."
        )
        XCTAssertEqual(discovered.activationActionTitle, "Activate")
        XCTAssertEqual(item.activationActionTitle, "Activate")
    }
}
