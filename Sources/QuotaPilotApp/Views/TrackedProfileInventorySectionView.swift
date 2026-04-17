import SwiftUI
import QuotaPilotCore

struct TrackedProfileInventorySectionView: View {
    let items: [TrackedProfileInventoryItem]

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

                            if let email = item.email {
                                Text(email)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }

                            HStack(spacing: 8) {
                                if let plan = item.plan {
                                    Text(plan.uppercased())
                                        .font(.caption2.weight(.semibold))
                                        .foregroundStyle(.secondary)
                                }

                                Text(item.statusSummary)
                                    .font(.caption)
                                    .foregroundStyle(item.hasLiveUsage ? Color.secondary : Color.orange)
                            }

                            Text(item.profileRootPath)
                                .font(.caption2.monospaced())
                                .foregroundStyle(.secondary)

                            Text(item.sourceDescription)
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }

                        Spacer()
                    }
                    .padding(14)
                    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                }
            }
        }
    }
}
