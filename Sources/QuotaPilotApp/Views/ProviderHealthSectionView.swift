import SwiftUI
import QuotaPilotCore

struct ProviderHealthSectionView: View {
    let summaries: [ProviderHealthSummary]
    let isRefreshingUsage: Bool
    let isActivatingProfile: Bool
    let onRefresh: () -> Void
    let onRestoreManagedBackup: (QuotaProvider, String) -> Void

    @State private var pendingRestoreSummary: ProviderHealthSummary?

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Provider Health")
                .font(.headline)

            ForEach(self.summaries) { summary in
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 8) {
                        ProviderIconView(provider: summary.provider, size: 14)
                        Text(summary.provider.displayName)
                            .fontWeight(.semibold)

                        Spacer()

                        Text(self.statusLabel(for: summary.state))
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(self.statusColor(for: summary.state))
                    }

                    Text(summary.summary)
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    if let detail = summary.detail {
                        Text(detail)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }

                    if let affectedProfilesSummary = summary.affectedProfilesSummary {
                        Text(affectedProfilesSummary)
                            .font(.caption2.weight(.medium))
                            .foregroundStyle(.secondary)
                    }

                    if !summary.recoveryItems.isEmpty {
                        VStack(alignment: .leading, spacing: 6) {
                            ForEach(summary.recoveryItems, id: \.self) { item in
                                HStack(alignment: .top, spacing: 8) {
                                    Image(systemName: "arrow.turn.down.right")
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                    Text(item)
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                    }

                    Text(summary.nextAutomaticAction)
                        .font(.caption2)
                        .foregroundStyle(.secondary)

                    Text(summary.manualAction)
                        .font(.caption2)
                        .foregroundStyle(.secondary)

                    if summary.state != .healthy {
                        HStack(spacing: 10) {
                            if let recoveryBackupProfileRootPath = summary.recoveryBackupProfileRootPath,
                               let recoveryBackupLabel = summary.recoveryBackupLabel
                            {
                                Button(self.isActivatingProfile ? "Activating..." : "Restore \(recoveryBackupLabel)") {
                                    self.pendingRestoreSummary = summary
                                }
                                .disabled(self.isActivatingProfile)
                            }

                            Button(self.isRefreshingUsage ? "Refreshing..." : "Retry Refresh") {
                                self.onRefresh()
                            }
                            .disabled(self.isRefreshingUsage)

                            SettingsLink {
                                Text(summary.state == .notConfigured ? "Add Profiles" : "Open Settings")
                            }
                        }
                    }
                }
                .padding(14)
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            }
        }
        .confirmationDialog(
            self.pendingRestoreSummary?.restoreConfirmationTitle ?? "Restore managed backup?",
            isPresented: Binding(
                get: { self.pendingRestoreSummary != nil },
                set: { isPresented in
                    if !isPresented {
                        self.pendingRestoreSummary = nil
                    }
                }
            ),
            presenting: self.pendingRestoreSummary
        ) { summary in
            if let recoveryBackupProfileRootPath = summary.recoveryBackupProfileRootPath,
               let recoveryBackupLabel = summary.recoveryBackupLabel
            {
                Button("Restore \(recoveryBackupLabel)") {
                    self.onRestoreManagedBackup(summary.provider, recoveryBackupProfileRootPath)
                    self.pendingRestoreSummary = nil
                }
            }
            Button("Cancel", role: .cancel) {
                self.pendingRestoreSummary = nil
            }
        } message: { summary in
            Text(summary.restoreConfirmationDetail ?? "QuotaPilot will restore this managed backup.")
        }
    }

    private func statusLabel(for state: ProviderHealthState) -> String {
        switch state {
        case .healthy:
            "Healthy"
        case .degraded:
            "Degraded"
        case .unavailable:
            "Unavailable"
        case .notConfigured:
            "Not Configured"
        }
    }

    private func statusColor(for state: ProviderHealthState) -> Color {
        switch state {
        case .healthy:
            .green
        case .degraded:
            .orange
        case .unavailable:
            .red
        case .notConfigured:
            .secondary
        }
    }
}
