import SwiftUI
import QuotaPilotCore

struct TrackedProfileInventorySectionView: View {
    let isRefreshingUsage: Bool
    let isActivatingProfile: Bool
    let items: [TrackedProfileInventoryItem]
    let onRefreshUsage: () -> Void
    let onActivate: (TrackedProfileInventoryItem) -> Void
    let onRestoreManagedBackup: (TrackedProfileInventoryItem) -> Void
    let onDelete: (TrackedProfileInventoryItem) -> Void

    @State private var pendingRestoreItem: TrackedProfileInventoryItem?
    @State private var pendingDeletionItem: TrackedProfileInventoryItem?

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Tracked Profiles")
                .font(.headline)

            if self.items.isEmpty {
                Text("No tracked profile sources yet.")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(Array(self.items.enumerated()), id: \.element.id) { _, item in
                    HStack(alignment: .top, spacing: 12) {
                        ProviderIconView(provider: item.provider, size: 16)

                        VStack(alignment: .leading, spacing: 4) {
                            HStack(spacing: 8) {
                                Text(item.label)
                                    .fontWeight(.semibold)

                                if item.isCurrentSelection {
                                    Text("Current")
                                        .font(.caption.weight(.medium))
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 3)
                                        .background(.quaternary, in: Capsule())
                                }

                                Text(item.lifecycleTitle)
                                    .font(.caption.weight(.medium))
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 3)
                                    .background(self.lifecycleBackground(for: item.lifecycleState), in: Capsule())
                                    .foregroundStyle(self.lifecycleForeground(for: item.lifecycleState))
                            }

                            if let identitySummary = item.identitySummary {
                                Text(identitySummary)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }

                            Text(item.sourceSummary)
                                .font(.caption2)
                                .foregroundStyle(.secondary)

                            Text(item.statusSummary)
                                .font(.caption)
                                .foregroundStyle(item.hasLiveUsage ? Color.secondary : Color.orange)

                            Text(item.capabilitySummary)
                                .font(.caption2)
                                .foregroundStyle(.secondary)

                            if let lastRefreshSummary = item.lastRefreshSummary {
                                Text(lastRefreshSummary)
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }

                            if let lifecycleDetail = item.lifecycleDetail {
                                Text(lifecycleDetail)
                                    .font(.caption2)
                                    .foregroundStyle(self.lifecycleForeground(for: item.lifecycleState))
                            }

                            if let refreshIssueSummary = item.refreshIssueSummary {
                                Text(refreshIssueSummary)
                                    .font(.caption2)
                                    .foregroundStyle(.orange)
                            }

                            if let lastErrorDetail = item.lastErrorDetail {
                                Text(lastErrorDetail)
                                    .font(.caption2)
                                    .foregroundStyle(.orange)
                            }

                            Text(item.lifecycleNextAction)
                                .font(.caption2)
                                .foregroundStyle(.secondary)

                            if let recoveryActionKind = item.recoveryActionKind,
                               let recoveryActionTitle = item.recoveryActionTitle
                            {
                                switch recoveryActionKind {
                                case .refreshUsage:
                                    Button(self.isRefreshingUsage ? "Refreshing..." : recoveryActionTitle) {
                                        self.onRefreshUsage()
                                    }
                                    .disabled(self.isRefreshingUsage)
                                case .openSettings:
                                    SettingsLink {
                                        Text(recoveryActionTitle)
                                    }
                                case .restoreManagedBackup:
                                    Button(self.isActivatingProfile ? "Activating..." : recoveryActionTitle) {
                                        self.pendingRestoreItem = item
                                    }
                                    .disabled(self.isActivatingProfile)
                                }
                            }

                            Text(item.profileRootPath)
                                .font(.caption2.monospaced())
                                .foregroundStyle(.secondary)

                            Text(item.sourceDescription)
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }

                        Spacer()

                        VStack(alignment: .trailing, spacing: 8) {
                            if !item.isCurrentSelection {
                                Button(self.isActivatingProfile ? "Activating..." : item.activationActionTitle) {
                                    self.onActivate(item)
                                }
                                .disabled(self.isActivatingProfile)
                            }

                            if item.sourceKind == .backup && item.ownershipMode == .quotaPilotManaged {
                                Button("Delete Backup", role: .destructive) {
                                    self.pendingDeletionItem = item
                                }
                                .disabled(self.isActivatingProfile)
                            }
                        }
                    }
                    .padding(14)
                    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                }
            }
        }
        .confirmationDialog(
            self.pendingRestoreItem?.restoreConfirmationTitle ?? "Restore managed backup?",
            isPresented: Binding(
                get: { self.pendingRestoreItem != nil },
                set: { isPresented in
                    if !isPresented {
                        self.pendingRestoreItem = nil
                    }
                }
            ),
            presenting: self.pendingRestoreItem
        ) { item in
            Button(item.recoveryActionTitle ?? "Restore Backup") {
                self.onRestoreManagedBackup(item)
                self.pendingRestoreItem = nil
            }
            Button("Cancel", role: .cancel) {
                self.pendingRestoreItem = nil
            }
        } message: { item in
            Text(item.restoreConfirmationDetail ?? "QuotaPilot will restore this managed backup.")
        }
        .confirmationDialog(
            self.pendingDeletionItem?.deletionConfirmationTitle ?? "Delete managed backup?",
            isPresented: Binding(
                get: { self.pendingDeletionItem != nil },
                set: { isPresented in
                    if !isPresented {
                        self.pendingDeletionItem = nil
                    }
                }
            ),
            presenting: self.pendingDeletionItem
        ) { item in
            Button("Delete Backup", role: .destructive) {
                self.onDelete(item)
                self.pendingDeletionItem = nil
            }
            Button("Cancel", role: .cancel) {
                self.pendingDeletionItem = nil
            }
        } message: { item in
            Text(item.deletionConfirmationDetail)
        }
    }

    private func lifecycleForeground(for state: TrackedProfileLifecycleState) -> Color {
        switch state {
        case .ready:
            .green
        case .awaitingRefresh:
            .secondary
        case .credentialsMissing, .authExpired:
            .red
        case .sessionUnavailable:
            .orange
        case .usageReadFailed:
            .orange
        }
    }

    private func lifecycleBackground(for state: TrackedProfileLifecycleState) -> Color {
        switch state {
        case .ready:
            .green.opacity(0.12)
        case .awaitingRefresh:
            .secondary.opacity(0.12)
        case .credentialsMissing, .authExpired:
            .red.opacity(0.12)
        case .sessionUnavailable:
            .orange.opacity(0.12)
        case .usageReadFailed:
            .orange.opacity(0.12)
        }
    }
}
