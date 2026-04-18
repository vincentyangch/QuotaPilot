import SwiftUI
import QuotaPilotCore

struct StatusMenuView: View {
    let model: AppModel
    let onOpenDashboard: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            if self.model.providerRecommendations.isEmpty {
                LiveAccountsEmptyStateView(
                    title: self.model.liveAccountsEmptyStateTitle,
                    detail: self.model.liveAccountsEmptyStateDetail
                )
            } else if let recommendation = self.model.globalRecommendation {
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

            if self.model.isShowingStaleAccounts {
                StaleAccountsWarningView(detail: self.model.staleAccountsWarningText)
            }

            if let latestBackupRestoreEntry = self.model.latestBackupRestoreEntry {
                LatestBackupRestoreView(entry: latestBackupRestoreEntry)
            }

            Divider()

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

            if !self.model.pendingSwitchConfirmations.isEmpty {
                Divider()

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
                Divider()

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

            Divider()

            ActivityLogSectionView(entries: self.model.activityLogEntries, maxEntries: 4)

            Divider()

            VStack(alignment: .leading, spacing: 12) {
                Text("Accounts")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)

                if self.model.providerRecommendations.isEmpty {
                    Text("No live accounts are loaded yet.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(self.model.providerRecommendations) { recommendation in
                        VStack(alignment: .leading, spacing: 8) {
                            Text(recommendation.provider.displayName)
                                .font(.caption.weight(.medium))
                                .foregroundStyle(.secondary)

                            ForEach(recommendation.rankedAccounts) { scoredAccount in
                                AccountRowView(
                                    account: scoredAccount.account,
                                    score: scoredAccount.score,
                                    isRecommended: scoredAccount.account.id == self.model.globalRecommendation?.recommendedAccount?.id,
                                    showsScore: false
                                )
                            }
                        }
                    }
                }
            }

            Divider()

            HStack {
                Button(self.model.isRefreshingUsage ? "Refreshing..." : "Refresh Live Usage") {
                    Task {
                        await self.model.refreshLiveUsage()
                    }
                }
                .disabled(self.model.isRefreshingUsage)

                Spacer()

                Button("Open Dashboard") {
                    self.onOpenDashboard()
                }

                SettingsLink {
                    Text("Settings")
                }
            }

            Text(self.model.lastUsageRefreshSummary)
                .font(.caption)
                .foregroundStyle(.secondary)

            if let lastProfileActionSummary = self.model.lastProfileActionSummary {
                Text(lastProfileActionSummary)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(16)
        .frame(width: 340)
    }
}
