import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

public enum AmbientUsageFailureKind: Equatable, Sendable {
    case invalidCredentials
    case noUsageData
    case requestFailed(statusCode: Int)
    case unexpected
}

public struct AmbientUsageRefreshFailure: Equatable, Sendable {
    public let provider: QuotaProvider
    public let profileLabel: String
    public let profileRootPath: String?
    public let detail: String
    public let kind: AmbientUsageFailureKind

    public init(
        provider: QuotaProvider,
        profileLabel: String,
        profileRootPath: String? = nil,
        detail: String,
        kind: AmbientUsageFailureKind
    ) {
        self.provider = provider
        self.profileLabel = profileLabel
        self.profileRootPath = profileRootPath
        self.detail = detail
        self.kind = kind
    }
}

public struct AmbientUsageRefreshResult: Sendable {
    public let accounts: [QuotaAccount]
    public let failures: [AmbientUsageRefreshFailure]

    public init(accounts: [QuotaAccount], failures: [AmbientUsageRefreshFailure]) {
        self.accounts = accounts
        self.failures = failures
    }
}

public protocol URLRequestPerforming: Sendable {
    func data(for request: URLRequest) async throws -> (Data, HTTPURLResponse)
}

public struct URLSessionRequestPerformer: URLRequestPerforming {
    public init() {}

    public func data(for request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw URLError(.badServerResponse)
        }
        return (data, httpResponse)
    }
}

public struct AmbientUsageLoader: Sendable {
    private let claudeKeychainProvider: ClaudeKeychainCredentialProviding
    private let network: URLRequestPerforming

    public init(
        network: URLRequestPerforming = URLSessionRequestPerformer(),
        claudeKeychainProvider: ClaudeKeychainCredentialProviding = ClaudeKeychainCredentialProvider()
    ) {
        self.network = network
        self.claudeKeychainProvider = claudeKeychainProvider
    }

    public func loadAccounts(
        from profiles: [DiscoveredLocalProfile],
        currentProfileRootPaths: [QuotaProvider: String] = [:]
    ) async -> AmbientUsageRefreshResult {
        var accounts: [QuotaAccount] = []
        var failures: [AmbientUsageRefreshFailure] = []

        for profile in profiles {
            do {
                if let account = try await self.loadAccount(
                    from: profile,
                    currentProfileRootPaths: currentProfileRootPaths
                ) {
                    accounts.append(account)
                }
            } catch {
                failures.append(self.makeFailure(for: profile, error: error))
            }
        }

        return AmbientUsageRefreshResult(accounts: accounts, failures: failures)
    }

    private func loadAccount(
        from profile: DiscoveredLocalProfile,
        currentProfileRootPaths: [QuotaProvider: String]
    ) async throws -> QuotaAccount? {
        switch profile.provider {
        case .codex:
            let credentials = try self.loadCodexCredentials(from: profile.credentialsURL)
            let request = self.makeCodexRequest(
                accessToken: credentials.accessToken,
                accountID: credentials.accountID
            )
            let (data, response) = try await self.network.data(for: request)
            guard (200...299).contains(response.statusCode) else {
                throw LoaderError.requestFailed(provider: .codex, statusCode: response.statusCode)
            }
            let decoded = try JSONDecoder().decode(CodexLiveUsageResponse.self, from: data)
            guard let account = self.makeCodexAccount(
                profile: profile,
                response: decoded,
                currentProfileRootPaths: currentProfileRootPaths
            ) else {
                throw LoaderError.noUsageData(provider: .codex)
            }
            return account

        case .claude:
            let credentials = try self.loadClaudeCredentials(from: profile.credentialsURL)
            let request = self.makeClaudeRequest(accessToken: credentials.accessToken)
            let (data, response) = try await self.network.data(for: request)
            guard (200...299).contains(response.statusCode) else {
                throw LoaderError.requestFailed(provider: .claude, statusCode: response.statusCode)
            }
            let decoded = try JSONDecoder().decode(ClaudeLiveUsageResponse.self, from: data)
            guard let account = self.makeClaudeAccount(
                profile: profile,
                response: decoded,
                currentProfileRootPaths: currentProfileRootPaths
            ) else {
                throw LoaderError.noUsageData(provider: .claude)
            }
            return account
        }
    }

    private func loadCodexCredentials(from url: URL) throws -> CodexCredentials {
        let data = try Data(contentsOf: url)
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw LoaderError.invalidCredentials(provider: .codex)
        }

        if let apiKey = json["OPENAI_API_KEY"] as? String,
           !apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        {
            return CodexCredentials(accessToken: apiKey, accountID: nil)
        }

        guard let tokens = json["tokens"] as? [String: Any],
              let accessToken = Self.string(in: tokens, snakeCaseKey: "access_token", camelCaseKey: "accessToken"),
              !accessToken.isEmpty
        else {
            throw LoaderError.invalidCredentials(provider: .codex)
        }

