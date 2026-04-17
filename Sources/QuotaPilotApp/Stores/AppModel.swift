import Foundation
import Observation
import QuotaPilotCore

@Observable
final class AppModel {
    private let engine = RecommendationEngine()
    private let rulesStorage: GlobalRulesStorage

    var accounts: [QuotaAccount]
    var rules: GlobalRules {
        didSet {
            self.rulesStorage.save(self.rules)
        }
    }

    init(
        accounts: [QuotaAccount] = DemoAccountRepository.makeAccounts(),
        rulesStorage: GlobalRulesStorage = GlobalRulesStorage(),
        rules: GlobalRules? = nil
    ) {
        self.rulesStorage = rulesStorage
        self.accounts = accounts
        self.rules = rules ?? rulesStorage.load()
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

    func updateSwitchThreshold(_ value: Int) {
        self.rules = self.rules.updating(switchThresholdPercent: value)
    }

    func updateMinimumScoreAdvantage(_ value: Int) {
        self.rules = self.rules.updating(minimumScoreAdvantage: value)
    }

    func updateRemainingWeight(_ value: Int) {
        self.rules = self.rules.updating(remainingWeight: value)
    }

    func updateResetWeight(_ value: Int) {
        self.rules = self.rules.updating(resetWeight: value)
    }

    func updatePriorityWeight(_ value: Int) {
        self.rules = self.rules.updating(priorityWeight: value)
    }

    func resetRules() {
        self.rules = .default
    }
}
