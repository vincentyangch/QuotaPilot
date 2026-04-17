import Foundation
import Observation
import QuotaPilotCore

@MainActor
@Observable
final class AppModel {
    private let engine = RecommendationEngine()
    private let ambientUsageLoader: AmbientUsageLoader
    private let profileActivator: LocalProfileActivator
    private let profileDiscovery: LocalProfileDiscovery
    private let currentProfileSelectionStore: CurrentProfileSelectionStoring
    private let profileSourceStore: StoredProfileSourceStoring
    private let rulesStorage: GlobalRulesStorage
    private var didAttemptInitialRefresh = false
    private let homeURL: URL

    var accounts: [QuotaAccount]
    var currentProfileSelections: [QuotaProvider: String]
    var discoveredProfiles: [DiscoveredLocalProfile]
    var storedProfileSources: [StoredProfileSource]
    var isActivatingProfile = false
    var isRefreshingUsage = false
    var lastProfileActionSummary: String?
    var lastUsageRefreshSummary: String
    var rules: GlobalRules {
        didSet {
            self.rulesStorage.save(self.rules)
        }
    }

    init(
        accounts: [QuotaAccount] = DemoAccountRepository.makeAccounts(),
        ambientUsageLoader: AmbientUsageLoader = AmbientUsageLoader(),
        profileActivator: LocalProfileActivator = LocalProfileActivator(),
        profileDiscovery: LocalProfileDiscovery = LocalProfileDiscovery(),
        currentProfileSelectionStore: CurrentProfileSelectionStoring = FileCurrentProfileSelectionStore(),
        profileSourceStore: StoredProfileSourceStoring = FileStoredProfileSourceStore(),
        rulesStorage: GlobalRulesStorage = GlobalRulesStorage(),
        homeURL: URL = FileManager.default.homeDirectoryForCurrentUser,
        rules: GlobalRules? = nil
    ) {
        self.ambientUsageLoader = ambientUsageLoader
        self.profileActivator = profileActivator
        self.profileDiscovery = profileDiscovery
        self.currentProfileSelectionStore = currentProfileSelectionStore
        self.profileSourceStore = profileSourceStore
        self.rulesStorage = rulesStorage
        self.homeURL = homeURL
        let storedSources = (try? profileSourceStore.loadSources()) ?? []
        let currentSelections = (try? currentProfileSelectionStore.loadSelections()) ?? [:]
        let candidates = ProfileSourceCatalog.makeCandidates(
            homeURL: homeURL,
            storedSources: storedSources,
            preferredSelections: currentSelections
        )
        let discoveredProfiles = profileDiscovery.discover(candidates: candidates)
        self.accounts = accounts
        self.currentProfileSelections = currentSelections
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

    var trackedProfileInventoryItems: [TrackedProfileInventoryItem] {
        TrackedProfileInventoryBuilder.makeItems(
            discoveredProfiles: self.discoveredProfiles,
            liveAccounts: self.accounts,
            currentProfileRootPaths: self.resolvedCurrentProfilePaths
        )
    }

    func recommendationActivationOption(for provider: QuotaProvider) -> RecommendationActivationOption? {
        guard let recommendation = self.recommendation(for: provider) else { return nil }
        return RecommendationActivationPlanner.makeOption(
            recommendation: recommendation,
            discoveredProfiles: self.discoveredProfiles,
            currentProfileRootPaths: self.resolvedCurrentProfilePaths
        )
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
        self.currentProfileSelections = (try? self.currentProfileSelectionStore.loadSelections()) ?? self.currentProfileSelections
        let candidates = ProfileSourceCatalog.makeCandidates(
            homeURL: self.homeURL,
            storedSources: self.storedProfileSources,
            preferredSelections: self.currentProfileSelections
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

        let result = await self.ambientUsageLoader.loadAccounts(
            from: self.discoveredProfiles,
            currentProfileRootPaths: self.resolvedCurrentProfilePaths
        )

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
        guard let normalizedInput = ProfileSourceInputNormalizer.normalize(
            provider: provider,
            label: label,
            path: path
        ) else { return }

        let source = StoredProfileSource(
            id: UUID(),
            provider: normalizedInput.provider,
            label: normalizedInput.label,
            profileRootPath: normalizedInput.normalizedPath,
            isEnabled: true,
            addedAt: Date()
        )

        guard !self.storedProfileSources.contains(where: {
            $0.provider == source.provider
                && URL(fileURLWithPath: $0.profileRootPath).standardizedFileURL.path == source.profileRootPath
        }) else { return }

        self.storedProfileSources.append(source)
        try? self.profileSourceStore.saveSources(self.storedProfileSources)
        self.refreshDiscoveredProfiles()
    }

    func selectCurrentProfile(_ profile: DiscoveredLocalProfile) {
        self.currentProfileSelections[profile.provider] = profile.profileRootURL.standardizedFileURL.path
        try? self.currentProfileSelectionStore.saveSelections(self.currentProfileSelections)
        self.refreshDiscoveredProfiles()
    }

    func activateProfile(_ profile: DiscoveredLocalProfile) async {
        self.isActivatingProfile = true
        defer { self.isActivatingProfile = false }

        do {
            let result = try self.profileActivator.activate(profile: profile)
            if let backupSource = result.createdBackupSource,
               !self.storedProfileSources.contains(where: {
                   $0.provider == backupSource.provider
                       && URL(fileURLWithPath: $0.profileRootPath, isDirectory: true).standardizedFileURL.path
                       == backupSource.profileRootURL.standardizedFileURL.path
               })
            {
                self.storedProfileSources.append(backupSource)
                try? self.profileSourceStore.saveSources(self.storedProfileSources)
            }

            self.currentProfileSelections[profile.provider] = result.activatedProfileRootPath
            try? self.currentProfileSelectionStore.saveSelections(self.currentProfileSelections)
            self.lastProfileActionSummary = "Activated \(profile.label) for \(profile.provider.displayName)."
            await self.refreshLiveUsage()
        } catch {
            self.lastProfileActionSummary = "Could not activate \(profile.label): \(error.localizedDescription)"
        }
    }

    func activateProfile(provider: QuotaProvider, profileRootPath: String) async {
        guard let profile = self.discoveredProfiles.first(where: {
            $0.provider == provider
                && $0.profileRootURL.standardizedFileURL.path
                == URL(fileURLWithPath: profileRootPath, isDirectory: true).standardizedFileURL.path
        }) else {
            self.lastProfileActionSummary = "Could not find that profile to activate."
            return
        }
        await self.activateProfile(profile)
    }

    func activateRecommendedProfile(for provider: QuotaProvider) async {
        guard let option = self.recommendationActivationOption(for: provider) else {
            self.lastProfileActionSummary = "No activatable recommendation is available for \(provider.displayName)."
            return
        }

        guard option.isActivatable else {
            self.lastProfileActionSummary = option.reason
            return
        }

        await self.activateProfile(provider: provider, profileRootPath: option.profileRootPath)
    }

    func removeStoredProfileSource(id: UUID) {
        let removed = self.storedProfileSources.first(where: { $0.id == id })
        self.storedProfileSources.removeAll { $0.id == id }
        if let removed,
           self.currentProfileSelections[removed.provider] == removed.profileRootURL.standardizedFileURL.path
        {
            self.currentProfileSelections.removeValue(forKey: removed.provider)
            try? self.currentProfileSelectionStore.saveSelections(self.currentProfileSelections)
        }
        try? self.profileSourceStore.saveSources(self.storedProfileSources)
        self.refreshDiscoveredProfiles()
    }

    func isCurrentProfile(_ profile: DiscoveredLocalProfile) -> Bool {
        self.resolvedCurrentProfilePaths[profile.provider] == profile.profileRootURL.standardizedFileURL.path
    }

    private func mergedAccounts(liveAccounts: [QuotaAccount]) -> [QuotaAccount] {
        let liveProviders = Set(liveAccounts.map(\.provider))
        let retained = self.accounts.filter { !liveProviders.contains($0.provider) }
        return retained + liveAccounts
    }

    private var resolvedCurrentProfilePaths: [QuotaProvider: String] {
        CurrentProfileResolver.resolve(
            discoveredProfiles: self.discoveredProfiles,
            preferredSelections: self.currentProfileSelections
        )
    }
}
