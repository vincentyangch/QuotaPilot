import SwiftUI
import QuotaPilotCore

struct StatusMenuView: View {
    let model: AppModel

    @Environment(\.openWindow) private var openWindow

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            RecommendationCard(
                decision: self.model.decision,
                account: self.model.recommendedAccount
            )

            Divider()

            VStack(alignment: .leading, spacing: 8) {
                Text("Accounts")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)

                ForEach(self.model.rankedAccounts) { scoredAccount in
                    AccountRowView(
                        account: scoredAccount.account,
                        score: scoredAccount.score,
                        isRecommended: scoredAccount.account.id == self.model.recommendedAccount?.id,
                        showsScore: false
                    )
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
