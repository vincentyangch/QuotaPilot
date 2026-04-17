import XCTest
@testable import QuotaPilotCore

final class ProviderHealthSummaryBuilderTests: XCTestCase {
    func testMarksProviderHealthyWhenProfilesLoadWithoutFailures() {
        let summaries = ProviderHealthSummaryBuilder.makeSummaries(
            discoveredProfiles: [self.makeProfile(provider: .codex, label: "Codex Work", rootPath: "/tmp/codex-work")],
            liveAccounts: [
                QuotaAccount.codex(
                    label: "Codex Work",
                    remainingPercent: 70,
                    resetHours: 2,
                    priority: 80,
                    isCurrent: true,
                    profileRootPath: "/tmp/codex-work"
                )
            ],
            failures: []
        )

        XCTAssertEqual(summaries.first(where: { $0.provider == .codex })?.state, .healthy)
    }

    func testMarksProviderDegradedWhenSomeProfilesFail() {
        let summaries = ProviderHealthSummaryBuilder.makeSummaries(
            discoveredProfiles: [
                self.makeProfile(provider: .claude, label: "Claude Free", rootPath: "/tmp/claude-free"),
                self.makeProfile(provider: .claude, label: "Claude Max", rootPath: "/tmp/claude-max"),
            ],
            liveAccounts: [
                QuotaAccount.claude(
                    label: "Claude Free",
                    remainingPercent: 55,
                    resetHours: 4,
                    priority: 40,
                    isCurrent: true,
                    profileRootPath: "/tmp/claude-free"
                )
            ],
            failures: [
                AmbientUsageRefreshFailure(
                    provider: .claude,
                    profileLabel: "Claude Max",
                    detail: "Claude usage request failed with HTTP 401.",
                    kind: .requestFailed(statusCode: 401)
                )
            ]
        )

        let summary = summaries.first(where: { $0.provider == .claude })
        XCTAssertEqual(summary?.state, .degraded)
        XCTAssertEqual(summary?.manualAction, "Reauthenticate Claude locally, then retry.")
    }

    func testMarksProviderNotConfiguredWhenNoProfilesAreDiscovered() {
        let summaries = ProviderHealthSummaryBuilder.makeSummaries(
            discoveredProfiles: [],
            liveAccounts: [],
            failures: []
        )

        XCTAssertEqual(summaries.first(where: { $0.provider == .codex })?.state, .notConfigured)
        XCTAssertEqual(summaries.first(where: { $0.provider == .claude })?.state, .notConfigured)
    }

    private func makeProfile(provider: QuotaProvider, label: String, rootPath: String) -> DiscoveredLocalProfile {
        let rootURL = URL(fileURLWithPath: rootPath, isDirectory: true)
        return DiscoveredLocalProfile(
            provider: provider,
            label: label,
            email: nil,
            plan: nil,
            profileRootURL: rootURL,
            credentialsURL: rootURL.appendingPathComponent("credentials"),
            sourceDescription: "Test"
        )
    }
}
