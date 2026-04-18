import SwiftUI
import QuotaPilotCore

struct LiveAccountsEmptyStateView: View {
    let title: String
    let detail: String

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(self.title)
                .font(.headline)

            Text(self.detail)
                .font(.subheadline)
                .foregroundStyle(.secondary)

            SettingsLink {
                Text("Open Settings")
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }
}

struct StaleAccountsWarningView: View {
    let detail: String

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.orange)

            Text(self.detail)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.orange.opacity(0.12), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }
}

struct LatestBackupRestoreView: View {
    let entry: ActivityLogEntry

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            if let provider = self.entry.provider {
                ProviderIconView(provider: provider, size: 16)
            } else {
                Image(systemName: "arrow.uturn.backward.circle.fill")
                    .foregroundStyle(.orange)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text("Last Backup Restore")
                    .font(.headline)

                Text(self.entry.detail)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                if let restoreProvenance = self.entry.restoreProvenance {
                    VStack(alignment: .leading, spacing: 3) {
                        Text("Backup used: \(restoreProvenance.sourceProfile.label)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text(restoreProvenance.sourceProfile.profileRootPath)
                            .font(.caption2.monospaced())
                            .foregroundStyle(.secondary)

                        if let replacedProfile = restoreProvenance.replacedProfile {
                            Text("Replaced: \(replacedProfile.label)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Text(replacedProfile.profileRootPath)
                                .font(.caption2.monospaced())
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                Text(Self.timestampFormatter.string(from: self.entry.timestamp))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.orange.opacity(0.12), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private static let timestampFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .none
        formatter.timeStyle = .short
        return formatter
    }()
}

struct DashboardView: View {
    let model: AppModel

    @State private var selection: QuotaAccount.ID?

    private var selectedAccount: QuotaAccount? {
        let selectedID = self.selection ?? self.model.globalRecommendation?.recommendedAccount?.id
        return self.model.accounts.first(where: { $0.id == selectedID })
    }

    var body: some View {
        NavigationSplitView {
            List(selection: self.$selection) {
                if self.model.providerRecommendations.isEmpty {
                    Section("Status") {
                        Text(self.model.liveAccountsEmptyStateDetail)
                            .foregroundStyle(.secondary)
                    }
                } else {
                    ForEach(self.model.providerRecommendations) { recommendation in
                        Section(recommendation.provider.displayName) {
                            ForEach(recommendation.rankedAccounts) { scoredAccount in
                                AccountRowView(
                                    account: scoredAccount.account,
                                    score: scoredAccount.score,
                                    isRecommended: scoredAccount.account.id == self.model.globalRecommendation?.recommendedAccount?.id,
                                    showsScore: true
                                )
                                .tag(scoredAccount.account.id)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Accounts")
            .listStyle(.sidebar)
        } detail: {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    Text(self.model.lastUsageRefreshSummary)
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    if !self.model.hasLiveAccounts {
                        LiveAccountsEmptyStateView(
                            title: self.model.liveAccountsEmptyStateTitle,
                            detail: self.model.liveAccountsEmptyStateDetail
                        )
                    }

                    if self.model.isShowingStaleAccounts {
                        StaleAccountsWarningView(detail: self.model.staleAccountsWarningText)
                    }

                    if let latestBackupRestoreEntry = self.model.latestBackupRestoreEntry {
                        LatestBackupRestoreView(entry: latestBackupRestoreEntry)
                    }

                    ProviderHealthSectionView(
                        summaries: self.model.providerHealthSummaries,
                        isRefreshingUsage: self.model.isRefreshingUsage,
                        isActivatingProfile: self.model.isActivatingProfile
                    ) {
                        Task {
                            await self.model.refreshLiveUsage()
                        }
                    } onRestoreManagedBackup: { provider, profileRootPath in
                        Task {
                            await self.model.activateProfile(provider: provider, profileRootPath: profileRootPath)
                        }
                    }

                    if let recommendation = self.model.globalRecommendation {
                        RecommendationCard(
                            recommendation: recommendation,
                            activationOption: self.model.globalRecommendationActivationOption,
                            guidedHandoffPlan: self.model.globalGuidedDesktopHandoffPlan,
                            isActivatingProfile: self.model.isActivatingProfile
                        ) {
                            Task {
                                await self.model.activateRecommendedProfile()
                            }
                        }
                    }

                    TrackedProfileInventorySectionView(
                        isRefreshingUsage: self.model.isRefreshingUsage,
                        isActivatingProfile: self.model.isActivatingProfile,
                        items: self.model.trackedProfileInventoryItems
                    ) {
                        Task {
                            await self.model.refreshLiveUsage()
                        }
                    } onActivate: { item in
                        Task {
                            await self.model.activateProfile(
                                provider: item.provider,
                                profileRootPath: item.profileRootPath
                            )
                        }
                    } onRestoreManagedBackup: { item in
                        guard let recoveryActionTargetProfileRootPath = item.recoveryActionTargetProfileRootPath else { return }
                        Task {
                            await self.model.activateProfile(
                                provider: item.provider,
                                profileRootPath: recoveryActionTargetProfileRootPath
                            )
                        }
                    } onDelete: { item in
                        self.model.removeTrackedProfileItem(item)
                    }

                    if !self.model.pendingSwitchConfirmations.isEmpty {
                        PendingSwitchConfirmationsSectionView(
                            confirmations: self.model.pendingSwitchConfirmations,
                            isActivatingProfile: self.model.isActivatingProfile
                        ) { provider in
                            Task {
                                await self.model.approvePendingSwitch(for: provider)
                            }
                        } onDismiss: { provider in
                            self.model.dismissPendingSwitch(for: provider)
                        }
                    }

                    if !self.model.automaticActivationRecoveryIssues.isEmpty {
                        AutomaticActivationRecoverySectionView(
                            issues: self.model.automaticActivationRecoveryIssues,
                            isRefreshingUsage: self.model.isRefreshingUsage
                        ) {
                            Task {
                                await self.model.refreshLiveUsage()
                            }
                        } onDismiss: { provider in
                            self.model.dismissAutomaticActivationRecoveryIssue(for: provider)
                        }
                    }

                    ActivityLogSectionView(entries: self.model.activityLogEntries)

                    if let selectedAccount {
                        VStack(alignment: .leading, spacing: 14) {
                            Text(selectedAccount.label)
                                .font(.title2.weight(.semibold))

                            HStack(spacing: 8) {
                                ProviderIconView(provider: selectedAccount.provider, size: 16)
                                Text(selectedAccount.provider.displayName)
                                    .foregroundStyle(.secondary)
                            }

                            if let identitySummary = selectedAccount.identitySummary {
                                Text(identitySummary)
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }

                            if !selectedAccount.capabilityLabels.isEmpty {
                                Text(selectedAccount.capabilityLabels.joined(separator: " • "))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }

                            Text(selectedAccount.sourceSummary)
                                .font(.caption)
                                .foregroundStyle(.secondary)

                            HStack(spacing: 14) {
                                ForEach(selectedAccount.windows) { window in
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(window.title)
                                            .font(.caption.weight(.semibold))
                                            .foregroundStyle(.secondary)
                                        Text("\(window.remainingPercent)% remaining")
                                            .font(.headline)
                                        Text("Resets in \(window.hoursUntilReset())h")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .padding(14)
                                    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                                }
                            }
                        }
                    }
                }
                .padding(24)
            }
            .background(Color(nsColor: .windowBackgroundColor))
        }
    }
}
