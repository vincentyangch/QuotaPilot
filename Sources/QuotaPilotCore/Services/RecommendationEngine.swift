import Foundation

public struct RecommendationEngine: Sendable {
    public struct ScoredAccount: Identifiable, Equatable, Sendable {
        public let account: QuotaAccount
        public let score: Int

        public var id: UUID { self.account.id }
    }

    public struct GlobalRecommendation: Equatable, Sendable {
        public let rankedAccounts: [ScoredAccount]
        public let decision: RecommendationDecision

        public var currentAccount: QuotaAccount? {
            guard let currentAccountID = self.decision.currentAccountID else { return nil }
            return self.rankedAccounts.first(where: { $0.account.id == currentAccountID })?.account
        }

        public var recommendedAccount: QuotaAccount? {
            self.rankedAccounts.first(where: { $0.account.id == self.decision.recommendedAccountID })?.account
        }
    }

    public struct ProviderRecommendation: Identifiable, Equatable, Sendable {
        public let provider: QuotaProvider
        public let rankedAccounts: [ScoredAccount]
        public let decision: RecommendationDecision

        public var id: QuotaProvider { self.provider }

        public var currentAccount: QuotaAccount? {
            guard let currentAccountID = self.decision.currentAccountID else { return nil }
            return self.rankedAccounts.first(where: { $0.account.id == currentAccountID })?.account
        }

        public var recommendedAccount: QuotaAccount? {
            self.rankedAccounts.first(where: { $0.account.id == self.decision.recommendedAccountID })?.account
        }
    }

    public init() {}

    public func globalRecommendation(
        accounts: [QuotaAccount],
        rules: GlobalRules,
        now: Date = .now
    ) -> GlobalRecommendation? {
        let ranked = self.rank(accounts: accounts, rules: rules, now: now)
        guard !ranked.isEmpty else { return nil }

        let top = ranked[0]
        let currentCandidates = ranked.filter { $0.account.isCurrent }

        let decision: RecommendationDecision
        if let recommendedSwitch = currentCandidates
            .map({ self.globalDecision(current: $0, top: top, rules: rules) })
            .filter({ $0.action == .recommendSwitch })
            .max(by: { lhs, rhs in
                let lhsAdvantage = lhs.recommendedScore - lhs.currentScore
                let rhsAdvantage = rhs.recommendedScore - rhs.currentScore
                if lhsAdvantage == rhsAdvantage {
                    return lhs.recommendedScore < rhs.recommendedScore
                }
                return lhsAdvantage < rhsAdvantage
            })
        {
            decision = recommendedSwitch
        } else if let bestCurrent = currentCandidates.max(by: { lhs, rhs in
            if lhs.score == rhs.score {
                return lhs.account.label > rhs.account.label
            }
            return lhs.score < rhs.score
        }) {
            decision = self.globalDecision(current: bestCurrent, top: top, rules: rules)
        } else {
            decision = self.evaluate(accounts: accounts, rules: rules, now: now)
        }

        return GlobalRecommendation(
            rankedAccounts: ranked,
            decision: decision
        )
    }

    public func rank(
        accounts: [QuotaAccount],
        rules: GlobalRules,
        now: Date = .now
    ) -> [ScoredAccount] {
        accounts
            .map { account in
                ScoredAccount(account: account, score: self.score(for: account, rules: rules, now: now))
            }
            .sorted { lhs, rhs in
                if lhs.score == rhs.score {
                    return lhs.account.label < rhs.account.label
                }
                return lhs.score > rhs.score
            }
    }

    public func evaluate(
        accounts: [QuotaAccount],
        rules: GlobalRules,
        now: Date = .now
    ) -> RecommendationDecision {
        let ranked = self.rank(accounts: accounts, rules: rules, now: now)
        guard let top = ranked.first else {
            return RecommendationDecision(
                currentAccountID: nil,
                recommendedAccountID: UUID(),
                action: .stayCurrent,
                currentScore: 0,
                recommendedScore: 0,
                explanation: "No accounts are available."
            )
        }

        let current = ranked.first(where: \.account.isCurrent) ?? top
        let shouldSwitch = current.account.primaryRemainingPercent <= rules.switchThresholdPercent
            && top.account.id != current.account.id
            && top.score - current.score >= rules.minimumScoreAdvantage

        if shouldSwitch {
            return RecommendationDecision(
                currentAccountID: current.account.id,
                recommendedAccountID: top.account.id,
                action: .recommendSwitch,
                currentScore: current.score,
                recommendedScore: top.score,
                explanation: "\(top.account.label) scores \(top.score - current.score) points better than \(current.account.label)."
            )
        }

        return RecommendationDecision(
            currentAccountID: current.account.id,
            recommendedAccountID: current.account.id,
            action: .stayCurrent,
            currentScore: current.score,
            recommendedScore: current.score,
            explanation: "\(current.account.label) remains the best active account under the current rules."
        )
    }

    public func recommendationsByProvider(
        accounts: [QuotaAccount],
        rules: GlobalRules,
        now: Date = .now
    ) -> [ProviderRecommendation] {
        QuotaProvider.allCases.compactMap { provider in
            let providerAccounts = accounts.filter { $0.provider == provider }
            guard !providerAccounts.isEmpty else { return nil }

            let rankedAccounts = self.rank(accounts: providerAccounts, rules: rules, now: now)
            let decision = self.evaluate(accounts: providerAccounts, rules: rules, now: now)

            return ProviderRecommendation(
                provider: provider,
                rankedAccounts: rankedAccounts,
                decision: decision
            )
        }
    }

    private func score(
        for account: QuotaAccount,
        rules: GlobalRules,
        now: Date
    ) -> Int {
        let remainingComponent = account.primaryRemainingPercent * rules.remainingWeight
        let resetHours = account.primaryResetHours(from: now)
        let resetComponent = max(0, 24 - min(resetHours, 24)) * rules.resetWeight
        let priorityComponent = account.priority * rules.priorityWeight
        let providerComponent = rules.providerWeights[account.provider] ?? 0

        return remainingComponent + resetComponent + priorityComponent + providerComponent
    }

    private func globalDecision(
        current: ScoredAccount,
        top: ScoredAccount,
        rules: GlobalRules
    ) -> RecommendationDecision {
        let shouldSwitch = current.account.primaryRemainingPercent <= rules.switchThresholdPercent
            && top.account.id != current.account.id
            && top.score - current.score >= rules.minimumScoreAdvantage

        if shouldSwitch {
            return RecommendationDecision(
                currentAccountID: current.account.id,
                recommendedAccountID: top.account.id,
                action: .recommendSwitch,
                currentScore: current.score,
                recommendedScore: top.score,
                explanation: "\(top.account.label) scores \(top.score - current.score) points better than \(current.account.label)."
            )
        }

        return RecommendationDecision(
            currentAccountID: current.account.id,
            recommendedAccountID: current.account.id,
            action: .stayCurrent,
            currentScore: current.score,
            recommendedScore: current.score,
            explanation: "\(current.account.label) remains the best active account under the current rules."
        )
    }
}
