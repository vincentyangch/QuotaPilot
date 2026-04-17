import SwiftUI
import QuotaPilotCore

struct RulesSettingsView: View {
    let model: AppModel

    @State private var draftProvider: QuotaProvider = .codex
    @State private var draftLabel = ""
    @State private var draftPath = ""
    @State private var pendingRemovalSource: StoredProfileSource?

    private func chooseProfileFolder() {
        guard let selectedPath = ProfileSourceFolderPicker.chooseFolder(startingAt: self.draftPath) else { return }
        self.draftPath = selectedPath
        if self.draftLabel.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            self.draftLabel = URL(fileURLWithPath: selectedPath, isDirectory: true).lastPathComponent
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
                                    Task {
                                        await self.model.refreshLiveUsage()
                                    }
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
                Task {
                    await self.model.refreshLiveUsage()
                }
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
                    Stepper("\(self.thresholdBinding.wrappedValue)% remaining", value: self.thresholdBinding, in: 0...100)
                }

                VStack(alignment: .leading, spacing: 6) {
                    Text("Minimum score advantage")
                    Stepper("\(self.minimumAdvantageBinding.wrappedValue) points", value: self.minimumAdvantageBinding, in: 0...100)
                }
            }

            Section("Scoring Weights") {
                Stepper("Remaining quota weight: \(self.remainingWeightBinding.wrappedValue)", value: self.remainingWeightBinding, in: 0...5)
                Stepper("Reset urgency weight: \(self.resetWeightBinding.wrappedValue)", value: self.resetWeightBinding, in: 0...5)
                Stepper("Profile priority weight: \(self.priorityWeightBinding.wrappedValue)", value: self.priorityWeightBinding, in: 0...5)
            }

            Section("Scope") {
                Text("These rules currently apply separately within Codex and Claude, so each provider keeps its own best active account.")
                    .foregroundStyle(.secondary)
            }

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
                    ForEach(Array(self.model.pendingSwitchConfirmations.keys), id: \.self) { provider in
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
        .formStyle(.grouped)
        .frame(width: 460)
        .padding(20)
    }
}
