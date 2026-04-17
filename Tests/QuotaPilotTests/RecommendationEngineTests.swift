import XCTest
@testable import QuotaPilotCore

final class RecommendationEngineTests: XCTestCase {
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
