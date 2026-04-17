import Foundation
import Observation
import QuotaPilotCore

@MainActor
@Observable
final class AppModel {
    private let engine = RecommendationEngine()
    private let ambientUsageLoader: AmbientUsageLoader
    private let profileDiscovery: LocalProfileDiscovery
    private let profileSourceStore: StoredProfileSourceStoring
    private let rulesStorage: GlobalRulesStorage
    private var didAttemptInitialRefresh = false
    private let homeURL: URL

    var accounts: [QuotaAccount]
    var discoveredProfiles: [DiscoveredLocalProfile]
    var storedProfileSources: [StoredProfileSource]
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
        profileSourceStore: StoredProfileSourceStoring = FileStoredProfileSourceStore(),
        rulesStorage: GlobalRulesStorage = GlobalRulesStorage(),
        homeURL: URL = FileManager.default.homeDirectoryForCurrentUser,
        rules: GlobalRules? = nil
    ) {
        self.ambientUsageLoader = ambientUsageLoader
        self.profileDiscovery = profileDiscovery
        self.profileSourceStore = profileSourceStore
        self.rulesStorage = rulesStorage
        self.homeURL = homeURL
        let storedSources = (try? profileSourceStore.loadSources()) ?? []
        let candidates = ProfileSourceCatalog.makeCandidates(homeURL: homeURL, storedSources: storedSources)
        let discoveredProfiles = profileDiscovery.discover(candidates: candidates)
        self.accounts = accounts
        self.discoveredProfiles = discoveredProfiles
        self.storedProfileSources = storedSources
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
        self.storedProfileSources = (try? self.profileSourceStore.loadSources()) ?? self.storedProfileSources
        let candidates = ProfileSourceCatalog.makeCandidates(
            homeURL: self.homeURL,
            storedSources: self.storedProfileSources
        )
        self.discoveredProfiles = self.profileDiscovery.discover(candidates: candidates)
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

    func addStoredProfileSource(
        provider: QuotaProvider,
        label: String,
        path: String
    ) {
        let trimmedPath = path.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedPath.isEmpty else { return }

        let normalizedURL = URL(fileURLWithPath: trimmedPath, isDirectory: true).standardizedFileURL
        let trimmedLabel = label.trimmingCharacters(in: .whitespacesAndNewlines)
        let finalLabel = trimmedLabel.isEmpty ? normalizedURL.lastPathComponent : trimmedLabel

        let source = StoredProfileSource(
            id: UUID(),
            provider: provider,
            label: finalLabel,
            profileRootPath: normalizedURL.path,
            isEnabled: true,
            addedAt: Date()
        )

        guard !self.storedProfileSources.contains(where: {
            $0.provider == source.provider && URL(fileURLWithPath: $0.profileRootPath).standardizedFileURL == normalizedURL
        }) else { return }

        self.storedProfileSources.append(source)
        try? self.profileSourceStore.saveSources(self.storedProfileSources)
        self.refreshDiscoveredProfiles()
    }

    func removeStoredProfileSource(id: UUID) {
        self.storedProfileSources.removeAll { $0.id == id }
        try? self.profileSourceStore.saveSources(self.storedProfileSources)
        self.refreshDiscoveredProfiles()
    }

    private func mergedAccounts(liveAccounts: [QuotaAccount]) -> [QuotaAccount] {
        let liveProviders = Set(liveAccounts.map(\.provider))
        let retained = self.accounts.filter { !liveProviders.contains($0.provider) }
        return retained + liveAccounts
    }
}
