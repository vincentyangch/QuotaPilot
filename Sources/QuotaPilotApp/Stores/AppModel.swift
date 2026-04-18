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
    private let launchAtLoginController: LaunchAtLoginControlling
    private let profileActivator: LocalProfileActivator
    private let profileDiscovery: LocalProfileDiscovery
    private let recommendationAlertNotifier: RecommendationAlertNotifying
    private let recommendationAlertSettingsStorage: RecommendationAlertSettingsStorage
    private let recommendationAlertStateStore: RecommendationAlertStateStore
    private let startupBehaviorStorage: StartupBehaviorStorage
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
    var automaticActivationRecoveryIssues: [QuotaProvider: AutomaticActivationRecoveryIssue]
    var backgroundRefreshSettings: BackgroundRefreshSettings
    var currentProfileSelections: [QuotaProvider: String]
    var discoveredProfiles: [DiscoveredLocalProfile]
    var lastAmbientRefreshFailures: [AmbientUsageRefreshFailure]
    var lastRecommendationAlertSummary: String?
    var launchAtLoginStatus: LaunchAtLoginStatus
    var launchSettingsSummary: String?
    var pendingSwitchConfirmations: [QuotaProvider: RecommendationActivationOption]
    var recommendationAlertSettings: RecommendationAlertSettings
    var isLaunchAtLoginEnabled: Bool
    var startupBehavior: StartupBehavior
    var switchActionMode: SwitchActionMode
    var storedProfileSources: [StoredProfileSource]
    var isActivatingProfile = false
    var isRefreshingUsage = false
    var isShowingStaleAccounts = false
    var lastProfileActionSummary: String?
    var lastUsageRefreshSummary: String
    var rules: GlobalRules {
        didSet {
            self.rulesStorage.save(self.rules)
        }
    }

    init(
        activityLogStore: ActivityLogStore = ActivityLogStore(),
        accounts: [QuotaAccount] = [],
        ambientUsageLoader: AmbientUsageLoader = AmbientUsageLoader(),
        backgroundRefreshSettingsStorage: BackgroundRefreshSettingsStorage = BackgroundRefreshSettingsStorage(),
        launchAtLoginController: LaunchAtLoginControlling = LaunchAtLoginController(),
        profileActivator: LocalProfileActivator = LocalProfileActivator(),
        profileDiscovery: LocalProfileDiscovery = LocalProfileDiscovery(),
        recommendationAlertNotifier: RecommendationAlertNotifying = UserNotificationRecommendationAlertNotifier(),
        recommendationAlertSettingsStorage: RecommendationAlertSettingsStorage = RecommendationAlertSettingsStorage(),
        recommendationAlertStateStore: RecommendationAlertStateStore = RecommendationAlertStateStore(),
        startupBehaviorStorage: StartupBehaviorStorage = StartupBehaviorStorage(),
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
        self.launchAtLoginController = launchAtLoginController
        self.profileActivator = profileActivator
        self.profileDiscovery = profileDiscovery
        self.recommendationAlertNotifier = recommendationAlertNotifier
        self.recommendationAlertSettingsStorage = recommendationAlertSettingsStorage
        self.recommendationAlertStateStore = recommendationAlertStateStore
        self.startupBehaviorStorage = startupBehaviorStorage
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
        self.automaticActivationRecoveryIssues = [:]
        self.backgroundRefreshSettings = backgroundRefreshSettingsStorage.load()
        self.currentProfileSelections = currentSelections
        self.discoveredProfiles = discoveredProfiles
        self.lastAmbientRefreshFailures = []
        self.lastRecommendationAlertSummary = nil
        self.launchAtLoginStatus = launchAtLoginController.status
        self.launchSettingsSummary = nil
        self.pendingSwitchConfirmations = [:]
        self.isLaunchAtLoginEnabled = launchAtLoginController.isEnabled
        self.recommendationAlertSettings = recommendationAlertSettingsStorage.load()
        self.startupBehavior = startupBehaviorStorage.load()
        self.switchActionMode = switchActionModeStorage.load()
        self.storedProfileSources = storedSources
        self.rules = rules ?? rulesStorage.load()
        self.lastUsageRefreshSummary = discoveredProfiles.isEmpty
            ? "No local profiles found yet. Add a Codex or Claude profile in Settings."
            : "Ambient profiles found. Refresh to load live usage."
        self.persistWidgetSnapshot()
    }

    var providerRecommendations: [RecommendationEngine.ProviderRecommendation] {
        self.engine.recommendationsByProvider(accounts: self.accounts, rules: self.rules)
    }

    var globalRecommendation: RecommendationEngine.GlobalRecommendation? {
        self.engine.globalRecommendation(accounts: self.accounts, rules: self.rules)
    }

    var globalRecommendationActivationOption: RecommendationActivationOption? {
        RecommendationActivationPlanner.makeOption(
            recommendation: self.globalRecommendation,
            discoveredProfiles: self.discoveredProfiles,
            currentProfileRootPaths: self.resolvedCurrentProfilePaths
        )
    }

    var globalGuidedDesktopHandoffPlan: GuidedDesktopHandoffPlan? {
        GuidedDesktopHandoffPlanner.makePlan(
            recommendation: self.globalRecommendation,
            activationOption: self.globalRecommendationActivationOption,
            switchActionMode: self.switchActionMode
        )
    }

    var latestBackupRestoreEntry: ActivityLogEntry? {
        self.activityLogEntries.first(where: \.isBackupRestore)
    }

    var trackedProfileInventoryItems: [TrackedProfileInventoryItem] {
        TrackedProfileInventoryBuilder.makeItems(
            discoveredProfiles: self.discoveredProfiles,
            liveAccounts: self.accounts,
            failures: self.lastAmbientRefreshFailures,
            currentProfileRootPaths: self.resolvedCurrentProfilePaths
        )
    }

    var providerHealthSummaries: [ProviderHealthSummary] {
        ProviderHealthSummaryBuilder.makeSummaries(
            discoveredProfiles: self.discoveredProfiles,
            liveAccounts: self.accounts,
            failures: self.lastAmbientRefreshFailures,
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

    func guidedDesktopHandoffPlan(for provider: QuotaProvider) -> GuidedDesktopHandoffPlan? {
        GuidedDesktopHandoffPlanner.makePlan(
            recommendation: self.recommendation(for: provider),
            activationOption: self.recommendationActivationOption(for: provider),
            switchActionMode: self.switchActionMode
        )
    }

    var recommendedAccountIDs: Set<UUID> {
        Set(self.globalRecommendation.map { [$0.decision.recommendedAccountID] } ?? [])
    }

    var hasLiveAccounts: Bool {
        !self.accounts.isEmpty
    }

    var isStartingUp: Bool {
        !self.didStartAppServices || self.isRefreshingUsage
    }

    var liveAccountsEmptyStateTitle: String {
        self.discoveredProfiles.isEmpty ? "No Local Profiles Yet" : "No Live Usage Loaded Yet"
    }

    var liveAccountsEmptyStateDetail: String {
        if self.discoveredProfiles.isEmpty {
            return "Add a Codex or Claude profile in Settings to start tracking real usage."
        }
        return "QuotaPilot found local profiles, but it has not loaded live usage yet. Refresh usage or review provider health below."
    }

    var staleAccountsWarningText: String {
        "QuotaPilot could not refresh live usage and is showing the last successful account snapshot."
    }

    func recommendation(for provider: QuotaProvider) -> RecommendationEngine.ProviderRecommendation? {
        self.providerRecommendations.first(where: { $0.provider == provider })
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

    @discardableResult
    func refreshLiveUsage(planPostRefreshActions: Bool = true) async -> AmbientUsageRefreshResult? {
        guard !self.isRefreshingUsage else { return nil }
        self.isRefreshingUsage = true
        var pendingAutomaticActivations: [RecommendationActivationOption] = []
        var pendingConfirmationUpdates: [QuotaProvider: RecommendationActivationOption] = [:]
        self.refreshDiscoveredProfiles()
        defer {
            self.isRefreshingUsage = false
            if planPostRefreshActions {
                self.pendingSwitchConfirmations = pendingConfirmationUpdates
            }
            if !pendingAutomaticActivations.isEmpty {
                Task { @MainActor [weak self] in
                    guard let self else { return }
                    for option in pendingAutomaticActivations {
                        await self.activateProfile(
                            provider: option.provider,
                            profileRootPath: option.profileRootPath,
                            verificationOption: option
                        )
                    }
                }
            }
        }

        guard !self.discoveredProfiles.isEmpty else {
            self.accounts = []
            self.isShowingStaleAccounts = false
            self.lastAmbientRefreshFailures = []
            self.pendingSwitchConfirmations = [:]
            self.automaticActivationRecoveryIssues = [:]
            self.lastUsageRefreshSummary = "No local profiles found yet. Add a Codex or Claude profile in Settings."
            self.persistWidgetSnapshot()
            return nil
        }

        let result = await self.ambientUsageLoader.loadAccounts(
            from: self.discoveredProfiles,
            currentProfileRootPaths: self.resolvedCurrentProfilePaths
        )
        self.lastAmbientRefreshFailures = result.failures

        if !result.accounts.isEmpty {
            self.accounts = self.mergedAccounts(liveAccounts: result.accounts)
            self.reconcileAutomaticActivationRecoveryIssues(refreshedAccounts: result.accounts)
            self.isShowingStaleAccounts = false
        }

        if result.accounts.isEmpty {
            self.isShowingStaleAccounts = !self.accounts.isEmpty
            self.lastUsageRefreshSummary = self.isShowingStaleAccounts
                ? self.staleAccountsWarningText
                : "Could not load live usage from local profiles."
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
        if planPostRefreshActions {
            let switchPlan = self.planSwitchActions()
            pendingAutomaticActivations = switchPlan.automaticActivations
            pendingConfirmationUpdates = Dictionary(uniqueKeysWithValues: switchPlan.confirmationsToPresent.map { ($0.provider, $0) })
            if !switchPlan.confirmationsToPresent.isEmpty {
                if let option = switchPlan.confirmationsToPresent.first {
                    self.lastProfileActionSummary = "Confirmation needed to switch to \(option.accountLabel)."
                }
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
                if let option = pendingAutomaticActivations.first {
                    self.lastProfileActionSummary = "Auto-activating \(option.accountLabel)."
                }
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

        return result
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

    func updateStartupBehavior(_ behavior: StartupBehavior) {
        self.startupBehavior = behavior
        self.startupBehaviorStorage.save(behavior)
        self.launchSettingsSummary = behavior.opensDashboardOnLaunch
            ? "QuotaPilot will open the dashboard when it launches."
            : "QuotaPilot will launch into the menu bar without opening the dashboard."
    }

    func updateLaunchAtLoginEnabled(_ isEnabled: Bool) {
        do {
            try self.launchAtLoginController.setEnabled(isEnabled)
        } catch {
            self.refreshLaunchAtLoginState()
            self.launchSettingsSummary = "Could not update launch at login: \(error.localizedDescription)"
            return
        }

        self.refreshLaunchAtLoginState()
        switch self.launchAtLoginStatus {
        case .enabled:
            self.launchSettingsSummary = "QuotaPilot will launch at login."
        case .requiresApproval:
            self.launchSettingsSummary = "Approve QuotaPilot in System Settings to finish enabling launch at login."
        case .disabled:
            self.launchSettingsSummary = "QuotaPilot will no longer launch at login."
        }
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
        await self.activateProfile(profile, verificationOption: nil)
    }

    private func activateProfile(
        _ profile: DiscoveredLocalProfile,
        verificationOption: RecommendationActivationOption?
    ) async {
        self.isActivatingProfile = true
        defer { self.isActivatingProfile = false }
        let restoreProvenance = profile.isManagedBackup ? self.makeRestoreProvenance(for: profile) : nil

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
            let actionVerb = profile.isManagedBackup ? "Restored" : "Activated"
            let activityTitle = profile.isManagedBackup ? "Restored backup" : "Activated profile"
            self.lastProfileActionSummary = "\(actionVerb) \(profile.label) for \(profile.provider.displayName)."
            self.recordActivity(
                kind: .activationSucceeded,
                provider: profile.provider,
                title: activityTitle,
                detail: self.lastProfileActionSummary ?? "\(actionVerb) \(profile.label) for \(profile.provider.displayName).",
                restoreProvenance: restoreProvenance
            )
            let refreshResult = await self.refreshLiveUsage(planPostRefreshActions: verificationOption == nil)
            if let verificationOption {
                self.resolveAutomaticActivationVerification(
                    option: verificationOption,
                    refreshResult: refreshResult
                )
            }
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
        await self.activateProfile(
            provider: provider,
            profileRootPath: profileRootPath,
            verificationOption: nil
        )
    }

    private func activateProfile(
        provider: QuotaProvider,
        profileRootPath: String,
        verificationOption: RecommendationActivationOption?
    ) async {
        guard let profile = self.discoveredProfiles.first(where: {
            $0.provider == provider
                && $0.profileRootURL.standardizedFileURL.path
                == URL(fileURLWithPath: profileRootPath, isDirectory: true).standardizedFileURL.path
        }) else {
            self.lastProfileActionSummary = "Could not find that profile to activate."
            return
        }
        await self.activateProfile(profile, verificationOption: verificationOption)
    }

    func activateRecommendedProfile(for provider: QuotaProvider) async {
        guard self.globalRecommendation?.recommendedAccount?.provider == provider else {
            self.lastProfileActionSummary = "No global recommendation is available for \(provider.displayName)."
            return
        }
        await self.activateRecommendedProfile()
    }

    func activateRecommendedProfile() async {
        guard let option = self.globalRecommendationActivationOption else {
            let providerName = self.globalRecommendation?.recommendedAccount?.provider.displayName ?? "the recommended provider"
            self.lastProfileActionSummary = "No activatable recommendation is available for \(providerName)."
            return
        }

        guard option.isActivatable else {
            self.lastProfileActionSummary = option.reason
            return
        }

        await self.activateProfile(provider: option.provider, profileRootPath: option.profileRootPath)
    }

    func approvePendingSwitch(for provider: QuotaProvider) async {
        guard let option = self.pendingSwitchConfirmations[provider] else {
            self.lastProfileActionSummary = "No pending switch confirmation for \(provider.displayName)."
            return
        }

        guard let latestOption = self.globalRecommendationActivationOption,
              latestOption.provider == option.provider,
              latestOption.accountID == option.accountID,
              latestOption.profileRootPath == option.profileRootPath
        else {
            self.pendingSwitchConfirmations.removeValue(forKey: provider)
            self.lastProfileActionSummary = "That switch request is no longer current."
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
            detail: "Approved the pending switch to \(option.accountLabel)."
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
        self.lastProfileActionSummary = "Dismissed the pending switch request for \(provider.displayName)."
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
        if let removed {
            do {
                try self.profileActivator.deleteManagedBackup(source: removed)
                if removed.sourceKind == .backup && removed.ownershipMode == .quotaPilotManaged {
                    self.lastProfileActionSummary = "Deleted managed backup \(removed.label)."
                }
            } catch {
                self.lastProfileActionSummary = "Could not delete managed backup \(removed.label): \(error.localizedDescription)"
            }
        }
        try? self.profileSourceStore.saveSources(self.storedProfileSources)
        self.refreshDiscoveredProfiles()
    }

    func removeTrackedProfileItem(_ item: TrackedProfileInventoryItem) {
        guard let source = self.storedProfileSources.first(where: {
            $0.provider == item.provider
                && $0.profileRootURL.standardizedFileURL.path == item.profileRootPath
        }) else { return }
        self.removeStoredProfileSource(id: source.id)
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

        guard let candidate = RecommendationAlertPlanner.makeCandidate(recommendation: self.globalRecommendation) else {
            try? self.recommendationAlertStateStore.saveState([:])
            self.lastRecommendationAlertSummary = "No new recommendation alerts were sent."
            return
        }

        let previousState = (try? self.recommendationAlertStateStore.loadState()) ?? [:]
        if previousState[candidate.provider] == candidate.identifier {
            self.lastRecommendationAlertSummary = "No new recommendation alerts were sent."
            return
        }

        let delivered = await self.recommendationAlertNotifier.deliver(candidate)
        if delivered {
            try? self.recommendationAlertStateStore.saveState([candidate.provider: candidate.identifier])
            self.lastRecommendationAlertSummary = "Sent recommendation alert for \(candidate.provider.displayName)."
            self.recordActivity(
                kind: .alertSent,
                provider: candidate.provider,
                title: "Sent recommendation alert",
                detail: "Sent a recommendation alert for \(candidate.provider.displayName)."
            )
        } else {
            self.lastRecommendationAlertSummary = "No new recommendation alerts were sent."
        }
    }

    func dismissAutomaticActivationRecoveryIssue(for provider: QuotaProvider) {
        guard self.automaticActivationRecoveryIssues.removeValue(forKey: provider) != nil else { return }
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
        guard let candidate = RecommendationAlertPlanner.makeCandidate(recommendation: self.globalRecommendation) else {
            return [:]
        }
        return [candidate.provider: candidate]
    }

    private var activationOptionsByProvider: [QuotaProvider: RecommendationActivationOption] {
        guard let option = self.globalRecommendationActivationOption else {
            return [:]
        }
        return [option.provider: option]
    }

    private func planSwitchActions() -> SwitchActionPlan {
        let previousState = (try? self.recommendationAlertStateStore.loadState()) ?? [:]
        let activationOptionsByProvider = self.activationOptionsByProvider.filter { provider, _ in
            self.automaticActivationRecoveryIssues[provider] == nil
        }
        let plan = SwitchActionPlanner.makePlan(
            mode: self.switchActionMode,
            activationOptionsByProvider: activationOptionsByProvider,
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
        detail: String,
        restoreProvenance: ActivityLogRestoreProvenance? = nil
    ) {
        let entry = ActivityLogEntry(
            id: UUID(),
            timestamp: .now,
            kind: kind,
            provider: provider,
            title: title,
            detail: detail,
            restoreProvenance: restoreProvenance
        )
        self.activityLogEntries.insert(entry, at: 0)
        let entriesForPersistence = self.activityLogEntries.sorted { $0.timestamp < $1.timestamp }
        try? self.activityLogStore.saveEntries(entriesForPersistence)
    }

    private func makeRestoreProvenance(for profile: DiscoveredLocalProfile) -> ActivityLogRestoreProvenance {
        let sourceProfile = self.profileReference(
            provider: profile.provider,
            profileRootPath: profile.profileRootURL.standardizedFileURL.path
        )
        let replacedProfile = self.resolvedCurrentProfilePaths[profile.provider].map {
            self.profileReference(provider: profile.provider, profileRootPath: $0)
        }

        return ActivityLogRestoreProvenance(
            sourceProfile: sourceProfile,
            replacedProfile: replacedProfile
        )
    }

    private func profileReference(
        provider: QuotaProvider,
        profileRootPath: String
    ) -> ActivityLogProfileReference {
        let standardizedPath = URL(fileURLWithPath: profileRootPath, isDirectory: true).standardizedFileURL.path
        let label = self.storedProfileSources.first(where: {
            $0.provider == provider && $0.profileRootURL.standardizedFileURL.path == standardizedPath
        })?.label
            ?? self.discoveredProfiles.first(where: {
            $0.provider == provider && $0.profileRootURL.standardizedFileURL.path == standardizedPath
        })?.label
            ?? self.accounts.first(where: {
                $0.provider == provider && $0.profileRootPath == standardizedPath
            })?.label
            ?? URL(fileURLWithPath: standardizedPath, isDirectory: true).lastPathComponent

        return ActivityLogProfileReference(label: label, profileRootPath: standardizedPath)
    }

    private func reconcileAutomaticActivationRecoveryIssues(refreshedAccounts: [QuotaAccount]) {
        self.automaticActivationRecoveryIssues = self.automaticActivationRecoveryIssues.filter { _, issue in
            !AutomaticActivationVerifier.isRecovered(
                issue: issue,
                refreshedAccounts: refreshedAccounts
            )
        }
    }

    private func resolveAutomaticActivationVerification(
        option: RecommendationActivationOption,
        refreshResult: AmbientUsageRefreshResult?
    ) {
        let issue = AutomaticActivationVerifier.verify(
            option: option,
            refreshedAccounts: refreshResult?.accounts ?? []
        )

        if let issue {
            self.automaticActivationRecoveryIssues[option.provider] = issue
            self.lastProfileActionSummary = "Recovery needed for \(option.provider.displayName)."
            self.recordActivity(
                kind: .verificationFailed,
                provider: option.provider,
                title: "Verification failed",
                detail: issue.detail
            )
        } else {
            self.automaticActivationRecoveryIssues.removeValue(forKey: option.provider)
        }
    }

    private func refreshLaunchAtLoginState() {
        self.launchAtLoginStatus = self.launchAtLoginController.status
        self.isLaunchAtLoginEnabled = self.launchAtLoginStatus != .disabled
    }
}