        let accountID = Self.string(in: tokens, snakeCaseKey: "account_id", camelCaseKey: "accountId")
        return CodexCredentials(accessToken: accessToken, accountID: accountID)
    }

    private func loadClaudeCredentials(from url: URL) throws -> ClaudeCredentials {
        if let data = try? Data(contentsOf: url),
           let credentials = self.parseClaudeCredentials(from: data)
        {
            return credentials
        }

        if let data = try? self.claudeKeychainProvider.readCredentialData(),
           let credentials = self.parseClaudeCredentials(from: data)
        {
            return credentials
        }

        throw LoaderError.invalidCredentials(provider: .claude)
    }

    private func makeCodexRequest(accessToken: String, accountID: String?) -> URLRequest {
        let url = URL(string: "https://chatgpt.com/backend-api/wham/usage")!
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.timeoutInterval = 30
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue("QuotaPilot", forHTTPHeaderField: "User-Agent")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        if let accountID, !accountID.isEmpty {
            request.setValue(accountID, forHTTPHeaderField: "ChatGPT-Account-Id")
        }
        return request
    }

    private func makeClaudeRequest(accessToken: String) -> URLRequest {
        let url = URL(string: "https://api.anthropic.com/api/oauth/usage")!
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.timeoutInterval = 30
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("oauth-2025-04-20", forHTTPHeaderField: "anthropic-beta")
        request.setValue("claude-code/2.1.0", forHTTPHeaderField: "User-Agent")
        return request
    }

    private func makeCodexAccount(
        profile: DiscoveredLocalProfile,
        response: CodexLiveUsageResponse,
        currentProfileRootPaths: [QuotaProvider: String]
    ) -> QuotaAccount? {
        let windows = [
            self.makeCodexWindow(response.rateLimit?.primaryWindow),
            self.makeCodexWindow(response.rateLimit?.secondaryWindow),
        ].compactMap { $0 }

        guard !windows.isEmpty else { return nil }

        let isCurrent = self.isCurrentProfile(profile, currentProfileRootPaths: currentProfileRootPaths)

        return QuotaAccount(
            id: UUID(),
            provider: .codex,
            label: profile.label,
            priority: Self.priority(for: profile.plan),
            isCurrent: isCurrent,
            profileRootPath: profile.profileRootURL.standardizedFileURL.path,
            sourceDescription: profile.sourceDescription,
            email: profile.email,
            plan: profile.plan,
            capabilities: .localProfile,
            lastSuccessfulRefreshAt: .now,
            windows: windows
        )
    }

    private func makeClaudeAccount(
        profile: DiscoveredLocalProfile,
        response: ClaudeLiveUsageResponse,
        currentProfileRootPaths: [QuotaProvider: String]
    ) -> QuotaAccount? {
        let windows = [
            self.makeClaudeWindow(response.fiveHour, title: "Session", minutes: 5 * 60),
            self.makeClaudeWindow(response.sevenDay, title: "Weekly", minutes: 7 * 24 * 60),
        ].compactMap { $0 }

        guard !windows.isEmpty else { return nil }

        let isCurrent = self.isCurrentProfile(profile, currentProfileRootPaths: currentProfileRootPaths)

        return QuotaAccount(
            id: UUID(),
            provider: .claude,
            label: profile.label,
            priority: Self.priority(for: profile.plan),
            isCurrent: isCurrent,
            profileRootPath: profile.profileRootURL.standardizedFileURL.path,
            sourceDescription: profile.sourceDescription,
            email: profile.email,
            plan: profile.plan,
            capabilities: .localProfile,
            lastSuccessfulRefreshAt: .now,
            windows: windows
        )
    }

    private func makeCodexWindow(_ window: CodexLiveUsageResponse.Window?) -> UsageWindow? {
        guard let window else { return nil }
        let resetDate = Date(timeIntervalSince1970: TimeInterval(window.resetAt))
        let title = window.limitWindowSeconds >= 7 * 24 * 60 * 60 ? "Weekly" : "Session"
        return UsageWindow(
            id: title.lowercased(),
            title: title,
            remainingPercent: max(0, 100 - window.usedPercent),
            resetsAt: resetDate
        )
    }

    private func makeClaudeWindow(
        _ window: ClaudeLiveUsageResponse.Window?,
        title: String,
        minutes: Int
    ) -> UsageWindow? {
        guard let window,
              let utilization = window.utilization,
              let resetString = window.resetsAt,
              let resetDate = Self.parseISO8601Date(resetString)
        else {
            return nil
        }

        let usedPercent = Int(utilization.rounded())
        return UsageWindow(
            id: title.lowercased(),
            title: title,
            remainingPercent: max(0, 100 - usedPercent),
            resetsAt: resetDate
        )
    }

    private static func priority(for plan: String?) -> Int {
        switch plan?.lowercased() {
        case "enterprise": 95
        case "team", "business": 85
        case "pro", "max": 80
        case "plus": 70
        case "free", "guest": 40
        default: 60
        }
    }

    private static func string(
        in dictionary: [String: Any],
        snakeCaseKey: String,
        camelCaseKey: String
    ) -> String? {
        if let value = dictionary[snakeCaseKey] as? String, !value.isEmpty {
            return value
        }
        if let value = dictionary[camelCaseKey] as? String, !value.isEmpty {
            return value
        }
        return nil
    }

    private static func parseISO8601Date(_ value: String) -> Date? {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = formatter.date(from: value) {
            return date
        }
        formatter.formatOptions = [.withInternetDateTime]
        return formatter.date(from: value)
    }

    private func parseClaudeCredentials(from data: Data) -> ClaudeCredentials? {
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let oauth = json["claudeAiOauth"] as? [String: Any],
              let accessToken = oauth["accessToken"] as? String,
              !accessToken.isEmpty
        else {
            return nil
        }

        return ClaudeCredentials(accessToken: accessToken)
    }

    private func isCurrentProfile(
        _ profile: DiscoveredLocalProfile,
        currentProfileRootPaths: [QuotaProvider: String]
    ) -> Bool {
        guard let selectedPath = currentProfileRootPaths[profile.provider] else { return true }
        return profile.profileRootURL.standardizedFileURL.path
            == URL(fileURLWithPath: selectedPath, isDirectory: true).standardizedFileURL.path
    }

    private func makeFailure(
        for profile: DiscoveredLocalProfile,
        error: Error
    ) -> AmbientUsageRefreshFailure {
        if let loaderError = error as? LoaderError {
            switch loaderError {
            case .invalidCredentials:
                return AmbientUsageRefreshFailure(
                    provider: profile.provider,
                    profileLabel: profile.label,
                    profileRootPath: profile.profileRootURL.standardizedFileURL.path,
                    detail: loaderError.localizedDescription,
                    kind: .invalidCredentials
                )
            case .noUsageData:
                return AmbientUsageRefreshFailure(
                    provider: profile.provider,
                    profileLabel: profile.label,
                    profileRootPath: profile.profileRootURL.standardizedFileURL.path,
                    detail: loaderError.localizedDescription,
                    kind: .noUsageData
                )
            case let .requestFailed(_, statusCode):
                return AmbientUsageRefreshFailure(
                    provider: profile.provider,
                    profileLabel: profile.label,
                    profileRootPath: profile.profileRootURL.standardizedFileURL.path,
                    detail: loaderError.localizedDescription,
                    kind: .requestFailed(statusCode: statusCode)
                )
            }
        }

        return AmbientUsageRefreshFailure(
            provider: profile.provider,
            profileLabel: profile.label,
            profileRootPath: profile.profileRootURL.standardizedFileURL.path,
            detail: "\(profile.label): \(error.localizedDescription)",
            kind: .unexpected
        )
    }
}

