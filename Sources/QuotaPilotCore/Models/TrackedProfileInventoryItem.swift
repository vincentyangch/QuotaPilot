import Foundation

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
}
