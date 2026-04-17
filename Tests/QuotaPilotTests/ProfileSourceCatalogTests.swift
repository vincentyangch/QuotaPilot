import XCTest
@testable import QuotaPilotCore

final class ProfileSourceCatalogTests: XCTestCase {
    func testBuildsAmbientAndStoredCandidates() {
        let home = URL(fileURLWithPath: "/Users/tester", isDirectory: true)
        let sources = [
            StoredProfileSource(
                id: UUID(uuidString: "A63D8C9A-FE20-49DE-9145-980D858A6A01") ?? UUID(),
                provider: .codex,
                label: "Codex Sidecar",
                profileRootPath: "/Users/tester/.quotapilot/codex-sidecar",
                isEnabled: true,
                addedAt: .now
            ),
            StoredProfileSource(
                id: UUID(uuidString: "A63D8C9A-FE20-49DE-9145-980D858A6A02") ?? UUID(),
                provider: .claude,
                label: "Claude Sidecar",
                profileRootPath: "/Users/tester/.quotapilot/claude-sidecar",
                isEnabled: true,
                addedAt: .now
            ),
        ]

        let candidates = ProfileSourceCatalog.makeCandidates(homeURL: home, storedSources: sources)

        XCTAssertEqual(candidates.count, 4)
        XCTAssertTrue(candidates.contains(where: { $0.provider == .codex && $0.profileRootURL.path == "/Users/tester/.codex" }))
        XCTAssertTrue(candidates.contains(where: { $0.provider == .claude && $0.profileRootURL.path == "/Users/tester/.claude" }))
        XCTAssertTrue(candidates.contains(where: { $0.provider == .codex && $0.profileRootURL.path == "/Users/tester/.quotapilot/codex-sidecar" }))
        XCTAssertTrue(candidates.contains(where: { $0.provider == .claude && $0.profileRootURL.path == "/Users/tester/.quotapilot/claude-sidecar" }))
    }

    func testIgnoresDisabledOrDuplicateStoredSources() {
        let home = URL(fileURLWithPath: "/Users/tester", isDirectory: true)
        let sources = [
            StoredProfileSource(
                id: UUID(),
                provider: .codex,
                label: "Duplicate Ambient",
                profileRootPath: "/Users/tester/.codex",
                isEnabled: true,
                addedAt: .now
            ),
            StoredProfileSource(
                id: UUID(),
                provider: .claude,
                label: "Disabled Claude",
                profileRootPath: "/Users/tester/custom-claude",
                isEnabled: false,
                addedAt: .now
            ),
        ]

        let candidates = ProfileSourceCatalog.makeCandidates(homeURL: home, storedSources: sources)

        XCTAssertEqual(candidates.filter { $0.provider == .codex }.count, 1)
        XCTAssertFalse(candidates.contains(where: { $0.profileRootURL.path == "/Users/tester/custom-claude" }))
    }
}
