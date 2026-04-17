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

    public var recoveryActionKind: TrackedProfileRecoveryActionKind? {
        switch self.lifecycleState {
        case .ready:
            nil
        case .awaitingRefresh, .authExpired, .sessionUnavailable, .usageReadFailed:
            .refreshUsage
        case .credentialsMissing:
            .openSettings
        }
    }

    public var recoveryActionTitle: String? {
        switch self.lifecycleState {
        case .awaitingRefresh:
            "Refresh Usage"
        case .authExpired, .sessionUnavailable, .usageReadFailed:
            "Retry Refresh"
        case .credentialsMissing:
            "Open Settings"
        case .ready:
            nil
        }
    }
}
