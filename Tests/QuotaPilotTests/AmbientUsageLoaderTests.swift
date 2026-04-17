import XCTest
@testable import QuotaPilotCore

final class AmbientUsageLoaderTests: XCTestCase {
    func testLoadsAccountsForCodexAndClaudeProfiles() async throws {
        let codexRoot = try self.makeTemporaryDirectory(named: "codex")
        let claudeRoot = try self.makeTemporaryDirectory(named: "claude")

        try self.writeCodexAuth(
            email: "codex@example.com",
            plan: "pro",
            to: codexRoot.appendingPathComponent("auth.json")
        )
        try self.writeClaudeCredentials(
            rateLimitTier: "max",
            to: claudeRoot.appendingPathComponent(".credentials.json")
        )

        let profiles = [
            DiscoveredLocalProfile(
                provider: .codex,
                label: "codex@example.com",
                email: "codex@example.com",
                plan: "pro",
                profileRootURL: codexRoot,
                credentialsURL: codexRoot.appendingPathComponent("auth.json"),
                sourceDescription: "Test"
            ),
            DiscoveredLocalProfile(
                provider: .claude,
                label: "Claude Max",
                email: nil,
                plan: "max",
                profileRootURL: claudeRoot,
                credentialsURL: claudeRoot.appendingPathComponent(".credentials.json"),
                sourceDescription: "Test"
            ),
        ]

        let loader = AmbientUsageLoader(network: StubRequestPerformer { request in
            if request.url?.absoluteString.contains("chatgpt.com/backend-api/wham/usage") == true {
                return try Self.makeHTTPResponse(
                    url: request.url!,
                    statusCode: 200,
                    json: """
                    {
                      "plan_type": "pro",
                      "rate_limit": {
                        "primary_window": {
                          "used_percent": 40,
                          "reset_at": 1893456000,
                          "limit_window_seconds": 300
                        },
                        "secondary_window": {
                          "used_percent": 10,
                          "reset_at": 1894060800,
                          "limit_window_seconds": 604800
                        }
                      }
                    }
                    """
                )
            }

            if request.url?.absoluteString.contains("api.anthropic.com/api/oauth/usage") == true {
                return try Self.makeHTTPResponse(
                    url: request.url!,
                    statusCode: 200,
                    json: """
                    {
                      "five_hour": {
                        "utilization": 35,
                        "resets_at": "2030-01-01T00:00:00Z"
                      },
                      "seven_day": {
                        "utilization": 55,
                        "resets_at": "2030-01-07T00:00:00Z"
                      }
                    }
                    """
                )
            }

            throw URLError(.unsupportedURL)
        })

        let result = await loader.loadAccounts(from: profiles)

        XCTAssertEqual(result.accounts.count, 2)
        XCTAssertTrue(result.failures.isEmpty)

        let codex = try XCTUnwrap(result.accounts.first(where: { $0.provider == .codex }))
        XCTAssertEqual(codex.label, "codex@example.com")
        XCTAssertEqual(codex.primaryRemainingPercent, 60)
        XCTAssertEqual(codex.windows.count, 2)

        let claude = try XCTUnwrap(result.accounts.first(where: { $0.provider == .claude }))
        XCTAssertEqual(claude.label, "Claude Max")
        XCTAssertEqual(claude.primaryRemainingPercent, 65)
        XCTAssertEqual(claude.windows.count, 2)
    }

    func testMarksOnlySelectedProfileAsCurrentPerProvider() async throws {
        let firstCodexRoot = try self.makeTemporaryDirectory(named: "codex-a")
        let secondCodexRoot = try self.makeTemporaryDirectory(named: "codex-b")

        try self.writeCodexAuth(
            email: "first@example.com",
            plan: "plus",
            to: firstCodexRoot.appendingPathComponent("auth.json")
        )
        try self.writeCodexAuth(
            email: "second@example.com",
            plan: "pro",
            to: secondCodexRoot.appendingPathComponent("auth.json")
        )

        let profiles = [
            DiscoveredLocalProfile(
                provider: .codex,
                label: "first@example.com",
                email: "first@example.com",
                plan: "plus",
                profileRootURL: firstCodexRoot,
                credentialsURL: firstCodexRoot.appendingPathComponent("auth.json"),
                sourceDescription: "Ambient local profile"
            ),
            DiscoveredLocalProfile(
                provider: .codex,
                label: "second@example.com",
                email: "second@example.com",
                plan: "pro",
                profileRootURL: secondCodexRoot,
                credentialsURL: secondCodexRoot.appendingPathComponent("auth.json"),
                sourceDescription: "Stored profile source"
            ),
        ]

        let loader = AmbientUsageLoader(network: StubRequestPerformer { request in
            return try Self.makeHTTPResponse(
                url: request.url!,
                statusCode: 200,
                json: """
                {
                  "rate_limit": {
                    "primary_window": {
                      "used_percent": 40,
                      "reset_at": 1893456000,
                      "limit_window_seconds": 300
                    }
                  }
                }
                """
            )
        })

        let result = await loader.loadAccounts(
            from: profiles,
            currentProfileRootPaths: [.codex: secondCodexRoot.path]
        )

        XCTAssertEqual(result.accounts.count, 2)
        XCTAssertEqual(result.accounts.filter(\.isCurrent).count, 1)
        XCTAssertEqual(result.accounts.first(where: \.isCurrent)?.label, "second@example.com")
    }

