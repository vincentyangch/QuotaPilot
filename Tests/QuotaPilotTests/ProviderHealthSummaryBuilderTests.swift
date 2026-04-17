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
        XCTAssertEqual(summary?.affectedProfilesSummary, "Affected profile: Claude Max")
        XCTAssertEqual(
            summary?.recoveryItems,
            ["Claude Max: Reauthenticate locally, then refresh."]
        )
        XCTAssertEqual(summary?.manualAction, "Review the affected profiles below, then refresh again.")
    }

    func testBuildsRecoveryChecklistForMultipleAffectedProfiles() {
        let summaries = ProviderHealthSummaryBuilder.makeSummaries(
            discoveredProfiles: [
                self.makeProfile(provider: .codex, label: "Codex A", rootPath: "/tmp/codex-a"),
                self.makeProfile(provider: .codex, label: "Codex B", rootPath: "/tmp/codex-b"),
            ],
            liveAccounts: [],
            failures: [
                AmbientUsageRefreshFailure(
                    provider: .codex,
                    profileLabel: "Codex A",
                    detail: "Missing credentials.",
                    kind: .invalidCredentials
                ),
                AmbientUsageRefreshFailure(
                    provider: .codex,
                    profileLabel: "Codex B",
                    detail: "No usage data returned.",
                    kind: .noUsageData
                ),
            ]
        )

        let summary = summaries.first(where: { $0.provider == .codex })
        XCTAssertEqual(summary?.state, .unavailable)
        XCTAssertEqual(summary?.affectedProfilesSummary, "Affected profiles: Codex A, Codex B")
        XCTAssertEqual(
            summary?.recoveryItems,
            [
                "Codex A: Repair or restore the local credentials, then refresh.",
                "Codex B: Open the local app or CLI to renew its session, then refresh.",
            ]
        )
        XCTAssertEqual(summary?.manualAction, "Work through the affected profiles below, then retry refresh.")
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
