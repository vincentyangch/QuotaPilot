import XCTest
@testable import QuotaPilotCore

final class AutomaticActivationVerifierTests: XCTestCase {
    func testReturnsNilWhenActivatedProfileIsPresentAndCurrentInFreshAccounts() {
        let option = RecommendationActivationOption(
            provider: .codex,
            accountID: UUID(),
            accountLabel: "Codex Work",
            profileRootPath: "/tmp/codex-work",
            isActivatable: true,
            reason: "Ready"
        )

        let refreshedAccounts = [
            QuotaAccount.codex(
                label: "Codex Work",
                remainingPercent: 72,
                resetHours: 2,
                priority: 90,
                isCurrent: true,
                profileRootPath: "/tmp/codex-work"
            )
        ]

        XCTAssertNil(
            AutomaticActivationVerifier.verify(
                option: option,
                refreshedAccounts: refreshedAccounts
            )
        )
    }

    func testReturnsRecoveryIssueWhenActivatedProfileIsMissingFromFreshAccounts() {
        let option = RecommendationActivationOption(
            provider: .claude,
            accountID: UUID(),
            accountLabel: "Claude Max",
            profileRootPath: "/tmp/claude-max",
            isActivatable: true,
            reason: "Ready"
        )

        let issue = AutomaticActivationVerifier.verify(
            option: option,
            refreshedAccounts: []
        )

        XCTAssertEqual(issue?.provider, .claude)
        XCTAssertEqual(issue?.accountLabel, "Claude Max")
        XCTAssertEqual(issue?.profileRootPath, "/tmp/claude-max")
        XCTAssertEqual(
            issue?.detail,
            "QuotaPilot switched the local profile, but it could not verify fresh live usage for Claude Max afterward."
        )
    }

    func testReportsRecoveryResolvedWhenFreshAccountsContainMatchingCurrentProfile() {
        let issue = AutomaticActivationRecoveryIssue(
            provider: .claude,
            accountLabel: "Claude Max",
            profileRootPath: "/tmp/claude-max",
            detail: "Recovery needed."
        )

        let refreshedAccounts = [
            QuotaAccount.claude(
                label: "Claude Max",
                remainingPercent: 66,
                resetHours: 4,
                priority: 85,
                isCurrent: true,
                profileRootPath: "/tmp/claude-max"
            )
        ]

        XCTAssertTrue(
            AutomaticActivationVerifier.isRecovered(
                issue: issue,
                refreshedAccounts: refreshedAccounts
            )
        )
    }

    func testKeepsRecoveryActiveWhenCurrentProfileDoesNotMatchRecoveryPath() {
        let issue = AutomaticActivationRecoveryIssue(
            provider: .codex,
            accountLabel: "Codex Work",
            profileRootPath: "/tmp/codex-work",
            detail: "Recovery needed."
        )

        let refreshedAccounts = [
            QuotaAccount.codex(
                label: "Codex Personal",
                remainingPercent: 80,
                resetHours: 2,
                priority: 70,
                isCurrent: true,
                profileRootPath: "/tmp/codex-personal"
            )
        ]

        XCTAssertFalse(
            AutomaticActivationVerifier.isRecovered(
                issue: issue,
                refreshedAccounts: refreshedAccounts
            )
        )
    }
}