private struct CodexCredentials {
    let accessToken: String
    let accountID: String?
}

private struct ClaudeCredentials {
    let accessToken: String
}

private enum LoaderError: LocalizedError {
    case invalidCredentials(provider: QuotaProvider)
    case noUsageData(provider: QuotaProvider)
    case requestFailed(provider: QuotaProvider, statusCode: Int)

    var errorDescription: String? {
        switch self {
        case let .invalidCredentials(provider):
            return "Invalid \(provider.displayName) credentials."
        case .noUsageData:
            return "No live usage windows were returned."
        case let .requestFailed(provider, statusCode):
            return "\(provider.displayName) usage request failed with HTTP \(statusCode)."
        }
    }
}

private struct CodexLiveUsageResponse: Decodable {
    let rateLimit: RateLimit?

    enum CodingKeys: String, CodingKey {
        case rateLimit = "rate_limit"
    }

    struct RateLimit: Decodable {
        let primaryWindow: Window?
        let secondaryWindow: Window?

        enum CodingKeys: String, CodingKey {
            case primaryWindow = "primary_window"
            case secondaryWindow = "secondary_window"
        }
    }

    struct Window: Decodable {
        let usedPercent: Int
        let resetAt: Int
        let limitWindowSeconds: Int

        enum CodingKeys: String, CodingKey {
            case usedPercent = "used_percent"
            case resetAt = "reset_at"
            case limitWindowSeconds = "limit_window_seconds"
        }
    }
}

private struct ClaudeLiveUsageResponse: Decodable {
    let fiveHour: Window?
    let sevenDay: Window?

    enum CodingKeys: String, CodingKey {
        case fiveHour = "five_hour"
        case sevenDay = "seven_day"
    }

    struct Window: Decodable {
        let utilization: Double?
        let resetsAt: String?

        enum CodingKeys: String, CodingKey {
            case utilization
            case resetsAt = "resets_at"
        }
    }
}
