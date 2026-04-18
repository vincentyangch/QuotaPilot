import Foundation

public struct QuotaPilotWidgetGlobalRecommendationPanel: Equatable, Sendable {
    public let currentProvider: QuotaProvider
    public let currentLabel: String
    public let currentRemainingPercent: Int
    public let recommendedProvider: QuotaProvider
    public let recommendedLabel: String
    public let recommendedRemainingPercent: Int
    public let showsWarning: Bool
    public let statusText: String

    public init(
        currentProvider: QuotaProvider,
        currentLabel: String,
        currentRemainingPercent: Int,
        recommendedProvider: QuotaProvider,
        recommendedLabel: String,
        recommendedRemainingPercent: Int,
        showsWarning: Bool,
        statusText: String
    ) {
        self.currentProvider = currentProvider
        self.currentLabel = currentLabel
        self.currentRemainingPercent = currentRemainingPercent
        self.recommendedProvider = recommendedProvider
        self.recommendedLabel = recommendedLabel
        self.recommendedRemainingPercent = recommendedRemainingPercent
        self.showsWarning = showsWarning
        self.statusText = statusText
    }
}

public struct QuotaPilotWidgetProjectionResult: Equatable, Sendable {
    public let generatedAt: Date
    public let lastRefreshText: String
    public let emptyStateText: String?
    public let globalRecommendationPanel: QuotaPilotWidgetGlobalRecommendationPanel?

    public init(
        generatedAt: Date,
        lastRefreshText: String,
        emptyStateText: String? = nil,
        globalRecommendationPanel: QuotaPilotWidgetGlobalRecommendationPanel?
    ) {
        self.generatedAt = generatedAt
        self.lastRefreshText = lastRefreshText
        self.emptyStateText = emptyStateText
        self.globalRecommendationPanel = globalRecommendationPanel
    }
}

public enum QuotaPilotWidgetProjection {
    public static func make(
        snapshot: QuotaPilotWidgetSnapshot,
        now: Date = .now
    ) -> QuotaPilotWidgetProjectionResult {
        let recommendation = RecommendationEngine().globalRecommendation(
            accounts: snapshot.accounts,
            rules: snapshot.rules,
            now: snapshot.generatedAt
        )

        let panel = recommendation.flatMap { recommendation -> QuotaPilotWidgetGlobalRecommendationPanel? in
            guard let current = recommendation.currentAccount,
                  let recommended = recommendation.recommendedAccount
            else {
                return nil
            }

            return QuotaPilotWidgetGlobalRecommendationPanel(
                currentProvider: current.provider,
                currentLabel: current.label,
                currentRemainingPercent: current.primaryRemainingPercent,
                recommendedProvider: recommended.provider,
                recommendedLabel: recommended.label,
                recommendedRemainingPercent: recommended.primaryRemainingPercent,
                showsWarning: recommendation.decision.action == .recommendSwitch
                    && current.primaryRemainingPercent <= snapshot.rules.switchThresholdPercent,
                statusText: recommendation.decision.action == .recommendSwitch
                    ? "Switch suggested"
                    : "Current stays best"
            )
        }

        return QuotaPilotWidgetProjectionResult(
            generatedAt: snapshot.generatedAt,
            lastRefreshText: self.relativeRefreshText(from: snapshot.generatedAt, now: now),
            emptyStateText: panel == nil ? snapshot.lastUsageRefreshSummary : nil,
            globalRecommendationPanel: panel
        )
    }

    private static func relativeRefreshText(from generatedAt: Date, now: Date) -> String {
        let elapsedMinutes = max(0, Int(now.timeIntervalSince(generatedAt) / 60.0))
        if elapsedMinutes < 1 {
            return "Updated just now"
        }
        if elapsedMinutes == 1 {
            return "Updated 1 min ago"
        }
        return "Updated \(elapsedMinutes) min ago"
    }
}
