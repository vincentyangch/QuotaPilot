import SwiftUI
import QuotaPilotCore

struct DashboardView: View {
    let model: AppModel

    @State private var selection: QuotaAccount.ID?

    private var selectedAccount: QuotaAccount? {
        let selectedID = self.selection ?? self.model.providerRecommendations.first?.recommendedAccount?.id
        return self.model.accounts.first(where: { $0.id == selectedID })
    }

    var body: some View {
        NavigationSplitView {
            List(selection: self.$selection) {
                ForEach(self.model.providerRecommendations) { recommendation in
                    Section(recommendation.provider.displayName) {
                        ForEach(recommendation.rankedAccounts) { scoredAccount in
                            AccountRowView(
                                account: scoredAccount.account,
                                score: scoredAccount.score,
                                isRecommended: scoredAccount.account.id == recommendation.recommendedAccount?.id,
                                showsScore: true
                            )
                            .tag(scoredAccount.account.id)
                        }
                    }
                }
            }
            .navigationTitle("Accounts")
            .listStyle(.sidebar)
        } detail: {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
                        ForEach(self.model.providerRecommendations) { recommendation in
                            RecommendationCard(recommendation: recommendation)
                        }
                    }

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
