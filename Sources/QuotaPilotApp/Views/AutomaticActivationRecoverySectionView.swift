import SwiftUI
import QuotaPilotCore

struct AutomaticActivationRecoverySectionView: View {
    let issues: [QuotaProvider: AutomaticActivationRecoveryIssue]
    let isRefreshingUsage: Bool
    let onRefresh: () -> Void
    let onDismiss: (QuotaProvider) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Recovery Needed")
                .font(.headline)

            ForEach(Array(self.issues.keys).sorted(by: { $0.displayName < $1.displayName }), id: \.self) { provider in
                if let issue = self.issues[provider] {
                    HStack(alignment: .top, spacing: 12) {
                        ProviderIconView(provider: provider, size: 16)

                        VStack(alignment: .leading, spacing: 4) {
                            Text(issue.accountLabel)
                                .fontWeight(.semibold)
                            Text(issue.detail)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }

                        Spacer()

                        HStack(spacing: 8) {
                            Button(self.isRefreshingUsage ? "Refreshing..." : "Retry Refresh") {
                                self.onRefresh()
                            }
                            .disabled(self.isRefreshingUsage)

                            Button("Dismiss") {
                                self.onDismiss(provider)
                            }
                        }
                    }
                    .padding(14)
                    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                }
            }
        }
    }
}
