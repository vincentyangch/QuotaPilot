import SwiftUI
import QuotaPilotCore

struct RecommendationCard: View {
    let decision: RecommendationDecision
    let account: QuotaAccount?

    private var title: String {
        self.decision.action == .recommendSwitch ? "Recommended Switch" : "Current Best Account"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(self.title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)

            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(self.account?.label ?? "No recommendation")
                        .font(.title3.weight(.semibold))

                    if let account {
                        Label(account.provider.displayName, systemImage: account.provider.symbolName)
                            .foregroundStyle(.secondary)
                    }
                }

                Spacer()

                Text("\(self.account?.primaryRemainingPercent ?? 0)%")
                    .font(.system(size: 32, weight: .bold, design: .rounded))
                    .foregroundStyle(.tint)
            }

            Text(self.decision.explanation)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding(18)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }
}
