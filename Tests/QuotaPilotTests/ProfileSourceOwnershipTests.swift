import XCTest
@testable import QuotaPilotCore

final class ProfileSourceOwnershipTests: XCTestCase {
    func testAmbientCandidatesAreExternalAmbientSources() {
        let home = URL(fileURLWithPath: "/Users/tester", isDirectory: true)

        let candidates = ProfileSourceCatalog.makeCandidates(
            homeURL: home,
            storedSources: []
        )

        let codexAmbient = try? XCTUnwrap(candidates.first(where: { $0.provider == .codex }))
        XCTAssertEqual(codexAmbient?.sourceKind, .ambient)
        XCTAssertEqual(codexAmbient?.ownershipMode, .externalLocal)
    }

    func testStoredCandidatesRemainExternalStoredSources() {
        let home = URL(fileURLWithPath: "/Users/tester", isDirectory: true)
        let sources = [
            StoredProfileSource(
                id: UUID(),
                provider: .codex,
                label: "Codex Work",
                profileRootPath: "/Users/tester/.quotapilot/codex-work",
                isEnabled: true,
                addedAt: .now,
                sourceKind: .stored,
                ownershipMode: .externalLocal
            )
        ]

        let candidates = ProfileSourceCatalog.makeCandidates(
            homeURL: home,
            storedSources: sources
        )

        let storedCandidate = candidates.first(where: { $0.profileRootURL.path == "/Users/tester/.quotapilot/codex-work" })
        XCTAssertEqual(storedCandidate?.sourceKind, .stored)
        XCTAssertEqual(storedCandidate?.ownershipMode, .externalLocal)
    }
}
