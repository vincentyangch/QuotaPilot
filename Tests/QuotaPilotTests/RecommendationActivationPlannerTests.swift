import XCTest
@testable import QuotaPilotCore

final class RecommendationActivationPlannerTests: XCTestCase {
    func testReturnsActivatableOptionWhenRecommendedProfileIsDiscoveredLocally() {
        let current = QuotaAccount.codex(
            label: "current@example.com",
            remainingPercent: 10,
            resetHours: 4,
            priority: 60,
            isCurrent: true,
            profileRootPath: "/Users/tester/.codex"
        )
        let recommended = QuotaAccount.codex(
            label: "better@example.com",
            remainingPercent: 80,
            resetHours: 1,
            priority: 80,
            isCurrent: false,
            profileRootPath: "/Users/tester/.quotapilot/codex-better"
        )

        let recommendation = RecommendationEngine.ProviderRecommendation(
            provider: .codex,
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

        let option = RecommendationActivationPlanner.makeOption(
            recommendation: recommendation,
            discoveredProfiles: [
                self.makeCodexProfile(
                    label: "better@example.com",
                    rootPath: "/Users/tester/.quotapilot/codex-better"
                )
            ],
            currentProfileRootPaths: [.codex: "/Users/tester/.codex"]
        )

        XCTAssertEqual(option?.provider, .codex)
        XCTAssertEqual(option?.profileRootPath, "/Users/tester/.quotapilot/codex-better")
        XCTAssertEqual(option?.accountLabel, "better@example.com")
        XCTAssertEqual(option?.reason, "Ready to activate the recommended profile.")
        XCTAssertEqual(option?.isActivatable, true)
    }

    func testReturnsNonActivatableOptionWhenRecommendedProfileIsNotDiscovered() {
        let current = QuotaAccount.claude(
            label: "Claude Free",
            remainingPercent: 8,
            resetHours: 5,
            priority: 40,
            isCurrent: true,
            profileRootPath: "/Users/tester/.claude"
        )
        let recommended = QuotaAccount.claude(
            label: "Claude Max",
            remainingPercent: 70,
            resetHours: 1,
            priority: 80,
            isCurrent: false,
            profileRootPath: "/Users/tester/.quotapilot/claude-max"
        )

        let recommendation = RecommendationEngine.ProviderRecommendation(
            provider: .claude,
            rankedAccounts: [
                .init(account: recommended, score: 280),
                .init(account: current, score: 90),
            ],
            decision: RecommendationDecision(
                currentAccountID: current.id,
                recommendedAccountID: recommended.id,
                action: .recommendSwitch,
                currentScore: 90,
                recommendedScore: 280,
                explanation: "Claude Max is materially better."
            )
        )

        let option = RecommendationActivationPlanner.makeOption(
            recommendation: recommendation,
            discoveredProfiles: [],
            currentProfileRootPaths: [.claude: "/Users/tester/.claude"]
        )

        XCTAssertEqual(option?.provider, .claude)
        XCTAssertEqual(option?.isActivatable, false)
        XCTAssertEqual(option?.reason, "The recommended profile is not currently discovered on this Mac.")
    }

    func testReturnsNilWhenNoSwitchIsRecommended() {
        let current = QuotaAccount.codex(
            label: "current@example.com",
            remainingPercent: 65,
            resetHours: 2,
            priority: 80,
            isCurrent: true,
            profileRootPath: "/Users/tester/.codex"
        )

        let recommendation = RecommendationEngine.ProviderRecommendation(
            provider: .codex,
            rankedAccounts: [
                .init(account: current, score: 220),
            ],
            decision: RecommendationDecision(
                currentAccountID: current.id,
                recommendedAccountID: current.id,
                action: .stayCurrent,
                currentScore: 220,
                recommendedScore: 220,
                explanation: "current@example.com remains best."
            )
        )

        let option = RecommendationActivationPlanner.makeOption(
            recommendation: recommendation,
            discoveredProfiles: [self.makeCodexProfile(label: "current@example.com", rootPath: "/Users/tester/.codex")],
            currentProfileRootPaths: [.codex: "/Users/tester/.codex"]
        )

        XCTAssertNil(option)
    }

    private func makeCodexProfile(label: String, rootPath: String) -> DiscoveredLocalProfile {
        let rootURL = URL(fileURLWithPath: rootPath, isDirectory: true)
        return DiscoveredLocalProfile(
            provider: .codex,
            label: label,
            email: label,
            plan: "pro",
            profileRootURL: rootURL,
            credentialsURL: rootURL.appendingPathComponent("auth.json"),
            sourceDescription: "Test"
        )
    }
}
