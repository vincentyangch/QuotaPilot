import XCTest
@testable import QuotaPilotCore

final class GuidedDesktopHandoffPlannerTests: XCTestCase {
    func testReturnsNilWhenRecommendationIsActivatable() {
        let recommendation = self.makeRecommendation(
            provider: .codex,
            current: .codex(
                label: "Current",
                remainingPercent: 10,
                resetHours: 4,
                priority: 50,
                isCurrent: true,
                profileRootPath: "/Users/tester/.codex"
            ),
            recommended: .codex(
                label: "Better",
                remainingPercent: 80,
                resetHours: 1,
                priority: 80,
                isCurrent: false,
                profileRootPath: "/Users/tester/.quotapilot/codex-better"
            )
        )
        let activationOption = RecommendationActivationOption(
            provider: .codex,
            accountID: UUID(),
            accountLabel: "Better",
            profileRootPath: "/Users/tester/.quotapilot/codex-better",
            status: .activatable,
            reason: "Ready"
        )

        let plan = GuidedDesktopHandoffPlanner.makePlan(
            recommendation: recommendation,
            activationOption: activationOption,
            switchActionMode: .autoActivateLocalProfiles
        )

        XCTAssertNil(plan)
    }

    func testBuildsSettingsGuidedPlanForUnavailableProfile() throws {
        let recommendation = self.makeRecommendation(
            provider: .claude,
            current: .claude(
                label: "Claude Free",
                remainingPercent: 5,
                resetHours: 6,
                priority: 40,
                isCurrent: true,
                profileRootPath: "/Users/tester/.claude"
            ),
            recommended: .claude(
                label: "Claude Max",
                remainingPercent: 80,
                resetHours: 1,
                priority: 90,
                isCurrent: false,
                profileRootPath: "/Users/tester/.quotapilot/claude-max"
            )
        )
        let activationOption = RecommendationActivationOption(
            provider: .claude,
            accountID: UUID(),
            accountLabel: "Claude Max",
            profileRootPath: "/Users/tester/.quotapilot/claude-max",
            status: .unavailableOnThisMac,
            reason: "Not discovered"
        )

        let plan = try XCTUnwrap(
            GuidedDesktopHandoffPlanner.makePlan(
                recommendation: recommendation,
                activationOption: activationOption,
                switchActionMode: .autoActivateLocalProfiles
            )
        )

        XCTAssertEqual(plan.provider, .claude)
        XCTAssertEqual(plan.accountLabel, "Claude Max")
        XCTAssertEqual(plan.targetProfileRootPath, "/Users/tester/.quotapilot/claude-max")
        XCTAssertTrue(plan.suggestsOpeningSettings)
        XCTAssertEqual(plan.steps.count, 3)
        XCTAssertEqual(
            plan.nextAutomaticAction,
            "QuotaPilot will keep monitoring and auto-activate once the target profile becomes locally available and verifiable."
        )
    }

    func testBuildsGenericMonitoringPlanWhenNoActivationOptionExists() throws {
        let recommendation = self.makeRecommendation(
            provider: .codex,
            current: .codex(
                label: "Current",
                remainingPercent: 8,
                resetHours: 6,
                priority: 50,
                isCurrent: true,
                profileRootPath: "/Users/tester/.codex"
            ),
            recommended: QuotaAccount(
                id: UUID(),
                provider: .codex,
                label: "Detached",
                priority: 90,
                isCurrent: false,
                profileRootPath: nil,
                sourceDescription: "Test",
                windows: [
                    UsageWindow(
                        id: "session",
                        title: "Session",
                        remainingPercent: 75,
                        resetsAt: .now.addingTimeInterval(3600)
                    )
                ]
            )
        )

        let plan = try XCTUnwrap(
            GuidedDesktopHandoffPlanner.makePlan(
                recommendation: recommendation,
                activationOption: nil,
                switchActionMode: .recommendOnly
            )
        )

        XCTAssertFalse(plan.suggestsOpeningSettings)
        XCTAssertNil(plan.targetProfileRootPath)
        XCTAssertEqual(plan.steps.count, 2)
        XCTAssertEqual(
            plan.nextAutomaticAction,
            "QuotaPilot will keep monitoring and recommending the best account, but it will not switch automatically."
        )
    }

    private func makeRecommendation(
        provider: QuotaProvider,
        current: QuotaAccount,
        recommended: QuotaAccount
    ) -> RecommendationEngine.ProviderRecommendation {
        RecommendationEngine.ProviderRecommendation(
            provider: provider,
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
                explanation: "\(recommended.label) is materially better."
            )
        )
    }
}
