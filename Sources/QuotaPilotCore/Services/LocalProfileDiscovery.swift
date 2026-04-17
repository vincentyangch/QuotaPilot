import Foundation

public struct LocalProfileDiscovery {
    private let claudeKeychainProvider: ClaudeKeychainCredentialProviding
    private let fileManager: FileManager

    public init(
        claudeKeychainProvider: ClaudeKeychainCredentialProviding = ClaudeKeychainCredentialProvider(),
        fileManager: FileManager = .default
    ) {
        self.claudeKeychainProvider = claudeKeychainProvider
        self.fileManager = fileManager
    }

    public func defaultCandidates(homeURL: URL = FileManager.default.homeDirectoryForCurrentUser) -> [LocalProfileCandidate] {
        [
            .codex(
                profileRootURL: homeURL.appendingPathComponent(".codex", isDirectory: true),
                labelHint: "Codex Ambient",
                sourceDescription: "Ambient local profile",
                sourceKind: .ambient,
                ownershipMode: .externalLocal
            ),
            .claude(
                profileRootURL: homeURL.appendingPathComponent(".claude", isDirectory: true),
                labelHint: "Claude Ambient",
                sourceDescription: "Ambient local profile",
                sourceKind: .ambient,
                ownershipMode: .externalLocal
            ),
        ]
    }

    public func discoverDefaultProfiles(
        homeURL: URL = FileManager.default.homeDirectoryForCurrentUser
    ) -> [DiscoveredLocalProfile] {
        self.discover(candidates: self.defaultCandidates(homeURL: homeURL))
    }

    public func discover(candidates: [LocalProfileCandidate]) -> [DiscoveredLocalProfile] {
        candidates.compactMap { candidate in
            switch candidate.provider {
            case .codex:
                guard self.fileManager.fileExists(atPath: candidate.credentialsURL.path),
                      let data = try? Data(contentsOf: candidate.credentialsURL)
                else { return nil }
                return self.discoverCodexProfile(candidate: candidate, data: data)
            case .claude:
                return self.discoverClaudeProfile(candidate: candidate)
            }
        }
    }

    private func discoverCodexProfile(
        candidate: LocalProfileCandidate,
        data: Data
    ) -> DiscoveredLocalProfile? {
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return nil }

        let tokens = json["tokens"] as? [String: Any]
        let idToken = Self.string(in: tokens, snakeCaseKey: "id_token", camelCaseKey: "idToken")
        let payload = idToken.flatMap(Self.decodeJWTPayload)
        let auth = payload?["https://api.openai.com/auth"] as? [String: Any]

        let email = Self.normalizedString(
            (payload?["email"] as? String)
            ?? (payload?["https://api.openai.com/profile"] as? [String: Any]).flatMap { $0["email"] as? String }
        )
        let plan = Self.normalizedString(
            (auth?["chatgpt_plan_type"] as? String)
            ?? (payload?["chatgpt_plan_type"] as? String)
        )

        guard tokens != nil || json["OPENAI_API_KEY"] != nil else { return nil }

        return DiscoveredLocalProfile(
            provider: .codex,
            label: email ?? candidate.labelHint,
            email: email,
            plan: plan,
            profileRootURL: candidate.profileRootURL,
            credentialsURL: candidate.credentialsURL,
            sourceDescription: candidate.sourceDescription,
            sourceKind: candidate.sourceKind,
            ownershipMode: candidate.ownershipMode
        )
    }

    private func discoverClaudeProfile(candidate: LocalProfileCandidate) -> DiscoveredLocalProfile? {
        if self.fileManager.fileExists(atPath: candidate.credentialsURL.path),
           let data = try? Data(contentsOf: candidate.credentialsURL),
           let profile = self.makeClaudeProfile(
               candidate: candidate,
               data: data,
               sourceDescription: candidate.sourceDescription
           )
        {
            return profile
        }

        if let data = try? self.claudeKeychainProvider.readCredentialData(),
           let profile = self.makeClaudeProfile(
               candidate: candidate,
               data: data,
               sourceDescription: "macOS Keychain"
           )
        {
            return profile
        }

        return nil
    }

    private func makeClaudeProfile(
        candidate: LocalProfileCandidate,
        data: Data,
        sourceDescription: String
    ) -> DiscoveredLocalProfile? {
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return nil }
        guard let oauth = json["claudeAiOauth"] as? [String: Any] else { return nil }
        guard let accessToken = oauth["accessToken"] as? String, !accessToken.isEmpty else { return nil }

        let plan = Self.normalizedString(oauth["rateLimitTier"] as? String)
        let label = plan.map { "Claude \($0.capitalized)" } ?? candidate.labelHint

        return DiscoveredLocalProfile(
            provider: .claude,
            label: label,
            email: nil,
            plan: plan,
            profileRootURL: candidate.profileRootURL,
            credentialsURL: candidate.credentialsURL,
            sourceDescription: sourceDescription,
            sourceKind: candidate.sourceKind,
            ownershipMode: candidate.ownershipMode
        )
    }

    private static func string(
        in dictionary: [String: Any]?,
        snakeCaseKey: String,
        camelCaseKey: String
    ) -> String? {
        if let value = dictionary?[snakeCaseKey] as? String, !value.isEmpty {
            return value
        }
        if let value = dictionary?[camelCaseKey] as? String, !value.isEmpty {
            return value
        }
        return nil
    }

    private static func normalizedString(_ value: String?) -> String? {
        guard let value = value?.trimmingCharacters(in: .whitespacesAndNewlines), !value.isEmpty else {
            return nil
        }
        return value
    }

    private static func decodeJWTPayload(_ token: String) -> [String: Any]? {
        let parts = token.split(separator: ".")
        guard parts.count >= 2 else { return nil }
        guard let data = self.base64URLDecode(String(parts[1])) else { return nil }
        return try? JSONSerialization.jsonObject(with: data) as? [String: Any]
    }

    private static func base64URLDecode(_ value: String) -> Data? {
        var base64 = value
            .replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")

        let remainder = base64.count % 4
        if remainder != 0 {
            base64 += String(repeating: "=", count: 4 - remainder)
        }

        return Data(base64Encoded: base64)
    }
}
