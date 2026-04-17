import Foundation

public struct RecommendationActivationOption: Equatable, Sendable {
    public let provider: QuotaProvider
    public let accountID: UUID
    public let accountLabel: String
    public let profileRootPath: String
    public let isActivatable: Bool
    public let reason: String

    public init(
        provider: QuotaProvider,
        accountID: UUID,
        accountLabel: String,
        profileRootPath: String,
        isActivatable: Bool,
        reason: String
    ) {
        self.provider = provider
        self.accountID = accountID
        self.accountLabel = accountLabel
        self.profileRootPath = profileRootPath
        self.isActivatable = isActivatable
        self.reason = reason
    }
}

public enum RecommendationActivationPlanner {
    public static func makeOption(
        recommendation: RecommendationEngine.ProviderRecommendation,
        discoveredProfiles: [DiscoveredLocalProfile],
        currentProfileRootPaths: [QuotaProvider: String]
    ) -> RecommendationActivationOption? {
        guard recommendation.decision.action == .recommendSwitch,
              let recommendedAccount = recommendation.recommendedAccount,
              let profileRootPath = recommendedAccount.profileRootPath
        else {
            return nil
        }

        let standardizedProfilePath = URL(fileURLWithPath: profileRootPath, isDirectory: true)
            .standardizedFileURL
            .path
        let standardizedCurrentPath = currentProfileRootPaths[recommendation.provider].map {
            URL(fileURLWithPath: $0, isDirectory: true).standardizedFileURL.path
        }

        if standardizedCurrentPath == standardizedProfilePath || recommendedAccount.isCurrent {
            return RecommendationActivationOption(
                provider: recommendation.provider,
                accountID: recommendedAccount.id,
                accountLabel: recommendedAccount.label,
                profileRootPath: standardizedProfilePath,
                isActivatable: false,
                reason: "The recommended profile is already active."
            )
        }

        let isDiscovered = discoveredProfiles.contains {
            $0.provider == recommendation.provider
                && $0.profileRootURL.standardizedFileURL.path == standardizedProfilePath
        }

        if !isDiscovered {
            return RecommendationActivationOption(
                provider: recommendation.provider,
                accountID: recommendedAccount.id,
                accountLabel: recommendedAccount.label,
                profileRootPath: standardizedProfilePath,
                isActivatable: false,
                reason: "The recommended profile is not currently discovered on this Mac."
            )
        }

        return RecommendationActivationOption(
            provider: recommendation.provider,
            accountID: recommendedAccount.id,
            accountLabel: recommendedAccount.label,
            profileRootPath: standardizedProfilePath,
            isActivatable: true,
            reason: "Ready to activate the recommended profile."
        )
    }
}
