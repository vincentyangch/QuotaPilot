import Foundation
import Observation
import QuotaPilotCore

@MainActor
@Observable
final class AppModel {
    private let engine = RecommendationEngine()
    private let ambientUsageLoader: AmbientUsageLoader
    private let profileDiscovery: LocalProfileDiscovery
    private let rulesStorage: GlobalRulesStorage
    private var didAttemptInitialRefresh = false

    var accounts: [QuotaAccount]
    var discoveredProfiles: [DiscoveredLocalProfile]
    var isRefreshingUsage = false
    var lastUsageRefreshSummary: String
    var rules: GlobalRules {
        didSet {
            self.rulesStorage.save(self.rules)
        }
    }

    init(
        accounts: [QuotaAccount] = DemoAccountRepository.makeAccounts(),
        ambientUsageLoader: AmbientUsageLoader = AmbientUsageLoader(),
        profileDiscovery: LocalProfileDiscovery = LocalProfileDiscovery(),
        rulesStorage: GlobalRulesStorage = GlobalRulesStorage(),
        rules: GlobalRules? = nil
    ) {
        self.ambientUsageLoader = ambientUsageLoader
        self.profileDiscovery = profileDiscovery
        self.rulesStorage = rulesStorage
        let discoveredProfiles = profileDiscovery.discoverDefaultProfiles()
        self.accounts = accounts
        self.discoveredProfiles = discoveredProfiles
        self.rules = rules ?? rulesStorage.load()
        self.lastUsageRefreshSummary = discoveredProfiles.isEmpty
            ? "No local profiles found. Showing demo data."
            : "Ambient profiles found. Refresh to load live usage."
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
        self.lastUsageRefreshSummary = "Reloaded demo data."
    }

    func refreshDiscoveredProfiles() {
        self.discoveredProfiles = self.profileDiscovery.discoverDefaultProfiles()
    }

    func performInitialLiveRefreshIfNeeded() async {
        guard !self.didAttemptInitialRefresh else { return }
        self.didAttemptInitialRefresh = true
        await self.refreshLiveUsage()
    }

    func refreshLiveUsage() async {
        self.isRefreshingUsage = true
        self.refreshDiscoveredProfiles()
        defer { self.isRefreshingUsage = false }

        guard !self.discoveredProfiles.isEmpty else {
            self.lastUsageRefreshSummary = "No local profiles found. Showing demo data."
            return
        }

        let result = await self.ambientUsageLoader.loadAccounts(from: self.discoveredProfiles)

        if !result.accounts.isEmpty {
            self.accounts = self.mergedAccounts(liveAccounts: result.accounts)
        }

        if result.accounts.isEmpty {
            self.lastUsageRefreshSummary = "Could not load live usage from local profiles."
        } else if result.failures.isEmpty {
            self.lastUsageRefreshSummary = "Loaded live usage for \(result.accounts.count) local profile(s)."
        } else {
            self.lastUsageRefreshSummary = "Loaded \(result.accounts.count) live profile(s); \(result.failures.count) refresh failed."
        }
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

    private func mergedAccounts(liveAccounts: [QuotaAccount]) -> [QuotaAccount] {
        let liveProviders = Set(liveAccounts.map(\.provider))
        let retained = self.accounts.filter { !liveProviders.contains($0.provider) }
        return retained + liveAccounts
    }
}
