import Foundation

public enum RecommendationActivationStatus: Equatable, Sendable {
    case alreadyActive
    case unavailableOnThisMac
    case activatable
}

public struct RecommendationActivationOption: Equatable, Sendable {
    public let provider: QuotaProvider
    public let accountID: UUID
    public let accountLabel: String
    public let profileRootPath: String
    public let status: RecommendationActivationStatus
    public let reason: String

    public var isActivatable: Bool {
        self.status == .activatable
    }

    public init(
        provider: QuotaProvider,
        accountID: UUID,
        accountLabel: String,
        profileRootPath: String,
        status: RecommendationActivationStatus,
        reason: String
    ) {
        self.provider = provider
        self.accountID = accountID
        self.accountLabel = accountLabel
        self.profileRootPath = profileRootPath
        self.status = status
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
                status: .alreadyActive,
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
                status: .unavailableOnThisMac,
                reason: "The recommended profile is not currently discovered on this Mac."
            )
        }

        return RecommendationActivationOption(
            provider: recommendation.provider,
            accountID: recommendedAccount.id,
            accountLabel: recommendedAccount.label,
            profileRootPath: standardizedProfilePath,
            status: .activatable,
            reason: "Ready to activate the recommended profile."
        )
    }
}
