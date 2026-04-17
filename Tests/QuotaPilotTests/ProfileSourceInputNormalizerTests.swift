import XCTest
@testable import QuotaPilotCore

final class ProfileSourceInputNormalizerTests: XCTestCase {
    func testUsesLastPathComponentWhenLabelIsBlank() {
        let result = ProfileSourceInputNormalizer.normalize(
            provider: .codex,
            label: "   ",
            path: " /Users/tester/.quotapilot/codex-work/ "
        )

        XCTAssertEqual(result?.provider, .codex)
        XCTAssertEqual(result?.label, "codex-work")
        XCTAssertEqual(result?.normalizedPath, "/Users/tester/.quotapilot/codex-work")
    }

    func testPreservesCustomLabelAndNormalizesPath() {
        let result = ProfileSourceInputNormalizer.normalize(
            provider: .claude,
            label: "Claude Alt",
            path: "/Users/tester/../tester/.quotapilot/claude-alt"
        )

        XCTAssertEqual(result?.provider, .claude)
        XCTAssertEqual(result?.label, "Claude Alt")
        XCTAssertEqual(result?.normalizedPath, "/Users/tester/.quotapilot/claude-alt")
    }

    func testReturnsNilForEmptyPath() {
        let result = ProfileSourceInputNormalizer.normalize(
            provider: .codex,
            label: "Codex",
            path: "   "
        )

        XCTAssertNil(result)
    }
}
