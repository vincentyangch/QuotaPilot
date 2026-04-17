import SwiftUI
import QuotaPilotCore

struct PendingSwitchConfirmationsSectionView: View {
    let confirmations: [QuotaProvider: RecommendationActivationOption]
    let isActivatingProfile: Bool
    let onApprove: (QuotaProvider) -> Void
    let onDismiss: (QuotaProvider) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Pending Confirmations")
                .font(.headline)

            if self.confirmations.isEmpty {
                Text("No pending switch confirmations.")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(Array(self.confirmations.keys).sorted(by: { $0.displayName < $1.displayName }), id: \.self) { provider in
                    if let option = self.confirmations[provider] {
                        HStack(alignment: .top, spacing: 12) {
                            ProviderIconView(provider: provider, size: 16)

                            VStack(alignment: .leading, spacing: 4) {
                                Text(option.accountLabel)
                                    .fontWeight(.semibold)
                                Text(provider.displayName)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                Text(option.reason)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }

                            Spacer()

                            HStack(spacing: 8) {
                                Button(self.isActivatingProfile ? "Activating..." : "Approve") {
                                    self.onApprove(provider)
                                }
                                .disabled(self.isActivatingProfile)

                                Button("Dismiss") {
                                    self.onDismiss(provider)
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
}
