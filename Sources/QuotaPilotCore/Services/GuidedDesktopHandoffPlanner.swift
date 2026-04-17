import Foundation

public struct GuidedDesktopHandoffPlan: Equatable, Sendable {
    public let provider: QuotaProvider
    public let accountLabel: String
    public let summary: String
    public let targetProfileRootPath: String?
    public let steps: [String]
    public let nextAutomaticAction: String
    public let suggestsOpeningSettings: Bool

    public init(
        provider: QuotaProvider,
        accountLabel: String,
        summary: String,
        targetProfileRootPath: String?,
        steps: [String],
        nextAutomaticAction: String,
        suggestsOpeningSettings: Bool
    ) {
        self.provider = provider
        self.accountLabel = accountLabel
        self.summary = summary
        self.targetProfileRootPath = targetProfileRootPath
        self.steps = steps
        self.nextAutomaticAction = nextAutomaticAction
        self.suggestsOpeningSettings = suggestsOpeningSettings
    }
}

public enum GuidedDesktopHandoffPlanner {
    public static func makePlan(
        recommendation: RecommendationEngine.ProviderRecommendation?,
        activationOption: RecommendationActivationOption?,
        switchActionMode: SwitchActionMode
    ) -> GuidedDesktopHandoffPlan? {
        guard let recommendation,
              recommendation.decision.action == .recommendSwitch,
              let recommendedAccount = recommendation.recommendedAccount
        else {
            return nil
        }

        if let activationOption, activationOption.status == .activatable {
            return nil
        }

        let targetProfileRootPath = activationOption?.profileRootPath.isEmpty == false
            ? activationOption?.profileRootPath
            : recommendedAccount.profileRootPath

        let summary: String
        let steps: [String]
        let suggestsOpeningSettings: Bool

        switch activationOption?.status {
        case .alreadyActive:
            return nil
        case .unavailableOnThisMac:
            summary = "\(recommendedAccount.label) looks best for \(recommendation.provider.displayName), but QuotaPilot cannot switch to it automatically until that profile is available on this Mac."
            var guidedSteps = [
                "Open Settings and add the recommended profile root under Additional Profile Sources.",
            ]
            if let targetProfileRootPath, !targetProfileRootPath.isEmpty {
                guidedSteps.append("Confirm the source points to \(targetProfileRootPath).")
            }
            guidedSteps.append("Refresh live usage after the profile appears so QuotaPilot can verify the handoff.")
            steps = guidedSteps
            suggestsOpeningSettings = true
        case .activatable:
            return nil
        case nil:
            summary = "\(recommendedAccount.label) looks best for \(recommendation.provider.displayName), but QuotaPilot does not have enough local profile information to switch automatically."
            steps = [
                "Make the recommended account current in the relevant desktop app or CLI.",
                "Refresh live usage so QuotaPilot can verify the active account.",
            ]
            suggestsOpeningSettings = false
        }

        return GuidedDesktopHandoffPlan(
            provider: recommendation.provider,
            accountLabel: recommendedAccount.label,
            summary: summary,
            targetProfileRootPath: targetProfileRootPath,
            steps: steps,
            nextAutomaticAction: self.nextAutomaticActionText(for: switchActionMode),
            suggestsOpeningSettings: suggestsOpeningSettings
        )
    }

    private static func nextAutomaticActionText(for switchActionMode: SwitchActionMode) -> String {
        switch switchActionMode {
        case .recommendOnly:
            return "QuotaPilot will keep monitoring and recommending the best account, but it will not switch automatically."
        case .confirmBeforeActivatingLocalProfiles:
            return "QuotaPilot will keep monitoring and ask for confirmation once the target profile becomes locally available."
        case .autoActivateLocalProfiles:
            return "QuotaPilot will keep monitoring and auto-activate once the target profile becomes locally available and verifiable."
        }
    }
}
