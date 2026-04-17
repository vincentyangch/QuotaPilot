import SwiftUI
import QuotaPilotCore

struct StatusMenuView: View {
    let model: AppModel

    @Environment(\.openWindow) private var openWindow

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            ForEach(self.model.providerRecommendations) { recommendation in
                RecommendationCard(recommendation: recommendation)
            }

            Divider()

            VStack(alignment: .leading, spacing: 12) {
                Text("Accounts")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)

                ForEach(self.model.providerRecommendations) { recommendation in
                    VStack(alignment: .leading, spacing: 8) {
                        Text(recommendation.provider.displayName)
                            .font(.caption.weight(.medium))
                            .foregroundStyle(.secondary)

                        ForEach(recommendation.rankedAccounts) { scoredAccount in
                            AccountRowView(
                                account: scoredAccount.account,
                                score: scoredAccount.score,
                                isRecommended: scoredAccount.account.id == recommendation.recommendedAccount?.id,
                                showsScore: false
                            )
                        }
                    }
                }
            }

            Divider()

            HStack {
                Button("Open Dashboard") {
                    self.openWindow(id: "dashboard")
                }

                Spacer()

                Button("Reload Demo Data") {
                    self.model.reloadDemoData()
                }
            }
        }
        .padding(16)
        .frame(width: 340)
    }
}
