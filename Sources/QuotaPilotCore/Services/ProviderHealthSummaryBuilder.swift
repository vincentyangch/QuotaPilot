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
    public let affectedProfilesSummary: String?
    public let recoveryItems: [String]
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
        affectedProfilesSummary: String? = nil,
        recoveryItems: [String] = [],
        nextAutomaticAction: String,
        manualAction: String
    ) {
        self.provider = provider
        self.state = state
        self.summary = summary
        self.detail = detail
        self.affectedProfilesSummary = affectedProfilesSummary
        self.recoveryItems = recoveryItems
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
                    affectedProfilesSummary: self.affectedProfilesSummary(for: providerFailures),
                    recoveryItems: self.recoveryItems(for: providerFailures),
                    nextAutomaticAction: "QuotaPilot will retry on the next refresh.",
                    manualAction: "Work through the affected profiles below, then retry refresh."
                )
            }

            if !providerFailures.isEmpty {
                return ProviderHealthSummary(
                    provider: provider,
                    state: .degraded,
                    summary: "Loaded \(providerAccounts.count) of \(providerProfiles.count) profile(s).",
                    detail: providerFailures.first?.detail,
                    affectedProfilesSummary: self.affectedProfilesSummary(for: providerFailures),
                    recoveryItems: self.recoveryItems(for: providerFailures),
                    nextAutomaticAction: "QuotaPilot will keep using the healthy profiles and retry the failed ones on the next refresh.",
                    manualAction: "Review the affected profiles below, then refresh again."
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

    private static func affectedProfilesSummary(for failures: [AmbientUsageRefreshFailure]) -> String? {
        let labels = Array(Set(failures.map(\.profileLabel))).sorted()
        guard !labels.isEmpty else { return nil }

        let heading = labels.count == 1 ? "Affected profile" : "Affected profiles"
        return "\(heading): \(labels.joined(separator: ", "))"
    }

    private static func recoveryItems(for failures: [AmbientUsageRefreshFailure]) -> [String] {
        failures.map { failure in
            "\(failure.profileLabel): \(self.recoveryText(for: failure))"
        }
    }

    private static func recoveryText(for failure: AmbientUsageRefreshFailure) -> String {
        switch failure.kind {
        case .invalidCredentials:
            return "Repair or restore the local credentials, then refresh."
        case .noUsageData:
            return "Open the local app or CLI to renew its session, then refresh."
        case let .requestFailed(statusCode) where statusCode == 401 || statusCode == 403:
            return "Reauthenticate locally, then refresh."
        case .requestFailed:
            return "Retry refresh. If it keeps failing, check network access and provider availability."
        case .unexpected:
            return "Retry refresh. If it keeps failing, inspect the local profile source and credentials."
        }
    }
}
