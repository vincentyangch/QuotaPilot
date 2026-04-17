import SwiftUI
import QuotaPilotCore

struct RulesSettingsView: View {
    let model: AppModel

    @State private var draftProvider: QuotaProvider = .codex
    @State private var draftLabel = ""
    @State private var draftPath = ""
    @State private var pendingRemovalSource: StoredProfileSource?

    private var providersNeedingRecovery: [ProviderHealthSummary] {
        self.model.providerHealthSummaries
            .filter { $0.state != .healthy }
            .sorted { $0.provider.displayName < $1.provider.displayName }
    }

    private var providersNeedingAttention: [ProviderHealthSummary] {
        self.providersNeedingRecovery.filter { $0.recoveryBackupProfileRootPath == nil }
    }

    private var providerRestoreOptions: [ProviderHealthSummary] {
        self.providersNeedingRecovery.filter { $0.recoveryBackupProfileRootPath != nil }
    }

    private var trackedProfilesNeedingRecovery: [TrackedProfileInventoryItem] {
        self.model.trackedProfileInventoryItems
            .filter { $0.recoveryActionKind != nil || $0.lastErrorDetail != nil }
            .sorted { lhs, rhs in
                if lhs.provider != rhs.provider {
                    return lhs.provider.displayName < rhs.provider.displayName
                }
                return lhs.label < rhs.label
            }
    }

    private var trackedProfilesNeedingAttention: [TrackedProfileInventoryItem] {
        self.trackedProfilesNeedingRecovery.filter { $0.recoveryActionKind != .restoreManagedBackup }
    }

    private var trackedProfileRestoreOptions: [TrackedProfileInventoryItem] {
        self.trackedProfilesNeedingRecovery.filter { $0.recoveryActionKind == .restoreManagedBackup }
    }

    private var automaticRecoveryIssues: [AutomaticActivationRecoveryIssue] {
        self.model.automaticActivationRecoveryIssues.values
            .sorted { lhs, rhs in
                if lhs.provider != rhs.provider {
                    return lhs.provider.displayName < rhs.provider.displayName
                }
                return lhs.accountLabel < rhs.accountLabel
            }
    }

    private var recentRecoveryEntries: [ActivityLogEntry] {
        Array(self.model.activityLogEntries.filter(\.isBackupRestore).prefix(3))
    }

    private var needsAttentionCount: Int {
        self.providersNeedingAttention.count
            + self.trackedProfilesNeedingAttention.count
            + self.automaticRecoveryIssues.count
    }

    private var restoreOptionsCount: Int {
        self.providerRestoreOptions.count + self.trackedProfileRestoreOptions.count
    }

    private var recentRecoveryCount: Int {
        self.recentRecoveryEntries.count
    }

    private var recoveryCenterIsEmpty: Bool {
        self.providersNeedingAttention.isEmpty
            && self.providerRestoreOptions.isEmpty
            && self.trackedProfilesNeedingAttention.isEmpty
            && self.trackedProfileRestoreOptions.isEmpty
            && self.automaticRecoveryIssues.isEmpty
            && self.recentRecoveryEntries.isEmpty
    }

