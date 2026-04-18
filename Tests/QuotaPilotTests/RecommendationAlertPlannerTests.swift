import XCTest
@testable import QuotaPilotCore

final class RecommendationAlertPlannerTests: XCTestCase {
    func testBuildsCandidateForGlobalRecommendSwitchDecision() {
        let current = QuotaAccount.codex(
            label: "current@example.com",
            remainingPercent: 8,
            resetHours: 4,
            priority: 60,
            isCurrent: true
        )
        let recommended = QuotaAccount.codex(
            label: "better@example.com",
            remainingPercent: 80,
            resetHours: 1,
            priority: 80,
            isCurrent: false
        )

        let recommendation = RecommendationEngine.GlobalRecommendation(
            rankedAccounts: [
                .init(account: recommended, score: 300),
                .init(account: current, score: 120),
            ],
            decision: RecommendationDecision(
                currentAccountID: current.id,
                recommendedAccountID: recommended.id,
                action: .recommendSwitch,
                currentScore: 120,
                recommendedScore: 300,
                explanation: "better@example.com is materially better."
            )
        )

        let candidate = RecommendationAlertPlanner.makeCandidate(recommendation: recommendation)

        XCTAssertEqual(candidate?.provider, .codex)
        XCTAssertEqual(candidate?.title, "Switch to better@example.com")
        XCTAssertEqual(
            candidate?.body,
            "better@example.com is currently the best next account instead of current@example.com."
        )
        XCTAssertEqual(
            candidate?.identifier,
            "\(current.id.uuidString):\(recommended.id.uuidString)"
        )
    }

    func testSkipsStayCurrentDecision() {
        let current = QuotaAccount.claude(
            label: "Claude Free",
            remainingPercent: 45,
            resetHours: 3,
            priority: 40,
            isCurrent: true
        )

        let recommendation = RecommendationEngine.GlobalRecommendation(
            rankedAccounts: [.init(account: current, score: 180)],
            decision: RecommendationDecision(
                currentAccountID: current.id,
                recommendedAccountID: current.id,
                action: .stayCurrent,
                currentScore: 180,
                recommendedScore: 180,
                explanation: "Claude Free remains best."
            )
        )

        XCTAssertNil(RecommendationAlertPlanner.makeCandidate(recommendation: recommendation))
    }
}
