import XCTest
@testable import QuotaPilotCore

final class SwitchActionPlannerTests: XCTestCase {
    func testReturnsAutoActivationForNewCandidateInAutoMode() {
        let option = RecommendationActivationOption(
            provider: .codex,
            accountID: UUID(uuidString: "00000000-0000-0000-0000-000000000001") ?? UUID(),
            accountLabel: "Codex Work",
            profileRootPath: "/tmp/codex-work",
            status: .activatable,
            reason: "Ready"
        )
        let candidate = RecommendationAlertCandidate(
            provider: .codex,
            identifier: "codex:a:b",
            title: "Switch Codex account",
            body: "Codex Work is better."
        )

        let plan = SwitchActionPlanner.makePlan(
            mode: .autoActivateLocalProfiles,
            activationOptionsByProvider: [.codex: option],
            recommendationCandidatesByProvider: [.codex: candidate],
            handledRecommendationIDsByProvider: [:],
            pendingConfirmationIDsByProvider: [:]
        )

        XCTAssertEqual(plan.automaticActivations, [option])
        XCTAssertTrue(plan.confirmationsToPresent.isEmpty)
    }

    func testReturnsConfirmationForNewCandidateInConfirmMode() {
        let option = RecommendationActivationOption(
            provider: .claude,
            accountID: UUID(uuidString: "00000000-0000-0000-0000-000000000002") ?? UUID(),
            accountLabel: "Claude Max",
            profileRootPath: "/tmp/claude-max",
            status: .activatable,
            reason: "Ready"
        )
        let candidate = RecommendationAlertCandidate(
            provider: .claude,
            identifier: "claude:c:d",
            title: "Switch Claude account",
            body: "Claude Max is better."
        )

        let plan = SwitchActionPlanner.makePlan(
            mode: .confirmBeforeActivatingLocalProfiles,
            activationOptionsByProvider: [.claude: option],
            recommendationCandidatesByProvider: [.claude: candidate],
            handledRecommendationIDsByProvider: [:],
            pendingConfirmationIDsByProvider: [:]
        )

        XCTAssertTrue(plan.automaticActivations.isEmpty)
        XCTAssertEqual(plan.confirmationsToPresent, [option])
    }

    func testDoesNotRepeatConfirmationWhenSameCandidateAlreadyPending() {
        let option = RecommendationActivationOption(
            provider: .claude,
            accountID: UUID(uuidString: "00000000-0000-0000-0000-000000000003") ?? UUID(),
            accountLabel: "Claude Team",
            profileRootPath: "/tmp/claude-team",
            status: .activatable,
            reason: "Ready"
        )
        let candidate = RecommendationAlertCandidate(
            provider: .claude,
            identifier: "claude:pending",
            title: "Switch Claude account",
            body: "Claude Team is better."
        )

        let plan = SwitchActionPlanner.makePlan(
            mode: .confirmBeforeActivatingLocalProfiles,
            activationOptionsByProvider: [.claude: option],
            recommendationCandidatesByProvider: [.claude: candidate],
            handledRecommendationIDsByProvider: [:],
            pendingConfirmationIDsByProvider: [.claude: "claude:pending"]
        )

        XCTAssertTrue(plan.automaticActivations.isEmpty)
        XCTAssertTrue(plan.confirmationsToPresent.isEmpty)
    }
}
