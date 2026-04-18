import Foundation

public struct RecommendationAlertCandidate: Equatable, Sendable {
    public let provider: QuotaProvider
    public let identifier: String
    public let title: String
    public let body: String

    public init(
        provider: QuotaProvider,
        identifier: String,
        title: String,
        body: String
    ) {
        self.provider = provider
        self.identifier = identifier
        self.title = title
        self.body = body
    }
}

public enum RecommendationAlertPlanner {
    public static func makeCandidate(
        recommendation: RecommendationEngine.GlobalRecommendation?
    ) -> RecommendationAlertCandidate? {
        guard let recommendation,
              recommendation.decision.action == .recommendSwitch,
              let recommendedAccount = recommendation.recommendedAccount
        else {
            return nil
        }

        let currentLabel = recommendation.currentAccount?.label ?? "the current account"
        return RecommendationAlertCandidate(
            provider: recommendedAccount.provider,
            identifier: "\(recommendation.decision.currentAccountID?.uuidString ?? "none"):\(recommendedAccount.id.uuidString)",
            title: "Switch to \(recommendedAccount.label)",
            body: "\(recommendedAccount.label) is currently the best next account instead of \(currentLabel)."
        )
    }

    public static func makeCandidates(
        recommendations: [RecommendationEngine.ProviderRecommendation]
    ) -> [RecommendationAlertCandidate] {
        recommendations.compactMap { recommendation in
            guard recommendation.decision.action == .recommendSwitch,
                  let recommendedAccount = recommendation.recommendedAccount
            else {
                return nil
            }

            let currentLabel = recommendation.currentAccount?.label ?? "the current account"
            return RecommendationAlertCandidate(
                provider: recommendation.provider,
                identifier: "\(recommendation.provider.rawValue):\(recommendation.decision.currentAccountID?.uuidString ?? "none"):\(recommendedAccount.id.uuidString)",
                title: "Switch \(recommendation.provider.displayName) account",
                body: "\(recommendedAccount.label) is currently the best \(recommendation.provider.displayName) account instead of \(currentLabel)."
            )
        }
    }
}
