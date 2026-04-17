import Foundation

public enum ProviderHealthState: Equatable, Sendable {
    case healthy
    case degraded
    case unavailable
    case notConfigured
}

public struct ProviderHealthSummary: Equatable, Sendable, Identifiable {
    public let provider: QuotaProvider
    public let state: ProviderHealthState
    public let summary: String
    public let detail: String?
    public let nextAutomaticAction: String
    public let manualAction: String

    public var id: QuotaProvider {
        self.provider
    }

    public init(
        provider: QuotaProvider,
        state: ProviderHealthState,
        summary: String,
        detail: String?,
        nextAutomaticAction: String,
        manualAction: String
    ) {
        self.provider = provider
        self.state = state
        self.summary = summary
        self.detail = detail
        self.nextAutomaticAction = nextAutomaticAction
        self.manualAction = manualAction
    }
}

public enum ProviderHealthSummaryBuilder {
    public static func makeSummaries(
        discoveredProfiles: [DiscoveredLocalProfile],
        liveAccounts: [QuotaAccount],
        failures: [AmbientUsageRefreshFailure]
    ) -> [ProviderHealthSummary] {
        QuotaProvider.allCases.map { provider in
            let providerProfiles = discoveredProfiles.filter { $0.provider == provider }
            let providerAccounts = liveAccounts.filter { $0.provider == provider }
            let providerFailures = failures.filter { $0.provider == provider }

            if providerProfiles.isEmpty {
                return ProviderHealthSummary(
                    provider: provider,
                    state: .notConfigured,
                    summary: "No local profiles discovered.",
                    detail: nil,
                    nextAutomaticAction: "QuotaPilot will keep checking ambient and stored sources during refresh.",
                    manualAction: "Add a local profile source in Settings if you want to monitor \(provider.displayName)."
                )
            }

            if !providerFailures.isEmpty && providerAccounts.isEmpty {
                return ProviderHealthSummary(
                    provider: provider,
                    state: .unavailable,
                    summary: "Live usage is currently unavailable.",
                    detail: providerFailures.first?.detail,
                    nextAutomaticAction: "QuotaPilot will retry on the next refresh.",
                    manualAction: self.manualActionText(for: providerFailures.first)
                )
            }

            if !providerFailures.isEmpty {
                return ProviderHealthSummary(
                    provider: provider,
                    state: .degraded,
                    summary: "Loaded \(providerAccounts.count) of \(providerProfiles.count) profile(s).",
                    detail: providerFailures.first?.detail,
                    nextAutomaticAction: "QuotaPilot will keep using the healthy profiles and retry the failed ones on the next refresh.",
                    manualAction: self.manualActionText(for: providerFailures.first)
                )
            }

            if providerAccounts.isEmpty {
                return ProviderHealthSummary(
                    provider: provider,
                    state: .unavailable,
                    summary: "No live usage windows were returned.",
                    detail: nil,
                    nextAutomaticAction: "QuotaPilot will retry on the next refresh.",
                    manualAction: "Refresh live usage again after confirming the local profile still has an active session."
                )
            }

            return ProviderHealthSummary(
                provider: provider,
                state: .healthy,
                summary: "Loaded \(providerAccounts.count) live profile(s).",
                detail: nil,
                nextAutomaticAction: "QuotaPilot will keep monitoring these profiles during scheduled refreshes.",
                manualAction: "No manual action needed right now."
            )
        }
    }

    private static func manualActionText(for failure: AmbientUsageRefreshFailure?) -> String {
        guard let failure else {
            return "Refresh live usage again after checking the local profile."
        }

        switch failure.kind {
        case .invalidCredentials:
            return "Refresh or repair the local \(failure.provider.displayName) credentials, then retry."
        case .noUsageData:
            return "Open the local app or CLI for this account to renew its session, then retry refresh."
        case let .requestFailed(statusCode) where statusCode == 401 || statusCode == 403:
            return "Reauthenticate \(failure.provider.displayName) locally, then retry."
        case .requestFailed:
            return "Retry refresh. If it keeps failing, check network access and provider availability."
        case .unexpected:
            return "Retry refresh. If it keeps failing, inspect the local profile source and credentials."
        }
    }
}
