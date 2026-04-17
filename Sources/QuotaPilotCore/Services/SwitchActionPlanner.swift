import Foundation

public struct SwitchActionPlan: Equatable, Sendable {
    public let automaticActivations: [RecommendationActivationOption]
    public let confirmationsToPresent: [RecommendationActivationOption]

    public init(
        automaticActivations: [RecommendationActivationOption],
        confirmationsToPresent: [RecommendationActivationOption]
    ) {
        self.automaticActivations = automaticActivations
        self.confirmationsToPresent = confirmationsToPresent
    }
}

public enum SwitchActionPlanner {
    public static func makePlan(
        mode: SwitchActionMode,
        activationOptionsByProvider: [QuotaProvider: RecommendationActivationOption],
        recommendationCandidatesByProvider: [QuotaProvider: RecommendationAlertCandidate],
        handledRecommendationIDsByProvider: [QuotaProvider: String],
        pendingConfirmationIDsByProvider: [QuotaProvider: String]
    ) -> SwitchActionPlan {
        switch mode {
        case .recommendOnly:
            return SwitchActionPlan(automaticActivations: [], confirmationsToPresent: [])
        case .autoActivateLocalProfiles:
            let automaticActivations = activationOptionsByProvider.compactMap { entry -> RecommendationActivationOption? in
                let (provider, option) = entry
                guard option.isActivatable,
                      let candidate = recommendationCandidatesByProvider[provider],
                      handledRecommendationIDsByProvider[provider] != candidate.identifier
                else {
                    return nil
                }
                return option
            }
            return SwitchActionPlan(
                automaticActivations: automaticActivations,
                confirmationsToPresent: []
            )
        case .confirmBeforeActivatingLocalProfiles:
            let confirmations = activationOptionsByProvider.compactMap { entry -> RecommendationActivationOption? in
                let (provider, option) = entry
                guard option.isActivatable,
                      let candidate = recommendationCandidatesByProvider[provider],
                      handledRecommendationIDsByProvider[provider] != candidate.identifier,
                      pendingConfirmationIDsByProvider[provider] != candidate.identifier
                else {
                    return nil
                }
                return option
            }
            return SwitchActionPlan(
                automaticActivations: [],
                confirmationsToPresent: confirmations
            )
        }
    }
}
