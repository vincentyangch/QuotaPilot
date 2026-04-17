import SwiftUI
import QuotaPilotCore

struct AccountRowView: View {
    let account: QuotaAccount
    let score: Int?
    let isRecommended: Bool
    let showsScore: Bool

    var body: some View {
        HStack(spacing: 12) {
            ProviderIconView(
                provider: self.account.provider,
                size: 18,
                tint: self.isRecommended ? .accentColor : .secondary
            )
            .frame(width: 22)

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 8) {
                    Text(self.account.label)
                        .fontWeight(self.isRecommended ? .semibold : .regular)

                    if self.account.isCurrent {
                        Text("Current")
                            .font(.caption.weight(.medium))
                            .foregroundStyle(.secondary)
                    }
                }

                Text("\(self.account.primaryRemainingPercent)% remaining")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            if self.showsScore, let score {
                Text("\(score)")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(.quaternary, in: Capsule())
            }

            if self.isRecommended {
                Text("Best")
                    .font(.caption.weight(.semibold))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(.tint.opacity(0.15), in: Capsule())
            }
        }
        .padding(.vertical, 4)
    }
}
