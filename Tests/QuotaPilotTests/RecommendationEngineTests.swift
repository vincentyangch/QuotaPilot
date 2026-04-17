import XCTest
@testable import QuotaPilotCore

final class RecommendationEngineTests: XCTestCase {
    func testBuildsSeparateRecommendationsForEachProvider() throws {
        let currentCodex = QuotaAccount.codex(
            label: "Codex Active",
            remainingPercent: 10,
            resetHours: 4,
            priority: 30,
            isCurrent: true
        )
        let backupCodex = QuotaAccount.codex(
            label: "Codex Backup",
            remainingPercent: 70,
            resetHours: 2,
            priority: 90,
            isCurrent: false
        )
        let currentClaude = QuotaAccount.claude(
            label: "Claude Active",
            remainingPercent: 62,
            resetHours: 1,
            priority: 80,
            isCurrent: true
        )
        let backupClaude = QuotaAccount.claude(
            label: "Claude Backup",
            remainingPercent: 64,
            resetHours: 1,
            priority: 81,
            isCurrent: false
        )

        let recommendations = RecommendationEngine().recommendationsByProvider(
            accounts: [currentCodex, backupCodex, currentClaude, backupClaude],
            rules: .default
        )

        XCTAssertEqual(recommendations.map(\.provider), [.codex, .claude])

        let codexRecommendation = try XCTUnwrap(recommendations.first(where: { $0.provider == .codex }))
        XCTAssertEqual(codexRecommendation.decision.recommendedAccountID, backupCodex.id)
        XCTAssertEqual(codexRecommendation.decision.action, .recommendSwitch)

        let claudeRecommendation = try XCTUnwrap(recommendations.first(where: { $0.provider == .claude }))
        XCTAssertEqual(claudeRecommendation.decision.recommendedAccountID, currentClaude.id)
        XCTAssertEqual(claudeRecommendation.decision.action, .stayCurrent)
    }

    func testPrefersAccountWithHigherCompositeScoreWhenCurrentDropsBelowThreshold() {
        let current = QuotaAccount.codex(
            label: "Codex A",
            remainingPercent: 12,
            resetHours: 4,
            priority: 20,
            isCurrent: true
        )
        let next = QuotaAccount.claude(
            label: "Claude B",
            remainingPercent: 64,
            resetHours: 2,
            priority: 80,
            isCurrent: false
        )

        let decision = RecommendationEngine().evaluate(
            accounts: [current, next],
            rules: .default
        )

        XCTAssertEqual(decision.recommendedAccountID, next.id)
        XCTAssertEqual(decision.action, .recommendSwitch)
    }

    func testKeepsCurrentAccountWhenNoAlternativeClearsMinimumAdvantage() {
        let current = QuotaAccount.codex(
            label: "Codex A",
            remainingPercent: 48,
            resetHours: 3,
            priority: 60,
            isCurrent: true
        )
        let next = QuotaAccount.codex(
            label: "Codex B",
            remainingPercent: 50,
            resetHours: 3,
            priority: 60,
            isCurrent: false
        )

        let decision = RecommendationEngine().evaluate(
            accounts: [current, next],
            rules: .default
        )

        XCTAssertEqual(decision.recommendedAccountID, current.id)
        XCTAssertEqual(decision.action, .stayCurrent)
    }
}
