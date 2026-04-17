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

    var providerRecommendations: [RecommendationEngine.ProviderRecommendation] {
        self.engine.recommendationsByProvider(accounts: self.accounts, rules: self.rules)
    }

    var recommendedAccountIDs: Set<UUID> {
        Set(self.providerRecommendations.compactMap(\.recommendedAccount?.id))
    }

    func recommendation(for provider: QuotaProvider) -> RecommendationEngine.ProviderRecommendation? {
        self.providerRecommendations.first(where: { $0.provider == provider })
    }

    func reloadDemoData() {
        self.accounts = DemoAccountRepository.makeAccounts()
    }
}
