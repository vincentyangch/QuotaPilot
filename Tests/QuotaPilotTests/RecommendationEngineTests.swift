import XCTest
@testable import QuotaPilotCore

final class RecommendationEngineTests: XCTestCase {
    func testBuildsSingleGlobalRecommendationAcrossProviders() throws {
        let currentCodex = QuotaAccount.codex(
            label: "Codex Active",
            remainingPercent: 80,
            resetHours: 2,
            priority: 80,
            isCurrent: true
        )
        let currentClaude = QuotaAccount.claude(
            label: "Claude Active",
            remainingPercent: 5,
            resetHours: 5,
            priority: 10,
            isCurrent: true
        )
        let backupClaude = QuotaAccount.claude(
            label: "Claude Max",
            remainingPercent: 75,
            resetHours: 1,
            priority: 60,
            isCurrent: false
        )

        let recommendation = try XCTUnwrap(
            RecommendationEngine().globalRecommendation(
                accounts: [currentCodex, currentClaude, backupClaude],
                rules: .default
            )
        )

        XCTAssertEqual(recommendation.currentAccount?.id, currentClaude.id)
        XCTAssertEqual(recommendation.recommendedAccount?.id, currentCodex.id)
        XCTAssertEqual(recommendation.decision.action, .recommendSwitch)
        XCTAssertTrue(recommendation.decision.explanation.contains("Codex Active"))
        XCTAssertTrue(recommendation.decision.explanation.contains("Claude Active"))
    }

    func testKeepsBestCurrentAccountWhenGlobalThresholdIsNotMet() throws {
        let currentCodex = QuotaAccount.codex(
            label: "Codex Active",
            remainingPercent: 42,
            resetHours: 3,
            priority: 80,
            isCurrent: true
        )
        let backupClaude = QuotaAccount.claude(
            label: "Claude Backup",
            remainingPercent: 90,
            resetHours: 1,
            priority: 85,
            isCurrent: false
        )

        let recommendation = try XCTUnwrap(
            RecommendationEngine().globalRecommendation(
                accounts: [currentCodex, backupClaude],
                rules: .default
            )
        )

        XCTAssertEqual(recommendation.currentAccount?.id, currentCodex.id)
        XCTAssertEqual(recommendation.recommendedAccount?.id, currentCodex.id)
        XCTAssertEqual(recommendation.decision.action, .stayCurrent)
    }

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
