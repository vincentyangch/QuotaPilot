import XCTest
@testable import QuotaPilotCore

final class LocalProfileDiscoveryTests: XCTestCase {
    func testDiscoversCodexProfileFromAuthJSON() throws {
        let root = try self.makeTemporaryDirectory()
        let profileRoot = root.appendingPathComponent("codex-work", isDirectory: true)
        try FileManager.default.createDirectory(at: profileRoot, withIntermediateDirectories: true)

        let payload = """
        {
          "email": "work@example.com",
          "https://api.openai.com/auth": {
            "chatgpt_plan_type": "pro"
          }
        }
        """
        let jwt = self.makeJWT(payloadJSON: payload)
        let authJSON = """
        {
          "tokens": {
            "access_token": "access",
            "refresh_token": "refresh",
            "id_token": "\(jwt)"
          }
        }
        """

        try authJSON.write(
            to: profileRoot.appendingPathComponent("auth.json"),
            atomically: true,
            encoding: .utf8
        )

        let profiles = LocalProfileDiscovery().discover(
            candidates: [
                .codex(
                    profileRootURL: profileRoot,
                    labelHint: "Codex Work",
                    sourceDescription: "Test"
                )
            ]
        )

        let discovered = try XCTUnwrap(profiles.first)
        XCTAssertEqual(discovered.provider, .codex)
        XCTAssertEqual(discovered.email, "work@example.com")
        XCTAssertEqual(discovered.plan, "pro")
        XCTAssertEqual(discovered.label, "work@example.com")
    }

    func testDiscoversClaudeProfileFromCredentialsFile() throws {
        let root = try self.makeTemporaryDirectory()
        let profileRoot = root.appendingPathComponent("claude-max", isDirectory: true)
        try FileManager.default.createDirectory(at: profileRoot, withIntermediateDirectories: true)

        let credentialsJSON = """
        {
          "claudeAiOauth": {
            "accessToken": "access",
            "refreshToken": "refresh",
            "expiresAt": 1893456000000,
            "rateLimitTier": "max"
          }
        }
        """

        try credentialsJSON.write(
            to: profileRoot.appendingPathComponent(".credentials.json"),
            atomically: true,
            encoding: .utf8
        )

        let profiles = LocalProfileDiscovery().discover(
            candidates: [
                .claude(
                    profileRootURL: profileRoot,
                    labelHint: "Claude Max",
                    sourceDescription: "Test"
                )
            ]
        )

        let discovered = try XCTUnwrap(profiles.first)
        XCTAssertEqual(discovered.provider, .claude)
        XCTAssertNil(discovered.email)
        XCTAssertEqual(discovered.plan, "max")
        XCTAssertEqual(discovered.label, "Claude Max")
    }

    func testDiscoversClaudeProfileFromKeychainWhenFileIsMissing() throws {
        let root = try self.makeTemporaryDirectory()
        let profileRoot = root.appendingPathComponent("claude-keychain", isDirectory: true)
        try FileManager.default.createDirectory(at: profileRoot, withIntermediateDirectories: true)

        let credentialsJSON = """
        {
          "claudeAiOauth": {
            "accessToken": "access",
            "refreshToken": "refresh",
            "expiresAt": 1893456000000,
            "rateLimitTier": "free"
          }
        }
        """

        let discovery = LocalProfileDiscovery(
            claudeKeychainProvider: StubClaudeKeychainCredentialProvider(data: Data(credentialsJSON.utf8))
        )

        let profiles = discovery.discover(
            candidates: [
                .claude(
                    profileRootURL: profileRoot,
                    labelHint: "Claude Ambient",
                    sourceDescription: "Test"
                )
            ]
        )

        let discovered = try XCTUnwrap(profiles.first)
        XCTAssertEqual(discovered.provider, .claude)
        XCTAssertEqual(discovered.plan, "free")
        XCTAssertEqual(discovered.label, "Claude Free")
        XCTAssertEqual(discovered.sourceDescription, "macOS Keychain")
    }

    func testSkipsMissingOrInvalidProfiles() throws {
        let root = try self.makeTemporaryDirectory()
        let invalidCodexRoot = root.appendingPathComponent("broken-codex", isDirectory: true)
        try FileManager.default.createDirectory(at: invalidCodexRoot, withIntermediateDirectories: true)
        try "{ invalid".write(
            to: invalidCodexRoot.appendingPathComponent("auth.json"),
            atomically: true,
            encoding: .utf8
        )

        let discovery = LocalProfileDiscovery(
            claudeKeychainProvider: StubClaudeKeychainCredentialProvider(data: nil)
        )

        let profiles = discovery.discover(
            candidates: [
                .codex(
                    profileRootURL: invalidCodexRoot,
                    labelHint: "Broken Codex",
                    sourceDescription: "Test"
                ),
                .claude(
                    profileRootURL: root.appendingPathComponent("missing-claude", isDirectory: true),
                    labelHint: "Missing Claude",
                    sourceDescription: "Test"
                )
            ]
        )

        XCTAssertTrue(profiles.isEmpty)
    }

    private func makeTemporaryDirectory() throws -> URL {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        return root
    }

    private func makeJWT(payloadJSON: String) -> String {
        let header = #"{"alg":"none","typ":"JWT"}"#
        return [
            self.base64url(header),
            self.base64url(payloadJSON),
            "signature",
        ].joined(separator: ".")
    }

    private func base64url(_ string: String) -> String {
        Data(string.utf8)
            .base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }
}

private struct StubClaudeKeychainCredentialProvider: ClaudeKeychainCredentialProviding {
    let data: Data?

    func readCredentialData() throws -> Data? {
        self.data
    }
}
