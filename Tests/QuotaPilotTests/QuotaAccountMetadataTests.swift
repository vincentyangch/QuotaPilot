import XCTest
@testable import QuotaPilotCore

final class QuotaAccountMetadataTests: XCTestCase {
    func testBuildsIdentitySummaryAndCapabilityLabelsForLocalAccount() {
        let account = QuotaAccount.codex(
            label: "Codex Work",
            remainingPercent: 72,
            resetHours: 2,
            priority: 80,
            isCurrent: true,
            profileRootPath: "/tmp/codex-work",
            sourceDescription: "Stored profile source",
            email: "work@example.com",
            plan: "pro",
            workspaceLabel: "Personal Workspace"
        )

        XCTAssertEqual(account.identitySummary, "work@example.com • PRO • Personal Workspace")
        XCTAssertEqual(account.capabilityLabels, ["Usage", "Recommend", "Auto-Switch", "Handoff"])
    }

    func testPrefersOrganizationWhenWorkspaceIsMissing() {
        let account = QuotaAccount.claude(
            label: "Claude Team",
            remainingPercent: 61,
            resetHours: 5,
            priority: 85,
            isCurrent: false,
            profileRootPath: "/tmp/claude-team",
            sourceDescription: "Ambient local profile",
            email: nil,
            plan: "team",
            organizationLabel: "Design Org"
        )

        XCTAssertEqual(account.identitySummary, "TEAM • Design Org")
    }
}
