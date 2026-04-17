import Foundation
import Observation
import QuotaPilotCore

@Observable
final class AppModel {
    private let engine = RecommendationEngine()

    var accounts: [QuotaAccount]
    var rules: GlobalRules

    init(
        accounts: [QuotaAccount] = DemoAccountRepository.makeAccounts(),
        rules: GlobalRules = .default
    ) {
        self.accounts = accounts
        self.rules = rules
    }

    var currentAccount: QuotaAccount? {
        self.accounts.first(where: \.isCurrent)
    }

    var decision: RecommendationDecision {
        self.engine.evaluate(accounts: self.accounts, rules: self.rules)
    }

    var rankedAccounts: [RecommendationEngine.ScoredAccount] {
        self.engine.rank(accounts: self.accounts, rules: self.rules)
    }

    var recommendedAccount: QuotaAccount? {
        self.accounts.first(where: { $0.id == self.decision.recommendedAccountID })
    }

    func reloadDemoData() {
        self.accounts = DemoAccountRepository.makeAccounts()
    }
}
