import SwiftUI
import QuotaPilotCore

struct TrackedProfileInventorySectionView: View {
    let isActivatingProfile: Bool
    let items: [TrackedProfileInventoryItem]
    let onActivate: (TrackedProfileInventoryItem) -> Void

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

                                if item.hasLiveUsage {
                                    Text("Live")
                                        .font(.caption.weight(.medium))
                                        .foregroundStyle(.green)
                                }
                            }

                            if let identitySummary = item.identitySummary {
                                Text(identitySummary)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }

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

                            if let lastErrorDetail = item.lastErrorDetail {
                                Text(lastErrorDetail)
                                    .font(.caption2)
                                    .foregroundStyle(.orange)
                            }

                            Text(item.profileRootPath)
                                .font(.caption2.monospaced())
                                .foregroundStyle(.secondary)

                            Text(item.sourceDescription)
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }

                        Spacer()

                        if !item.isCurrentSelection {
                            Button(self.isActivatingProfile ? "Activating..." : "Activate") {
                                self.onActivate(item)
                            }
                            .disabled(self.isActivatingProfile)
                        }
                    }
                    .padding(14)
                    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                }
            }
        }
    }
}
