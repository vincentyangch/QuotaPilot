import Foundation

public struct QuotaPilotWidgetSnapshot: Codable, Equatable, Sendable {
    public let generatedAt: Date
    public let accounts: [QuotaAccount]
    public let rules: GlobalRules
    public let lastUsageRefreshSummary: String

    public init(
        generatedAt: Date,
        accounts: [QuotaAccount],
        rules: GlobalRules,
        lastUsageRefreshSummary: String
    ) {
        self.generatedAt = generatedAt
        self.accounts = accounts
        self.rules = rules
        self.lastUsageRefreshSummary = lastUsageRefreshSummary
    }
}