    func testCollectsFailuresWithoutDiscardingSuccessfulAccounts() async throws {
        let codexRoot = try self.makeTemporaryDirectory(named: "codex")
        let claudeRoot = try self.makeTemporaryDirectory(named: "claude")

        try self.writeCodexAuth(
            email: "codex@example.com",
            plan: "plus",
            to: codexRoot.appendingPathComponent("auth.json")
        )
        try self.writeClaudeCredentials(
            rateLimitTier: "max",
            to: claudeRoot.appendingPathComponent(".credentials.json")
        )

        let profiles = [
            DiscoveredLocalProfile(
                provider: .codex,
                label: "codex@example.com",
                email: "codex@example.com",
                plan: "plus",
                profileRootURL: codexRoot,
                credentialsURL: codexRoot.appendingPathComponent("auth.json"),
                sourceDescription: "Test"
            ),
            DiscoveredLocalProfile(
                provider: .claude,
                label: "Claude Max",
                email: nil,
                plan: "max",
                profileRootURL: claudeRoot,
                credentialsURL: claudeRoot.appendingPathComponent(".credentials.json"),
                sourceDescription: "Test"
            ),
        ]

        let loader = AmbientUsageLoader(network: StubRequestPerformer { request in
            if request.url?.absoluteString.contains("chatgpt.com/backend-api/wham/usage") == true {
                return try Self.makeHTTPResponse(
                    url: request.url!,
                    statusCode: 200,
                    json: """
                    {
                      "rate_limit": {
                        "primary_window": {
                          "used_percent": 45,
                          "reset_at": 1893456000,
                          "limit_window_seconds": 300
                        }
                      }
                    }
                    """
                )
            }

            if request.url?.absoluteString.contains("api.anthropic.com/api/oauth/usage") == true {
                return try Self.makeHTTPResponse(
                    url: request.url!,
                    statusCode: 401,
                    json: """
                    {
                      "error": "unauthorized"
                    }
                    """
                )
            }

            throw URLError(.unsupportedURL)
        })

        let result = await loader.loadAccounts(from: profiles)

        XCTAssertEqual(result.accounts.count, 1)
        XCTAssertEqual(result.accounts.first?.provider, .codex)
        XCTAssertEqual(result.failures.count, 1)
        XCTAssertEqual(result.failures.first?.provider, .claude)
        XCTAssertEqual(result.failures.first?.profileLabel, "Claude Max")
        XCTAssertEqual(result.failures.first?.kind, .requestFailed(statusCode: 401))
    }

    func testReportsNoUsageDataWhenProviderReturnsNoWindows() async throws {
        let codexRoot = try self.makeTemporaryDirectory(named: "codex")

        try self.writeCodexAuth(
            email: "codex@example.com",
            plan: "plus",
            to: codexRoot.appendingPathComponent("auth.json")
        )

        let profiles = [
            DiscoveredLocalProfile(
                provider: .codex,
                label: "codex@example.com",
                email: "codex@example.com",
                plan: "plus",
                profileRootURL: codexRoot,
                credentialsURL: codexRoot.appendingPathComponent("auth.json"),
                sourceDescription: "Test"
            )
        ]

        let loader = AmbientUsageLoader(network: StubRequestPerformer { request in
            try Self.makeHTTPResponse(
                url: request.url!,
                statusCode: 200,
                json: """
                {
                  "rate_limit": {}
                }
                """
            )
        })

        let result = await loader.loadAccounts(from: profiles)

        XCTAssertTrue(result.accounts.isEmpty)
        XCTAssertEqual(result.failures.count, 1)
        XCTAssertEqual(result.failures.first?.kind, .noUsageData)
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

    private func writeClaudeCredentials(rateLimitTier: String, to url: URL) throws {
        let json = """
        {
          "claudeAiOauth": {
            "accessToken": "access",
            "refreshToken": "refresh",
            "expiresAt": 1893456000000,
            "rateLimitTier": "\(rateLimitTier)"
          }
        }
        """
        try json.write(to: url, atomically: true, encoding: .utf8)
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

    private static func makeHTTPResponse(
        url: URL,
        statusCode: Int,
        json: String
    ) throws -> (Data, HTTPURLResponse) {
        let response = try XCTUnwrap(HTTPURLResponse(
            url: url,
            statusCode: statusCode,
            httpVersion: nil,
            headerFields: ["Content-Type": "application/json"]
        ))
        return (Data(json.utf8), response)
    }
}

private struct StubRequestPerformer: URLRequestPerforming {
    let handler: @Sendable (URLRequest) throws -> (Data, HTTPURLResponse)

    func data(for request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        try self.handler(request)
    }
}
