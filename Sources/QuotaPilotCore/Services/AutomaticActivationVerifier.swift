import Foundation

public struct AutomaticActivationRecoveryIssue: Identifiable, Equatable, Sendable {
    public let provider: QuotaProvider
    public let accountLabel: String
    public let profileRootPath: String
    public let detail: String

    public var id: String {
        "\(self.provider.rawValue):\(self.profileRootPath)"
    }

    public init(
        provider: QuotaProvider,
        accountLabel: String,
        profileRootPath: String,
        detail: String
    ) {
        self.provider = provider
        self.accountLabel = accountLabel
        self.profileRootPath = profileRootPath
        self.detail = detail
    }
}

public enum AutomaticActivationVerifier {
    public static func verify(
        option: RecommendationActivationOption,
        refreshedAccounts: [QuotaAccount]
    ) -> AutomaticActivationRecoveryIssue? {
        let targetPath = Self.standardizedPath(option.profileRootPath)

        guard !Self.containsCurrentMatch(
            provider: option.provider,
            profileRootPath: targetPath,
            refreshedAccounts: refreshedAccounts
        ) else {
            return nil
        }

        return AutomaticActivationRecoveryIssue(
            provider: option.provider,
            accountLabel: option.accountLabel,
            profileRootPath: targetPath,
            detail: "QuotaPilot switched the local profile, but it could not verify fresh live usage for \(option.accountLabel) afterward."
        )
    }

    public static func isRecovered(
        issue: AutomaticActivationRecoveryIssue,
        refreshedAccounts: [QuotaAccount]
    ) -> Bool {
        Self.containsCurrentMatch(
            provider: issue.provider,
            profileRootPath: issue.profileRootPath,
            refreshedAccounts: refreshedAccounts
        )
    }

    private static func containsCurrentMatch(
        provider: QuotaProvider,
        profileRootPath: String,
        refreshedAccounts: [QuotaAccount]
    ) -> Bool {
        refreshedAccounts.contains { account in
            account.provider == provider
                && account.isCurrent
                && account.profileRootPath.map(Self.standardizedPath) == profileRootPath
        }
    }

    private static func standardizedPath(_ path: String) -> String {
        URL(fileURLWithPath: path, isDirectory: true).standardizedFileURL.path
    }
}
