import Foundation

public struct TrackedProfileInventoryItem: Identifiable, Equatable, Sendable {
    public let provider: QuotaProvider
    public let label: String
    public let email: String?
    public let plan: String?
    public let profileRootPath: String
    public let sourceDescription: String
    public let isCurrentSelection: Bool
    public let hasLiveUsage: Bool
    public let liveRemainingPercent: Int?
    public let statusSummary: String

    public var id: String {
        "\(self.provider.rawValue):\(self.profileRootPath)"
    }
}
