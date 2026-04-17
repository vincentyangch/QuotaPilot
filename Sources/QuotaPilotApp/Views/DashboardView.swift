import SwiftUI
import QuotaPilotCore

struct DashboardView: View {
    let model: AppModel

    @State private var selection: QuotaAccount.ID?

    private var selectedAccount: QuotaAccount? {
        let selectedID = self.selection ?? self.model.recommendedAccount?.id
        return self.model.accounts.first(where: { $0.id == selectedID }) ?? self.model.recommendedAccount
    }

    var body: some View {
        NavigationSplitView {
            List(self.model.rankedAccounts, selection: self.$selection) { scoredAccount in
                AccountRowView(
                    account: scoredAccount.account,
                    score: scoredAccount.score,
                    isRecommended: scoredAccount.account.id == self.model.recommendedAccount?.id,
                    showsScore: true
                )
                .tag(scoredAccount.account.id)
            }
            .navigationTitle("Accounts")
            .listStyle(.sidebar)
        } detail: {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    RecommendationCard(
                        decision: self.model.decision,
                        account: self.model.recommendedAccount
                    )

                    if let selectedAccount {
                        VStack(alignment: .leading, spacing: 14) {
                            Text(selectedAccount.label)
                                .font(.title2.weight(.semibold))

                            Label(selectedAccount.provider.displayName, systemImage: selectedAccount.provider.symbolName)
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
