import Foundation

public enum RecommendationAction: String, Codable, Equatable, Sendable {
    case stayCurrent
    case recommendSwitch
}

public struct RecommendationDecision: Codable, Equatable, Sendable {
    public let currentAccountID: UUID?
    public let recommendedAccountID: UUID
    public let action: RecommendationAction
    public let currentScore: Int
    public let recommendedScore: Int
    public let explanation: String

    public init(
        currentAccountID: UUID?,
        recommendedAccountID: UUID,
        action: RecommendationAction,
        currentScore: Int,
        recommendedScore: Int,
        explanation: String
    ) {
        self.currentAccountID = currentAccountID
        self.recommendedAccountID = recommendedAccountID
        self.action = action
        self.currentScore = currentScore
        self.recommendedScore = recommendedScore
        self.explanation = explanation
    }
}
