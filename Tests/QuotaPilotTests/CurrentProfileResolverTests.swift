import XCTest
@testable import QuotaPilotCore

final class CurrentProfileResolverTests: XCTestCase {
    func testUsesExplicitSelectionWhenItMatchesADiscoveredProfile() {
        let profiles = [
            DiscoveredLocalProfile(
                provider: .codex,
                label: "Ambient Codex",
                email: "a@example.com",
                plan: "pro",
                profileRootURL: URL(fileURLWithPath: "/Users/tester/.codex", isDirectory: true),
                credentialsURL: URL(fileURLWithPath: "/Users/tester/.codex/auth.json"),
                sourceDescription: "Ambient local profile"
            ),
            DiscoveredLocalProfile(
                provider: .codex,
                label: "Work Codex",
                email: "b@example.com",
                plan: "pro",
                profileRootURL: URL(fileURLWithPath: "/Users/tester/.quotapilot/codex-work", isDirectory: true),
                credentialsURL: URL(fileURLWithPath: "/Users/tester/.quotapilot/codex-work/auth.json"),
                sourceDescription: "Stored profile source"
            ),
        ]

        let resolved = CurrentProfileResolver.resolve(
            discoveredProfiles: profiles,
            preferredSelections: [.codex: "/Users/tester/.quotapilot/codex-work"]
        )

        XCTAssertEqual(resolved[.codex], "/Users/tester/.quotapilot/codex-work")
    }

    func testFallsBackToFirstDiscoveredProfileWhenSelectionIsMissing() {
        let profiles = [
            DiscoveredLocalProfile(
                provider: .claude,
                label: "Claude Ambient",
                email: nil,
                plan: "free",
                profileRootURL: URL(fileURLWithPath: "/Users/tester/.claude", isDirectory: true),
                credentialsURL: URL(fileURLWithPath: "/Users/tester/.claude/.credentials.json"),
                sourceDescription: "Ambient local profile"
            ),
            DiscoveredLocalProfile(
                provider: .claude,
                label: "Claude Alt",
                email: nil,
                plan: "max",
                profileRootURL: URL(fileURLWithPath: "/Users/tester/.quotapilot/claude-max", isDirectory: true),
                credentialsURL: URL(fileURLWithPath: "/Users/tester/.quotapilot/claude-max/.credentials.json"),
                sourceDescription: "Stored profile source"
            ),
        ]

        let resolved = CurrentProfileResolver.resolve(
            discoveredProfiles: profiles,
            preferredSelections: [:]
        )

        XCTAssertEqual(resolved[.claude], "/Users/tester/.claude")
    }
}
