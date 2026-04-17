import Foundation
import Observation
import QuotaPilotCore
#if canImport(WidgetKit)
import WidgetKit
#endif

@MainActor
@Observable
final class AppModel {
    private let activityLogStore: ActivityLogStore
    private let engine = RecommendationEngine()
    private let ambientUsageLoader: AmbientUsageLoader
    private let backgroundRefreshSettingsStorage: BackgroundRefreshSettingsStorage
    private let profileActivator: LocalProfileActivator
    private let profileDiscovery: LocalProfileDiscovery
    private let recommendationAlertNotifier: RecommendationAlertNotifying
    private let recommendationAlertSettingsStorage: RecommendationAlertSettingsStorage
    private let recommendationAlertStateStore: RecommendationAlertStateStore
    private let switchActionModeStorage: SwitchActionModeStorage
    private let currentProfileSelectionStore: CurrentProfileSelectionStoring
    private let profileSourceStore: StoredProfileSourceStoring
    private let rulesStorage: GlobalRulesStorage
    private let widgetSnapshotStore: QuotaPilotWidgetSnapshotStore
    private var backgroundRefreshTask: Task<Void, Never>?
    private var didAttemptInitialRefresh = false
    private var didStartAppServices = false
    private let homeURL: URL

    var accounts: [QuotaAccount]
    var activityLogEntries: [ActivityLogEntry]
    var backgroundRefreshSettings: BackgroundRefreshSettings
    var currentProfileSelections: [QuotaProvider: String]
    var discoveredProfiles: [DiscoveredLocalProfile]
    var lastRecommendationAlertSummary: String?
    var pendingSwitchConfirmations: [QuotaProvider: RecommendationActivationOption]
    var recommendationAlertSettings: RecommendationAlertSettings
    var switchActionMode: SwitchActionMode
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
        activityLogStore: ActivityLogStore = ActivityLogStore(),
        accounts: [QuotaAccount] = DemoAccountRepository.makeAccounts(),
        ambientUsageLoader: AmbientUsageLoader = AmbientUsageLoader(),
        backgroundRefreshSettingsStorage: BackgroundRefreshSettingsStorage = BackgroundRefreshSettingsStorage(),
        profileActivator: LocalProfileActivator = LocalProfileActivator(),
        profileDiscovery: LocalProfileDiscovery = LocalProfileDiscovery(),
        recommendationAlertNotifier: RecommendationAlertNotifying = UserNotificationRecommendationAlertNotifier(),
        recommendationAlertSettingsStorage: RecommendationAlertSettingsStorage = RecommendationAlertSettingsStorage(),
        recommendationAlertStateStore: RecommendationAlertStateStore = RecommendationAlertStateStore(),
        switchActionModeStorage: SwitchActionModeStorage = SwitchActionModeStorage(),
        currentProfileSelectionStore: CurrentProfileSelectionStoring = FileCurrentProfileSelectionStore(),
        profileSourceStore: StoredProfileSourceStoring = FileStoredProfileSourceStore(),
        rulesStorage: GlobalRulesStorage = GlobalRulesStorage(),
        widgetSnapshotStore: QuotaPilotWidgetSnapshotStore = QuotaPilotWidgetSnapshotStore(),
        homeURL: URL = FileManager.default.homeDirectoryForCurrentUser,
        rules: GlobalRules? = nil
    ) {
        self.activityLogStore = activityLogStore
        self.ambientUsageLoader = ambientUsageLoader
        self.backgroundRefreshSettingsStorage = backgroundRefreshSettingsStorage
        self.profileActivator = profileActivator
        self.profileDiscovery = profileDiscovery
        self.recommendationAlertNotifier = recommendationAlertNotifier
        self.recommendationAlertSettingsStorage = recommendationAlertSettingsStorage
        self.recommendationAlertStateStore = recommendationAlertStateStore
        self.switchActionModeStorage = switchActionModeStorage
        self.currentProfileSelectionStore = currentProfileSelectionStore
        self.profileSourceStore = profileSourceStore
        self.rulesStorage = rulesStorage
        self.widgetSnapshotStore = widgetSnapshotStore
        self.homeURL = homeURL
        let storedSources = (try? profileSourceStore.loadSources()) ?? []
        let currentSelections = (try? currentProfileSelectionStore.loadSelections()) ?? [:]
        let candidates = ProfileSourceCatalog.makeCandidates(
            homeURL: homeURL,
            storedSources: storedSources,
            preferredSelections: currentSelections
        )
        let discoveredProfiles = profileDiscovery.discover(candidates: candidates)
        let activityLogEntries = ((try? activityLogStore.loadEntries()) ?? []).sorted {
            $0.timestamp > $1.timestamp
        }
        self.accounts = accounts
        self.activityLogEntries = activityLogEntries
        self.backgroundRefreshSettings = backgroundRefreshSettingsStorage.load()
        self.currentProfileSelections = currentSelections
        self.discoveredProfiles = discoveredProfiles
        self.lastRecommendationAlertSummary = nil
        self.pendingSwitchConfirmations = [:]
        self.recommendationAlertSettings = recommendationAlertSettingsStorage.load()
        self.switchActionMode = switchActionModeStorage.load()
        self.storedProfileSources = storedSources
        self.rules = rules ?? rulesStorage.load()
        self.lastUsageRefreshSummary = discoveredProfiles.isEmpty
            ? "No local profiles found. Showing demo data."
            : "Ambient profiles found. Refresh to load live usage."
        self.persistWidgetSnapshot()
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
        self.persistWidgetSnapshot()
        self.recordActivity(
            kind: .refreshSucceeded,
            provider: nil,
            title: "Reloaded demo data",
            detail: "QuotaPilot is showing demo data again."
        )
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

    func startAppServicesIfNeeded() async {
        guard !self.didStartAppServices else { return }
        self.didStartAppServices = true
        await self.performInitialLiveRefreshIfNeeded()
        self.rebuildBackgroundRefreshLoop()
    }

    func refreshLiveUsage() async {
        guard !self.isRefreshingUsage else { return }
        self.isRefreshingUsage = true
        var pendingAutomaticActivations: [RecommendationActivationOption] = []
        var pendingConfirmationUpdates: [QuotaProvider: RecommendationActivationOption] = [:]
        self.refreshDiscoveredProfiles()
        defer {
            self.isRefreshingUsage = false
            if !pendingConfirmationUpdates.isEmpty {
                for (provider, option) in pendingConfirmationUpdates {
                    self.pendingSwitchConfirmations[provider] = option
                }
            }
            if !pendingAutomaticActivations.isEmpty {
                Task { @MainActor [weak self] in
                    guard let self else { return }
                    for option in pendingAutomaticActivations {
                        await self.activateProfile(provider: option.provider, profileRootPath: option.profileRootPath)
                    }
                }
            }
        }

        guard !self.discoveredProfiles.isEmpty else {
            self.lastUsageRefreshSummary = "No local profiles found. Showing demo data."
            self.recordActivity(
                kind: .refreshFailed,
                provider: nil,
                title: "Refresh skipped",
                detail: self.lastUsageRefreshSummary
            )
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
            self.recordActivity(
                kind: .refreshFailed,
                provider: nil,
                title: "Refresh failed",
                detail: self.lastUsageRefreshSummary
            )
        } else if result.failures.isEmpty {
            self.lastUsageRefreshSummary = "Loaded live usage for \(result.accounts.count) local profile(s)."
            self.recordActivity(
                kind: .refreshSucceeded,
                provider: nil,
                title: "Refresh succeeded",
                detail: self.lastUsageRefreshSummary
            )
        } else {
            self.lastUsageRefreshSummary = "Loaded \(result.accounts.count) live profile(s); \(result.failures.count) refresh failed."
            self.recordActivity(
                kind: .refreshFailed,
                provider: nil,
                title: "Refresh partially failed",
                detail: self.lastUsageRefreshSummary
            )
        }

        self.persistWidgetSnapshot()
        let switchPlan = self.planSwitchActions()
        pendingAutomaticActivations = switchPlan.automaticActivations
        pendingConfirmationUpdates = Dictionary(uniqueKeysWithValues: switchPlan.confirmationsToPresent.map { ($0.provider, $0) })
        if !switchPlan.confirmationsToPresent.isEmpty {
            self.lastProfileActionSummary = "Confirmation needed for \(switchPlan.confirmationsToPresent.count) recommended profile(s)."
            for option in switchPlan.confirmationsToPresent {
                self.recordActivity(
                    kind: .confirmationQueued,
                    provider: option.provider,
                    title: "Confirmation needed",
                    detail: "Review whether to switch to \(option.accountLabel)."
                )
            }
        }

        if pendingAutomaticActivations.isEmpty {
            await self.syncRecommendationAlerts()
        } else {
            self.lastProfileActionSummary = "Auto-activating \(pendingAutomaticActivations.count) recommended profile(s)."
            for option in pendingAutomaticActivations {
                self.recordActivity(
                    kind: .autoActivationQueued,
                    provider: option.provider,
                    title: "Auto-activation queued",
                    detail: "QuotaPilot will activate \(option.accountLabel) after refresh."
                )
            }
        }
    }

    func updateSwitchThreshold(_ value: Int) {
        self.rules = self.rules.updating(switchThresholdPercent: value)
        self.persistWidgetSnapshot()
    }

    func updateMinimumScoreAdvantage(_ value: Int) {
        self.rules = self.rules.updating(minimumScoreAdvantage: value)
        self.persistWidgetSnapshot()
    }

    func updateRemainingWeight(_ value: Int) {
        self.rules = self.rules.updating(remainingWeight: value)
        self.persistWidgetSnapshot()
    }

    func updateResetWeight(_ value: Int) {
        self.rules = self.rules.updating(resetWeight: value)
        self.persistWidgetSnapshot()
    }

    func updatePriorityWeight(_ value: Int) {
        self.rules = self.rules.updating(priorityWeight: value)
        self.persistWidgetSnapshot()
    }

    func resetRules() {
        self.rules = .default
        self.persistWidgetSnapshot()
    }

    func updateRecommendationAlertsEnabled(_ isEnabled: Bool) {
        self.recommendationAlertSettings = RecommendationAlertSettings(isEnabled: isEnabled)
        self.recommendationAlertSettingsStorage.save(self.recommendationAlertSettings)

        if !isEnabled {
            try? self.recommendationAlertStateStore.saveState([:])
            self.lastRecommendationAlertSummary = "Recommendation alerts disabled."
        } else {
            self.lastRecommendationAlertSummary = "Recommendation alerts will appear when a new switch suggestion is detected."
        }
    }

    func updateSwitchActionMode(_ mode: SwitchActionMode) {
        self.switchActionMode = mode
        self.switchActionModeStorage.save(mode)
        if mode != .confirmBeforeActivatingLocalProfiles {
            self.pendingSwitchConfirmations = [:]
        }
    }

    func updateBackgroundRefreshEnabled(_ isEnabled: Bool) {
        self.backgroundRefreshSettings = BackgroundRefreshSettings(
            isEnabled: isEnabled,
            intervalMinutes: self.backgroundRefreshSettings.intervalMinutes
        )
        self.backgroundRefreshSettingsStorage.save(self.backgroundRefreshSettings)
        self.rebuildBackgroundRefreshLoop()
    }

    func updateBackgroundRefreshInterval(_ minutes: Int) {
        self.backgroundRefreshSettings = BackgroundRefreshSettings(
            isEnabled: self.backgroundRefreshSettings.isEnabled,
            intervalMinutes: minutes
        )
        self.backgroundRefreshSettingsStorage.save(self.backgroundRefreshSettings)
        self.rebuildBackgroundRefreshLoop()
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
            self.recordActivity(
                kind: .activationSucceeded,
                provider: profile.provider,
                title: "Activated profile",
                detail: "Activated \(profile.label) for \(profile.provider.displayName)."
            )
            await self.refreshLiveUsage()
        } catch {
            self.lastProfileActionSummary = "Could not activate \(profile.label): \(error.localizedDescription)"
            self.recordActivity(
                kind: .activationFailed,
                provider: profile.provider,
                title: "Activation failed",
                detail: self.lastProfileActionSummary ?? "Activation failed."
            )
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

    func approvePendingSwitch(for provider: QuotaProvider) async {
        guard let option = self.pendingSwitchConfirmations[provider] else {
            self.lastProfileActionSummary = "No pending switch confirmation for \(provider.displayName)."
            return
        }

        self.pendingSwitchConfirmations.removeValue(forKey: provider)
        if let candidate = self.recommendationCandidatesByProvider[provider] {
            var state = (try? self.recommendationAlertStateStore.loadState()) ?? [:]
            state[provider] = candidate.identifier
            try? self.recommendationAlertStateStore.saveState(state)
        }
        self.recordActivity(
            kind: .confirmationApproved,
            provider: provider,
            title: "Approved switch",
            detail: "Approved the pending \(provider.displayName) switch."
        )
        await self.activateProfile(provider: provider, profileRootPath: option.profileRootPath)
    }

    func dismissPendingSwitch(for provider: QuotaProvider) {
        guard self.pendingSwitchConfirmations.removeValue(forKey: provider) != nil else { return }
        if let candidate = self.recommendationCandidatesByProvider[provider] {
            var state = (try? self.recommendationAlertStateStore.loadState()) ?? [:]
            state[provider] = candidate.identifier
            try? self.recommendationAlertStateStore.saveState(state)
        }
        self.lastProfileActionSummary = "Dismissed the pending \(provider.displayName) switch request."
        self.recordActivity(
            kind: .confirmationDismissed,
            provider: provider,
            title: "Dismissed switch",
            detail: self.lastProfileActionSummary ?? "Dismissed switch."
        )
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

    private func persistWidgetSnapshot() {
        let snapshot = QuotaPilotWidgetSnapshot(
            generatedAt: .now,
            accounts: self.accounts,
            rules: self.rules,
            lastUsageRefreshSummary: self.lastUsageRefreshSummary
        )
        try? self.widgetSnapshotStore.save(snapshot)
        #if canImport(WidgetKit)
        WidgetCenter.shared.reloadAllTimelines()
        #endif
    }

    private func syncRecommendationAlerts() async {
        guard self.recommendationAlertSettings.isEnabled else { return }

        let candidates = RecommendationAlertPlanner.makeCandidates(recommendations: self.providerRecommendations)
        let previousState = (try? self.recommendationAlertStateStore.loadState()) ?? [:]
        var nextState: [QuotaProvider: String] = [:]
        var deliveredProviders: [String] = []

        for candidate in candidates {
            if previousState[candidate.provider] == candidate.identifier {
                nextState[candidate.provider] = candidate.identifier
                continue
            }

            let delivered = await self.recommendationAlertNotifier.deliver(candidate)
            if delivered {
                nextState[candidate.provider] = candidate.identifier
                deliveredProviders.append(candidate.provider.displayName)
            }
        }

        try? self.recommendationAlertStateStore.saveState(nextState)

        if deliveredProviders.isEmpty {
            self.lastRecommendationAlertSummary = "No new recommendation alerts were sent."
        } else {
            self.lastRecommendationAlertSummary = "Sent recommendation alert for \(deliveredProviders.joined(separator: ", "))."
            for providerName in deliveredProviders {
                let provider = QuotaProvider.allCases.first(where: { $0.displayName == providerName })
                self.recordActivity(
                    kind: .alertSent,
                    provider: provider,
                    title: "Sent recommendation alert",
                    detail: "Sent a recommendation alert for \(providerName)."
                )
            }
        }
    }

    private func rebuildBackgroundRefreshLoop() {
        self.backgroundRefreshTask?.cancel()
        self.backgroundRefreshTask = nil

        guard self.backgroundRefreshSettings.isEnabled else { return }

        let intervalNanoseconds = UInt64(self.backgroundRefreshSettings.intervalMinutes) * 60 * 1_000_000_000
        self.backgroundRefreshTask = Task { [weak self] in
            while !Task.isCancelled {
                do {
                    try await Task.sleep(nanoseconds: intervalNanoseconds)
                } catch {
                    return
                }

                guard let self else { return }
                await self.refreshLiveUsage()
            }
        }
    }

    private var recommendationCandidatesByProvider: [QuotaProvider: RecommendationAlertCandidate] {
        Dictionary(
            uniqueKeysWithValues: RecommendationAlertPlanner
                .makeCandidates(recommendations: self.providerRecommendations)
                .map { ($0.provider, $0) }
        )
    }

    private var activationOptionsByProvider: [QuotaProvider: RecommendationActivationOption] {
        Dictionary(
            uniqueKeysWithValues: QuotaProvider.allCases.compactMap { provider in
                guard let option = self.recommendationActivationOption(for: provider) else { return nil }
                return (provider, option)
            }
        )
    }

    private func planSwitchActions() -> SwitchActionPlan {
        let previousState = (try? self.recommendationAlertStateStore.loadState()) ?? [:]
        let plan = SwitchActionPlanner.makePlan(
            mode: self.switchActionMode,
            activationOptionsByProvider: self.activationOptionsByProvider,
            recommendationCandidatesByProvider: self.recommendationCandidatesByProvider,
            handledRecommendationIDsByProvider: previousState,
            pendingConfirmationIDsByProvider: Dictionary(
                uniqueKeysWithValues: self.pendingSwitchConfirmations.compactMap { provider, _ in
                    guard let candidate = self.recommendationCandidatesByProvider[provider] else { return nil }
                    return (provider, candidate.identifier)
                }
            )
        )

        if !plan.automaticActivations.isEmpty {
            var nextState = previousState
            for option in plan.automaticActivations {
                if let candidate = self.recommendationCandidatesByProvider[option.provider] {
                    nextState[option.provider] = candidate.identifier
                }
            }
            try? self.recommendationAlertStateStore.saveState(nextState)
        }

        return plan
    }

    private func recordActivity(
        kind: ActivityLogKind,
        provider: QuotaProvider?,
        title: String,
        detail: String
    ) {
        let entry = ActivityLogEntry(
            id: UUID(),
            timestamp: .now,
            kind: kind,
            provider: provider,
            title: title,
            detail: detail
        )
        self.activityLogEntries.insert(entry, at: 0)
        let entriesForPersistence = self.activityLogEntries.sorted { $0.timestamp < $1.timestamp }
        try? self.activityLogStore.saveEntries(entriesForPersistence)
    }
}