    private func chooseProfileFolder() {
        guard let selectedPath = ProfileSourceFolderPicker.chooseFolder(startingAt: self.draftPath) else { return }
        self.draftPath = selectedPath
        if self.draftLabel.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            self.draftLabel = URL(fileURLWithPath: selectedPath, isDirectory: true).lastPathComponent
        }
    }

    private func refreshUsage() {
        Task {
            await self.model.refreshLiveUsage()
        }
    }

    private func activateProfile(provider: QuotaProvider, profileRootPath: String) {
        Task {
            await self.model.activateProfile(provider: provider, profileRootPath: profileRootPath)
        }
    }

    private func triggerTrackedRecovery(for item: TrackedProfileInventoryItem) {
        guard let recoveryActionKind = item.recoveryActionKind else { return }

        switch recoveryActionKind {
        case .refreshUsage:
            self.refreshUsage()
        case .openSettings:
            break
        case .restoreManagedBackup:
            guard let profileRootPath = item.recoveryActionTargetProfileRootPath else { return }
            self.activateProfile(provider: item.provider, profileRootPath: profileRootPath)
        }
    }

    private var recoveryCenterSection: some View {
        Section("Recovery Center") {
            if self.recoveryCenterIsEmpty {
                Text("No recovery actions are needed right now.")
                    .foregroundStyle(.secondary)
            } else {
                if !self.providersNeedingAttention.isEmpty || !self.trackedProfilesNeedingAttention.isEmpty || !self.automaticRecoveryIssues.isEmpty {
                    VStack(alignment: .leading, spacing: 10) {
                        self.recoveryGroupHeader(
                            title: "Needs Attention",
                            detail: "Accounts that still need refresh, reauthentication, or manual repair.",
                            count: self.needsAttentionCount,
                            tint: .red
                        )

                        ForEach(self.providersNeedingAttention) { summary in
                            self.providerRecoveryCard(summary)
                        }

                        ForEach(self.trackedProfilesNeedingAttention) { item in
                            self.trackedProfileRecoveryCard(item)
                        }

                        ForEach(self.automaticRecoveryIssues) { issue in
                            self.automaticRecoveryCard(issue)
                        }
                    }
                    .padding(.vertical, 4)
                }

                if !self.providerRestoreOptions.isEmpty || !self.trackedProfileRestoreOptions.isEmpty {
                    VStack(alignment: .leading, spacing: 10) {
                        self.recoveryGroupHeader(
                            title: "Restore Options",
                            detail: "Managed backups that QuotaPilot can restore immediately.",
                            count: self.restoreOptionsCount,
                            tint: .orange
                        )

                        ForEach(self.providerRestoreOptions) { summary in
                            self.providerRestoreOptionCard(summary)
                        }

                        ForEach(self.trackedProfileRestoreOptions) { item in
                            self.trackedProfileRestoreOptionCard(item)
                        }
                    }
                    .padding(.vertical, 4)
                }

                if !self.recentRecoveryEntries.isEmpty {
                    VStack(alignment: .leading, spacing: 10) {
                        self.recoveryGroupHeader(
                            title: "Recent Recovery",
                            detail: "Recent managed backup restores recorded by QuotaPilot.",
                            count: self.recentRecoveryCount,
                            tint: .green
                        )

                        ForEach(self.recentRecoveryEntries) { entry in
                            self.recentRecoveryCard(entry)
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
        }
    }

    @ViewBuilder
    private func recoveryGroupHeader(title: String, detail: String, count: Int, tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 8) {
                Text(title)
                    .font(.subheadline.weight(.semibold))

                Text("\(count)")
                    .font(.caption2.weight(.semibold))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(tint.opacity(0.14), in: Capsule())
                    .foregroundStyle(tint)
            }

            Text(detail)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    @ViewBuilder
    private func providerRecoveryCard(_ summary: ProviderHealthSummary) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                ProviderIconView(provider: summary.provider, size: 14)
                Text(summary.provider.displayName)
                    .fontWeight(.semibold)
                Spacer()
                Text(self.healthLabel(for: summary.state))
                    .font(.caption.weight(.medium))
                    .foregroundStyle(self.healthColor(for: summary.state))
            }

            Text(summary.summary)
                .foregroundStyle(.secondary)

            if let affectedProfilesSummary = summary.affectedProfilesSummary {
                Text(affectedProfilesSummary)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if let detail = summary.detail {
                Text(detail)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            if !summary.recoveryItems.isEmpty {
                ForEach(summary.recoveryItems, id: \.self) { item in
                    Text(item)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }

            HStack(spacing: 10) {
                Button(self.model.isRefreshingUsage ? "Refreshing..." : "Retry Refresh") {
                    self.refreshUsage()
                }
                .disabled(self.model.isRefreshingUsage)
            }
        }
    }

    @ViewBuilder
    private func providerRestoreOptionCard(_ summary: ProviderHealthSummary) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                ProviderIconView(provider: summary.provider, size: 14)
                Text(summary.provider.displayName)
                    .fontWeight(.semibold)
                Spacer()
                Text("Backup Ready")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.orange)
            }

            Text(summary.summary)
                .foregroundStyle(.secondary)

            if let recoveryBackupLabel = summary.recoveryBackupLabel,
               let recoveryBackupProfileRootPath = summary.recoveryBackupProfileRootPath
            {
                Button(self.model.isActivatingProfile ? "Activating..." : "Restore \(recoveryBackupLabel)") {
                    self.activateProfile(
                        provider: summary.provider,
                        profileRootPath: recoveryBackupProfileRootPath
                    )
                }
                .disabled(self.model.isActivatingProfile)
            }
        }
    }

    @ViewBuilder
    private func trackedProfileRecoveryCard(_ item: TrackedProfileInventoryItem) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                ProviderIconView(provider: item.provider, size: 14)
                Text(item.label)
                    .fontWeight(.semibold)
                Spacer()
                Text(item.lifecycleTitle)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(self.healthColor(for: item.lifecycleState))
            }

            if let refreshIssueSummary = item.refreshIssueSummary {
                Text(refreshIssueSummary)
                    .font(.caption)
                    .foregroundStyle(.orange)
            } else if let lifecycleDetail = item.lifecycleDetail {
                Text(lifecycleDetail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if let lastErrorDetail = item.lastErrorDetail {
                Text(lastErrorDetail)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            Text(item.lifecycleNextAction)
                .font(.caption2)
                .foregroundStyle(.secondary)

            if let recoveryActionKind = item.recoveryActionKind,
               let recoveryActionTitle = item.recoveryActionTitle
            {
                switch recoveryActionKind {
                case .refreshUsage:
                    Button(self.model.isRefreshingUsage ? "Refreshing..." : recoveryActionTitle) {
                        self.triggerTrackedRecovery(for: item)
                    }
                    .disabled(self.model.isRefreshingUsage)
                case .openSettings:
                    Text("Review the profile and source sections below to repair this account.")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                case .restoreManagedBackup:
                    EmptyView()
                }
            }
        }
    }

    @ViewBuilder
    private func trackedProfileRestoreOptionCard(_ item: TrackedProfileInventoryItem) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                ProviderIconView(provider: item.provider, size: 14)
                Text(item.label)
                    .fontWeight(.semibold)
                Spacer()
                Text("Backup Ready")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.orange)
            }

            if let refreshIssueSummary = item.refreshIssueSummary {
                Text(refreshIssueSummary)
                    .font(.caption)
                    .foregroundStyle(.orange)
            }

            Text(item.lifecycleNextAction)
                .font(.caption2)
                .foregroundStyle(.secondary)

            if let recoveryActionTitle = item.recoveryActionTitle {
                Button(self.model.isActivatingProfile ? "Activating..." : recoveryActionTitle) {
                    self.triggerTrackedRecovery(for: item)
                }
                .disabled(self.model.isActivatingProfile)
            }
        }
    }

    @ViewBuilder
    private func automaticRecoveryCard(_ issue: AutomaticActivationRecoveryIssue) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                ProviderIconView(provider: issue.provider, size: 14)
                Text(issue.accountLabel)
                    .fontWeight(.semibold)
            }

            Text(issue.detail)
                .font(.caption)
                .foregroundStyle(.secondary)

            HStack(spacing: 10) {
                Button(self.model.isRefreshingUsage ? "Refreshing..." : "Retry Refresh") {
                    self.refreshUsage()
                }
                .disabled(self.model.isRefreshingUsage)

                Button("Dismiss") {
                    self.model.dismissAutomaticActivationRecoveryIssue(for: issue.provider)
                }
            }
        }
    }

    @ViewBuilder
    private func recentRecoveryCard(_ entry: ActivityLogEntry) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(entry.detail)
                .foregroundStyle(.secondary)
            Text(Self.timestampFormatter.string(from: entry.timestamp))
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
    }

    private var discoveredProfilesSection: some View {
        Section("Discovered Local Profiles") {
            Text(self.model.lastUsageRefreshSummary)
                .foregroundStyle(.secondary)

            if self.model.discoveredProfiles.isEmpty {
                Text("No ambient Codex or Claude profiles were found yet.")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(self.model.discoveredProfiles) { profile in
                    VStack(alignment: .leading, spacing: 6) {
                        HStack(spacing: 8) {
                            ProviderIconView(provider: profile.provider, size: 14)
                            Text(profile.label)
                                .fontWeight(.semibold)
                            Spacer()
                            if self.model.isCurrentProfile(profile) {
                                Text("Current")
                                    .font(.caption.weight(.medium))
                                    .foregroundStyle(.secondary)
                            } else {
                                Button("Set Current") {
                                    self.model.selectCurrentProfile(profile)
                                    self.refreshUsage()
                                }
                            }
                            if let plan = profile.plan {
                                Text(plan.uppercased())
                                    .font(.caption.weight(.medium))
                                    .foregroundStyle(.secondary)
                            }
                            Button(self.model.isActivatingProfile ? "Activating..." : profile.activationActionTitle) {
                                Task {
                                    await self.model.activateProfile(profile)
                                }
                            }
                            .disabled(self.model.isActivatingProfile)
                        }

                        if let identitySummary = profile.identitySummary {
                            Text(identitySummary)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }

                        Text(profile.sourceSummary)
                            .font(.caption2)
                            .foregroundStyle(.secondary)

                        Text(profile.profileRootURL.path)
                            .font(.caption2.monospaced())
                            .foregroundStyle(.secondary)

                        Text(profile.sourceDescription)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 4)
                }
            }

            Button(self.model.isRefreshingUsage ? "Refreshing local usage..." : "Refresh live usage from local profiles") {
                self.refreshUsage()
            }
            .disabled(self.model.isRefreshingUsage)

            if let lastProfileActionSummary = self.model.lastProfileActionSummary {
                Text(lastProfileActionSummary)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var storedSourcesSection: some View {
        Section("Additional Profile Sources") {
            if self.model.storedProfileSources.isEmpty {
                Text("No extra profile roots added yet.")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(self.model.storedProfileSources) { source in
                    HStack(alignment: .top, spacing: 8) {
                        ProviderIconView(provider: source.provider, size: 14)
                        VStack(alignment: .leading, spacing: 4) {
                            Text(source.label)
                                .fontWeight(.semibold)
                            Text(source.sourceSummary)
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                            Text(source.profileRootPath)
                                .font(.caption2.monospaced())
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Button(source.removalActionTitle) {
                            self.pendingRemovalSource = source
                        }
                    }
                    .padding(.vertical, 2)
                }
            }

            Picker("Provider", selection: self.$draftProvider) {
                ForEach(QuotaProvider.allCases, id: \.self) { provider in
                    Text(provider.displayName).tag(provider)
                }
            }

            TextField("Label", text: self.$draftLabel)

            HStack(spacing: 8) {
                TextField("Profile root path", text: self.$draftPath)
                    .textFieldStyle(.roundedBorder)

                Button("Choose Folder…") {
                    self.chooseProfileFolder()
                }
            }

            Button("Add Profile Source") {
                self.model.addStoredProfileSource(
                    provider: self.draftProvider,
                    label: self.draftLabel,
                    path: self.draftPath
                )
                self.draftLabel = ""
                self.draftPath = ""
            }
            .disabled(self.draftPath.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        }
    }

    private var thresholdBinding: Binding<Int> {
        Binding(
            get: { self.model.rules.switchThresholdPercent },
            set: { self.model.updateSwitchThreshold($0) }
        )
    }

    private var minimumAdvantageBinding: Binding<Int> {
        Binding(
            get: { self.model.rules.minimumScoreAdvantage },
            set: { self.model.updateMinimumScoreAdvantage($0) }
        )
    }

    private var remainingWeightBinding: Binding<Int> {
        Binding(
            get: { self.model.rules.remainingWeight },
            set: { self.model.updateRemainingWeight($0) }
        )
    }

    private var resetWeightBinding: Binding<Int> {
        Binding(
            get: { self.model.rules.resetWeight },
            set: { self.model.updateResetWeight($0) }
        )
    }

    private var priorityWeightBinding: Binding<Int> {
        Binding(
            get: { self.model.rules.priorityWeight },
            set: { self.model.updatePriorityWeight($0) }
        )
    }

    var body: some View {
        Form {
            Section("Switching Rules") {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Switch threshold")
                    Stepper(
                        "\(self.thresholdBinding.wrappedValue)% remaining",
                        value: self.thresholdBinding,
                        in: 0...100
                    )
                }

                VStack(alignment: .leading, spacing: 6) {
                    Text("Minimum score advantage")
                    Stepper(
                        "\(self.minimumAdvantageBinding.wrappedValue) points",
                        value: self.minimumAdvantageBinding,
                        in: 0...100
                    )
                }
            }

            Section("Scoring Weights") {
                Stepper(
                    "Remaining quota weight: \(self.remainingWeightBinding.wrappedValue)",
                    value: self.remainingWeightBinding,
                    in: 0...5
                )
                Stepper(
                    "Reset urgency weight: \(self.resetWeightBinding.wrappedValue)",
                    value: self.resetWeightBinding,
                    in: 0...5
                )
                Stepper(
                    "Profile priority weight: \(self.priorityWeightBinding.wrappedValue)",
                    value: self.priorityWeightBinding,
                    in: 0...5
                )
            }

            Section("Scope") {
                Text("These rules currently apply separately within Codex and Claude, so each provider keeps its own best active account.")
                    .foregroundStyle(.secondary)
            }

            self.recoveryCenterSection

            Section("Switch Behavior") {
                Picker(
                    "When a better account is available",
                    selection: Binding(
                        get: { self.model.switchActionMode },
                        set: { self.model.updateSwitchActionMode($0) }
                    )
                ) {
                    ForEach(SwitchActionMode.allCases, id: \.self) { mode in
                        Text(mode.displayName).tag(mode)
                    }
                }

                Text(self.model.switchActionMode.summary)
                    .foregroundStyle(.secondary)

                if !self.model.pendingSwitchConfirmations.isEmpty {
                    ForEach(
                        Array(self.model.pendingSwitchConfirmations.keys).sorted(by: { $0.displayName < $1.displayName }),
                        id: \.self
                    ) { provider in
                        if let option = self.model.pendingSwitchConfirmations[provider] {
                            HStack {
                                Text("Pending \(provider.displayName): \(option.accountLabel)")
                                    .foregroundStyle(.secondary)
                                Spacer()
                                Button("Approve") {
                                    Task {
                                        await self.model.approvePendingSwitch(for: provider)
                                    }
                                }
                                Button("Dismiss") {
                                    self.model.dismissPendingSwitch(for: provider)
                                }
                            }
                        }
                    }
                }
            }

            Section("Alerts") {
                Toggle(
                    "Notify when a better account is available",
                    isOn: Binding(
                        get: { self.model.recommendationAlertSettings.isEnabled },
                        set: { self.model.updateRecommendationAlertsEnabled($0) }
                    )
                )

                Text("QuotaPilot sends a macOS notification only when it detects a new switch suggestion, so refreshes do not spam repeated alerts.")
                    .foregroundStyle(.secondary)

                if let lastRecommendationAlertSummary = self.model.lastRecommendationAlertSummary {
                    Text(lastRecommendationAlertSummary)
                        .foregroundStyle(.secondary)
                }
            }

            Section("Background Refresh") {
                Toggle(
                    "Refresh local usage automatically",
                    isOn: Binding(
                        get: { self.model.backgroundRefreshSettings.isEnabled },
                        set: { self.model.updateBackgroundRefreshEnabled($0) }
                    )
                )

                Stepper(
                    "Refresh every \(self.model.backgroundRefreshSettings.intervalMinutes) minutes",
                    value: Binding(
                        get: { self.model.backgroundRefreshSettings.intervalMinutes },
                        set: { self.model.updateBackgroundRefreshInterval($0) }
                    ),
                    in: 1...60
                )
                .disabled(!self.model.backgroundRefreshSettings.isEnabled)

                Text("While QuotaPilot is running, background refresh keeps the widget, recommendations, and alerts up to date without opening the dashboard.")
                    .foregroundStyle(.secondary)
            }

            self.discoveredProfilesSection
            self.storedSourcesSection

            Section {
                Button("Reset to defaults") {
                    self.model.resetRules()
                }
            }
        }
        .confirmationDialog(
            self.pendingRemovalSource?.removalConfirmationTitle ?? "Remove stored profile source?",
            isPresented: Binding(
                get: { self.pendingRemovalSource != nil },
                set: { isPresented in
                    if !isPresented {
                        self.pendingRemovalSource = nil
                    }
                }
            ),
            presenting: self.pendingRemovalSource
        ) { source in
            Button(source.removalActionTitle, role: .destructive) {
                self.model.removeStoredProfileSource(id: source.id)
                self.pendingRemovalSource = nil
            }
            Button("Cancel", role: .cancel) {
                self.pendingRemovalSource = nil
            }
        } message: { source in
            Text(source.removalConfirmationDetail)
        }
        .formStyle(.grouped)
        .frame(width: 520)
        .padding(20)
    }

    private func healthLabel(for state: ProviderHealthState) -> String {
        switch state {
        case .healthy:
            return "Healthy"
        case .degraded:
            return "Degraded"
        case .unavailable:
            return "Unavailable"
        case .notConfigured:
            return "Not Configured"
        }
    }

    private func healthColor(for state: ProviderHealthState) -> Color {
        switch state {
        case .healthy:
            return .green
        case .degraded:
            return .orange
        case .unavailable:
            return .red
        case .notConfigured:
            return .secondary
        }
    }

    private func healthColor(for state: TrackedProfileLifecycleState) -> Color {
        switch state {
        case .ready:
            return .green
        case .awaitingRefresh:
            return .secondary
        case .credentialsMissing, .authExpired:
            return .red
        case .sessionUnavailable, .usageReadFailed:
            return .orange
        }
    }

    private static let timestampFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .none
        formatter.timeStyle = .short
        return formatter
    }()
}
