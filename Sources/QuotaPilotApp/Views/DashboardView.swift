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

struct DashboardView: View {
    let model: AppModel

    @State private var selection: QuotaAccount.ID?

    private var selectedAccount: QuotaAccount? {
        let selectedID = self.selection ?? self.model.providerRecommendations.first?.recommendedAccount?.id
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
                                    isRecommended: scoredAccount.account.id == recommendation.recommendedAccount?.id,
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

                    ProviderHealthSectionView(summaries: self.model.providerHealthSummaries)

                    if !self.model.providerRecommendations.isEmpty {
                        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
                            ForEach(self.model.providerRecommendations) { recommendation in
                                RecommendationCard(
                                    recommendation: recommendation,
                                    activationOption: self.model.recommendationActivationOption(for: recommendation.provider),
                                    guidedHandoffPlan: self.model.guidedDesktopHandoffPlan(for: recommendation.provider),
                                    isActivatingProfile: self.model.isActivatingProfile
                                ) {
                                    Task {
                                        await self.model.activateRecommendedProfile(for: recommendation.provider)
                                    }
                                }
                            }
                        }
                    }

                    TrackedProfileInventorySectionView(
                        isActivatingProfile: self.model.isActivatingProfile,
                        items: self.model.trackedProfileInventoryItems
                    ) { item in
                        Task {
                            await self.model.activateProfile(
                                provider: item.provider,
                                profileRootPath: item.profileRootPath
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
