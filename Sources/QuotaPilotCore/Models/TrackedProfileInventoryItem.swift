import Foundation

public enum TrackedProfileRecoveryActionKind: Equatable, Sendable {
    case refreshUsage
    case openSettings
    case restoreManagedBackup
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
    public let recoveryActionTargetProfileRootPath: String?
    public let recoveryActionBackupLabel: String?

    public init(
        provider: QuotaProvider,
        label: String,
        email: String?,
        plan: String?,
        identitySummary: String?,
        profileRootPath: String,
        sourceDescription: String,
        sourceKind: ProfileSourceKind,
        ownershipMode: ProfileOwnershipMode,
        sourceSummary: String,
        isCurrentSelection: Bool,
        hasLiveUsage: Bool,
        liveRemainingPercent: Int?,
        lifecycleState: TrackedProfileLifecycleState,
        lifecycleTitle: String,
        lifecycleDetail: String?,
        lifecycleNextAction: String,
        capabilitySummary: String,
        lastRefreshSummary: String?,
        lastErrorDetail: String?,
        statusSummary: String,
        recoveryActionTargetProfileRootPath: String? = nil,
        recoveryActionBackupLabel: String? = nil
    ) {
        self.provider = provider
        self.label = label
        self.email = email
        self.plan = plan
        self.identitySummary = identitySummary
        self.profileRootPath = profileRootPath
        self.sourceDescription = sourceDescription
        self.sourceKind = sourceKind
        self.ownershipMode = ownershipMode
        self.sourceSummary = sourceSummary
        self.isCurrentSelection = isCurrentSelection
        self.hasLiveUsage = hasLiveUsage
        self.liveRemainingPercent = liveRemainingPercent
        self.lifecycleState = lifecycleState
        self.lifecycleTitle = lifecycleTitle
        self.lifecycleDetail = lifecycleDetail
        self.lifecycleNextAction = lifecycleNextAction
        self.capabilitySummary = capabilitySummary
        self.lastRefreshSummary = lastRefreshSummary
        self.lastErrorDetail = lastErrorDetail
        self.statusSummary = statusSummary
        self.recoveryActionTargetProfileRootPath = recoveryActionTargetProfileRootPath
        self.recoveryActionBackupLabel = recoveryActionBackupLabel
    }

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

    public var restoreConfirmationTitle: String {
        "Restore managed backup?"
    }

    public var restoreConfirmationDetail: String? {
        guard let recoveryActionBackupLabel else { return nil }
        return "QuotaPilot will replace the active \(self.provider.displayName) credentials with \(recoveryActionBackupLabel), then refresh live usage."
    }

    public var recoveryActionKind: TrackedProfileRecoveryActionKind? {
        if self.recoveryActionTargetProfileRootPath != nil {
            return .restoreManagedBackup
        }

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
        if let recoveryActionBackupLabel = self.recoveryActionBackupLabel {
            return "Restore \(recoveryActionBackupLabel)"
        }

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
