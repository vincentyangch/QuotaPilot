import SwiftUI
import QuotaPilotCore

struct RecommendationCard: View {
    let recommendation: RecommendationEngine.ProviderRecommendation
    let activationOption: RecommendationActivationOption?
    let guidedHandoffPlan: GuidedDesktopHandoffPlan?
    let isActivatingProfile: Bool
    let onActivateRecommended: (() -> Void)?

    private var title: String {
        "Best \(self.recommendation.provider.displayName) Account"
    }

    private var statusText: String {
        self.recommendation.decision.action == .recommendSwitch ? "Switch suggested" : "Current stays best"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(self.title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)

            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(self.recommendation.recommendedAccount?.label ?? "No recommendation")
                        .font(.title3.weight(.semibold))

                    if let account = self.recommendation.recommendedAccount {
                        HStack(spacing: 6) {
                            ProviderIconView(provider: account.provider, size: 14)
                            Text(account.provider.displayName)
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                Spacer()

                Text("\(self.recommendation.recommendedAccount?.primaryRemainingPercent ?? 0)%")
                    .font(.system(size: 32, weight: .bold, design: .rounded))
                    .foregroundStyle(.tint)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(self.statusText)
                    .font(.subheadline.weight(.semibold))
                Text(self.recommendation.decision.explanation)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            if let activationOption {
                Divider()

                if activationOption.isActivatable {
                    HStack(alignment: .center, spacing: 12) {
                        Text(activationOption.reason)
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        Spacer()

                        if let onActivateRecommended {
                            Button(self.isActivatingProfile ? "Activating..." : "Activate Recommended") {
                                onActivateRecommended()
                            }
                            .disabled(self.isActivatingProfile)
                        }
                    }
                } else if let guidedHandoffPlan {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Desktop Handoff Required")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)

                        Text(guidedHandoffPlan.summary)
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        if let targetProfileRootPath = guidedHandoffPlan.targetProfileRootPath {
                            Text(targetProfileRootPath)
                                .font(.caption2.monospaced())
                                .foregroundStyle(.secondary)
                                .textSelection(.enabled)
                        }

                        VStack(alignment: .leading, spacing: 6) {
                            ForEach(Array(guidedHandoffPlan.steps.enumerated()), id: \.offset) { index, step in
                                HStack(alignment: .top, spacing: 8) {
                                    Text("\(index + 1).")
                                        .font(.caption.weight(.semibold))
                                        .foregroundStyle(.secondary)
                                    Text(step)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }

                        Text(guidedHandoffPlan.nextAutomaticAction)
                            .font(.caption2)
                            .foregroundStyle(.secondary)

                        if guidedHandoffPlan.suggestsOpeningSettings {
                            SettingsLink {
                                Text("Open Settings")
                            }
                        }
                    }
                } else {
                    Text(activationOption.reason)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(18)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }
}
