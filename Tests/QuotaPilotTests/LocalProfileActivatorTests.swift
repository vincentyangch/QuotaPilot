import XCTest
@testable import QuotaPilotCore

final class LocalProfileActivatorTests: XCTestCase {
    func testActivatingCodexProfileBacksUpAmbientCredentialsAndCopiesSelectedAuth() throws {
        let homeURL = try self.makeTemporaryDirectory(named: "home")
        let ambientRoot = homeURL.appendingPathComponent(".codex", isDirectory: true)
        let selectedRoot = try self.makeTemporaryDirectory(named: "selected-codex")
        let backupRoot = try self.makeTemporaryDirectory(named: "backups")

        try FileManager.default.createDirectory(at: ambientRoot, withIntermediateDirectories: true)
        try self.writeCodexAuth(
            email: "ambient@example.com",
            plan: "plus",
            to: ambientRoot.appendingPathComponent("auth.json")
        )
        let originalAmbientData = try Data(contentsOf: ambientRoot.appendingPathComponent("auth.json"))
        try self.writeCodexAuth(
            email: "selected@example.com",
            plan: "pro",
            to: selectedRoot.appendingPathComponent("auth.json")
        )

        let profile = DiscoveredLocalProfile(
            provider: .codex,
            label: "selected@example.com",
            email: "selected@example.com",
            plan: "pro",
            profileRootURL: selectedRoot,
            credentialsURL: selectedRoot.appendingPathComponent("auth.json"),
            sourceDescription: "Stored profile source"
        )

        let activator = LocalProfileActivator(
            homeURL: homeURL,
            backupRootURL: backupRoot,
            claudeKeychainManager: StubClaudeKeychainCredentialManager(data: nil)
        )

        let result = try activator.activate(profile: profile)

        XCTAssertEqual(result.activatedProfileRootPath, selectedRoot.standardizedFileURL.path)
        XCTAssertEqual(
            try Data(contentsOf: ambientRoot.appendingPathComponent("auth.json")),
            try Data(contentsOf: selectedRoot.appendingPathComponent("auth.json"))
        )

        let backupSource = try XCTUnwrap(result.createdBackupSource)
        XCTAssertEqual(backupSource.provider, .codex)
        XCTAssertEqual(backupSource.label, "Codex Ambient Backup")
        XCTAssertEqual(backupSource.sourceKind, .backup)
        XCTAssertEqual(backupSource.ownershipMode, .quotaPilotManaged)
        XCTAssertEqual(
            try Data(contentsOf: URL(fileURLWithPath: backupSource.profileRootPath, isDirectory: true).appendingPathComponent("auth.json")),
            originalAmbientData
        )
    }

    func testActivatingClaudeProfileBacksUpCurrentKeychainCredentialAndWritesSelectedCredentialEverywhere() throws {
        let homeURL = try self.makeTemporaryDirectory(named: "home")
        let ambientRoot = homeURL.appendingPathComponent(".claude", isDirectory: true)
        let selectedRoot = try self.makeTemporaryDirectory(named: "selected-claude")
        let backupRoot = try self.makeTemporaryDirectory(named: "backups")

        try FileManager.default.createDirectory(at: ambientRoot, withIntermediateDirectories: true)

        let ambientCredentials = self.makeClaudeCredentials(rateLimitTier: "free")
        let selectedCredentials = self.makeClaudeCredentials(rateLimitTier: "max")
        try selectedCredentials.write(
            to: selectedRoot.appendingPathComponent(".credentials.json"),
            atomically: true,
            encoding: .utf8
        )

        let keychainManager = StubClaudeKeychainCredentialManager(data: Data(ambientCredentials.utf8))
        let profile = DiscoveredLocalProfile(
            provider: .claude,
            label: "Claude Max",
            email: nil,
            plan: "max",
            profileRootURL: selectedRoot,
            credentialsURL: selectedRoot.appendingPathComponent(".credentials.json"),
            sourceDescription: "Stored profile source"
        )

        let activator = LocalProfileActivator(
            homeURL: homeURL,
            backupRootURL: backupRoot,
            claudeKeychainManager: keychainManager
        )

        let result = try activator.activate(profile: profile)

        XCTAssertEqual(result.activatedProfileRootPath, selectedRoot.standardizedFileURL.path)
        XCTAssertEqual(
            try String(contentsOf: ambientRoot.appendingPathComponent(".credentials.json")),
            selectedCredentials
        )
        XCTAssertEqual(
            try String(decoding: XCTUnwrap(keychainManager.data), as: UTF8.self),
            selectedCredentials
        )

        let backupSource = try XCTUnwrap(result.createdBackupSource)
        XCTAssertEqual(backupSource.provider, .claude)
        XCTAssertEqual(backupSource.sourceKind, .backup)
        XCTAssertEqual(backupSource.ownershipMode, .quotaPilotManaged)
        XCTAssertEqual(
            try String(contentsOf: URL(fileURLWithPath: backupSource.profileRootPath, isDirectory: true).appendingPathComponent(".credentials.json")),
            ambientCredentials
        )
    }

    private func makeTemporaryDirectory(named name: String) throws -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathComponent(name, isDirectory: true)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    private func writeCodexAuth(email: String, plan: String, to url: URL) throws {
        let payload = """
        {
          "email": "\(email)",
          "https://api.openai.com/auth": {
            "chatgpt_plan_type": "\(plan)"
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
        try authJSON.write(to: url, atomically: true, encoding: .utf8)
    }

    private func makeClaudeCredentials(rateLimitTier: String) -> String {
        """
        {
          "claudeAiOauth": {
            "accessToken": "access",
            "refreshToken": "refresh",
            "expiresAt": 1893456000000,
            "rateLimitTier": "\(rateLimitTier)"
          }
        }
        """
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

private final class StubClaudeKeychainCredentialManager: @unchecked Sendable, ClaudeKeychainCredentialManaging {
    var data: Data?

    init(data: Data?) {
        self.data = data
    }

    func readCredentialData() throws -> Data? {
        self.data
    }

    func writeCredentialData(_ data: Data) throws {
        self.data = data
    }
}
