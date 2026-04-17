import Foundation

public struct QuotaPilotWidgetProviderPanel: Equatable, Sendable {
    public let provider: QuotaProvider
    public let currentLabel: String
    public let currentRemainingPercent: Int
    public let recommendedLabel: String
    public let recommendedRemainingPercent: Int
    public let showsWarning: Bool
    public let statusText: String

    public init(
        provider: QuotaProvider,
        currentLabel: String,
        currentRemainingPercent: Int,
        recommendedLabel: String,
        recommendedRemainingPercent: Int,
        showsWarning: Bool,
        statusText: String
    ) {
        self.provider = provider
        self.currentLabel = currentLabel
        self.currentRemainingPercent = currentRemainingPercent
        self.recommendedLabel = recommendedLabel
        self.recommendedRemainingPercent = recommendedRemainingPercent
        self.showsWarning = showsWarning
        self.statusText = statusText
    }
}

public struct QuotaPilotWidgetProjectionResult: Equatable, Sendable {
    public let generatedAt: Date
    public let lastRefreshText: String
    public let providerPanels: [QuotaPilotWidgetProviderPanel]

    public init(
        generatedAt: Date,
        lastRefreshText: String,
        providerPanels: [QuotaPilotWidgetProviderPanel]
    ) {
        self.generatedAt = generatedAt
        self.lastRefreshText = lastRefreshText
        self.providerPanels = providerPanels
    }
}

public enum QuotaPilotWidgetProjection {
    public static func make(
        snapshot: QuotaPilotWidgetSnapshot,
        now: Date = .now
    ) -> QuotaPilotWidgetProjectionResult {
        let recommendations = RecommendationEngine().recommendationsByProvider(
            accounts: snapshot.accounts,
            rules: snapshot.rules,
            now: snapshot.generatedAt
        )

        let panels = recommendations.compactMap { recommendation -> QuotaPilotWidgetProviderPanel? in
            guard let current = recommendation.currentAccount,
                  let recommended = recommendation.recommendedAccount
            else {
                return nil
            }

            return QuotaPilotWidgetProviderPanel(
                provider: recommendation.provider,
                currentLabel: current.label,
                currentRemainingPercent: current.primaryRemainingPercent,
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
            providerPanels: panels
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
