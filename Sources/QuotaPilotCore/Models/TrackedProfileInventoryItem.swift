import Foundation

public enum TrackedProfileRecoveryActionKind: Equatable, Sendable {
    case refreshUsage
    case openSettings
}

public struct TrackedProfileInventoryItem: Identifiable, Equatable, Sendable {
    public let provider: QuotaProvider
    public let label: String
    public let email: String?
    public let plan: String?
    public let identitySummary: String?
    public let profileRootPath: String
    public let sourceDescription: String
    public let sourceKind: ProfileSourceKind
    public let ownershipMode: ProfileOwnershipMode
    public let sourceSummary: String
    public let isCurrentSelection: Bool
    public let hasLiveUsage: Bool
    public let liveRemainingPercent: Int?
    public let lifecycleState: TrackedProfileLifecycleState
    public let lifecycleTitle: String
    public let lifecycleDetail: String?
    public let lifecycleNextAction: String
    public let capabilitySummary: String
    public let lastRefreshSummary: String?
    public let lastErrorDetail: String?
    public let statusSummary: String

    public var id: String {
        "\(self.provider.rawValue):\(self.profileRootPath)"
    }

    public var activationActionTitle: String {
        self.sourceKind == .backup && self.ownershipMode == .quotaPilotManaged
            ? "Restore Backup"
            : "Activate"
    }

    public var deletionConfirmationTitle: String {
        "Delete managed backup?"
    }

    public var deletionConfirmationDetail: String {
        "QuotaPilot will permanently delete \(self.label) from its managed backup storage."
    }

    public var refreshIssueSummary: String? {
        guard self.lastErrorDetail != nil else { return nil }
        return "Latest refresh failed. QuotaPilot is showing the previous snapshot for this profile."
    }

    public var recoveryActionKind: TrackedProfileRecoveryActionKind? {
        if self.lastErrorDetail != nil {
            return .refreshUsage
        }

        switch self.lifecycleState {
        case .ready:
            return nil
        case .awaitingRefresh, .authExpired, .sessionUnavailable, .usageReadFailed:
            return .refreshUsage
        case .credentialsMissing:
            return .openSettings
        }
    }

    public var recoveryActionTitle: String? {
        if self.lastErrorDetail != nil {
            return "Retry Refresh"
        }

        switch self.lifecycleState {
        case .awaitingRefresh:
            return "Refresh Usage"
        case .authExpired, .sessionUnavailable, .usageReadFailed:
            return "Retry Refresh"
        case .credentialsMissing:
            return "Open Settings"
        case .ready:
            return nil
        }
    }
}
